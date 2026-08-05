/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */


import { PiPWindow } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { PlayConstants } from '@ohos/common/src/main/ets/constants/player/PlayConstants';
import { HiLog } from '@ohos/common/src/main/ets/utils/HiLog';
import WindowUtil from '@ohos/common/src/main/ets/utils/WindowUtil';
import { VideoPlayerController } from '../controller/VideoPlayerController';
import { VideoPipConstants, VideoPipContentSize } from '../constants/VideoPipConstants';
import { IVideoPipSystemLockDelegate } from '../session/VideoPlaybackSession';

const TAG: string = 'VideoPipViewModel';
/** 迁窗结束后再动 UI，避开「闪一下就消失」 */
const PIP_VISUAL_SETTLE_MS: number = 420;

/** 由页面提供当前视频内容尺寸的回调 */
export type VideoPipContentSizeProvider = () => VideoPipContentSize;

/**
 * 视频画中画 ViewModel：XComponent 就绪后 setAutoStartEnabled，回桌面由系统拉起小窗。
 */
export class VideoPipViewModel implements IVideoPipSystemLockDelegate {
  private readonly videoController: VideoPlayerController;
  private pipController: PiPWindow.PiPController | undefined = undefined;
  private xComponentController: XComponentController | undefined = undefined;
  private hostContext: Context | undefined = undefined;
  private contentSizeProvider: VideoPipContentSizeProvider | undefined = undefined;
  private pipSessionActive: boolean = false;
  private autoPipArmed: boolean = false;
  private phoneCallSuspended: boolean = false;
  private autoPipArmedBeforeCall: boolean = false;
  /** 系统锁屏导致暂停，回桌面后需在 PiP 续播 */
  private pendingResumeOnDesktop: boolean = false;
  private lastContentWidth: number = 0;
  private lastContentHeight: number = 0;
  private lastPipSurfaceWidth: number = 0;
  private lastPipSurfaceHeight: number = 0;
  private pendingForegroundRestore: boolean = false;
  /**
   * 仅 ABOUT_TO_STOP/RESTORE 冻结。
   * 日志：仅收到 state=1 未收到 STARTED 时，若 ABOUT_TO_START 也冻结，则全程无法 sync →
   * bounds=1146×480 / dst=860×361 黑遮罩。
   */
  private pipSurfaceTeardownFreeze: boolean = false;
  private pipStartSyncTimerId: number = -1;
  private pipVisualSettleTimerId: number = -1;
  private foregroundSurfaceProvider: (() => string) | undefined = undefined;
  private readonly controlEventHandler = (control: PiPWindow.ControlEventParam): void => {
    this.handlePipControlEvent(control);
  };
  private readonly stateChangeHandler = (state: PiPWindow.PiPState, reason: string): void => {
    this.handlePipStateChange(state, reason);
  };
  private readonly pipWindowSizeChangeHandler = (size: PiPWindow.PiPWindowSize): void => {
    this.handlePipWindowSizeChange(size);
  };

  /**
   * @param videoController 视频播放控制器，用于 PiP 面板播控与后台播放豁免
   */
  public constructor(videoController: VideoPlayerController) {
    this.videoController = videoController;
  }

  /**
   * 绑定页面上下文与内容尺寸提供方。
   *
   * @param context UIAbility 上下文
   * @param contentSizeProvider 返回当前视频内容宽高的回调
   */
  public bindHost(context: Context, contentSizeProvider: VideoPipContentSizeProvider): void {
    this.hostContext = context;
    this.contentSizeProvider = contentSizeProvider;
    HiLog.i(TAG, `bindHost pipEnabled=${PiPWindow.isPiPEnabled()}`);
  }

  /**
   * 注册视频 XComponent 控制器，须与 AVVideoPlayer 内实例一致方可迁移画面。
   *
   * @param controller XComponent 控制器
   */
  public setXComponentController(controller: XComponentController): void {
    this.xComponentController = controller;
    this.videoController.setXComponentController(controller);
    HiLog.i(TAG, 'setXComponentController ready=true');
  }

  /**
   * Surface 就绪后注册 PiP：用户按 Home / 回桌面时由系统自动进入小窗。
   */
  public async prepareAutoPipOnHome(): Promise<void> {
    HiLog.i(TAG, 'prepareAutoPipOnHome start');
    if (!PiPWindow.isPiPEnabled()) {
      HiLog.w(TAG, 'prepareAutoPipOnHome aborted deviceNotSupported');
      return;
    }
    const ready = await this.ensurePipController();
    if (!ready || this.pipController === undefined) {
      HiLog.w(TAG, 'prepareAutoPipOnHome aborted controllerNotReady');
      return;
    }
    try {
      this.refreshContentSize();
      this.pipController.setAutoStartEnabled(true);
      this.autoPipArmed = true;
      this.syncBackgroundExempt();
      this.syncPlaybackControlState(this.videoController.playState);
      HiLog.i(TAG, 'prepareAutoPipOnHome autoStartEnabled=true');
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      const code = (error as BusinessError).code;
      HiLog.e(TAG, `prepareAutoPipOnHome failed code=${code} message=${message}`);
      this.autoPipArmed = false;
      this.syncBackgroundExempt();
    }
  }

  /**
   * 回桌面前刷新 PiP 比例，并在已武装/小窗活动中时跳过页面层 pause。
   *
   * @returns 是否应跳过退后台暂停
   */
  public onAppBackground(): boolean {
    if (this.phoneCallSuspended) {
      HiLog.i(TAG, 'onAppBackground phoneCallSuspended=true deferPause=false');
      return false;
    }
    this.refreshContentSize();
    const deferPause = this.pipSessionActive || this.autoPipArmed;
    if (deferPause) {
      HiLog.i(TAG, `onAppBackground deferPause pipSession=${this.pipSessionActive} autoArmed=${this.autoPipArmed}`);
    }
    return deferPause;
  }

  /**
   * 系统锁屏：正在播放时暂停，并标记回桌面后需在 PiP 续播。
   */
  public onSystemScreenLocked(): void {
    if (this.videoController.playState !== PlayConstants.STATUS_START) {
      HiLog.i(TAG, `onSystemScreenLocked skipped playState=${this.videoController.playState}`);
      return;
    }
    this.pendingResumeOnDesktop = true;
    this.videoController.pause();
    this.syncPlaybackControlState(PlayConstants.STATUS_PAUSE);
    HiLog.i(TAG, `onSystemScreenLocked pausePlayback pipSession=${this.pipSessionActive}`);
  }

  /**
   * 系统解锁：应用内直接续播；已在桌面则在 PiP 小窗续播。
   *
   * @param isAppInBackground 应用是否处于后台（桌面/多任务）
   */
  public onSystemScreenUnlocked(isAppInBackground: boolean): void {
    if (!this.pendingResumeOnDesktop) {
      HiLog.i(TAG, 'onSystemScreenUnlocked skipped noPendingResume');
      return;
    }
    HiLog.i(TAG, `onSystemScreenUnlocked isAppInBackground=${isAppInBackground} pipSession=${this.pipSessionActive}`);
    if (isAppInBackground) {
      this.tryResumeAfterLockOnDesktop();
      return;
    }
    this.tryResumeAfterLockInApp();
  }

  /**
   * 来电中断：关闭自动画中画并停止小窗，避免接听界面出现画中画。
   */
  public suspendForPhoneCall(): void {
    this.phoneCallSuspended = true;
    this.autoPipArmedBeforeCall = this.autoPipArmed;
    if (this.pipController !== undefined) {
      try {
        this.pipController.setAutoStartEnabled(false);
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        HiLog.w(TAG, `suspendForPhoneCall setAutoStartEnabled false failed message=${message}`);
      }
    }
    this.autoPipArmed = false;
    if (this.pipSessionActive && this.pipController !== undefined) {
      void this.pipController.stopPiP().catch((error: BusinessError) => {
        HiLog.w(TAG, `suspendForPhoneCall stopPiP failed code=${error.code}`);
      });
    }
    this.syncBackgroundExempt();
    HiLog.i(TAG, 'suspendForPhoneCall done');
  }

  /**
   * 通话结束：恢复来电前的自动画中画武装状态。
   */
  public restoreAfterPhoneCall(): void {
    if (!this.phoneCallSuspended) {
      return;
    }
    this.phoneCallSuspended = false;
    if (this.autoPipArmedBeforeCall && this.pipController !== undefined) {
      try {
        this.pipController.setAutoStartEnabled(true);
        this.autoPipArmed = true;
        HiLog.i(TAG, 'restoreAfterPhoneCall autoStartEnabled=true');
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        HiLog.w(TAG, `restoreAfterPhoneCall failed message=${message}`);
      }
    }
    this.autoPipArmedBeforeCall = false;
    this.syncBackgroundExempt();
  }

  /**
   * 从多任务/桌面回到应用：结束画中画并将画面迁回主窗口 Surface
   *
   * @param surfaceIdProvider 主窗口 Surface ID 提供方
   */
  public async onAppForeground(surfaceIdProvider: () => string): Promise<void> {
    const wasPipActive = this.pipSessionActive;
    HiLog.i(TAG, `onAppForeground pipSession=${this.pipSessionActive} autoArmed=${this.autoPipArmed}`);
    this.foregroundSurfaceProvider = surfaceIdProvider;
    if (this.pipController !== undefined && wasPipActive) {
      this.pendingForegroundRestore = true;
      this.beginPipTransitionQuiet();
      try {
        await this.pipController.stopPiP();
        HiLog.i(TAG, 'onAppForeground stopPiP success');
        // 优先交给 STOPPED 的 settle；超时未到则兜底
        if (this.pendingForegroundRestore) {
          setTimeout((): void => {
            if (this.pendingForegroundRestore) {
              this.pendingForegroundRestore = false;
              this.endPipTransitionQuietAfterSettle((): void => {
                this.restoreMainSurfaceIfNeeded();
                this.videoController.setPipSessionVisualActive(false);
              });
            }
          }, PIP_VISUAL_SETTLE_MS + 80);
        }
      } catch (error) {
        this.pendingForegroundRestore = false;
        WindowUtil.setPipTransitionQuiet(false);
        this.videoController.setPipSessionVisualActive(false);
        const message = error instanceof Error ? error.message : String(error);
        const code = (error as BusinessError).code;
        HiLog.w(TAG, `onAppForeground stopPiP failed code=${code} message=${message}`);
      }
    }
    if (!wasPipActive) {
      this.restoreMainSurfaceIfNeeded();
    }
    if (this.pipController !== undefined && this.autoPipArmed) {
      try {
        this.pipController.setAutoStartEnabled(true);
        HiLog.i(TAG, 'onAppForeground autoStartEnabled=true');
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        HiLog.w(TAG, `onAppForeground setAutoStartEnabled failed message=${message}`);
      }
    }
    this.syncBackgroundExempt();
  }

  /**
   * 解析主窗口 XComponent Surface ID（优先控制器实例）
   *
   * @param fallbackProvider 页面 @State 兜底
   * @returns Surface ID
   */
  private resolveMainSurfaceId(fallbackProvider: () => string): string {
    if (this.xComponentController !== undefined) {
      const fromComponent = this.xComponentController.getXComponentSurfaceId();
      if (fromComponent.length > 0) {
        return fromComponent;
      }
    }
    return fallbackProvider();
  }

  /**
   * 窗口尺寸或切歌后刷新 PiP 比例（尺寸未变则跳过系统调用）。
   */
  public refreshContentSize(): void {
    if (this.pipController === undefined || this.contentSizeProvider === undefined) {
      return;
    }
    const size = this.resolveContentSize();
    if (size.width === this.lastContentWidth && size.height === this.lastContentHeight) {
      return;
    }
    try {
      this.pipController.updateContentSize(size.width, size.height);
      this.lastContentWidth = size.width;
      this.lastContentHeight = size.height;
      HiLog.i(TAG, `refreshContentSize width=${size.width} height=${size.height}`);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      HiLog.w(TAG, `refreshContentSize failed message=${message}`);
    }
  }

  /**
   * 将主界面播放状态同步到 PiP 控制面板播放/暂停按钮。
   *
   * @param playState 当前播放状态（PlayConstants.STATUS_*）
   */
  public syncPlaybackControlState(playState: number): void {
    if (this.pipController === undefined) {
      return;
    }
    const status = playState === PlayConstants.STATUS_START ?
      PiPWindow.PiPControlStatus.PLAY : PiPWindow.PiPControlStatus.PAUSE;
    try {
      this.pipController.updatePiPControlStatus(PiPWindow.PiPControlType.VIDEO_PLAY_PAUSE, status);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      HiLog.w(TAG, `syncPlaybackControlState failed message=${message}`);
    }
  }

  /**
   * 页面销毁：注销监听并停止画中画，避免泄漏与重复小窗。
   */
  public async release(): Promise<void> {
    HiLog.i(TAG, `release start sessionActive=${this.pipSessionActive} autoArmed=${this.autoPipArmed}`);
    if (this.pipController !== undefined) {
      try {
        this.pipController.setAutoStartEnabled(false);
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        HiLog.w(TAG, `release setAutoStartEnabled false failed message=${message}`);
      }
      this.pipController.off('stateChange');
      this.pipController.off('controlEvent', this.controlEventHandler);
      this.pipController.off('pipWindowSizeChange', this.pipWindowSizeChangeHandler);
      try {
        await this.pipController.stopPiP();
        HiLog.i(TAG, 'release stopPiP success');
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        const code = (error as BusinessError).code;
        HiLog.w(TAG, `release stopPiP failed code=${code} message=${message}`);
      }
      this.pipController = undefined;
    }
    this.videoController.setPipBreakHwcForced(false);
    this.videoController.restoreDefaultSurfaceSize();
    this.autoPipArmed = false;
    this.pipSessionActive = false;
    this.clearLockResumeState();
    this.lastContentWidth = 0;
    this.lastContentHeight = 0;
    this.lastPipSurfaceWidth = 0;
    this.lastPipSurfaceHeight = 0;
    this.syncBackgroundExempt();
  }

  /**
   * 懒创建 PiP 控制器并注册生命周期与播控回调。
   *
   * @returns 控制器是否可用
   */
  private async ensurePipController(): Promise<boolean> {
    if (this.pipController !== undefined) {
      return true;
    }
    if (this.xComponentController === undefined || this.hostContext === undefined) {
      HiLog.w(TAG, 'ensurePipController aborted missingXComponentOrContext');
      return false;
    }
    const size = this.resolveContentSize();
    const config: PiPWindow.PiPConfiguration = {
      context: this.hostContext,
      componentController: this.xComponentController,
      templateType: PiPWindow.PiPTemplateType.VIDEO_PLAY,
      contentWidth: size.width,
      contentHeight: size.height,
    };
    try {
      this.pipController = await PiPWindow.create(config);
      this.pipController.on('stateChange', this.stateChangeHandler);
      this.pipController.on('controlEvent', this.controlEventHandler);
      this.pipController.on('pipWindowSizeChange', this.pipWindowSizeChangeHandler);
      this.lastContentWidth = size.width;
      this.lastContentHeight = size.height;
      HiLog.i(TAG, `ensurePipController success width=${size.width} height=${size.height}`);
      return true;
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      const code = (error as BusinessError).code;
      HiLog.e(TAG, `ensurePipController failed code=${code} message=${message}`);
      this.pipController = undefined;
      return false;
    }
  }

  /**
   * 解析画中画内容尺寸，由页面 provider 提供；无效时回退 16:9 默认值。
   */
  private resolveContentSize(): VideoPipContentSize {
    if (this.contentSizeProvider !== undefined) {
      const size = this.contentSizeProvider();
      if (size.width > 0 && size.height > 0) {
        return size;
      }
    }
    const defaultSize: VideoPipContentSize = {
      width: VideoPipConstants.DEFAULT_CONTENT_WIDTH_PX,
      height: VideoPipConstants.DEFAULT_CONTENT_HEIGHT_PX,
    };
    return defaultSize;
  }

  /**
   * PiP 生命周期回调：维护会话标记与后台播放豁免。
   */
  private clearPipStartSyncTimer(): void {
    if (this.pipStartSyncTimerId !== -1) {
      clearTimeout(this.pipStartSyncTimerId);
      this.pipStartSyncTimerId = -1;
    }
  }

  private clearPipVisualSettleTimer(): void {
    if (this.pipVisualSettleTimerId !== -1) {
      clearTimeout(this.pipVisualSettleTimerId);
      this.pipVisualSettleTimerId = -1;
    }
  }

  /** 迁窗静默：禁止壳层刷色 + 禁止改 UI/@State（会触发一帧黑闪） */
  private beginPipTransitionQuiet(): void {
    WindowUtil.setPipTransitionQuiet(true);
    WindowUtil.setVideoPlayerPageActive(true);
    this.videoController.ensureVideoWindowBackgroundBlack();
  }

  private endPipTransitionQuietAfterSettle(onSettled?: () => void): void {
    this.clearPipVisualSettleTimer();
    this.pipVisualSettleTimerId = setTimeout((): void => {
      this.pipVisualSettleTimerId = -1;
      WindowUtil.setPipTransitionQuiet(false);
      if (onSettled !== undefined) {
        onSettled();
      }
      HiLog.i(TAG, 'pipTransitionQuiet ended layoutFix=v12');
    }, PIP_VISUAL_SETTLE_MS);
  }

  private handlePipStateChange(state: PiPWindow.PiPState, reason: string): void {
    HiLog.i(TAG, `stateChange state=${state} reason=${reason}`);
    if (state === PiPWindow.PiPState.ABOUT_TO_START) {
      // 迁窗期零 UI 变更：不 refreshContentSize / 不改 breakHwc / 不改 @State
      this.pipSurfaceTeardownFreeze = true;
      this.pipSessionActive = true;
      this.beginPipTransitionQuiet();
      this.syncBackgroundExempt();
      return;
    }
    if (state === PiPWindow.PiPState.STARTED) {
      this.pipSessionActive = true;
      this.pipSurfaceTeardownFreeze = true;
      this.clearPipStartSyncTimer();
      this.syncBackgroundExempt();
      this.syncPlaybackControlState(this.videoController.playState);
      this.tryResumeAfterLockOnDesktop();
      // 动画停稳后再动视觉标记
      this.endPipTransitionQuietAfterSettle((): void => {
        if (this.pipSessionActive) {
          this.videoController.setPipBreakHwcForced(true);
          this.videoController.setPipSessionVisualActive(true);
        }
      });
      return;
    }
    if (state === PiPWindow.PiPState.ABOUT_TO_RESTORE || state === PiPWindow.PiPState.ABOUT_TO_STOP) {
      this.pipSurfaceTeardownFreeze = true;
      this.clearPipStartSyncTimer();
      this.clearPipVisualSettleTimer();
      this.beginPipTransitionQuiet();
      HiLog.i(TAG, `pipTeardown quiet state=${state} layoutFix=v12`);
      return;
    }
    if (state === PiPWindow.PiPState.STOPPED) {
      this.pipSessionActive = false;
      this.pipSurfaceTeardownFreeze = true;
      this.clearPipStartSyncTimer();
      this.lastPipSurfaceWidth = 0;
      this.lastPipSurfaceHeight = 0;
      this.syncBackgroundExempt();
      const needRestore = this.pendingForegroundRestore;
      this.pendingForegroundRestore = false;
      // 等系统迁窗动画结束再改 UI / 重绑 Surface，避免「闪一下就没」
      this.endPipTransitionQuietAfterSettle((): void => {
        this.videoController.setPipBreakHwcForced(false);
        this.videoController.setPipSessionVisualActive(false);
        this.videoController.ensureVideoWindowBackgroundBlack();
        if (needRestore) {
          this.restoreMainSurfaceIfNeeded();
        }
      });
      if (reason === 'panelActionDelete' || reason === 'dragDelete') {
        this.videoController.pause();
        HiLog.i(TAG, `pipStopped reason=${reason} pausePlayback`);
      }
      return;
    }
    if (state === PiPWindow.PiPState.ERROR) {
      this.pipSessionActive = false;
      this.pipSurfaceTeardownFreeze = true;
      this.clearPipStartSyncTimer();
      this.clearPipVisualSettleTimer();
      this.lastPipSurfaceWidth = 0;
      this.lastPipSurfaceHeight = 0;
      WindowUtil.setPipTransitionQuiet(false);
      this.videoController.setPipBreakHwcForced(false);
      this.videoController.setPipSessionVisualActive(false);
      this.videoController.ensureVideoWindowBackgroundBlack();
      this.syncBackgroundExempt();
    }
  }

  /**
   * 不再跟 sizeChange 改 Surface：日志证明 setXComponentSurfaceSize 会黑闪。
   */
  private handlePipWindowSizeChange(size: PiPWindow.PiPWindowSize): void {
    HiLog.i(TAG,
      `pipWindowSizeChange ignored ${size.width}x${size.height} layoutFix=v12`);
  }

  /**
   * PiP 控制面板点击：将系统播控动作委托给视频控制器。
   */
  private handlePipControlEvent(control: PiPWindow.ControlEventParam): void {
    HiLog.i(TAG, `controlEvent type=${control.controlType} status=${control.status}`);
    if (control.controlType === PiPWindow.PiPControlType.VIDEO_PLAY_PAUSE) {
      if (control.status === PiPWindow.PiPControlStatus.PAUSE) {
        this.clearLockResumeState();
        this.videoController.pause();
      } else if (control.status === PiPWindow.PiPControlStatus.PLAY) {
        this.videoController.play();
      }
    }
  }

  /** 同步 Controller 后台播放豁免（小窗活动中或已武装自动 PiP） */
  private syncBackgroundExempt(): void {
    this.videoController.setPipBackgroundExempt(this.pipSessionActive || this.autoPipArmed);
  }

  /**
   * 锁屏暂停后仍在应用内解锁：主界面直接恢复播放。
   */
  private tryResumeAfterLockInApp(): void {
    if (!this.pendingResumeOnDesktop) {
      return;
    }
    if (this.videoController.playState === PlayConstants.STATUS_START) {
      this.clearLockResumeState();
      return;
    }
    this.videoController.play();
    this.syncPlaybackControlState(PlayConstants.STATUS_START);
    this.clearLockResumeState();
    HiLog.i(TAG, 'tryResumeAfterLockInApp playInApp');
  }

  /**
   * 锁屏暂停后回到桌面：PiP 已可见则恢复播放。
   */
  private tryResumeAfterLockOnDesktop(): void {
    if (!this.pendingResumeOnDesktop) {
      return;
    }
    if (this.videoController.playState === PlayConstants.STATUS_START) {
      this.clearLockResumeState();
      return;
    }
    if (!this.pipSessionActive && !this.autoPipArmed) {
      HiLog.w(TAG, 'tryResumeAfterLockOnDesktop skipped pipNotReady');
      return;
    }
    this.videoController.play();
    this.syncPlaybackControlState(PlayConstants.STATUS_START);
    this.clearLockResumeState();
    HiLog.i(TAG, 'tryResumeAfterLockOnDesktop playInPip');
  }

  /** 清除系统锁屏续播标记 */
  private clearLockResumeState(): void {
    this.pendingResumeOnDesktop = false;
  }

  /**
   * 将 AVPlayer 画面绑回主窗口 XComponent（画中画结束或回前台后）
   */
  private restoreMainSurfaceIfNeeded(): void {
    const provider = this.foregroundSurfaceProvider ?? ((): string => '');
    const surfaceId = this.resolveMainSurfaceId(provider);
    if (surfaceId.length > 0) {
      this.videoController.restoreMainSurfaceAfterPip(surfaceId);
      HiLog.i(TAG, `restoreMainSurfaceIfNeeded surfaceId=${surfaceId}`);
      return;
    }
    HiLog.w(TAG, 'restoreMainSurfaceIfNeeded skipped emptySurfaceId');
  }
}
