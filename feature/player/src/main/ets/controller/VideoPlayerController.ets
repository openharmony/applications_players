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


import { AVPlayerController } from './AVPlayerController';
import { Constants, LoadingStatus, OpenType, WindowType } from '@ohos/common/src/main/ets/constants/ui/Constants';
import { HiLog } from '@ohos/common/src/main/ets/utils/HiLog';
import { PlayConstants } from '@ohos/common/src/main/ets/constants/player/PlayConstants';
import { EventName, ResultOpenState, TaskId, VideoOperate } from '@ohos/common/src/main/ets/constants/system/EventName';
import { window } from '@kit.ArkUI';
import hiTraceMeter from '@ohos.hiTraceMeter';
import { AVOperationParams, PreviewResultParams } from '@ohos/common/src/main/ets/player/Params';
import { ReportUtil } from '@ohos/common/src/main/ets/utils/ReportUtil';
import { BusinessError } from '@ohos.base';
import FileInfo from '@ohos/common/src/main/ets/model/FileInfo';
import DeviceConfigUtil from '@ohos/common/src/main/ets/utils/DeviceConfigUtil';
import { QuickViewConfig } from '@ohos/common/src/main/ets/constants/ui/QuickViewConfig';
import { systemDateTime } from '@kit.BasicServicesKit';
import media from '@ohos.multimedia.media';
import audio from '@ohos.multimedia.audio';
import { AppStorageParam, LocalStorageParam } from '@ohos/common/src/main/ets/constants/storage/StorageParam';
import LRUCache from '@ohos/common/src/main/ets/utils/LRUCache';
import LooperUtil from '@ohos/common/src/main/ets/utils/LooperUtil';
import { VideoCoverEvent } from '@ohos/common/src/main/ets/player/Events';
import WindowUtil from '@ohos/common/src/main/ets/utils/WindowUtil';
import { TraceCategoryParam, TraceNameParam } from '@ohos/common/src/main/ets/constants/system/TraceParam';
import { PlaybackQueueManager } from '@ohos/common/src/main/ets/player/PlaybackQueueManager';
import { PlaybackResumeContext } from '@ohos/common/src/main/ets/player/PlaybackResumeContext';
import { MediaPlaybackFileOpener, MediaPlaybackOpenResult } from '@ohos/common/src/main/ets/utils/MediaPlaybackFileOpener';
import {
  MediaPlaybackSourceHelper,
  MediaSourceAccessState
} from '@ohos/common/src/main/ets/utils/MediaPlaybackSourceHelper';
import { SessionCoverLoader } from '@ohos/common/src/main/ets/utils/SessionCoverLoader';
import { PlaybackControlConstants } from '../constants/PlaybackControlConstants';
import image from '@ohos.multimedia.image';
import { VideoPipContentSize } from '../constants/VideoPipConstants';
import { VideoPlaybackSession } from '../session/VideoPlaybackSession';
import { IPlaybackQueueControlTarget } from '../session/PlaybackControlSessionHelper';
import {
  alignEvenPx,
  alignSurfacePx,
  computeAspectMatchedSurfaceSize,
  computeVideoContainRatio,
  computeVideoCoverRatio,
  normalizeContainerForOrientation,
  VideoLayoutSize
} from '../utils/VideoLayoutUtil';
import { PlayerWindowModeUtil } from '../utils/PlayerWindowModeUtil';
import { showMediaSourceFailureToast } from '../utils/MediaSourceFailureToast';

const TAG: string = 'VideoPlayerController';

export class VideoPlayerController extends AVPlayerController implements IPlaybackQueueControlTarget {
  public fileInfo: FileInfo = new FileInfo('', '', '', 0, 0, 0, 0, 0);
  private surfaceID: string = '';
  /** PiP 期间绑定的 XComponent，用于按显示尺寸重建 surface，避免 4K HWC 硬缩白条 */
  private xComponentController: XComponentController | undefined = undefined;
  private pipSurfaceActive: boolean = false;
  /** PiP 会话中强制 breakHwc（不区分横竖屏 cover），打断 4K→小窗 HWC 白条 */
  private pipBreakHwcForced: boolean = false;
  private pipExitConcealTimerId: number = -1;
  private playingUri: string = '';
  /** 正在切向的目标 URI：未清空 playingUri 前用于去重与 getActiveUri */
  private pendingUri: string = '';
  /** 单飞切源：仅保留最新待切 FileInfo */
  private pendingSwitchFileInfo: FileInfo | null = null;
  /** 是否已有切源循环在执行（保证同一时刻仅一条 stop/reset/open） */
  private switchInFlight: boolean = false;
  private playerThis: Record<string, Object> | null = null;
  private startTime: number = Date.now();
  private progressHideEvent: number | null = null;
  private mouseLastMoveTime: number = 0;
  private storage?: LocalStorage;
  private isPCConfig: boolean = DeviceConfigUtil.checkConfigForPC();
  private isPhoneConfig: boolean = DeviceConfigUtil.checkConfigForPhone();
  private pipBackgroundExempt: boolean = false;
  public uniqueId: string = '';
  public windowType: WindowType = WindowType.MAIN_WINDOW;
  public showLoadingEvent: () => void = () => {
  };
  public seekBackEvent: () => void = () => {
  };
  public notShowLoadingEvent: () => void = () => {
  };
  public switchVideoEvent: () => void = () => {
  };
  private context: Context = getContext();
  private isSwitch: boolean = false;
  /** 当前手势起点纵向偏移（vp） */
  private gestureStartOffsetY: number = PlayConstants.POSITION_Y;
  /** 当前手势起点对应的亮度/音量百分比 */
  private gestureStartValue: number = PlayConstants.PLAY_PAGE_DEFAULT_BRIGHTNESS;
  private isAncoRunning: boolean = false;
  private ancoRuningTimer: number = -1;
  /** 媒体库 asset.open 产生的 fd 需 asset.close，与 fs.open 区分 */
  private fdRelease: (() => Promise<void>) | null = null;
  private sessionCoverPixelMap: image.PixelMap | null = null;
  private sessionCoverLoadKey: string = '';

  constructor(storage?: LocalStorage) {
    super();
    this.storage = storage;
  }

  /**
   * 绑定页面 LocalStorage，保证视频页和控制器读取同一份窗口与播放状态。
   *
   * @param storage 页面本地存储
   */
  bindStorage(storage: LocalStorage): void {
    this.storage = storage;
    this.localStorage = storage;
  }

  /**
   * 获取视频画面适配尺寸，优先使用页面稳定的 XComponent 容器尺寸。
   *
   * @param windowRect 兜底窗口矩形
   * @returns 视频适配尺寸
   */
  private resolveVideoDisplaySize(windowRect?: window.Rect): window.Size {
    const stackSize = this.playPage?.videoPlayerSize as window.Size;
    if (stackSize !== undefined && stackSize.width > 0 && stackSize.height > 0) {
      return stackSize;
    }
    let size: window.Size = { width: 0, height: 0 };
    if (windowRect === undefined) {
      return size;
    }
    size.width = windowRect.width;
    let height = windowRect.height;
    const isPortraitPanel = !this.isPCConfig && !(this.playPage?.isLandscapeMode as boolean);
    if (isPortraitPanel) {
      height = height - vp2px(Constants.APP_BAR_HEIGHT);
    }
    size.height = height;
    return size;
  }

  /**
   * 判断是否显示系统栏；横屏主视频固定隐藏系统栏，避免顶部栏变化造成闪屏。
   *
   * @returns 是否显示系统栏
   */
  private shouldShowSystemBars(): boolean {
    if (this.playPage === null || this.isPCConfig || this.playPage.windowType !== WindowType.MAIN_WINDOW) {
      return false;
    }
    return this.playPage.isLandscapeMode !== true;
  }

  getVideoWinClass(): window.Window | undefined {
    if (this.playPage) {
      return this.playPage.videoWinClass as window.Window;
    }
    return undefined;
  }

  isShowSharePage(): boolean {
    if (!this.playPage) {
      return false;
    }
    return this.playPage.isSharePageOn === true;
  }

  releaseResource(): void {
    void this.releaseSessionCover();
    if (this.fdRelease) {
      this.fdRelease()
        .catch((error: BusinessError) => {
          HiLog.e(TAG, `fdRelease failed message=${error.message} code=${error.code}`);
        });
      this.fdRelease = null;
      this.fdSrc = null;
      this.url = null;
      return;
    }
    super.releaseResource();
  }

  initPlayerThis(playerThis: Object): void {
    this.playerThis = playerThis as Record<string, Object>;
  }

  initPlayPage(playPage: Object): void {
    super.initPlayPage(playPage);
    if (this.playPage === null) {
      return;
    }
    let fileInfo = this.playPage.fileInfo as FileInfo;
    if (fileInfo) {
      this.fileInfo = fileInfo;
      this.fileInfo.mimeType = fileInfo.mimeType ?? 'undefi';
    } else {
      HiLog.w(TAG, `the playPage fileInfo is undefined`);
    }
    this.setFileInfo(this.fileInfo, false);
    VideoPlaybackSession.getInstance().bindController(this);
  }

  /**
   * 当前活跃 URI：切源过程中优先返回 pending，避免 Session/页面二次 switchToTrack
   *
   * @returns 视频 URI
   */
  public getActiveUri(): string {
    if (this.pendingUri.length > 0) {
      return this.pendingUri;
    }
    return this.playingUri;
  }

  /**
   * 重建 AVPlayer 后重绑 surface，避免画面无输出
   */
  protected async recreateAvPlayer(): Promise<boolean> {
    const ok = await super.recreateAvPlayer();
    if (ok && this.avPlayer !== null && this.surfaceID.length > 0) {
      this.avPlayer.surfaceId = this.surfaceID;
      HiLog.i(TAG, `recreateAvPlayer rebound surfaceId=${this.surfaceID}`);
    }
    return ok;
  }

  /**
   * 通话挂断/焦点失败后：重新打开视频源并续播。
   *
   * @param resumePositionMs 恢复位置
   * @returns 是否已启动重开流程
   */
  protected async rebindMediaSourceForRecovery(resumePositionMs: number): Promise<boolean> {
    const fileInfo = this.resolveTargetFileInfo();
    if (!fileInfo || fileInfo.uri.length === 0) {
      HiLog.e(TAG, 'rebindMediaSourceForRecovery no fileInfo');
      return false;
    }
    HiLog.i(TAG, `rebindMediaSourceForRecovery ms=${resumePositionMs} uri=%{private}s`, fileInfo.uri);
    if (resumePositionMs > 0) {
      PlaybackResumeContext.setPendingStartMs(resumePositionMs);
    }
    this.releaseResource();
    this.rendererNeedsRebuild = false;
    const recreated = await this.recreateAvPlayer();
    if (!recreated || !this.isAvPlayerIdle()) {
      HiLog.e(TAG, 'rebindMediaSourceForRecovery recreate failed');
      return false;
    }
    await this.openVideoSourceAsync(fileInfo);
    return true;
  }

  /**
   * 视频播控默认封面资源
   *
   * @returns 默认封面 Resource
   */
  protected getDefaultSessionCoverResource(): Resource {
    return $r('app.media.ic_normal_video');
  }

  protected getSessionCoverPixelMap(): image.PixelMap | null {
    return this.sessionCoverPixelMap;
  }

  private async releaseSessionCover(): Promise<void> {
    if (this.sessionCoverPixelMap) {
      await this.sessionCoverPixelMap.release();
      this.sessionCoverPixelMap = null;
    }
    this.sessionCoverLoadKey = '';
  }

  /**
   * 加载播控中心封面：优先列表 thumbUri，失败则提取首帧（对齐音频 extractAlbumCover 时机）
   */
  private async loadVideoSessionCover(fileInfo: FileInfo, opened: MediaPlaybackOpenResult): Promise<void> {
    const loadKey = `${fileInfo.uri}|${this.fileInfo.thumbUri}`;
    if (loadKey === this.sessionCoverLoadKey && this.sessionCoverPixelMap !== null) {
      return;
    }
    await this.releaseSessionCover();
    this.sessionCoverLoadKey = loadKey;
    const maxPx = PlaybackControlConstants.SESSION_COVER_MAX_PX;
    const thumbUri = this.fileInfo.thumbUri;
    if (thumbUri.length > 0) {
      this.sessionCoverPixelMap = await SessionCoverLoader.loadPixelMap(thumbUri, maxPx);
      if (this.sessionCoverPixelMap !== null) {
        HiLog.i(TAG, `Session cover thumbUri loaded successfully fileName=${fileInfo.fileName}`);
        return;
      }
      HiLog.w(TAG, `Session cover thumbUri load failed fileName=${fileInfo.fileName} thumbUri=${thumbUri}`);
    }
    this.sessionCoverPixelMap =
      await SessionCoverLoader.extractVideoFrameFromFd(opened.fd, opened.size, maxPx);
    if (this.sessionCoverPixelMap !== null) {
      HiLog.i(TAG, `Session cover first frame extracted successfully fileName=${fileInfo.fileName}`);
      return;
    }
    HiLog.w(TAG, `Session cover unavailable fileName=${fileInfo.fileName}`);
  }

  /**
   * 画中画已武装或小窗活动中：允许视频在退后台后继续播放。
   *
   * @param exempt 是否豁免退后台暂停
   */
  setPipBackgroundExempt(exempt: boolean): void {
    this.pipBackgroundExempt = exempt;
    HiLog.i(TAG, `setPipBackgroundExempt exempt=${exempt}`);
  }

  /**
   * @returns 画中画场景豁免移动端退后台自动暂停
   */
  protected allowVideoPlayOnBackground(): boolean {
    return this.pipBackgroundExempt;
  }

  private pipSuspendForCallHook?: () => void;
  private pipRestoreAfterCallHook?: () => void;

  /**
   * 绑定来电时暂停/恢复画中画的页面钩子。
   */
  setPhoneInterruptPipHooks(suspend: () => void, restore: () => void): void {
    this.pipSuspendForCallHook = suspend;
    this.pipRestoreAfterCallHook = restore;
  }

  public handlePhoneCallBegin(): void {
    super.handlePhoneCallBegin();
  }

  public handlePhoneCallEnd(): void {
    super.handlePhoneCallEnd();
  }

  protected notifyInterruptPaused(): void {
    this.pipSuspendForCallHook?.();
  }

  protected notifyInterruptResumed(): void {
    this.pipRestoreAfterCallHook?.();
  }

  /**
   * 获取当前视频流像素尺寸，供画中画窗口比例计算。
   *
   * @returns 视频宽高（px），未就绪时返回 undefined
   */
  getVideoPixelSize(): VideoPipContentSize | undefined {
    if (this.avPlayer === null || this.avPlayer.width <= 0 || this.avPlayer.height <= 0) {
      return undefined;
    }
    const size: VideoPipContentSize = {
      width: this.avPlayer.width,
      height: this.avPlayer.height,
    };
    return size;
  }

  /**
   * 注册与 AVVideoPlayer 一致的 XComponent 控制器，供 PiP 调整出帧尺寸。
   */
  public setXComponentController(controller: XComponentController): void {
    this.xComponentController = controller;
    HiLog.i(TAG, 'setXComponentController ready=true');
  }

  /**
   * PiP Surface：严格按片源比适配窗口。
   * 不再减高度：日志里 height-8 会变成 src.y=4 → HWC 扫描线白条。
   */
  public applyPipDisplayOutputSize(width: number, height: number): void {
    // 拒绝迁窗收尾的 2×2/4×4，避免黑色方块
    if (width < 64 || height < 64) {
      HiLog.i(TAG, `applyPipDisplayOutputSize skipped tiny ${width}x${height}`);
      return;
    }
    let surfaceWidth = alignSurfacePx(width);
    let surfaceHeight = height > 8 ? alignSurfacePx(height) : alignEvenPx(height);
    if (this.avPlayer !== null && this.avPlayer.width > 0 && this.avPlayer.height > 0) {
      const matched = computeAspectMatchedSurfaceSize(
        Math.max(surfaceWidth, surfaceHeight),
        this.avPlayer.width,
        this.avPlayer.height
      );
      if (matched.width / matched.height > surfaceWidth / Math.max(surfaceHeight, 1)) {
        surfaceWidth = alignSurfacePx(surfaceWidth);
        surfaceHeight = alignSurfacePx(surfaceWidth * matched.height / matched.width);
      } else {
        surfaceHeight = alignSurfacePx(surfaceHeight);
        surfaceWidth = alignSurfacePx(surfaceHeight * matched.width / matched.height);
      }
    }
    if (surfaceWidth < 4 || surfaceHeight < 4) {
      return;
    }
    if (this.xComponentController === undefined) {
      HiLog.w(TAG, `applyPipDisplayOutputSize aborted noXComponent ${surfaceWidth}x${surfaceHeight}`);
      return;
    }
    try {
      this.xComponentController.setXComponentSurfaceSize({
        surfaceWidth: surfaceWidth,
        surfaceHeight: surfaceHeight,
      });
      this.pipSurfaceActive = true;
      const surfaceId = this.xComponentController.getXComponentSurfaceId();
      if (this.avPlayer !== null && surfaceId.length > 0) {
        this.surfaceID = surfaceId;
        this.avPlayer.surfaceId = surfaceId;
      }
      this.syncBreakHwcComposeFlag();
      this.applyVideoScaleType();
      HiLog.i(TAG, `applyPipDisplayOutputSize ${surfaceWidth}x${surfaceHeight} layoutFix=v10`);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      HiLog.e(TAG, `applyPipDisplayOutputSize failed message=${message}`);
    }
  }

  /**
   * 主窗 Surface 严格按片源比（不减高度，避免 src.y=4 白条）。
   */
  public applyAspectMatchedSurfaceSize(): void {
    if (this.xComponentController === undefined || this.avPlayer === null) {
      return;
    }
    if (this.avPlayer.width <= 0 || this.avPlayer.height <= 0) {
      return;
    }
    const matched: VideoLayoutSize = computeAspectMatchedSurfaceSize(
      PlayConstants.VIDEO_PLAY_PLAYER_SURFACE_WIDTH,
      this.avPlayer.width,
      this.avPlayer.height
    );
    try {
      this.xComponentController.setXComponentSurfaceSize({
        surfaceWidth: matched.width,
        surfaceHeight: matched.height,
      });
      HiLog.i(TAG, `applyAspectMatchedSurfaceSize ${matched.width}x${matched.height}`);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      HiLog.w(TAG, `applyAspectMatchedSurfaceSize failed message=${message}`);
    }
  }

  /**
   * 退出 PiP：恢复与片源同宽高比的主窗 Surface。
   */
  public restoreDefaultSurfaceSize(): void {
    if (!this.pipSurfaceActive || this.xComponentController === undefined) {
      return;
    }
    this.pipSurfaceActive = false;
    this.applyAspectMatchedSurfaceSize();
    if (this.avPlayer === null || this.avPlayer.width <= 0) {
      try {
        this.xComponentController.setXComponentSurfaceSize({
          surfaceWidth: PlayConstants.VIDEO_PLAY_PLAYER_SURFACE_WIDTH,
          surfaceHeight: PlayConstants.VIDEO_PLAY_PLAYER_SURFACE_HEIGHT,
        });
        HiLog.i(TAG, 'restoreDefaultSurfaceSize 1920x1080');
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        HiLog.w(TAG, `restoreDefaultSurfaceSize failed message=${message}`);
      }
    }
  }

  /**
   * 从画中画回到主界面：强制将 AVPlayer 渲染目标切回主窗口 XComponent Surface
   *
   * @param surfaceId 主窗口 XComponent 的 Surface ID
   */
  public restoreMainSurfaceAfterPip(surfaceId: string): void {
    // PiP 未改 Surface 尺寸时勿 restoreDefault，避免无谓重建闪黑
    this.restoreDefaultSurfaceSize();
    if (this.avPlayer === null || surfaceId.length === 0) {
      HiLog.w(TAG, `restoreMainSurfaceAfterPip aborted player=${this.avPlayer !== null} surfaceLen=${surfaceId.length}`);
      return;
    }
    const playerState = this.avPlayer.state;
    if (playerState === 'idle' || playerState === 'released' || playerState === 'error') {
      HiLog.w(TAG, `restoreMainSurfaceAfterPip skipped state=${playerState}`);
      return;
    }
    // 同一 Surface 再写 surfaceId / adjustVideoSize 会闪一帧，跳过
    if (this.surfaceID === surfaceId && this.avPlayer.surfaceId === surfaceId) {
      HiLog.i(TAG, `restoreMainSurfaceAfterPip skipped sameSurface state=${playerState}`);
      return;
    }
    HiLog.i(TAG, `restoreMainSurfaceAfterPip surfaceId=${surfaceId} state=${playerState}`);
    this.surfaceID = surfaceId;
    this.avPlayer.surfaceId = surfaceId;
  }

  toStopped(): void {
    HiLog.i(TAG, `toStopped uniqueId:${this.uniqueId}`);
    super.toStopped();
    this.dealUIExtensionPauseOrStop();
  }

  toPlaying(): void {
    HiLog.i(TAG, `toPlaying uniqueId:${this.uniqueId}`);
    this.applyControlCenterPlayingState(true);
    super.toPlaying();
    this.dealUIExtensionPlay();
    this.notShowLoadingEvent();
  }

  isFloating(windowClass: window.Window): boolean {
    if (this.isPCConfig) {
      return false;
    }
    let isFloating: boolean = false;
    try {
      isFloating = windowClass.getWindowProperties().windowRect.top !== 0;
    } catch (error) {
      HiLog.e(TAG, `error code: ${error.code}, error msg: ${error.message}.`);
    }
    return isFloating;
  }

  async dealUIExtensionPlay(): Promise<void> {
    if (!this.uniqueId) {
      return;
    }
    let cache: LRUCache<string> = AppStorage.get(AppStorageParam.UI_EXTENSION_PLAYING_VIDEO_CACHE) ??
    new LRUCache<string>(PlayConstants.UI_EXTENSION_PLAYING_THRESHOLD);
    let stopVideoUniqueId: string | undefined = cache.put(this.uniqueId);
    cache.put(this.uniqueId);
    AppStorage.setOrCreate(AppStorageParam.UI_EXTENSION_PLAYING_VIDEO_CACHE, cache);
    if (stopVideoUniqueId) {
      LooperUtil.emit(PlayConstants.PLAYING_VIDEO_EXCEED_THRESHOLD_EVENT, { data: { value: stopVideoUniqueId } });
    }
    HiLog.i(TAG, `dealUIExtensionPlay uniqueId:${this.uniqueId} cache:${cache.getSize()} \
      stopVideoUniqueId:${stopVideoUniqueId}`);
  }

  async dealUIExtensionPauseOrStop(): Promise<void> {
    if (!this.uniqueId || this.windowType !== WindowType.UI_EXTENSION_WINDOW) {
      return;
    }
    let cache: LRUCache<string> = AppStorage.get(AppStorageParam.UI_EXTENSION_PLAYING_VIDEO_CACHE) ??
    new LRUCache<string>(PlayConstants.UI_EXTENSION_PLAYING_THRESHOLD);
    let stopVideoUniqueId: string | undefined = cache.put(this.uniqueId);
    cache.put(this.uniqueId);
    AppStorage.setOrCreate(AppStorageParam.UI_EXTENSION_PLAYING_VIDEO_CACHE, cache);
    if (stopVideoUniqueId) {
      LooperUtil.emit(PlayConstants.PLAYING_VIDEO_EXCEED_THRESHOLD_EVENT, { data: { value: stopVideoUniqueId } });
    }
    HiLog.i(TAG, `dealUIExtensionPlay uniqueId:${this.uniqueId} cache:${cache.getSize()} \
      stopVideoUniqueId:${stopVideoUniqueId}`);
  }

  /**
   * 按当前视频窗口模式刷新系统栏，并同步全屏状态给 XComponent。
   *
   * @param isSystemBarHide 兼容旧调用的系统栏隐藏参数
   */
  handleSystemBar(isSystemBarHide?: boolean) {
    if (this.playPage === null) {
      HiLog.e(TAG, 'PlayPage is null');
      return;
    }
    const windowClass = this.playPage.videoWinClass as window.Window;
    if (!windowClass || this.isPCConfig) {
      return;
    }
    try {
      if (this.shouldShowSystemBars()) {
        WindowUtil.applyPlayerDarkSystemBars(windowClass);
      } else {
        try {
          windowClass.setWindowSystemBarEnable([]);
        } catch (exception) {
          HiLog.e(TAG, `Failed to hide system bars. Cause: ${JSON.stringify(exception)}`);
        }
      }
      if (isSystemBarHide === undefined) {
        this.playPage.isFullScreen = this.playPage.isLandscapeMode === true &&
          this.playPage.isProgressHide === true;
        HiLog.i(TAG, `fullscreen state: ${this.playPage.isFullScreen}.`);
      }
    } catch (exception) {
      HiLog.e(TAG, `Failed to update system bars. Cause: ${JSON.stringify(exception)}`);
    }
  }

  clearHideEvent(): void {
    if (this.progressHideEvent) {
      clearTimeout(this.progressHideEvent);
      this.progressHideEvent = null;
    }
  }

  reportBehaviorEvent(operation: VideoOperate): void {
    if (this.play === null) {
      return;
    }
    let mimeType: string = this.fileInfo.mimeType ?? 'undefined';
    let params = new AVOperationParams(mimeType, operation, this.operatePath, this.operationSource);
    let recordParams: Record<string, Object> = {
      "mimeType": params.mimeType,
      "operation": params.operation,
      "operatePath": params.operatePath,
      "operationSource": params.operationSource
    };
    ReportUtil.reportBehaviorEvent(EventName.BEV_VIDEO_OPERATION, recordParams);
  }

  keepScreenOn(windowClass: window.Window, isKeepScreenOn: boolean) {
    try {
      windowClass.setWindowKeepScreenOn(isKeepScreenOn, (err: BusinessError) => {
        const errCode: number = err.code;
        if (errCode) {
          HiLog.e(TAG, `Failed to set the screen to be always on. Cause: ${JSON.stringify(err)}`);
          return;
        }
        HiLog.i(TAG, 'Succeeded in setting the screen to be always on.');
      });
    } catch (exception) {
      HiLog.e(TAG, `Failed to set the screen to be always on. Cause: ${JSON.stringify(exception)}`);
    }
  }

  /**
   * 创建视频控制区自动隐藏定时器。
   *
   * @param timestamp 最近一次交互时间戳
   * @param func 超时回调
   */
  createHideEvent(timestamp: number, func: () => void): void {
    this.clearHideEvent();
    this.progressHideEvent = setTimeout(func, PlayConstants.PLAY_PROGRESS_VIDEO_HIDE_TIME);
  }

  /**
   * 动画更新控制区隐藏状态。
   *
   * @param isProgressHide 是否隐藏控制区
   */
  animateSetProgressHide(isProgressHide: boolean) {
    animateTo({ duration: 300, curve: Curve.Smooth }, () => {
      if (this.playPage === null || this.playProgress === null) {
        HiLog.e(TAG, 'playPage or playProgress is null');
        return;
      }
      this.playPage.isProgressHide = isProgressHide;
    })
  }

  /**
   * 更新视频控制区显隐；主窗口用户交互后 4 秒自动隐藏。
   *
   * @param timestamp 最近一次交互时间戳，0 表示不创建自动隐藏计时器
   * @param isProgressHide 是否隐藏控制区
   */
  setProgressHide(timestamp: number, isProgressHide?: boolean): void {
    HiLog.d(TAG, `setProgressHide: ${isProgressHide} timeStamp:${timestamp}`);
    if (this.playPage === null || this.playProgress === null) {
      HiLog.e(TAG, 'playPage or playProgress is null');
      return;
    }
    let newState: boolean = isProgressHide === true;
    if (newState && this.isShowSharePage()) {
      HiLog.i(TAG, 'share page is on, skip hiding progress');
      return;
    }
    this.animateSetProgressHide(newState);
    HiLog.d(TAG, `param: ${isProgressHide}, isProgressHide: ${this.playPage.isProgressHide}`);
    this.handleSystemBar();
    const canAutoHide = this.playPage.windowType === WindowType.MAIN_WINDOW;
    if (!canAutoHide || timestamp <= 0) {
      return;
    }
    HiLog.d(TAG,
      `param: ${isProgressHide}, isProgressHide: ${this.playPage.isProgressHide}, begin to createHideEvent`);
    this.createHideEvent(timestamp, () => {
      if (this.progressHideEvent === null) {
        HiLog.e(TAG, 'progressHideEvent is null');
        return;
      }
      if (this.isMovingVolumeSlider || this.isMovingProgressSlider) {
        HiLog.i(TAG, 'Slider is Moving, skip hiding progress');
        return;
      }
      if (this.isLeftOrRightKeyDown) {
        HiLog.i(TAG, 'Left Or Right, skip hiding progress');
        return;
      }
      if (this.playPage === null) {
        HiLog.e(TAG, 'playPage is null');
        return;
      }
      if (this.isShowSharePage()) {
        HiLog.i(TAG, 'share page is on, skip auto hiding progress');
        return;
      }
      if (this.isProgressFocus) {
        HiLog.i(TAG, 'progress is focus, skip auto hiding progress');
        return;
      }
      let timeInterval = systemDateTime.getTime() - timestamp;
      if (timeInterval >= PlayConstants.PLAY_PROGRESS_VIDEO_HIDE_TIME) {
        this.animateSetProgressHide(true);
        this.handleSystemBar();
      }
      HiLog.i(TAG, `hide event timeout, timeInterval:${timeInterval}`);
    });

  }

  setWindowLayoutFullScreen(): void {
    window.getLastWindow(getContext(this), (err: BusinessError<void>, windowClass: window.Window) => {
      if (err.code) {
        HiLog.e(TAG, `Failed to obtain the top window. Cause: ${JSON.stringify(err)}`);
        return;
      }
      this.keepScreenOn(windowClass, true);
    });
  }

  async release() {
    this.clearHideEvent();
    this.pendingUri = '';
    this.pendingSwitchFileInfo = null;
    this.switchInFlight = false;
    VideoPlaybackSession.getInstance().unbindController(this);
    this.stopContinuousTask();
    await this.clearAvSession();
    super.release();
  }

  /**
   * 横屏或 PC 全屏时使用铺满裁剪；竖屏/窗口模式使用等比适配。
   * 竖屏视频在横屏设备上也使用等比适配，避免画面被裁切。
   *
   * @returns 是否使用 FIT_CROP
   */
  private shouldUseCoverVideoScale(): boolean {
    if (this.playPage === null) {
      return false;
    }
    // 手机端一律 contain：横屏 cover 会与竖屏 contain 切换造成拉伸/色差（日志仍见 cover mode）
    if (!this.isPCConfig) {
      return false;
    }
    if (this.isPCConfig) {
      return this.playPage.isPcFullScreen === true && this.isVideoLandscape();
    }
    return false;
  }

  /**
   * 判断当前视频是否为横屏内容（宽 >= 高）。
   * 视频尺寸未就绪时默认返回 true，保持现有横屏铺满行为。
   *
   * @returns 视频是否为横屏
   */
  private isVideoLandscape(): boolean {
    if (this.avPlayer !== null && this.avPlayer.width > 0 && this.avPlayer.height > 0) {
      return this.avPlayer.width >= this.avPlayer.height;
    }
    return true;
  }

  /**
   * 是否处于分屏或悬浮窗等非全屏窗口模式。
   * 委托 PlayerWindowModeUtil 统一处理。
   */
  private isInSplitOrFloatingMode(): boolean {
    return PlayerWindowModeUtil.isInSplitOrFloatingMode(
      this.playPage?.videoWinClass as window.Window,
      this.isPCConfig
    );
  }

  /**
   * Surface 内 FIT_CROP：竖屏等比只由 UI contain 完成，不改片源显示比例。
   */
  private applyVideoScaleType(): void {
    if (this.avPlayer === null) {
      return;
    }
    try {
      this.avPlayer.videoScaleType = media.VideoScaleType.VIDEO_SCALE_TYPE_FIT_CROP;
      HiLog.i(TAG, `applyVideoScaleType scaleType=${media.VideoScaleType.VIDEO_SCALE_TYPE_FIT_CROP}`);
    } catch (error) {
      const bizError = error as BusinessError;
      HiLog.e(TAG, `applyVideoScaleType failed code=${bizError.code} message=${bizError.message}`);
    }
  }

  /**
   * PiP 进/出：同步 renderGroup。
   * 高分片横竖屏本就恒开，进出 PiP 不再垫厚遮罩、也不误关合成路径。
   */
  public setPipBreakHwcForced(forced: boolean): void {
    if (this.pipBreakHwcForced === forced) {
      this.syncBreakHwcComposeFlag();
      return;
    }
    this.pipBreakHwcForced = forced;
    HiLog.i(TAG, `setPipBreakHwcForced forced=${forced}`);
    if (this.pipExitConcealTimerId !== -1) {
      clearTimeout(this.pipExitConcealTimerId);
      this.pipExitConcealTimerId = -1;
    }
    // 进出 PiP 均不再垫 conceal 黑条；高分粘性 breakHwc 由 sync 保证
    if (this.playPage !== null) {
      this.playPage.concealVideoSurface = false;
      this.playPage.pendingBreakHwcDisable = false;
    }
    this.syncBreakHwcComposeFlag();
  }

  /**
   * PiP 会话视觉：关掉底边黑遮罩、主窗视频区改透明，避免小窗四周/迁窗黑遮罩。
   */
  public setPipSessionVisualActive(active: boolean): void {
    if (this.playPage === null) {
      return;
    }
    const wasActive: boolean = this.playPage.pipSessionActive as boolean;
    if (wasActive === active) {
      return;
    }
    this.playPage.pipSessionActive = active;
    this.playPage.concealVideoSurface = false;
    HiLog.i(TAG, `setPipSessionVisualActive active=${active}`);
  }

  /**
   * PiP 还原瞬间抢在壳层浅灰底之前锁黑窗底（日志：#FFF2F2F7 导致闪现）。
   */
  public ensureVideoWindowBackgroundBlack(): void {
    WindowUtil.setVideoPlayerPageActive(true);
    const windowClass = this.storage?.get<window.Window>(LocalStorageParam.WINDOW_CLASS);
    if (windowClass === undefined) {
      return;
    }
    WindowUtil.applyVideoWindowBackgroundColor(windowClass)
      .catch((error: Error) => {
        HiLog.w(TAG, `ensureVideoWindowBackgroundBlack failed message=${error.message}`);
      });
  }

  private isHighResVideoForBreakHwc(): boolean {
    let vw = 0;
    let vh = 0;
    if (this.avPlayer !== null && this.avPlayer.width > 0 && this.avPlayer.height > 0) {
      vw = this.avPlayer.width;
      vh = this.avPlayer.height;
    } else if (this.playPage !== null) {
      const pageW: number = Number(this.playPage.videoPixelWidth);
      const pageH: number = Number(this.playPage.videoPixelHeight);
      if (pageW > 0 && pageH > 0) {
        vw = pageW;
        vh = pageH;
      }
    }
    if (vw <= 0 || vh <= 0) {
      return false;
    }
    // ≥2K 或超宽比（>2.0，如 3840×1608）
    return vw >= 2560 || (vw * vh) >= (2560 * 1080) || (vw / vh) > 2.0;
  }

  /** 供页面在延迟收罩后重新对齐 breakHwc（避免误关高分片合成路径） */
  public refreshBreakHwcComposeFlag(): void {
    this.syncBreakHwcComposeFlag();
  }

  /**
   * 高分超宽片：一旦开启 breakHwc 本会话内不再关闭，避免切向黑条闪断与色差。
   */
  private syncBreakHwcComposeFlag(): void {
    if (this.playPage === null) {
      return;
    }
    let enable = false;
    if (this.isHighResVideoForBreakHwc()) {
      enable = true;
    } else if (this.pipBreakHwcForced) {
      enable = true;
    }
    // 粘性：高分片已开启后禁止再关（含 defer disable 路径）
    if (this.playPage.breakHwcCompose && this.isHighResVideoForBreakHwc()) {
      enable = true;
      this.playPage.pendingBreakHwcDisable = false;
      this.playPage.concealVideoSurface = false;
    }
    if (this.playPage.breakHwcCompose !== enable) {
      if (!enable) {
        // 不再因 conceal 推迟；直接保持现状或按 enable 关闭（仅非高分）
        this.playPage.pendingBreakHwcDisable = false;
      }
      this.playPage.breakHwcCompose = enable;
      HiLog.i(TAG, `syncBreakHwcCompose enable=${enable} pipForced=${this.pipBreakHwcForced} stickyHighRes=true`);
    }
  }

  private syncVideoPixelSizeToPage(): void {
    if (this.playPage === null || this.avPlayer === null) {
      return;
    }
    const vw = this.avPlayer.width;
    const vh = this.avPlayer.height;
    if (vw <= 0 || vh <= 0) {
      return;
    }
    if (this.playPage.videoPixelWidth !== vw || this.playPage.videoPixelHeight !== vh) {
      this.playPage.videoPixelWidth = vw;
      this.playPage.videoPixelHeight = vh;
      HiLog.i(TAG, `syncVideoPixelSize ${vw}x${vh}`);
    }
    // 片源尺寸一就绪就对齐合成路径与 Surface 比，避免首帧横屏仍走 HWC/16:9
    this.syncBreakHwcComposeFlag();
    if (!this.pipSurfaceActive) {
      this.applyAspectMatchedSurfaceSize();
    }
  }

  adjustVideoSize(data: window.Rect | window.Size | undefined): void {
    if (data === undefined || this.playPage === null) {
      HiLog.e(TAG, 'adjustVideoSize invalid args');
      return;
    }
    if (data.height === 0 || data.width === 0) {
      HiLog.e(TAG, 'adjustVideoSize container size is zero');
      return;
    }

    this.syncVideoPixelSizeToPage();

    if (this.shouldUseCoverVideoScale()) {
      const coverRatio = computeVideoCoverRatio();
      this.playPage.videoHeightRatio = coverRatio.heightRatio;
      this.playPage.videoWidthRatio = coverRatio.widthRatio;
      this.syncBreakHwcComposeFlag();
      if (!this.pipSurfaceActive) {
        this.applyAspectMatchedSurfaceSize();
      }
      this.applyVideoScaleType();
      HiLog.i(TAG, 'adjustVideoSize cover mode landscape/fullscreen');
      return;
    }

    let width = data.width as number;
    let height = data.height as number;

    if (this.isPCConfig && !this.playPage.isPcFullScreen) {
      if (this.playPage?.windowType === WindowType.DIALOG_WINDOW) {
        height = height - vp2px(Constants.NEW_PC_DIALOG_WINDOW_DECOR_HEIGHT);
      } else {
        height = height - vp2px(Constants.NEW_PC_WINDOW_DECOR_HEIGHT);
      }
    }

    // 分屏/悬浮窗按实测容器 contain，禁止宽高对调（否则横屏分屏会按竖屏比例拉伸）
    const inSplitOrFloat = this.isInSplitOrFloatingMode();
    if (!this.isPCConfig && !inSplitOrFloat) {
      const portraitPanel = this.playPage.isLandscapeMode !== true;
      const normalized = normalizeContainerForOrientation(new VideoLayoutSize(width, height), portraitPanel);
      width = normalized.width;
      height = normalized.height;
    }

    let videoWidth: number = 16;
    let videoHeight: number = 9;
    if (this.avPlayer !== null && this.avPlayer.width > 0 && this.avPlayer.height > 0) {
      videoWidth = this.avPlayer.width;
      videoHeight = this.avPlayer.height;
    } else {
      const pageW: number = Number(this.playPage.videoPixelWidth);
      const pageH: number = Number(this.playPage.videoPixelHeight);
      if (pageW > 0 && pageH > 0) {
        videoWidth = pageW;
        videoHeight = pageH;
      }
    }

    HiLog.i(TAG, `adjustVideoSize container W=${width} H=${height} video W=${videoWidth} H=${videoHeight}`);

    const containRatio = computeVideoContainRatio(
      new VideoLayoutSize(width, height),
      new VideoLayoutSize(videoWidth, videoHeight)
    );
    this.playPage.videoHeightRatio = containRatio.heightRatio;
    this.playPage.videoWidthRatio = containRatio.widthRatio;
    this.syncBreakHwcComposeFlag();
    if (!this.pipSurfaceActive) {
      this.applyAspectMatchedSurfaceSize();
    }
    this.applyVideoScaleType();
    HiLog.i(TAG,
      `adjustVideoSize contain layoutFix=v4 ratioW=${containRatio.widthRatio} ratioH=${containRatio.heightRatio}`);
  }

  adjustWindowSize(): void {
    HiLog.i(TAG, 'adjustWindowSize skip.')
    return;
  }

  async switchPlayOrPause() {
    await super.switchPlayOrPause();
    HiLog.i(TAG, `switchPlayOrPause, curr playState:${this.playState} this.uniqueId:${this.uniqueId}`);
    if (this.playState === PlayConstants.STATUS_START) {
      this.reportBehaviorEvent(VideoOperate.PLAY);
    } else if (this.playState === PlayConstants.STATUS_PAUSE) {
      this.reportBehaviorEvent(VideoOperate.PAUSE);
    }
  }

  pause(): void {
    if (this.playState === PlayConstants.STATUS_START) {
      super.pause();
    }
  }

  seekBack(needPlay: boolean) {
    super.seekBack(needPlay);
  }

  async play(): Promise<void> {
    this.showLoadingEvent();
    super.play();
  }

  stop(): void {
    HiLog.i(TAG, `stop uniqueId:${this.uniqueId}`);
    super.stop();
  }

  async reset() {
    super.reset();
  }

  /**
   * 切换到新视频（单飞 + 最新优先）：
   * 连点时只更新 pending，串行执行 stop/reset/open，最终只打开最后一首。
   */
  async switchToTrack(fileInfo: FileInfo): Promise<void> {
    if (fileInfo.uri.length === 0) {
      return;
    }
    // 已在播且无待切目标，或已指向同一 pending → 跳过（消双触发 / 同曲连点）
    if (fileInfo.uri === this.playingUri && this.pendingUri.length === 0 &&
      this.pendingSwitchFileInfo === null) {
      HiLog.i(TAG, `switchToTrack skipped playingUri=%{private}s`, this.playingUri);
      return;
    }
    if (fileInfo.uri === this.pendingUri) {
      HiLog.i(TAG, `switchToTrack skipped pendingUri=%{private}s`, this.pendingUri);
      return;
    }
    this.pendingSwitchFileInfo = fileInfo;
    this.pendingUri = fileInfo.uri;
    this.fileInfo = fileInfo;
    this.setFileInfo(fileInfo, false);
    this.startTime = Date.now();
    if (this.playPage !== null) {
      this.playPage.loadingStatus = LoadingStatus.LOAD_STATE_LOADING;
    }
    HiLog.i(TAG, `switchToTrack enqueue from=%{private}s to=%{private}s inFlight=${this.switchInFlight}`,
      this.playingUri, fileInfo.uri);
    await this.runTrackSwitchLoop();
  }

  /**
   * 串行消化 pendingSwitchFileInfo；循环内任意时刻新请求只覆盖 pending，不并发 prepare。
   */
  private async runTrackSwitchLoop(): Promise<void> {
    if (this.switchInFlight) {
      return;
    }
    this.switchInFlight = true;
    try {
      while (this.pendingSwitchFileInfo !== null) {
        const target = this.pendingSwitchFileInfo;
        this.pendingSwitchFileInfo = null;
        const generation = this.beginTrackSwitch();
        this.pendingUri = target.uri;
        this.fileInfo = target;
        void this.releaseSessionCover();
        this.setFileInfo(target, false);
        HiLog.i(TAG, `runTrackSwitchLoop start gen=${generation} uri=%{private}s`, target.uri);

        await this.prepareForTrackSwitch();
        if (!this.isTrackSwitchCurrent(generation)) {
          HiLog.i(TAG, `runTrackSwitchLoop stale after prepare gen=${generation}`);
          continue;
        }
        // prepare 期间又来了更新目标：丢弃本次 open，立刻处理最新一首
        if (this.pendingSwitchFileInfo !== null) {
          HiLog.i(TAG, 'runTrackSwitchLoop skip open, newer pending exists');
          continue;
        }
        if (this.surfaceID.length === 0) {
          HiLog.w(TAG, 'runTrackSwitchLoop surfaceId not ready');
          continue;
        }
        this.startTime = Date.now();
        hiTraceMeter.startAsyncTrace(hiTraceMeter.HiTraceOutputLevel.COMMERCIAL,
          'VIDEO_PARSE_FILE', TaskId.PARSE_FILE, 'PARSE_FILE');
        await this.openVideoSourceAsync(target, generation);
      }
    } finally {
      this.switchInFlight = false;
      if (this.pendingSwitchFileInfo !== null) {
        void this.runTrackSwitchLoop();
      } else if (this.pendingUri.length > 0 && this.pendingUri === this.playingUri) {
        this.pendingUri = '';
      }
    }
  }

  switchVideo(surfaceId: string) {
    this.isSwitch = true;
    this.videoSurfaceID(surfaceId);
  }

  /**
   * 解析待打开视频：后台/PiP 播控切歌时控制器 fileInfo 已更新，playPage.fileInfo（@Prop）可能滞后
   *
   * @returns 目标 FileInfo，无效时 null
   */
  private resolveTargetFileInfo(): FileInfo | null {
    if (this.fileInfo !== null && this.fileInfo.uri.length > 0) {
      return this.fileInfo;
    }
    if (this.playPage !== null) {
      const pageInfo = this.playPage.fileInfo as FileInfo;
      if (pageInfo !== null && pageInfo !== undefined &&
        pageInfo.uri !== undefined && pageInfo.uri.length > 0) {
        return pageInfo;
      }
    }
    return null;
  }

  videoSurfaceID(surfaceId: string, switchGeneration?: number) {
    if (this.playPage === null) {
      return;
    }
    // 切源单飞进行中：只更新 surface，避免与 runTrackSwitchLoop 并发 open
    if (this.switchInFlight || this.pendingSwitchFileInfo !== null) {
      this.surfaceID = surfaceId;
      if (this.avPlayer !== null) {
        this.avPlayer.surfaceId = surfaceId;
        this.applyVideoScaleType();
      }
      HiLog.i(TAG, `videoSurfaceID surface only during switch, surfaceId=${surfaceId}`);
      return;
    }
    const targetFileInfo = this.resolveTargetFileInfo();
    const targetUri: string = targetFileInfo?.uri ?? '';
    if (this.avPlayer !== null) {
      const playerState = this.avPlayer.state;
      if (playerState !== 'idle' && playerState !== 'released' && playerState !== 'error') {
        if (this.surfaceID === surfaceId && this.playingUri === targetUri && targetUri.length > 0) {
          HiLog.i(TAG, `videoSurfaceID skip reopen, state:${playerState}`);
          this.adjustVideoSize(this.playPage.videoPlayerSize as window.Size ??
            this.storage?.get<window.Size>(LocalStorageParam.WINDOW_SIZE) as window.Size);
          return;
        }
        if (this.surfaceID !== surfaceId) {
          HiLog.i(TAG, `videoSurfaceID update surface only, state:${playerState}`);
          this.surfaceID = surfaceId;
          this.avPlayer.surfaceId = surfaceId;
          this.applyVideoScaleType();
          // 必须 return：否则会穿透到 openVideoSource/set url，触发 5400102 并卡住播放
          return;
        }
      }
    }
    this.startTime = Date.now();
    hiTraceMeter.startAsyncTrace(hiTraceMeter.HiTraceOutputLevel.COMMERCIAL,
      'VIDEO_PARSE_FILE', TaskId.PARSE_FILE, 'PARSE_FILE');

    this.surfaceID = surfaceId;
    HiLog.i(TAG, `videoSurfaceID called with surfaceId: %{private}s targetUri=%{private}s`,
      surfaceId, targetUri);
    const fileInfo = targetFileInfo;
    if (!fileInfo || !fileInfo.uri) {
      HiLog.e(TAG, 'fileInfo or fileInfo.uri is null');
      if (this.playPage) {
        this.playPage.loadingStatus = LoadingStatus.LOAD_STATE_FAILED;
        this.playPage.errorMessage = '文件信息无效';
      }
      hiTraceMeter.finishAsyncTrace(hiTraceMeter.HiTraceOutputLevel.COMMERCIAL, 'VIDEO_PARSE_FILE',
        TaskId.PARSE_FILE);
      return;
    }
    HiLog.i(TAG, `Attempting to open file: %{private}s`, fileInfo.uri);
    this.openVideoSource(fileInfo, switchGeneration);
  }

  /**
   * 打开视频源：与音频一致，经 MediaPlaybackFileOpener 转为 fd 后交给 AVPlayer
   *
   * @param fileInfo 视频文件信息
   * @param switchGeneration 切歌代际
   */
  private openVideoSource(fileInfo: FileInfo, switchGeneration?: number): void {
    void this.openVideoSourceAsync(fileInfo, switchGeneration);
  }

  /**
   * 异步打开视频并设置 fd 播放源
   *
   * @param fileInfo 视频文件信息
   * @param switchGeneration 切歌代际
   */
  private finishParseFileTrace(): void {
    hiTraceMeter.finishAsyncTrace(hiTraceMeter.HiTraceOutputLevel.COMMERCIAL, 'VIDEO_PARSE_FILE',
      TaskId.PARSE_FILE);
  }

  private async openVideoSourceAsync(fileInfo: FileInfo, switchGeneration?: number): Promise<void> {
    if (this.isSwitchTargetStale(fileInfo.uri, switchGeneration)) {
      HiLog.i(TAG, `openVideoSource aborted before open uri=%{private}s`, fileInfo.uri);
      this.finishParseFileTrace();
      return;
    }
    const filePath = fileInfo.filePath.length > 0 ? fileInfo.filePath : fileInfo.mediaPath;
    HiLog.i(TAG, `Playing video file URI uri=${fileInfo.uri} path=${filePath}`);
    const beforeOpen: MediaSourceAccessState = MediaPlaybackSourceHelper.checkAccess(
      fileInfo.uri, fileInfo.filePath, fileInfo.mediaPath);
    HiLog.i(TAG, `openVideoSource precheck state=${beforeOpen} fileName=${fileInfo.fileName}`);
    if (beforeOpen === MediaSourceAccessState.MISSING) {
      showMediaSourceFailureToast(MediaSourceAccessState.MISSING);
      if (this.playPage) {
        this.playPage.loadingStatus = LoadingStatus.LOAD_STATE_FAILED;
      }
      this.finishParseFileTrace();
      this.openError();
      return;
    }
    const opened: MediaPlaybackOpenResult | null =
      await MediaPlaybackFileOpener.openReadOnly(fileInfo.uri, fileInfo.fileName);
    if (this.isSwitchTargetStale(fileInfo.uri, switchGeneration)) {
      if (opened) {
        await opened.release();
      }
      HiLog.i(TAG, `openVideoSource aborted stale uri=%{private}s gen=${switchGeneration}`,
        fileInfo.uri);
      this.finishParseFileTrace();
      return;
    }
    if (opened) {
      await this.applyVideoFdSource(fileInfo, opened, switchGeneration);
      return;
    }
    HiLog.e(TAG, `openVideoSource failed fileName=${fileInfo.fileName}`);
    const failureState: MediaSourceAccessState = MediaPlaybackSourceHelper.classifyOpenFailure(
      fileInfo.uri, fileInfo.filePath, fileInfo.mediaPath, beforeOpen);
    showMediaSourceFailureToast(failureState);
    if (this.playPage) {
      this.playPage.loadingStatus = LoadingStatus.LOAD_STATE_FAILED;
    }
    this.finishParseFileTrace();
    this.openError();
  }

  /**
   * 目标是否已过期：代际落后，或 pendingUri 已指向更新的曲目 / 有更新的 pending 排队
   */
  private isSwitchTargetStale(uri: string, switchGeneration?: number): boolean {
    if (switchGeneration !== undefined && !this.isTrackSwitchCurrent(switchGeneration)) {
      return true;
    }
    if (this.pendingSwitchFileInfo !== null && this.pendingSwitchFileInfo.uri !== uri) {
      return true;
    }
    if (this.pendingUri.length > 0 && this.pendingUri !== uri) {
      return true;
    }
    return false;
  }

  /**
   * 将已打开 fd 绑定到 AVPlayer（url 必须为 fd://）
   *
   * @param fileInfo 视频文件信息
   * @param opened 只读打开结果
   * @param switchGeneration 切歌代际
   */
  private async applyVideoFdSource(fileInfo: FileInfo, opened: MediaPlaybackOpenResult,
    switchGeneration?: number): Promise<void> {
    if (this.isSwitchTargetStale(fileInfo.uri, switchGeneration)) {
      void opened.release();
      this.finishParseFileTrace();
      return;
    }
    if (this.playPage === null) {
      HiLog.e(TAG, `applyVideoFdSource playPage is null uri=%{private}s`, fileInfo.uri);
      void opened.release();
      this.openError();
      return;
    }
    HiLog.i(TAG, `applyVideoFdSource uri=%{private}s fd=${opened.fd}`, fileInfo.uri);
    await this.loadVideoSessionCover(fileInfo, opened);
    if (this.isSwitchTargetStale(fileInfo.uri, switchGeneration)) {
      void opened.release();
      this.finishParseFileTrace();
      return;
    }
    const idle = await this.ensureIdleForSetSource();
    if (!idle) {
      HiLog.e(TAG, `applyVideoFdSource ensureIdle failed uri=%{private}s`, fileInfo.uri);
      void opened.release();
      this.openError();
      return;
    }
    if (this.isSwitchTargetStale(fileInfo.uri, switchGeneration)) {
      void opened.release();
      this.finishParseFileTrace();
      return;
    }
    this.fileInfo.fileSize = opened.size;
    this.fdRelease = opened.release;
    this.setFdSrc(opened.fd);
    this.playingUri = fileInfo.uri;
    if (this.pendingSwitchFileInfo === null && this.pendingUri === fileInfo.uri) {
      this.pendingUri = '';
    }
  }

  openError(error?: BusinessError): void {
    if (error) {
      HiLog.e(TAG, `open file failed with error message: ${JSON.stringify(error)}`);
      if (this.playPage) {
        this.playPage.errorMessage = `文件打开失败: ${error.message}`;
      }
    } else {
      HiLog.e(TAG, 'open file failed');
      if (this.playPage) {
        this.playPage.errorMessage = '文件打开失败';
      }
    }
    this.error();
  }

  error() {
    super.error();
    if (this.playPage !== null) {
      this.playPage.openType = OpenType.LOAD_STATE_FAILED;
      this.playPage.loadingStatus = LoadingStatus.LOAD_STATE_FAILED;
      HiLog.e(TAG, `Video prepare error, loadingStatus is LOAD_STATE_FAILED`);
    }
    if (this.fileInfo !== null) {
      let eventParams =
        new PreviewResultParams(this.fileInfo.mimeType, 1, Date.now() - this.startTime,
          this.fileInfo.fileSize);
      let recordParams: Record<string, Object> = {
        "mimeType": eventParams.mimeType,
        "openState": eventParams.openState,
        "costTime": eventParams.costTime,
        "fileSize": eventParams.fileSize
      };
      ReportUtil.reportFaultEvent(EventName.DFT_PREVIEW_RESULT, recordParams);
    }
    hiTraceMeter.finishAsyncTrace(hiTraceMeter.HiTraceOutputLevel.COMMERCIAL, 'VIDEO_PARSE_FILE',
      TaskId.PARSE_FILE);
  }

  toIdle(): void {
    super.toIdle();
    this.switchVideoEvent();
  }

  async toInitialized() {
    HiLog.i(TAG, `toInitialized with surfaceId: %{private}s`, this.surfaceID);
    if (this.avPlayer === null) {
      HiLog.e(TAG, 'avPlayer is null in toInitialized');
      return;
    }
    this.avPlayer.surfaceId = this.surfaceID;
    HiLog.i(TAG, `AVPlayer surfaceId set to: %{private}s`, this.surfaceID);
    // 必须在 prepare 前 await：否则策略未生效就开播
    await this.applyPreferredPlaybackStrategy();
    this.avPlayer.audioRendererInfo = {
      usage: audio.StreamUsage.STREAM_USAGE_MOVIE,
      rendererFlags: 0
    };
    this.avPlayer.prepare();

    if (this.windowType === WindowType.MAIN_WINDOW && this.playPage && this.isSwitch) {
      this.playPage.videoHeightRatio = Constants.ALL_PERCENT;
      this.playPage.videoWidthRatio = Constants.ALL_PERCENT;
      HiLog.i(TAG, 'toInitialized keep video surface size during switch');
    }
  }

  /**
   * initialized 态设置 PlaybackStrategy；preferredWidth/Height 为提示值。
   */
  private async applyPreferredPlaybackStrategy(): Promise<void> {
    if (this.avPlayer === null || this.avPlayer.state !== 'initialized') {
      return;
    }
    try {
      await this.avPlayer.setPlaybackStrategy({
        preferredBufferDuration: 20,
        showFirstFrameOnPrepare: true,
        preferredWidth: PlayConstants.VIDEO_PLAY_PLAYER_SURFACE_WIDTH,
        preferredHeight: PlayConstants.VIDEO_PLAY_PLAYER_SURFACE_HEIGHT
      });
      HiLog.i(TAG, 'applyPreferredPlaybackStrategy 1920x1080');
    } catch (error) {
      const bizError = error as BusinessError;
      HiLog.w(TAG, `applyPreferredPlaybackStrategy failed code=${bizError.code} message=${bizError.message}`);
    }
  }

  async toPrepared() {
    if (this.playPage === null) {
      HiLog.e(TAG, 'playPage is null');
      return;
    }

    HiLog.i(TAG, `toPrepared with window type: ${this.playPage.windowType}`);
    this.syncVideoPixelSizeToPage();
    this.adjustWindowSize();
    hiTraceMeter.startAsyncTrace(hiTraceMeter.HiTraceOutputLevel.INFO,
      TraceNameParam.VIDEO_PREPARE_PLAYER, TaskId.PREPARE_PLAYER, TraceCategoryParam.PREVIEW_VIDEO_FILE);
    let windowRect: window.Rect | undefined;
    if (this.playPage.windowType === WindowType.MAIN_WINDOW) {
      try {
        let windowClass: window.Window = await window.getLastWindow(getContext(this));
        windowRect = windowClass.getWindowProperties().windowRect;
        const displaySize = this.resolveVideoDisplaySize(windowRect);
        if (displaySize.width > 0 && displaySize.height > 0) {
          this.adjustVideoSize(displaySize);
        }
        await super.toPrepared();
      } catch (e) {
        let error: BusinessError = e as BusinessError;
        HiLog.e(TAG, `get window failed ,errorCode = ${error.code}, errorMessage = ${error.message}`);
      }
    } else if (WindowType.DIALOG_WINDOW === this.playPage.windowType) {
      this.adjustVideoSize(QuickViewConfig.dialogRect);
      await super.toPrepared();
    } else {
      this.adjustVideoSize(this.playPage.videoPlayerSize as window.Size);
      await super.toPrepared();
    }
    this.seekBackEvent();
    hiTraceMeter.finishAsyncTrace(hiTraceMeter.HiTraceOutputLevel.INFO, TraceNameParam.VIDEO_PREPARE_PLAYER,
      TaskId.PREPARE_PLAYER);
    this.setProgressHide(systemDateTime.getTime());

    if (this.playPage.loadingStatus !== LoadingStatus.LOAD_STATE_FAILED) {
      this.setWindowLayoutFullScreen();
      let needWaitVideoCvoer = (this.windowType === WindowType.UI_EXTENSION_WINDOW && this.isPCConfig);
      if (needWaitVideoCvoer && this.playPage?.isVideoCoverReady !== undefined &&
        this.playPage?.isVideoCoverReady === false) {
        HiLog.i(TAG, 'videoCover has not load completed');
        this.context.eventHub.on(VideoCoverEvent.event, (event: VideoCoverEvent) => {
          if (event.isReady && this.playPage !== null) {
            this.playPage.loadingStatus = LoadingStatus.LOAD_STATE_SUCCESS;
            this.context.eventHub.off(VideoCoverEvent.event);
          }
        })
      } else {
        HiLog.i(TAG, `LoadingStatus change to LOAD_STATE_SUCCESS`);
        this.playPage.loadingStatus = LoadingStatus.LOAD_STATE_SUCCESS;
      }
      this.storage?.setOrCreate<boolean>(LocalStorageParam.LOADING_END, true);
      hiTraceMeter.finishAsyncTrace(hiTraceMeter.HiTraceOutputLevel.COMMERCIAL, TraceNameParam.VIDEO_PARSE_FILE,
        TaskId.PARSE_FILE);
    }
    HiLog.i(TAG, `Video prepare successful, loadingStatus is LOAD_STATE_SUCCESS`);
    let eventParams =
      new PreviewResultParams(this.fileInfo.mimeType, 0, Date.now() - this.startTime,
        this.fileInfo.fileSize);
    let recordParams: Record<string, Object> = {};
    ReportUtil.reportFaultEvent(EventName.DFT_PREVIEW_RESULT, recordParams);
  }

  toPaused(): void {
    super.toPaused();
    this.applyControlCenterPausedState();
    this.dealUIExtensionPauseOrStop();
  }

  toCompleted(): void {
    HiLog.i(TAG, 'toCompleted.');
    if (PlaybackQueueManager.getInstance().skipToNext()) {
      return;
    }
    super.toCompleted();
    this.setProgressHide(systemDateTime.getTime());
  }

  get player(): media.AVPlayer | null {
    return this.avPlayer;
  }

  timeUpdate(time: number): void {
    super.timeUpdate(time);
    if (this.playPage !== null && this.playPage !== undefined) {
      if (time > 0 && this.playPage.isVideoCoverFirstShown) {
        this.playPage.isVideoCoverFirstShown = false;
      }
    }
  }

  isBrightAction(event: GestureEvent): boolean {
    if (!event || !event.fingerList || event.fingerList.length === 0 || !this.playPage) {
      HiLog.e(TAG, `isBrightAction, event is undefined`);
      return false;
    }

    const windowSize = this.resolveGestureWindowSize();
    if (!windowSize) {
      HiLog.e(TAG, `isBrightAction, windowSize is undefined`);
      return false;
    }
    let screenWidth: number = px2vp(windowSize.width);
    let localX: number = event.fingerList[0]?.localX ?? 0;
    HiLog.d(TAG, `isBrightAction, localX:${localX} screenWidth:${screenWidth}`);
    return localX !== 0 && localX < screenWidth / 2;
  }

  isVolumeAction(event: GestureEvent): boolean {
    if (!event || !event.fingerList || event.fingerList.length === 0 || !this.playPage) {
      HiLog.e(TAG, `isVolumeAction, event or playPage is undefined`);
      return false;
    }

    const windowSize = this.resolveGestureWindowSize();
    if (!windowSize) {
      HiLog.e(TAG, `isVolumeAction, windowSize is undefined`);
      return false;
    }
    let screenWidth: number = px2vp(windowSize.width);
    let localX: number = event.fingerList[0]?.localX ?? 0;
    HiLog.d(TAG, `isVolumeAction, localX:${localX} screenWidth:${screenWidth}`);
    return localX > screenWidth / 2;
  }

  onVolumeActionStart(event: GestureEvent) {
    if (!event || !this.playPage || !this.isActive()) {
      HiLog.w(TAG, `onVolumeActionStart, GestureEvent or playPage is undefined`);
      return;
    }
    // 每次新手势都重置起点：面板延时隐藏期间 panelVisible 仍为 true，否则会沿用上一轮 startValue 导致跳变
    this.gestureStartOffsetY = event.offsetY;
    this.gestureStartValue = this.lastPageVolumePercentage;
    HiLog.i(TAG, `onVolumeActionStart offsetY=${event.offsetY} startValue=${this.gestureStartValue}`);
    this.setBrightnessPanelVisible(false);
    this.setVolumePanelVisible(true);
  }

  onVolumeActionUpdate(event: GestureEvent) {
    if (!event || !this.avPlayer || !this.playPage || !this.isActive() || this.brightnessPanelVisible) {
      HiLog.w(TAG, `onVolumeActionUpdate, GestureEvent or avPlayer or playPage is undefined`);
      return;
    }
    try {
      let newVolumePercentage: number =
        this.computeGestureAdjustedValue(event, this.gestureStartOffsetY, this.gestureStartValue);
      if (!Number.isFinite(newVolumePercentage)) {
        HiLog.e(TAG, `onVolumeActionUpdate aborted invalid newVolume=${newVolumePercentage}`);
        return;
      }
      HiLog.i(TAG, `onVolumeActionUpdate, current:${this.playPage.volumePercentage} new:${newVolumePercentage} \
       source:${event.sourceTool}`);
      const volumeValue = newVolumePercentage * PlayConstants.MAX_AUDIO_LEVEL;
      this.updatePageVolume(volumeValue, newVolumePercentage);
      if (this.isPCConfig) {
        this.avPlayer.setVolume(this.playPage?.volumePercentage as number);
      } else {
        this.setSystemVolume(newVolumePercentage);
      }
    } catch (e) {
      let err: BusinessError = e as BusinessError;
      HiLog.e(TAG, `onVolumeActionUpdate error, message:${err.message} code:${err.code}`);
    }
  }

  onBrightActionStart(event: GestureEvent) {
    if (!event || !this.playPage || !this.isActive()) {
      HiLog.w(TAG, `onBrightActionStart, GestureEvent is undefined or playPage is undefined or isNotActive`);
      return;
    }
    // 每次新手势都重置起点：onActionEnd 延时隐藏面板时 brightnessPanelVisible 仍为 true，沿用旧 startBright 会跳回首轮亮度
    this.gestureStartOffsetY = event.offsetY;
    let baselineBright = this.lastPageBrightness;
    if (!Number.isFinite(baselineBright) || baselineBright === PlayConstants.FOLLOW_SYSTEM_BRIGHTNESS) {
      baselineBright = this.resolveGestureBrightnessBaseline();
      this.updatePageBrightness(baselineBright);
    }
    this.gestureStartValue = baselineBright;
    HiLog.i(TAG, `onBrightActionStart offsetY=${event.offsetY} startBright=${this.gestureStartValue}`);
    this.setVolumePanelVisible(false);
    this.setBrightnessPanelVisible(true);
  }

  onBrightActionUpdate(event: GestureEvent) {
    if (!event || !this.playPage || !this.isActive()) {
      HiLog.w(TAG, `onBrightActionUpdate, GestureEvent or playPage is undefined or isNotActive`);
      return;
    }
    try {
      let windowClass: window.Window = this.storage?.get<window.Window>(LocalStorageParam.WINDOW_CLASS) as
      window.Window;
      let newBright: number = this.computeGestureAdjustedValue(event, this.gestureStartOffsetY, this.gestureStartValue);
      if (!Number.isFinite(newBright)) {
        HiLog.e(TAG, `onBrightActionUpdate aborted invalid newBright=${newBright}`);
        return;
      }

      HiLog.d(TAG, `onBrightActionUpdate start=${this.gestureStartValue} new=${newBright} offsetY=${event.offsetY}`);
      this.updatePageBrightness(newBright);
      WindowUtil.setWindowBrightness(windowClass, newBright);
      if (this.isPCConfig) {
        WindowUtil.setWindowBrightness(windowClass, PlayConstants.FOLLOW_SYSTEM_BRIGHTNESS);
      }
    } catch (e) {
      let err: BusinessError = e as BusinessError;
      HiLog.e(TAG, `onBrightActionUpdate error, message:${err.message} code:${err.code}`);
    }
  }

  /**
   * 读取手势计算用的窗口尺寸：优先 LocalStorage windowSize，缺失时从 Window 属性回填。
   *
   * @returns 窗口宽高（px）
   */
  private resolveGestureWindowSize(): window.Size | undefined {
    const stored = this.storage?.get<window.Size>(LocalStorageParam.WINDOW_SIZE);
    if (stored !== undefined && stored.width > 0 && stored.height > 0) {
      return stored;
    }
    const windowClass = this.storage?.get<window.Window>(LocalStorageParam.WINDOW_CLASS);
    if (!windowClass) {
      return undefined;
    }
    try {
      const windowRect = windowClass.getWindowProperties().windowRect;
      const size: window.Size = { width: windowRect.width, height: windowRect.height };
      this.storage?.setOrCreate<window.Size>(LocalStorageParam.WINDOW_SIZE, size);
      HiLog.i(TAG, `resolveGestureWindowSize fromWindow width=${size.width} height=${size.height}`);
      return size;
    } catch (exception) {
      HiLog.e(TAG, `resolveGestureWindowSize failed: ${JSON.stringify(exception)}`);
      return undefined;
    }
  }

  /**
   * 亮度手势起点基准：跟随系统或非法值时回落到默认亮度。
   *
   * @returns 0~1 亮度值
   */
  private resolveGestureBrightnessBaseline(): number {
    const windowClass = this.storage?.get<window.Window>(LocalStorageParam.WINDOW_CLASS);
    const bright = WindowUtil.getCurrentBrightness(windowClass);
    if (!Number.isFinite(bright) || bright === PlayConstants.FOLLOW_SYSTEM_BRIGHTNESS) {
      return PlayConstants.PLAY_PAGE_DEFAULT_BRIGHTNESS;
    }
    return bright;
  }

  /**
   * 手势区域高度（vp）：优先视频 Stack 实测高度，与 PanGesture 坐标系一致。
   *
   * @returns 手势区域高度（vp）
   */
  private resolveGestureAreaHeightVp(): number {
    const videoSize = this.playPage?.videoPlayerSize as window.Size;
    if (videoSize !== undefined && videoSize.height > 0) {
      return videoSize.height as number;
    }
    const windowSize = this.resolveGestureWindowSize();
    if (windowSize !== undefined && windowSize.height > 0) {
      return px2vp(windowSize.height);
    }
    return 0;
  }

  /**
   * 按手势起点到当前偏移计算亮度/音量百分比（上滑增大、下滑减小）。
   *
   * @param event 手势事件
   * @param startOffsetY 手势起点 offsetY
   * @param startValue 手势起点数值
   * @returns 0~1 调整后的值
   */
  private computeGestureAdjustedValue(event: GestureEvent, startOffsetY: number, startValue: number): number {
    if (!Number.isFinite(startValue)) {
      HiLog.e(TAG, `computeGestureAdjustedValue invalid startValue=${startValue}`);
      return PlayConstants.PLAY_PAGE_DEFAULT_BRIGHTNESS;
    }
    const areaHeightVp: number = this.resolveGestureAreaHeightVp();
    if (!Number.isFinite(areaHeightVp) || areaHeightVp <= 0) {
      HiLog.e(TAG, `computeGestureAdjustedValue areaHeightVp invalid=${areaHeightVp}`);
      return startValue;
    }
    let changePercentage: number = (startOffsetY - event.offsetY) / areaHeightVp;
    if (event?.sourceTool === SourceTool.MOUSE && (event.axisVertical != 0 || event.axisHorizontal != 0)) {
      changePercentage *= -1;
    }
    return Math.min(PlayConstants.MAX_VALUE, Math.max(PlayConstants.MIN_VALUE, startValue + changePercentage));
  }
}
