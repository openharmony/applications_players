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


import window from '@ohos.window';
import { Constants, LoadingStatus, WindowType } from '@ohos/common/src/main/ets/constants/ui/Constants';
import { PlayConstants } from '@ohos/common/src/main/ets/constants/player/PlayConstants';
import { VideoPlayerController } from '../controller/VideoPlayerController';
import { HiLog } from '@ohos/common/src/main/ets/utils/HiLog';
import { systemDateTime } from '@kit.BasicServicesKit';

const TAG: string = 'VideoPlaybackViewModel';

/** 视频播放页 UI 状态快照，供 VideoPlayPage 通过 @State 绑定刷新。 */
export interface VideoPlaybackUiState {
  isProgressHide: boolean;
  isLandscapeMode: boolean;
  isFullScreen: boolean;
  toolbarTransitionEnabled: boolean;
  isScreenLocked: boolean;
  showUnlockAffordance: boolean;
}

/**
 * 视频播放 ViewModel：独立维护视频交互状态和控制器，避免复用音频播放会话。
 */
export class VideoPlaybackViewModel {
  private readonly videoController: VideoPlayerController;
  private uiListeners: ((state: VideoPlaybackUiState) => void)[] = [];
  private loadingStatus: LoadingStatus = LoadingStatus.LOAD_STATE_LOADING;
  private state: VideoPlaybackUiState = VideoPlaybackViewModel.createInitialState();
  private unlockAffordanceTimerId: number = -1;

  /**
   * 创建视频播放 ViewModel，可注入页面持有的控制器以保持 ArkUI 绑定实例稳定。
   *
   * @param controller 视频播放控制器
   */
  public constructor(controller?: VideoPlayerController) {
    this.videoController = controller ?? new VideoPlayerController();
  }

  /**
   * 获取视频专属控制器。
   *
   * @returns VideoPlayerController 实例
   */
  public getController(): VideoPlayerController {
    return this.videoController;
  }

  /**
   * 注册 UI 状态监听。
   *
   * @param listener 状态变化回调
   */
  public addUiStateListener(listener: (state: VideoPlaybackUiState) => void): void {
    if (this.uiListeners.indexOf(listener) < 0) {
      this.uiListeners.push(listener);
    }
  }

  /**
   * 移除 UI 状态监听。
   *
   * @param listener 已注册的状态变化回调
   */
  public removeUiStateListener(listener: (state: VideoPlaybackUiState) => void): void {
    const index = this.uiListeners.indexOf(listener);
    if (index >= 0) {
      this.uiListeners.splice(index, 1);
    }
  }

  /**
   * 绑定播放器本地存储，保持视频控制器与页面使用同一个 LocalStorage。
   *
   * @param storage 页面本地存储
   */
  public bindStorage(storage: LocalStorage): void {
    this.videoController.bindStorage(storage);
  }

  /**
   * 记录加载状态，用于首帧前禁用控制区转场，避免进入视频时闪屏。
   *
   * @param status 当前加载状态
   */
  public setLoadingStatus(status: LoadingStatus): void {
    this.loadingStatus = status;
  }

  /**
   * 同步横竖屏状态。
   *
   * @param isLandscapeMode 是否横屏
   * @param reason 状态来源
   */
  public setLandscapeMode(isLandscapeMode: boolean, reason: string): void {
    if (this.state.isLandscapeMode === isLandscapeMode) {
      return;
    }
    this.state.isLandscapeMode = isLandscapeMode;
    HiLog.i(TAG, `setLandscapeMode value=${isLandscapeMode} reason=${reason}`);
    this.notifyUiState();
  }

  /**
   * 同步沉浸式全屏状态。
   *
   * @param isFullScreen 是否全屏
   */
  public setFullScreen(isFullScreen: boolean): void {
    if (this.state.isFullScreen === isFullScreen) {
      return;
    }
    this.state.isFullScreen = isFullScreen;
    HiLog.i(TAG, `setFullScreen value=${isFullScreen}`);
    this.notifyUiState();
  }

  /**
   * 同步控制区隐藏状态，并在首帧加载完成后再启用浮层转场。
   *
   * @param isProgressHide 控制区是否隐藏
   * @param loadingStatus 当前加载状态
   */
  public syncControlsHidden(isProgressHide: boolean, loadingStatus: LoadingStatus): void {
    this.loadingStatus = loadingStatus;
    this.videoController.setVideoFullScene(isProgressHide);
    const canAnimateToolbar = loadingStatus === LoadingStatus.LOAD_STATE_SUCCESS;
    if (this.state.isProgressHide === isProgressHide &&
      this.state.toolbarTransitionEnabled === canAnimateToolbar) {
      return;
    }
    this.state.isProgressHide = isProgressHide;
    this.state.toolbarTransitionEnabled = canAnimateToolbar;
    HiLog.i(TAG, `syncControlsHidden hidden=${isProgressHide} canAnimate=${canAnimateToolbar}`);
    this.notifyUiState();
  }

  /**
   * 判断是否竖屏视频布局；竖屏与横屏均使用 Stack 浮层控制区，视频区尺寸恒定。
   *
   * @param isPCConfig 是否 PC 配置
   * @returns 是否竖屏视频布局
   */
  public isPortraitPanelMode(isPCConfig: boolean): boolean {
    return !isPCConfig && !this.state.isLandscapeMode;
  }

  /**
   * 判断标题栏浮层是否应该显示。
   *
   * @param isPCConfig 是否 PC 配置
   * @param windowType 当前窗口类型
   * @param isImmersion 是否 PC 沉浸全屏
   * @returns 是否显示标题栏浮层
   */
  public shouldShowTitleOverlay(isPCConfig: boolean, windowType: WindowType, isImmersion: boolean): boolean {
    if (this.isPortraitPanelMode(isPCConfig) || windowType !== WindowType.MAIN_WINDOW) {
      return false;
    }
    return !this.state.isProgressHide || (isPCConfig && !isImmersion);
  }

  /**
   * 判断系统栏是否显示；横屏主视频始终隐藏系统栏，避免状态栏切换造成顶部闪屏。
   *
   * @param isPCConfig 是否 PC 配置
   * @param windowType 当前窗口类型
   * @returns 是否显示系统栏
   */
  public shouldShowSystemBars(isPCConfig: boolean, windowType: WindowType): boolean {
    if (isPCConfig) {
      return false;
    }
    return this.isPortraitPanelMode(isPCConfig) && windowType === WindowType.MAIN_WINDOW;
  }

  /**
   * 计算横屏底部控制区位置，控制区作为浮层覆盖在视频上，不挤压 XComponent。
   *
   * @param videoPlayerSize 视频承载区域尺寸
   * @param toolbarHeight 控制区测量高度
   * @returns 底部控制区 y 偏移
   */
  public getLandscapeProgressPanelOffsetY(videoPlayerSize: window.Size, toolbarHeight: number): number {
    if (videoPlayerSize.height <= 0 || toolbarHeight <= 0) {
      return Constants.ORIGIN_Y;
    }
    return Math.max(Constants.ORIGIN_Y, videoPlayerSize.height - toolbarHeight);
  }

  /**
   * 用户操作后显示控制区并重新开始 4 秒自动隐藏计时。
   *
   * @param timestamp 交互时间戳
   */
  public showControlsAndScheduleHide(timestamp: number): void {
    if (this.state.isScreenLocked) {
      return;
    }
    HiLog.i(TAG, `showControlsAndScheduleHide timestamp=${timestamp}`);
    this.videoController.setProgressHide(timestamp, false);
  }

  /**
   * 用户点击视频区域时切换控制区显隐。
   *
   * @param timestamp 交互时间戳
   * @param isCurrentlyHidden 当前是否隐藏
   */
  public toggleControls(timestamp: number, isCurrentlyHidden: boolean): void {
    if (this.state.isScreenLocked) {
      HiLog.w(TAG, `toggleControls ignored screenLocked=true`);
      return;
    }
    HiLog.i(TAG, `toggleControls timestamp=${timestamp} hidden=${isCurrentlyHidden}`);
    const targetHidden = !isCurrentlyHidden;
    this.videoController.setProgressHide(targetHidden ? 0 : timestamp, targetHidden);
  }

  /**
   * 锁定视频画面：隐藏控制区并展示锁屏解锁入口。
   */
  public lockScreen(): void {
    HiLog.i(TAG, `lockScreen start locked=${this.state.isScreenLocked}`);
    if (this.state.isScreenLocked) {
      return;
    }
    this.clearUnlockAffordanceTimer();
    this.videoController.clearHideEvent();
    this.state.isScreenLocked = true;
    this.state.showUnlockAffordance = true;
    this.videoController.setProgressHide(0, true);
    this.scheduleUnlockAffordanceHide();
    HiLog.i(TAG, 'lockScreen success affordanceVisible=true');
    this.notifyUiState();
  }

  /**
   * 解锁视频画面并恢复控制区。
   */
  public unlockScreen(): void {
    HiLog.i(TAG, `unlockScreen start locked=${this.state.isScreenLocked}`);
    if (!this.state.isScreenLocked) {
      return;
    }
    this.clearUnlockAffordanceTimer();
    this.state.isScreenLocked = false;
    this.state.showUnlockAffordance = false;
    this.videoController.setProgressHide(systemDateTime.getTime(), false);
    HiLog.i(TAG, 'unlockScreen success controlsVisible=true');
    this.notifyUiState();
  }

  /**
   * 锁屏态下用户交互：展示锁定图标并重新计时 4 秒自动隐藏。
   */
  public onLockedScreenInteraction(): void {
    if (!this.state.isScreenLocked) {
      return;
    }
    const wasVisible = this.state.showUnlockAffordance;
    this.state.showUnlockAffordance = true;
    this.scheduleUnlockAffordanceHide();
    if (!wasVisible) {
      HiLog.i(TAG, 'onLockedScreenInteraction showLockAffordance=true');
      this.notifyUiState();
    }
  }

  /**
   * 退出视频页或切歌时重置锁屏状态。
   */
  public resetScreenLock(): void {
    if (!this.state.isScreenLocked && !this.state.showUnlockAffordance) {
      return;
    }
    HiLog.i(TAG, 'resetScreenLock');
    this.clearUnlockAffordanceTimer();
    this.state.isScreenLocked = false;
    this.state.showUnlockAffordance = false;
    this.notifyUiState();
  }

  /**
   * 立即隐藏控制区，用于鼠标拖出窗口等明确退出场景。
   */
  public hideControlsNow(): void {
    if (this.state.isScreenLocked) {
      return;
    }
    HiLog.i(TAG, 'hideControlsNow');
    this.videoController.setProgressHide(0, true);
  }

  /**
   * 暂停自动隐藏计时，用于鼠标悬停控制区。
   */
  public pauseAutoHide(): void {
    HiLog.i(TAG, 'pauseAutoHide');
    this.videoController.clearHideEvent();
  }

  /**
   * 获取当前 UI 状态快照。
   *
   * @returns UI 状态副本
   */
  public getUiState(): VideoPlaybackUiState {
    return this.copyState();
  }

  /**
   * 复制当前 UI 状态，避免外部监听者直接修改内部状态对象。
   *
   * @returns UI 状态副本
   */
  private copyState(): VideoPlaybackUiState {
    return {
      isProgressHide: this.state.isProgressHide,
      isLandscapeMode: this.state.isLandscapeMode,
      isFullScreen: this.state.isFullScreen,
      toolbarTransitionEnabled: this.state.toolbarTransitionEnabled,
      isScreenLocked: this.state.isScreenLocked,
      showUnlockAffordance: this.state.showUnlockAffordance
    };
  }

  /**
   * 创建视频播放 UI 初始状态。
   *
   * @returns UI 状态快照
   */
  private static createInitialState(): VideoPlaybackUiState {
    return {
      isProgressHide: false,
      isLandscapeMode: false,
      isFullScreen: false,
      toolbarTransitionEnabled: false,
      isScreenLocked: false,
      showUnlockAffordance: false
    };
  }

  /**
   * 锁屏解锁入口自动隐藏计时。
   */
  private scheduleUnlockAffordanceHide(): void {
    this.clearUnlockAffordanceTimer();
    this.unlockAffordanceTimerId = setTimeout(() => {
      if (!this.state.isScreenLocked) {
        this.unlockAffordanceTimerId = -1;
        return;
      }
      this.state.showUnlockAffordance = false;
      this.unlockAffordanceTimerId = -1;
      HiLog.i(TAG, 'lockAffordance auto hidden');
      this.notifyUiState();
    }, PlayConstants.PLAY_PROGRESS_VIDEO_HIDE_TIME);
  }

  /**
   * 清理锁屏解锁入口自动隐藏计时器。
   */
  private clearUnlockAffordanceTimer(): void {
    if (this.unlockAffordanceTimerId === -1) {
      return;
    }
    clearTimeout(this.unlockAffordanceTimerId);
    this.unlockAffordanceTimerId = -1;
  }

  /**
   * 通知页面刷新 @State，单个监听失败不影响其他监听者。
   */
  private notifyUiState(): void {
    const state = this.copyState();
    for (let i = 0; i < this.uiListeners.length; i++) {
      try {
        this.uiListeners[i](state);
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        HiLog.e(TAG, `notifyUiState failed index=${i} message=${message}`);
      }
    }
  }
}
