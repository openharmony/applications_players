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
import { VideoPlayerController } from '../controller/VideoPlayerController';
import { Constants, LoadingStatus, ViewFileType, WindowType } from '@ohos/common/src/main/ets/constants/ui/Constants';
import { PlayConstants } from '@ohos/common/src/main/ets/constants/player/PlayConstants';
import { AVVideoPlayer } from '../component/AVVideoPlayer';
import { PlayerProgress } from '../component/PlayerProgress';
import FileInfo from '@ohos/common/src/main/ets/model/FileInfo';
import ToolbarItem, { ToolbarArray } from '@ohos/common/src/main/ets/model/ToolbarItem';
import { KeyCode } from '@ohos.multimodalInput.keyCode';
import { HiLog } from '@ohos/common/src/main/ets/utils/HiLog';
import DeviceConfigUtil from '@ohos/common/src/main/ets/utils/DeviceConfigUtil';
import mediaquery from '@ohos.mediaquery';
import { systemDateTime } from '@kit.BasicServicesKit';
import { TextConstants } from '@ohos/common/src/main/ets/constants/preview/TxtConstants';
import { VolumeAndBrightProgress } from '../component/VolumeAndBrightProgress';
import { media } from '@kit.MediaKit';
import { TitleBar } from '../view/appBar/TitleBar';
import router from '@ohos.router';
import { LocalStorageParam } from '@ohos/common/src/main/ets/constants/storage/StorageParam';
import VideoInformation from '@ohos/common/src/main/ets/model/VideoInformation';
import WindowUtil from '@ohos/common/src/main/ets/utils/WindowUtil';
import { appLocalStorage, syncAppLocalStorageSafeArea } from '@ohos/common/src/main/ets/storage/AppLocalStorage';
import { SafeAreaConstants } from '@ohos/common/src/main/ets/constants/ui/SafeAreaConstants';
import { VideoPlaybackUiState, VideoPlaybackViewModel } from '../viewmodel/VideoPlaybackViewModel';
import { VideoPlayerUiConstants } from '../constants/VideoPlayerUiConstants';
import { VideoPipViewModel } from '../viewmodel/VideoPipViewModel';
import { VideoPipContentSize } from '../constants/VideoPipConstants';
import { resolveVideoPipContentSize } from '../utils/VideoPipSizeUtil';
import {
  computeVideoContainRatio,
  computeVideoCoverRatio,
  DEFAULT_VIDEO_LAYOUT_SIZE,
  normalizeContainerForOrientation,
  VideoLayoutSize
} from '../utils/VideoLayoutUtil';
import { PlayerWindowModeParams, PlayerWindowModeUtil } from '../utils/PlayerWindowModeUtil';
import { VideoPlaybackSession } from '../session/VideoPlaybackSession';
import { AppThemeConstants } from '@ohos/common/src/main/ets/constants/ui/AppThemeConstants';

const TAG: string = 'VideoPlayPage';
/** 切向时不再叠厚黑条；与 AVVideoPlayer 恒定底边遮罩一致，避免弹出感 */
const BOTTOM_ORIENTATION_MASK_VP: number = 0;
/** 竖→横：不再加厚底边遮罩 */
const BOTTOM_ORIENTATION_MASK_TO_LANDSCAPE_VP: number = 0;
/** 竖→横：先关 renderGroup 后再收底边遮罩的额外等待（高分片通常不再关） */
const BREAK_HWC_OFF_MASK_HOLD_MS: number = 200;
/** 无窗口回调时的揭幕兜底 */
const ORIENTATION_CONCEAL_FAILSAFE_MS: number = 800;

@Component
export struct VideoPlayPage {
  @Link @Watch('onLoadingStatusChange') loadingStatus: LoadingStatus;
  @Prop @Watch('onFileInfoChange') fileInfo: FileInfo;
  @State title?: string = '';
  private videoControllerHolder: VideoPlayerController = new VideoPlayerController();
  private viewModel: VideoPlaybackViewModel = new VideoPlaybackViewModel(this.videoControllerHolder);
  private pipViewModel: VideoPipViewModel = new VideoPipViewModel(this.videoControllerHolder);
  @State videoController: VideoPlayerController = this.videoControllerHolder;
  @Provide status: number = PlayConstants.STATUS_PAUSE;
  @Provide currentVolume: number = PlayConstants.PLAY_PAGE_DEFAULT_VOLUME;
  @Provide @Watch('isProgressHideCallBack') isProgressHide: boolean = false;
  @State videoHeightRatio: string = Constants.ALL_PERCENT;
  @State videoWidthRatio: string = Constants.ALL_PERCENT;
  /** 片源像素尺寸（布局预估用） */
  @State videoPixelWidth: number = 0;
  @State videoPixelHeight: number = 0;
  /** 高分辨率竖屏 contain：renderGroup 消白条（不改视频比例） */
  @State breakHwcCompose: boolean = false;
  /** 旋转过渡：底边贴边遮绿（非整页黑屏） */
  @State concealVideoSurface: boolean = false;
  /** 画中画会话中：关闭底边黑遮罩，视频区背景改透明，避免小窗黑边 */
  @State pipSessionActive: boolean = false;
  @State bottomEdgeMaskVp: number = BOTTOM_ORIENTATION_MASK_VP;
  private concealSurfaceTimerId: number = -1;
  /** 切向中推迟关闭 renderGroup，等底边遮罩仍在时再关，减轻竖→横底边绿闪 */
  pendingBreakHwcDisable: boolean = false;
  @State videoPlayerSize: window.Size = { width: 0, height: 0 };
  @State isFullScreen: boolean = false;
  @State isImmersion: boolean = false;
  @State isTouchingPage: boolean = false;
  @State @Watch('playKeepScreenOn') playState: number = PlayConstants.STATUS_START;
  @State menuList: ToolbarItem[] = [];
  @State windowType: WindowType = WindowType.MAIN_WINDOW;
  @State bgColor: ResourceStr | Color = Color.Black;
  @StorageProp(AppThemeConstants.STORAGE_DARK_MODE) @Watch('onDarkModeChange') isDarkMode: boolean = false;
  @State avoidPcDefaultButton: boolean = true;
  @State videoFullScreenButton: ToolbarItem = new ToolbarItem('arrow_up_left_and_arrow_down_right',
    $r('app.string.amplify_title'), Constants.APP_BAR_ICON_IMMERSION, undefined, true, () => {
    });
  @State surfaceId: string = '';
  @State longPressStart: boolean = false;
  @State longPressSpeedPillTopMargin: number = 0;
  @State showVolumeProgress: boolean = false;
  @State showBrightnessProgress: boolean = false;
  @State volume: number = PlayConstants.PLAY_PAGE_DEFAULT_VOLUME;
  @State bright: number = PlayConstants.PLAY_PAGE_DEFAULT_BRIGHTNESS;
  @State volumePercentage: number = PlayConstants.PLAY_PAGE_DEFAULT_VOLUME;
  @State toolbarHeight: number = 0;
  @State speedLabel: string = '1.0X';
  @State showSpeedMenu: boolean = false;
  @State toolbarTransitionEnabled: boolean = false;
  @State isScreenLocked: boolean = false;
  @State showUnlockAffordance: boolean = false;
  @ObjectLink toolBarItems: ToolbarArray;
  public onClose?: () => void = undefined;
  @LocalStorageProp('isPcFullScreen') @Watch('isPcFullScreenChanged') isPcFullScreen: boolean = false;
  @LocalStorageProp(SafeAreaConstants.AVOID_BOTTOM_AREA_KEY) avoidBottomArea: number = 0;
  @LocalStorageProp(SafeAreaConstants.AVOID_CUTOUT_AREA_KEY) avoidArea: number = 0;
  @StorageProp(SafeAreaConstants.STATUS_BAR_HEIGHT_KEY) statusBarHeight: number = 0;
  @State @Watch('onLandscapeModeChanged') isLandscapeMode: boolean = false;
  @LocalStorageProp('windowSize') @Watch('windowSizeChange') windowSize: Size | undefined = undefined;
  @LocalStorageProp(LocalStorageParam.APP_IN_BACKGROUND) @Watch('onAppInBackgroundChange') isAppInBackground: boolean = false;
  @LocalStorageProp('playVideo') @Watch('onAppInBackgroundChange') playVideo: boolean = false;
  @LocalStorageProp('swiperVideo') @Watch('onSwiperVideo') swiperVideo: boolean = true;
  @LocalStorageProp(LocalStorageParam.VIDEO_INFORMATION) videoInformation: VideoInformation = new VideoInformation();

  private showGestureProgressTimerId: number = -1;
  private volumePanelHideTimerId: number = -1;
  private viewFileType: ViewFileType = ViewFileType.SINGLE;
  private activeUri: string = '';
  private visibleRatios: number[] = [0.0, 1.0];
  private storage: LocalStorage = appLocalStorage;
  private isPCConfig: boolean = DeviceConfigUtil.checkConfigForPC();
  private isPhoneConfig: boolean = DeviceConfigUtil.checkConfigForPhone();
  private preAccelerationSpeed: number = 1;
  private panOption: PanGestureOptions = new PanGestureOptions({ direction: PanDirection.Vertical });
  /** 旋转请求进行中，避免重复点击与乐观状态冲突 */
  private orientationTogglePending: boolean = false;
  private windowSizeChangeCallback = (data: window.Size) => {
    HiLog.d(TAG, `windowSizeChange size=${JSON.stringify(data)}`);
    const isLandscape = data.width > data.height;
    this.orientationTogglePending = false;
    // 先写本地方向，再算 contain；不再开关 conceal 黑条
    this.isLandscapeMode = isLandscape;
    this.concealVideoSurface = false;
    this.viewModel.setLandscapeMode(isLandscape, 'windowSizeChangeCallback');
    this.viewModel.setFullScreen(isLandscape);
    this.storage?.setOrCreate<Size>(LocalStorageParam.WINDOW_SIZE, { width: data.width, height: data.height });
    // 以窗口真实尺寸为准，避免 Stack 旧尺寸 + 对调造成拉伸
    const displaySize = this.resolveDisplaySize(data, isLandscape);
    this.applyVideoLayoutRatios(displaySize);
    this.videoController.refreshBreakHwcComposeFlag();
    this.videoController.handleSystemBar();
    this.scheduleSafeAreaRefreshAfterOrientation();
    this.pipViewModel.refreshContentSize();
  };

  private orientationMediaCallback = (result: mediaquery.MediaQueryResult) => {
    const isLandscape = result.matches as boolean;
    this.orientationTogglePending = false;
    this.isLandscapeMode = isLandscape;
    this.concealVideoSurface = false;
    this.viewModel.setLandscapeMode(isLandscape, 'orientationMediaCallback');
    this.viewModel.setFullScreen(isLandscape);
    HiLog.i(TAG, `orientationMediaCallback isLandscapeMode=${isLandscape} layoutFix=v4`);
    const rawSize = this.windowSize ?? this.videoPlayerSize;
    const displaySize = this.resolveDisplaySize(rawSize, isLandscape);
    this.applyVideoLayoutRatios(displaySize);
    this.videoController.refreshBreakHwcComposeFlag();
    this.videoController.handleSystemBar();
    this.scheduleSafeAreaRefreshAfterOrientation();
  };

  /**
   * ViewModel UI 状态回调：将视频交互状态同步到 ArkUI @State。
   *
   * @param state 视频播放 UI 状态快照
   */
  private handleUiStateChange = (state: VideoPlaybackUiState): void => {
    const wasLandscape = this.isLandscapeMode;
    this.isProgressHide = state.isProgressHide;
    this.isLandscapeMode = state.isLandscapeMode;
    this.isFullScreen = state.isFullScreen || (state.isLandscapeMode && state.isProgressHide);
    this.toolbarTransitionEnabled = state.toolbarTransitionEnabled;
    this.isScreenLocked = state.isScreenLocked;
    this.showUnlockAffordance = state.showUnlockAffordance;
    if (wasLandscape !== state.isLandscapeMode) {
      this.concealVideoSurface = false;
      this.syncVideoCanvasBackground();
      const displaySize = this.resolveDisplaySize(this.windowSize ?? this.videoPlayerSize, state.isLandscapeMode);
      this.applyVideoLayoutRatios(displaySize);
      this.videoController.refreshBreakHwcComposeFlag();
    }
  };

  mediaListener = mediaquery.matchMediaSync('(orientation: landscape)');
  @State videoWinClass: window.Window | undefined = this.storage?.get<window.Window>('windowClass');

  private toolBarEffect: TransitionEffect =
    TransitionEffect.OPACITY.animation({ duration: TextConstants.ANIMATE_LOAD_TIME, curve: Curve.Smooth })
      .combine(TransitionEffect.translate({ y: Constants.BAR_HEIGHT }))
      .combine(TransitionEffect.move(TransitionEdge.BOTTOM))

  /**
   * 控制区显隐回调：同步 ViewModel 状态并按视频场景更新系统栏。
   */
  isProgressHideCallBack() {
    this.viewModel.syncControlsHidden(this.isProgressHide, this.loadingStatus);
    this.applyPlayerSystemBars();
  }

  /**
   * 加载状态变化回调：首帧加载完成后才允许控制区转场动画。
   */
  onLoadingStatusChange(): void {
    this.viewModel.setLoadingStatus(this.loadingStatus);
    this.viewModel.syncControlsHidden(this.isProgressHide, this.loadingStatus);
    if (this.loadingStatus === LoadingStatus.LOAD_STATE_SUCCESS) {
      this.applyVideoLayoutRatios(this.videoPlayerSize);
      // 视频准备完成，此时视频像素尺寸已知，延迟创建PiP以使用正确的视频宽高比
      this.tryPrepareAutoPipOnHome();
    }
    HiLog.i(TAG, `onLoadingStatusChange status=${this.loadingStatus}`);
  }

  /**
   * 获取当前视频显示区域尺寸，优先使用已测量的 XComponent 容器尺寸。
   *
   * @param fallback 兜底窗口尺寸
   * @returns 视频显示区域尺寸
   */
  /**
   * @param fallback 容器尺寸回退（优先用窗口真实尺寸，避免 Stack 旧尺寸造成拉伸）
   * @param landscapeOverride 目标是否横屏；切向时传入避免 @State 尚未更新
   */
  private resolveDisplaySize(fallback: window.Size, landscapeOverride?: boolean): window.Size {
    let size: window.Size = { width: 0, height: 0 };
    // 切向时优先窗口回调尺寸（与目标方向一致），再用 Stack 实测
    if (fallback.width > 0 && fallback.height > 0) {
      size = fallback;
    } else if (this.windowSize !== undefined && this.windowSize.width > 0) {
      size = this.windowSize;
    } else if (this.videoPlayerSize.width > 0 && this.videoPlayerSize.height > 0) {
      size = this.videoPlayerSize;
    }
    // 分屏/悬浮窗用实测尺寸，避免强制竖屏面板时对调宽高导致拉伸
    if (this.isInSplitOrFloatingMode() || this.isPcFullScreen) {
      return size;
    }
    const portraitPanel = landscapeOverride !== undefined ?
      (!landscapeOverride && !this.isPcFullScreen) :
      (this.isPortraitPanelMode() && !this.isPcFullScreen);
    return this.normalizeContainerSize(size, portraitPanel);
  }

  /**
   * 按当前面板方向归一化容器尺寸，避免旋转过渡期用错宽高比。
   */
  private normalizeContainerSize(container: window.Size, portraitPanelMode: boolean): window.Size {
    const normalized = normalizeContainerForOrientation(
      new VideoLayoutSize(container.width, container.height),
      portraitPanelMode
    );
    const result: window.Size = { width: normalized.width, height: normalized.height };
    return result;
  }

  /**
   * 将窗口矩形转换为尺寸对象。
   *
   * @param windowRect 窗口矩形
   * @returns 窗口尺寸
   */
  private windowRectToSize(windowRect: window.Rect): window.Size {
    let size: window.Size = { width: 0, height: 0 };
    size.width = windowRect.width;
    size.height = windowRect.height;
    return size;
  }

  /**
   * 读取本地化字符串，失败时返回空字符串避免页面异常。
   *
   * @param resource 字符串资源
   * @returns 本地化文本
   */
  private getString(resource: Resource): string {
    try {
      return getContext(this).resourceManager.getStringSync(resource);
    } catch (exception) {
      HiLog.e(TAG, `Failed to get localized string. Cause: ${JSON.stringify(exception)}`);
      return '';
    }
  }

  /**
   * 处理视频控制区悬停状态；悬停暂停隐藏计时，离开后重新进入 4 秒自动隐藏流程。
   *
   * @param isHover 是否悬停
   * @param event 悬停事件
   */
  private handleControlsHover(isHover: boolean, event: HoverEvent): void {
    if (isHover) {
      HiLog.i(TAG, `handleControlsHover enter source=${event.source}`);
      this.viewModel.pauseAutoHide();
      return;
    }
    HiLog.i(TAG, `handleControlsHover leave source=${event.source}`);
    this.viewModel.showControlsAndScheduleHide(systemDateTime.getTime());
  }

  /**
   * PC 全屏状态变化回调：恢复窗口按钮状态并重新适配视频画面尺寸。
   */
  isPcFullScreenChanged() {
    if (!this.videoWinClass) {
      return;
    }
    HiLog.i(TAG, `isPcFullScreenChanged! isPcFullScreen:${this.isPcFullScreen}`);
    this.syncVideoCanvasBackground();
    if (!this.isPcFullScreen) {
      this.videoFullScreenButton.icon = Constants.APP_BAR_ICON_IMMERSION;
      this.videoFullScreenButton.title = $r('app.string.amplify_title');
      this.isImmersion = false;
      this.avoidPcDefaultButton = true;
    }
    let properties: window.WindowProperties = this.videoWinClass.getWindowProperties();
    let windowRect = properties.windowRect;
    const displaySize = this.resolveDisplaySize(this.windowRectToSize(windowRect));
    this.applyVideoLayoutRatios(displaySize);
  }

  /**
   * 播放状态变化回调：播放中保持屏幕常亮，暂停后恢复系统策略。
   */
  playKeepScreenOn() {
    let windowClass: window.Window | undefined;
    if (this.windowType === WindowType.MAIN_WINDOW) {
      windowClass = this.videoWinClass
    }
    if (windowClass) {
      this.videoController.keepScreenOn(windowClass, this.playState === PlayConstants.STATUS_START);
    }
  }

  /**
   * 方向变化回调：刷新视频页系统栏显示策略。
   */
  orientationChanged() {
    this.videoController.handleSystemBar();
  }

  /**
   * 本地窗口尺寸变化回调：同步横竖屏状态并刷新系统栏。
   */
  windowSizeChange() {
    if (this.windowSize !== undefined) {
      this.viewModel.setLandscapeMode(this.windowSize.width > this.windowSize.height, 'windowSizeChange');
    }
    this.videoController.handleSystemBar();
  }

  /**
   * LocalStorage「app_in_background」变化回调（MainAbility 前后台同步），非 UIAbility.onBackground。
   * 退后台：暂停或维持 PiP；回前台：结束画中画并恢复主窗口 Surface。
   */
  onAppInBackgroundChange(): void {
    if (!this.isAppInBackground) {
      HiLog.i(TAG, `onAppForeground playState=${this.playState} uri=${this.fileInfo?.uri ?? ''}`);
      void this.pipViewModel.onAppForeground(() => this.surfaceId);
      return;
    }
    HiLog.i(TAG, `onAppBackground isAppInBackground=${this.isAppInBackground} playVideo=${this.playVideo} playState=${this.playState} uri:%{private}s`, this.fileInfo?.uri ?? '');
    if (this.pipViewModel.onAppBackground()) {
      return;
    }
    if (!this.isPCConfig && this.playState === PlayConstants.STATUS_START) {
      this.videoController.pause();
    }
  }

  onFileInfoChange(): void {
    if (!this.fileInfo?.uri) {
      return;
    }
    if (this.activeUri.length === 0) {
      this.activeUri = this.fileInfo.uri;
      return;
    }
    if (this.activeUri === this.fileInfo.uri) {
      return;
    }
    this.viewModel.resetScreenLock();
    this.activeUri = this.fileInfo.uri;
    this.title = this.fileInfo.fileName;
    this.loadingStatus = LoadingStatus.LOAD_STATE_LOADING;
    this.storage?.setOrCreate<string>('preVideoUri', this.fileInfo.uri);
    this.pipViewModel.refreshContentSize();
    // Session 已切源时 getActiveUri 含 pendingUri，此处只同步 UI，避免二次 switchToTrack
    if (this.videoController.getActiveUri() === this.fileInfo.uri) {
      HiLog.i(TAG, `onFileInfoChange ui only uri=%{private}s`, this.fileInfo.uri);
      return;
    }
    HiLog.i(TAG, `onFileInfoChange switch track uri=%{private}s`, this.fileInfo.uri);
    this.videoController.switchToTrack(this.fileInfo);
  }

  /**
   * 页面初始化：绑定视频 ViewModel、窗口监听、控制器回调和当前文件信息。
   */
  aboutToAppear(): void {
    HiLog.i(TAG, `aboutToAppear loadingStatus:${this.loadingStatus}`)
    // 标记视频页存活：PiP 还原回前台时禁止壳层刷浅灰底
    WindowUtil.setVideoPlayerPageActive(true);
    if (this.videoWinClass) {
      WindowUtil.applyVideoWindowBackgroundColor(this.videoWinClass)
        .catch((error: Error) => {
          HiLog.w(TAG, `aboutToAppear applyVideoWindowBackground failed message=${error.message}`);
        });
    }
    syncAppLocalStorageSafeArea();
    HiLog.i(TAG, `aboutToAppear statusBarHeight=${this.statusBarHeight} avoidArea=${this.avoidArea}`);
    this.storage = appLocalStorage;
    this.viewModel.addUiStateListener(this.handleUiStateChange);
    this.viewModel.bindStorage(this.storage);
    this.pipViewModel.bindHost(getContext(this) as Context, () => this.resolvePipContentSizePx());
    VideoPlaybackSession.getInstance().bindPipSystemLockDelegate(this.pipViewModel);
    this.videoController.setPhoneInterruptPipHooks(
      () => this.pipViewModel.suspendForPhoneCall(),
      () => this.pipViewModel.restoreAfterPhoneCall()
    );
    HiLog.i(TAG, 'aboutToAppear pipHostBound=true');
    this.viewModel.setLoadingStatus(this.loadingStatus);
    if (this.fileInfo) {
      this.title = this.fileInfo.fileName;
      this.activeUri = this.fileInfo.uri;
      this.storage?.setOrCreate<string>('preVideoUri', this.fileInfo?.uri);
    } else {
      this.title = this.getString($r('app.string.unknown_file'));
    }
    HiLog.d(TAG, `begin to open video file: %{private}s uri:%{private}s`, this.title ?? '', this.fileInfo?.uri);
    this.videoFullScreenButton.action = () => {
      this.immersionAction();
    };
    if (this.isPCConfig) {
      this.menuList.push(this.videoFullScreenButton);
    }
    this.videoController.initPlayPage(this);
    this.videoController.setPagePlayStateUpdater((state: number) => {
      this.playState = state;
      this.pipViewModel.syncPlaybackControlState(state);
    });
    this.videoController.setVolumePanelUpdater((show: boolean) => {
      this.showVolumeProgress = show;
      if (this.volumePanelHideTimerId !== -1) {
        clearTimeout(this.volumePanelHideTimerId);
        this.volumePanelHideTimerId = -1;
      }
      if (show) {
        this.volumePanelHideTimerId = setTimeout(() => {
          this.showVolumeProgress = false;
          this.videoController.setVolumePanelVisible(false);
          this.volumePanelHideTimerId = -1;
        }, PlayConstants.HIDE_VOLUME_PROGRESS_TIME);
      }
    });
    this.videoController.setPageVolumeUpdater((volume: number, volumePercentage: number) => {
      this.volume = volume;
      this.volumePercentage = volumePercentage;
    });
    this.videoController.setBrightnessPanelUpdater((show: boolean) => {
      this.showBrightnessProgress = show;
    });
    this.videoController.setPageBrightnessUpdater((bright: number) => {
      HiLog.i(TAG, `brightnessUiUpdate bright=${bright}`);
      this.bright = bright;
    });
    
    if (!this.videoWinClass) {
      try {
        window.getLastWindow(getContext(this), (err, win) => {
          if (err.code) {
            HiLog.e(TAG, `Failed to getLastWindow: ${JSON.stringify(err)}`);
            return;
          }
          this.videoWinClass = win;
          this.storage?.setOrCreate<window.Window>('windowClass', win);
          this.initWindowProperties();
        });
      } catch (exception) {
        HiLog.e(TAG, `Failed to getLastWindow catch: ${JSON.stringify(exception)}`);
      }
    } else {
      this.initWindowProperties();
    }
    this.mediaListener.on('change', this.orientationMediaCallback);
  }

  private initWindowProperties(): void {
    if (!this.videoWinClass) {
      HiLog.e(TAG, 'initWindowProperties: videoWinClass is undefined');
      return;
    }
    try {
      let windowRect = this.videoWinClass.getWindowProperties().windowRect;
      const isLandscape = windowRect.width > windowRect.height;
      this.viewModel.setLandscapeMode(isLandscape, 'initWindowProperties');
      this.viewModel.setFullScreen(isLandscape);
      this.storage?.setOrCreate<Size>(LocalStorageParam.WINDOW_SIZE, { width: windowRect.width, height: windowRect.height });
      HiLog.i(TAG, `initWindowProperties windowSize width=${windowRect.width} height=${windowRect.height}`);
      try {
        this.videoWinClass.on('windowSizeChange', this.windowSizeChangeCallback);
      } catch (exception) {
        HiLog.e(TAG, `Failed to enable listener for window size changes. Cause: ${JSON.stringify(exception)}`);
      }
      HiLog.i(TAG, 'Succeeded in obtaining top window.');
      WindowUtil.refreshAppSafeArea(this.videoWinClass);
      this.applyPlayerSystemBars();
    } catch (exception) {
      HiLog.e(TAG, `Failed to obtain window properties. Cause: ${JSON.stringify(exception)}`);
    }
  }

  /**
   * PC 沉浸全屏切换入口：全屏时立即隐藏控制区，避免窗口装饰变化闪烁。
   */
  private async immersionAction() {
    if (!this.videoWinClass) {
      HiLog.e(TAG, `immersionAction, videoWinClass is undefind`);
      return;
    }
    if (!this.isImmersion) {
      HiLog.i(TAG, `maximize video window`);
      this.isImmersion = true;
      this.viewModel.setFullScreen(true);
      this.avoidPcDefaultButton = false;
      this.videoFullScreenButton.title = $r('app.string.shrink_title');
      this.viewModel.hideControlsNow();
      this.videoFullScreenButton.icon = Constants.APP_BAR_ICON_RECOVER;
      await this.videoWinClass.setFullScreen(true);
    } else {
      HiLog.i(TAG, `recover video window`);
      await this.recoverWindow();
    }
    let properties: window.WindowProperties = this.videoWinClass.getWindowProperties();
    let windowRect = properties.windowRect;
    this.videoController.adjustVideoSize(windowRect);
  }

  /**
   * 恢复 PC 沉浸窗口，用于全屏按钮和 ESC 快捷键。
   */
  public async recoverWindow() {
    if (!this.videoWinClass) {
      HiLog.e(TAG, `recoverWindow, videoWinClass is undefind`);
      return;
    }
    HiLog.i(TAG, `recover window`);
    this.videoFullScreenButton.icon = Constants.APP_BAR_ICON_IMMERSION;
    this.videoFullScreenButton.title = $r('app.string.amplify_title');
    this.isImmersion = false;
    this.viewModel.setFullScreen(false);
    this.avoidPcDefaultButton = true;
    await this.videoWinClass.recover();
  }

  /**
   * 页面销毁：释放播放器、监听器、定时器并恢复系统栏。
   */
  aboutToDisappear() {
    HiLog.i(TAG, `aboutToDisappear`)
    WindowUtil.setVideoPlayerPageActive(false);
    VideoPlaybackSession.getInstance().unbindPipSystemLockDelegate(this.pipViewModel);
    this.viewModel.resetScreenLock();
    this.viewModel.removeUiStateListener(this.handleUiStateChange);
    if (this.volumePanelHideTimerId !== -1) {
      clearTimeout(this.volumePanelHideTimerId);
      this.volumePanelHideTimerId = -1;
    }
    if (this.showGestureProgressTimerId !== -1) {
      clearTimeout(this.showGestureProgressTimerId);
      this.showGestureProgressTimerId = -1;
    }
    if (this.concealSurfaceTimerId !== -1) {
      clearTimeout(this.concealSurfaceTimerId);
      this.concealSurfaceTimerId = -1;
    }
    this.concealVideoSurface = false;
    this.pendingBreakHwcDisable = false;
    this.bottomEdgeMaskVp = BOTTOM_ORIENTATION_MASK_VP;
    this.restoreSystemBars();
    this.pipViewModel.release()
      .then(() => {
        this.videoController.release();
      })
      .catch((error: Error) => {
        HiLog.w(TAG, `pipRelease failed message=${error.message}`);
        this.videoController.release();
      });
    try {
      if (!this.videoWinClass) {
        return;
      }
      this.videoWinClass.off('windowSizeChange', this.windowSizeChangeCallback);
      this.mediaListener.off('change', this.orientationMediaCallback);
      if (this.isPhoneConfig) {
        this.viewModel.setLandscapeMode(false, 'aboutToDisappear');
        WindowUtil.applyAppAutoRotation(this.videoWinClass);
      }
    } catch (exception) {
      HiLog.e(TAG, `Failed to off windowSizeChange. Cause: ${JSON.stringify(exception)}`);
    }
  }

  /**
   * 滑动切换回视频页时，在合适状态下恢复播放。
   */
  onSwiperVideo() {
    HiLog.i(TAG, `onSwiperChange video, ${this.swiperVideo} ${this.playState} viewFileType:${this.viewFileType}`);
    if (this.viewFileType === ViewFileType.MULTIPLE && this.swiperVideo && !this.isAppInBackground &&
      this.playState === PlayConstants.STATUS_PAUSE && !this.isPCConfig) {
      this.videoController.play();
    }
  }

  /**
   * 判断移动端视频是否已播放完成。
   *
   * @returns 是否处于移动端完成态
   */
  isMobileStop(): boolean {
    return this.playState === PlayConstants.STATUS_COMPLETE && (!this.isPCConfig);
  }

  /**
   * 锁屏态用户交互：仅拉起锁定图标，4 秒无操作后自动隐藏。
   */
  private handleLockedScreenInteraction(): void {
    HiLog.i(TAG, 'handleLockedScreenInteraction');
    this.viewModel.onLockedScreenInteraction();
  }

  /**
   * 单击视频画面：显隐控制区（标题栏 + 底部交互区）。
   */
  private handleVideoSingleTap(): void {
    if (this.isScreenLocked) {
      this.handleLockedScreenInteraction();
      return;
    }
    HiLog.i(TAG, `handleVideoSingleTap isProgressHide=${this.isProgressHide} portrait=${this.isPortraitPanelMode()}`);
    this.videoController.setVolumeShow(false);
    this.viewModel.toggleControls(systemDateTime.getTime(), this.isProgressHide);
  }

  /**
   * 双击视频画面：播放 / 暂停；横屏沉浸时顺带拉起控制区并续订自动隐藏。
   */
  private handleVideoDoubleTap(): void {
    if (this.isScreenLocked) {
      this.handleLockedScreenInteraction();
      return;
    }
    HiLog.i(TAG, `handleVideoDoubleTap isMobileStop=${this.isMobileStop()}`);
    if (this.isMobileStop()) {
      return;
    }
    this.videoController.switchPlayOrPause();
    if (!this.isPortraitPanelMode()) {
      this.viewModel.showControlsAndScheduleHide(systemDateTime.getTime());
    }
  }

  /** 透明手势层：未锁屏时承接单击/双击与音量亮度滑动。 */
  @Builder
  VideoTapGestureOverlay() {
    if (this.isScreenLocked) {
      this.VideoLockedTapGestureOverlay()
    } else {
      this.VideoUnlockedTapGestureOverlay()
    }
  }

  /** 锁屏态手势层：单击/双击/滑动/触摸仅拉起锁定图标，不触发播放或控制区。 */
  @Builder
  VideoLockedTapGestureOverlay() {
    Column()
      .width(Constants.ALL_PERCENT)
      .height(Constants.ALL_PERCENT)
      .backgroundColor($r('sys.color.ohos_id_color_background_transparent'))
      .zIndex(Constants.ZINDEX_THIRD)
      .gesture(
        GestureGroup(GestureMode.Exclusive,
          TapGesture({ count: Constants.DOUBLE_CLICK })
            .onAction(() => {
              this.handleLockedScreenInteraction();
            }),
          TapGesture({ count: Constants.SINGLE_CLICK })
            .onAction(() => {
              this.handleLockedScreenInteraction();
            })
        )
      )
      .parallelGesture(
        LongPressGesture({ fingers: 1, duration: PlayConstants.PLAYER_PROGRESS_ONE_THOUSAND })
          .onAction(() => {
            this.handleLockedScreenInteraction();
          })
      )
      .parallelGesture(
        PanGesture(this.panOption)
          .onActionStart(() => {
            this.handleLockedScreenInteraction();
          })
      )
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          this.handleLockedScreenInteraction();
        }
      })
  }

  /** 未锁屏手势层：单击显隐控制区、双击播放暂停、滑动调音量亮度。 */
  @Builder
  VideoUnlockedTapGestureOverlay() {
    Column()
      .width(Constants.ALL_PERCENT)
      .height(Constants.ALL_PERCENT)
      .backgroundColor($r('sys.color.ohos_id_color_background_transparent'))
      .zIndex(Constants.ZINDEX_THIRD)
      .gesture(
        GestureGroup(GestureMode.Exclusive,
          TapGesture({ count: Constants.DOUBLE_CLICK })
            .onAction(() => {
              this.handleVideoDoubleTap();
            }),
          TapGesture({ count: Constants.SINGLE_CLICK })
            .onAction(() => {
              this.handleVideoSingleTap();
            })
        )
      )
      .parallelGesture(
        LongPressGesture({ fingers: 1, duration: PlayConstants.PLAYER_PROGRESS_ONE_THOUSAND })
          .onAction(() => {
            this.longPressStart = this.playState === PlayConstants.STATUS_START;
            if (!this.longPressStart) {
              return;
            }
            this.syncLongPressSpeedPillTopMargin();
            HiLog.i(TAG, `longPressSpeedStart portrait=${this.isPortraitPanelMode()} pillTop=${this.longPressSpeedPillTopMargin}`);
            this.preAccelerationSpeed = this.videoController.getSpeed();
            this.videoController.setSpeed(media.PlaybackSpeed.SPEED_FORWARD_3_00_X);
          })
          .onActionEnd(() => {
            HiLog.i(TAG, `longPressSpeedEnd restoreSpeed=${this.preAccelerationSpeed}`);
            this.longPressStart = false;
            this.videoController.setSpeed(this.preAccelerationSpeed);
          })
      )
      .parallelGesture(
        GestureGroup(GestureMode.Exclusive,
          PanGesture(this.panOption)
            .onActionStart((event: GestureEvent) => {
              if (this.windowType === WindowType.UI_EXTENSION_WINDOW ||
                (!this.isPCConfig && this.playState === PlayConstants.STATUS_COMPLETE)) {
                return;
              }
              if (this.showGestureProgressTimerId !== -1) {
                clearTimeout(this.showGestureProgressTimerId);
                this.showGestureProgressTimerId = -1;
              }
              if (this.videoController.isBrightAction(event)) {
                this.videoController.onBrightActionStart(event);
              } else {
                this.videoController.onVolumeActionStart(event);
              }
            })
            .onActionUpdate((event: GestureEvent) => {
              if (this.windowType === WindowType.UI_EXTENSION_WINDOW ||
                (!this.isPCConfig && this.playState === PlayConstants.STATUS_COMPLETE)) {
                return;
              }
              if (this.videoController.isBrightAction(event)) {
                this.videoController.onBrightActionUpdate(event);
              } else {
                this.videoController.onVolumeActionUpdate(event);
              }
            })
            .onActionEnd(() => {
              if (this.windowType === WindowType.UI_EXTENSION_WINDOW) {
                return;
              }
              this.showGestureProgressTimerId = setTimeout(() => {
                this.videoController.setVolumePanelVisible(false);
                this.videoController.setBrightnessPanelVisible(false);
                clearTimeout(this.showGestureProgressTimerId);
                this.showGestureProgressTimerId = -1;
                HiLog.i(TAG, `onActionEnd volume=${this.volume} brightness=${this.bright}`);
              }, PlayConstants.HIDE_VOLUME_PROGRESS_TIME);
            }),
          PinchGesture({ fingers: 2 })
            .onActionStart(() => {
              HiLog.i(TAG, 'PinchGesture fingers');
            })
        )
      )
  }

  /** 视频播放区左侧居中锁屏按钮：横向滑入/滑出，不参与标题栏纵向转场。 */
  @Builder
  VideoScreenLockSideButton() {
    Stack({ alignContent: Alignment.Start }) {
      Column() {
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph(this.isScreenLocked ? Constants.APP_BAR_ICON_LOCK : Constants.APP_BAR_ICON_UNLOCK)
            .fontSize(VideoPlayerUiConstants.LOCK_SIDE_ICON_SIZE)
            .fontColor([Color.White])
        }
        .width(VideoPlayerUiConstants.LOCK_SIDE_BUTTON_SIZE)
        .height(VideoPlayerUiConstants.LOCK_SIDE_BUTTON_SIZE)
        .backgroundColor(VideoPlayerUiConstants.LOCK_SIDE_BUTTON_BG)
        .accessibilityText(this.isScreenLocked ? $r('app.string.video_screen_unlock') :
          $r('app.string.video_screen_lock'))
        .onClick(() => {
          if (this.isScreenLocked) {
            HiLog.i(TAG, 'videoLockSideButton clicked action=unlock');
            this.viewModel.unlockScreen();
          } else {
            HiLog.i(TAG, 'videoLockSideButton clicked action=lock');
            this.viewModel.lockScreen();
          }
        })
      }
      .justifyContent(FlexAlign.Center)
      .height(Constants.ALL_PERCENT)
      .margin({ left: VideoPlayerUiConstants.LOCK_SIDE_BUTTON_MARGIN_LEFT })
      .offset({ x: this.getLockSideOffsetX() })
      .opacity(this.shouldShowLockSideButton() ? 1 : 0)
      .hitTestBehavior(this.shouldShowLockSideButton() ? HitTestMode.Default : HitTestMode.None)
      .animation({
        duration: VideoPlayerUiConstants.LOCK_SIDE_SLIDE_DURATION_MS,
        curve: Curve.Smooth
      })
    }
    .width(Constants.ALL_PERCENT)
    .height(Constants.ALL_PERCENT)
    .zIndex(VideoPlayerUiConstants.LOCK_OVERLAY_Z_INDEX)
    .hitTestBehavior(this.shouldShowLockSideButton() ? HitTestMode.Transparent : HitTestMode.None)
  }

  /**
   * 返回上一层页面或关闭外部容器。
   * 横屏时首次返回仅恢复竖屏：与 rotate 按钮一致，只请求系统旋转，不乐观更新 isLandscapeMode。
   */
  goBack() {
    HiLog.i(TAG, 'goBack called');
    if (!this.isPCConfig && this.isLandscapeMode && this.videoWinClass) {
      HiLog.i(TAG, 'goBack recover portrait first');
      if (this.orientationTogglePending) {
        HiLog.w(TAG, 'goBack recover portrait ignored pending=true');
        return;
      }
      try {
        this.concealVideoSurface = false;
        this.orientationTogglePending = true;
        WindowUtil.applyDarkVideoSystemBars(this.videoWinClass, true);
        this.videoWinClass.setPreferredOrientation(window.Orientation.PORTRAIT);
        setTimeout(() => {
          this.orientationTogglePending = false;
        }, 1500);
      } catch (exception) {
        this.orientationTogglePending = false;
        HiLog.e(TAG, `goBack recover portrait failed: ${JSON.stringify(exception)}`);
      }
      return;
    }
    if (this.onClose) {
      this.onClose();
    } else {
      router.back();
    }
  }

  /**
   * 构建当前页面窗口模式参数快照，供 PlayerWindowModeUtil 消费。
   *
   * @returns 窗口模式参数
   */
  private buildWindowModeParams(): PlayerWindowModeParams {
    return {
      isPCConfig: this.isPCConfig,
      windowClass: this.videoWinClass,
      isLandscapeMode: this.isLandscapeMode,
      isPcFullScreen: this.isPcFullScreen,
      windowType: this.windowType,
    };
  }

  /**
   * 判断当前是否为竖屏视频面板模式。
   * 委托 PlayerWindowModeUtil 统一处理：竖屏 / 分屏 / 悬浮窗均返回 true。
   *
   * @returns 是否竖屏面板
   */
  private isPortraitPanelMode(): boolean {
    return PlayerWindowModeUtil.isPortraitPanelMode(this.buildWindowModeParams());
  }

  /**
   * 是否处于分屏或悬浮窗等非全屏窗口模式。
   * 委托 PlayerWindowModeUtil 统一处理，避免与控制器中重复实现。
   */
  private isInSplitOrFloatingMode(): boolean {
    return PlayerWindowModeUtil.isInSplitOrFloatingMode(this.videoWinClass, this.isPCConfig);
  }

  /**
   * 视频进度条时间是否使用全屏白色样式：手机横屏或 PC 全屏。
   *
   * @returns 是否全屏播放场景
   */
  private isVideoProgressFullscreenMode(): boolean {
    return (!this.isPCConfig && this.isLandscapeMode) || this.isPcFullScreen;
  }

  /**
   * 解析视频像素尺寸：优先 AVPlayer，其次缓存的 videoInformation。
   */
  private resolveVideoPixelSize(): window.Size | undefined {
    const fromPlayer = this.videoController.getVideoPixelSize();
    if (fromPlayer !== undefined && fromPlayer.width > 0 && fromPlayer.height > 0) {
      return fromPlayer;
    }
    if (this.videoInformation.width > 0 && this.videoInformation.height > 0) {
      return { width: this.videoInformation.width, height: this.videoInformation.height };
    }
    return undefined;
  }

  /**
   * 判断当前视频是否为横屏内容（宽 >= 高）。
   * 视频尺寸未就绪时默认返回 true，保持现有横屏铺满行为。
   *
   * @returns 视频是否为横屏
   */
  private isVideoLandscape(): boolean {
    const videoSize = this.resolveVideoPixelSize();
    if (videoSize && videoSize.width > 0 && videoSize.height > 0) {
      return videoSize.width >= videoSize.height;
    }
    return true;
  }

  /**
   * 同步 UI 层 Surface 比例，与横竖屏状态同帧更新，避免旋转后先留白再恢复。
   *
   * @param containerSize 视频容器尺寸
   */
  private applyVideoLayoutRatios(containerSize?: window.Size): void {
    let container = containerSize ?? this.videoPlayerSize;
    if (container.width <= 0 || container.height <= 0) {
      if (this.windowSize !== undefined && this.windowSize.width > 0 && this.windowSize.height > 0) {
        container = this.windowSize;
      } else {
        HiLog.w(TAG, 'applyVideoLayoutRatios skip empty container');
        return;
      }
    }
    this.videoController.adjustVideoSize(container);
    this.syncLongPressSpeedPillTopMargin();
  }

  /** 切向遮罩已废弃：保留空实现避免旧调用链编译失败 */
  private beginOrientationConceal(_toLandscape?: boolean): void {
    this.concealVideoSurface = false;
    this.pendingBreakHwcDisable = false;
  }

  private endOrientationConceal(_delayMs: number = 650, _toLandscape: boolean = false): void {
    this.concealVideoSurface = false;
    this.pendingBreakHwcDisable = false;
  }

  private applyDeferredBreakHwcDisable(): void {
    this.pendingBreakHwcDisable = false;
    this.concealVideoSurface = false;
    this.videoController.refreshBreakHwcComposeFlag();
  }

  /**
   * 控制区浮层（标题栏 + 底部进度条）是否可见且可点击。
   * 与 isProgressHide 联动：单击切换、4 秒自动隐藏；锁屏时强制隐藏。
   *
   * @returns 是否显示控制区浮层
   */
  private isControlsChromeVisible(): boolean {
    if (this.isScreenLocked) {
      return false;
    }
    if (this.windowType !== WindowType.MAIN_WINDOW) {
      return true;
    }
    if (!this.isProgressHide) {
      return true;
    }
    return this.isPCConfig && !this.isImmersion;
  }

  /**
   * 右侧锁屏按钮是否可见：锁屏时随 showUnlockAffordance 显隐；未锁屏时随控制区显隐。
   *
   * @returns 是否显示锁屏侧按钮
   */
  private shouldShowLockSideButton(): boolean {
    if (this.isScreenLocked) {
      return this.showUnlockAffordance;
    }
    return this.isControlsChromeVisible();
  }

  /**
   * 获取视频原始帧率，用于底部信息区展示。
   *
   * @returns 视频帧率
   */
  private getVideoFrameRate(): number {
    return this.videoInformation?.originFrameRate ?? 0;
  }

  /**
   * 读取设备当前真实横竖屏方向，避免 @State 与窗口尺寸不一致导致旋转早退。
   *
   * @returns 当前是否为横屏
   */
  private resolveDeviceLandscape(): boolean {
    if (this.windowSize !== undefined && this.windowSize.width > 0 && this.windowSize.height > 0) {
      return this.windowSize.width > this.windowSize.height;
    }
    if (this.videoWinClass) {
      try {
        const windowRect = this.videoWinClass.getWindowProperties().windowRect;
        return windowRect.width > windowRect.height;
      } catch (exception) {
        HiLog.e(TAG, `resolveDeviceLandscape failed: ${JSON.stringify(exception)}`);
      }
    }
    return this.isLandscapeMode;
  }

  /**
   * 锁屏侧按钮横向偏移：显示贴左，隐藏滑出屏幕左侧。
   *
   * @returns 横向偏移量（vp）
   */
  private getLockSideOffsetX(): number {
    return this.shouldShowLockSideButton() ? 0 : -VideoPlayerUiConstants.LOCK_SIDE_BUTTON_SLIDE_X;
  }

  /**
   * 切换手机横竖屏；仅以系统方向回调更新布局态，不做乐观 setState。
   */
  private toggleOrientation(): void {
    if (!this.videoWinClass) {
      HiLog.e(TAG, 'toggleOrientation: videoWinClass is undefined');
      return;
    }
    if (this.orientationTogglePending) {
      HiLog.w(TAG, 'toggleOrientation ignored pending=true');
      return;
    }
    try {
      const currentlyLandscape = this.resolveDeviceLandscape();
      const targetLandscape = !currentlyLandscape;
      const targetOrientation = targetLandscape ?
        window.Orientation.LANDSCAPE : window.Orientation.PORTRAIT;
      HiLog.i(TAG, `toggleOrientation deviceLandscape=${currentlyLandscape} targetLandscape=${targetLandscape}`);
      this.concealVideoSurface = false;
      this.orientationTogglePending = true;
      WindowUtil.applyDarkVideoSystemBars(this.videoWinClass, !targetLandscape);
      this.videoWinClass.setPreferredOrientation(targetOrientation);
      setTimeout(() => {
        this.orientationTogglePending = false;
        // 分屏等场景可能无二次 onAreaChange，结算后强制按实测容器重算 contain
        this.applyVideoLayoutRatios(this.videoPlayerSize);
        HiLog.i(TAG, `toggleOrientation settle refresh size=${JSON.stringify(this.videoPlayerSize)}`);
      }, 1500);
    } catch (exception) {
      this.orientationTogglePending = false;
      HiLog.e(TAG, `Failed to toggle orientation: ${JSON.stringify(exception)}`);
    }
  }

  /**
   * 视频页画布统一黑底，标题/控件使用浮层浅色样式以保证可读。
   */
  private useVideoOverlayChrome(): boolean {
    return true;
  }

  /** 视频页（含竖屏 letterbox）统一纯黑底。 */
  private syncVideoCanvasBackground(): void {
    this.bgColor = Color.Black;
  }

  /** 系统深浅色切换时同步播放器系统栏与画布背景 */
  private onDarkModeChange(): void {
    HiLog.i(TAG, `onDarkModeChange isDarkMode=${this.isDarkMode}`);
    this.syncVideoCanvasBackground();
    this.applyPlayerSystemBars();
  }

  /**
   * 根据当前窗口模式应用视频页系统栏策略。
   */
  private applyPlayerSystemBars(): void {
    if (!this.videoWinClass || this.isPCConfig) {
      return;
    }
    const showBars = PlayerWindowModeUtil.shouldShowSystemBars(this.buildWindowModeParams());
    WindowUtil.applyDarkVideoSystemBars(this.videoWinClass, showBars);
  }

  /**
   * 获取横屏底部控制区 y 轴位置。
   *
   * @returns 控制区 y 偏移
   */
  private getLandscapeProgressPanelOffsetY(): number {
    return this.viewModel.getLandscapeProgressPanelOffsetY(this.videoPlayerSize, this.toolbarHeight);
  }

  /**
   * 标题浮层显隐与底栏共用 isControlsChromeVisible，避免底栏可见而顶栏缺失。
   * 单一 TitleBar 不随横竖屏销毁重建，避免旋转过渡卡住导致返回/旋转按钮消失。
   *
   * @returns 是否显示标题浮层
   */
  private shouldShowTitleOverlay(): boolean {
    if (this.windowType !== WindowType.MAIN_WINDOW) {
      return false;
    }
    return this.isControlsChromeVisible();
  }

  /** 横屏顶栏半透明底；竖屏透明由 TitleBar 自身处理。 */
  private getTitleOverlayBackground(): ResourceColor {
    if (this.isPortraitPanelMode()) {
      return $r('sys.color.ohos_id_color_background_transparent');
    }
    if (this.isPCConfig && !this.isPcFullScreen) {
      return Constants.COLOR_BACKGROUND;
    }
    return VideoPlayerUiConstants.LANDSCAPE_TITLE_BAR_BG;
  }

  /** 标题栏 + 底部进度条浮层：始终挂载，仅用显隐控制，不参与 Column 垂直占位。 */
  @Builder
  VideoControlsOverlay() {
    if (this.windowType === WindowType.MAIN_WINDOW) {
      Column() {
        TitleBar({
          toolBarItems: this.toolBarItems,
          fileInfo: this.fileInfo,
          fileName: this.title,
          windowType: this.windowType,
          page: this as Object,
          avoidPcDefaultButton: this.avoidPcDefaultButton,
          isVideoMode: this.isPortraitPanelMode() ? this.useVideoOverlayChrome() : true,
          transparentTitleBar: this.isPortraitPanelMode() ? !this.useVideoOverlayChrome() : false,
          showRotateButton: this.isPortraitPanelMode() || this.isPhoneConfig,
          onRotate: () => {
            this.toggleOrientation();
          },
          onBack: () => {
            this.goBack();
          }
        })
          .id('video_play_title_bar')
          .onHover((isHover: boolean, event: HoverEvent) => {
            this.handleControlsHover(isHover, event);
          })
      }
      .padding({ top: this.getStatusBarTopInset() })
      .backgroundColor(this.getTitleOverlayBackground())
      .visibility(this.shouldShowTitleOverlay() ? Visibility.Visible : Visibility.Hidden)
      .position({ x: Constants.ORIGIN_X, y: Constants.ORIGIN_Y })
      .width(Constants.ALL_PERCENT)
      .hitTestBehavior(this.shouldShowTitleOverlay() ? HitTestMode.Default : HitTestMode.None)
      .zIndex(VideoPlayerUiConstants.LOCK_OVERLAY_Z_INDEX)
    }

    Column() {
      Blank()
        .layoutWeight(1)
        .hitTestBehavior(HitTestMode.None)
      this.PlayerProgressPanel()
    }
    .width(Constants.ALL_PERCENT)
    .height(Constants.ALL_PERCENT)
    .hitTestBehavior(HitTestMode.None)
    .zIndex(Constants.ZINDEX_FOURTH)
  }

  /**
   * 横竖屏切换后刷新安全区：系统栏显隐与 avoidArea 回调存在滞后，分次同步。
   */
  private onLandscapeModeChanged(): void {
    HiLog.i(TAG, `onLandscapeModeChanged isLandscapeMode=${this.isLandscapeMode}`);
    this.applyPlayerSystemBars();
    this.scheduleSafeAreaRefreshAfterOrientation();
  }

  /**
   * 方向切换后延迟刷新 AppStorage / LocalStorage 安全区，供 TitleBar inset 与 Nav 页使用。
   */
  private scheduleSafeAreaRefreshAfterOrientation(): void {
    if (!this.videoWinClass) {
      return;
    }
    WindowUtil.refreshAppSafeArea(this.videoWinClass);
    setTimeout(() => {
      if (this.videoWinClass) {
        WindowUtil.refreshAppSafeArea(this.videoWinClass);
        syncAppLocalStorageSafeArea();
      }
    }, 150);
    setTimeout(() => {
      if (this.videoWinClass) {
        WindowUtil.refreshAppSafeArea(this.videoWinClass);
        syncAppLocalStorageSafeArea();
      }
    }, 400);
  }

  /**
   * 顶栏顶部避让：竖屏预留状态栏；横屏系统栏隐藏时仍避让 cutout，避免返回/旋转贴顶被挡。
   *
   * @returns 顶部避让高度（vp）
   */
  private getStatusBarTopInset(): number {
    if (this.isPCConfig) {
      return 0;
    }
    if (this.windowType !== WindowType.MAIN_WINDOW) {
      return 0;
    }
    const liveInset = WindowUtil.getStatusBarInsetVp(this.videoWinClass);
    if (liveInset > 0) {
      return liveInset;
    }
    if (!this.isPortraitPanelMode()) {
      const cutoutInset = WindowUtil.getCutoutTopInsetVp(this.videoWinClass);
      if (cutoutInset > 0) {
        return cutoutInset;
      }
      return 0;
    }
    if (this.statusBarHeight > 0) {
      return this.statusBarHeight;
    }
    return this.avoidArea;
  }

  /**
   * 同步长按倍速胶囊顶边距：竖屏居中于视频上方留白区，横屏贴近屏幕上方正中。
   */
  private syncLongPressSpeedPillTopMargin(): void {
    const containerHeight = this.videoPlayerSize.height;
    const pillHeight = VideoPlayerUiConstants.LONG_PRESS_SPEED_PILL_HEIGHT;
    if (containerHeight <= 0) {
      this.longPressSpeedPillTopMargin = VideoPlayerUiConstants.LONG_PRESS_SPEED_PILL_FALLBACK_TOP;
      return;
    }
    if (!this.isPortraitPanelMode()) {
      this.longPressSpeedPillTopMargin = VideoPlayerUiConstants.LONG_PRESS_SPEED_LANDSCAPE_TOP_MARGIN;
      return;
    }
    let heightPercent = 100;
    if (this.videoHeightRatio.endsWith('%')) {
      const parsed = parseFloat(this.videoHeightRatio.substring(0, this.videoHeightRatio.length - 1));
      heightPercent = Number.isNaN(parsed) ? 100 : parsed;
    }
    const videoDisplayHeight = containerHeight * heightPercent / 100;
    const videoTop = (containerHeight - videoDisplayHeight) / 2;
    const marginTop = (videoTop - pillHeight) / 2;
    this.longPressSpeedPillTopMargin = Math.max(0, marginTop);
  }

  /** 视频底部交互区：复用 PlayerProgress，但在横屏时作为浮层覆盖视频，避免挤压 XComponent。 */
  @Builder
  PlayerProgressPanel() {
    Column() {
      PlayerProgress({
        avPlayerController: this.videoController,
        playState: $playState,
        isHideProgressAndTitle: $isProgressHide,
        type: 'video',
        windowType: this.windowType,
        volumePercentage: this.volumePercentage,
        isAudio: false,
        isPortraitVideoPanel: this.isPortraitPanelMode(),
        isVideoFullscreen: this.isVideoProgressFullscreenMode(),
        videoFrameRate: this.getVideoFrameRate(),
        toolbarHeight: this.toolbarHeight,
        fileInfo: this.fileInfo,
        speedLabel: $speedLabel,
        showSpeedMenu: $showSpeedMenu,
      })
        .id('video_play_play_progress')
        .padding({
          bottom: this.isPortraitPanelMode() ?
            (this.avoidBottomArea > 0 ? this.avoidBottomArea : $r('app.float.play_progress_margin_bottom_phone')) :
            $r('app.float.play_progress_margin_bottom_phone'),
          left: this.avoidArea + 'px',
          right: this.avoidArea + 'px',
          top: 0,
        })
        .animation(Constants.PADDING_ANIMATE_PARAM)
        .linearGradient(this.isPortraitPanelMode() ? {
          direction: GradientDirection.Bottom,
          colors: [[$r('sys.color.ohos_id_color_background_transparent'), 0.0], [$r('sys.color.ohos_id_color_background_transparent'), 1.0]]
        } : {
          direction: GradientDirection.Bottom,
          colors: Constants.PLAYER_PROGRESS_BG_GRADIENT_VIDEO
        })
        .visibility(this.isMobileStop() ? Visibility.None : Visibility.Visible)
        .onVisibleAreaChange(this.visibleRatios, (isVisible: boolean, currentRatio: number) => {
          HiLog.i(TAG, `progress visible=${isVisible} ratio=${currentRatio} time=${systemDateTime.getTime()}`)
          this.videoController.setProgressVisible(isVisible);
        })
    }
    .zIndex(Constants.ZINDEX_FOURTH)
    .transition(this.toolbarTransitionEnabled ? this.toolBarEffect : undefined)
    .visibility(this.isControlsChromeVisible() ? Visibility.Visible : Visibility.Hidden)
    .onHover((isHover: boolean, event: HoverEvent) => {
      this.handleControlsHover(isHover, event);
    })
    .hitTestBehavior(this.isControlsChromeVisible() ? HitTestMode.Default : HitTestMode.None)
    .onAreaChange((oldValue: Area, newValue: Area) => {
      this.toolbarHeight = newValue.height as number;
      HiLog.i(TAG, `toolbarHeight=${this.toolbarHeight}`);
    })
    .width(Constants.ALL_PERCENT)
    .backgroundColor($r('sys.color.ohos_id_color_background_transparent'))
  }

  /**
   * 供 PiP ViewModel 查询当前内容尺寸。
   */
  private resolvePipContentSizePx(): VideoPipContentSize {
    const videoInfo = this.storage?.get<VideoInformation>(LocalStorageParam.VIDEO_INFORMATION);
    let storedVideoInfo: VideoPipContentSize | undefined = undefined;
    if (videoInfo !== undefined && videoInfo.width > 0 && videoInfo.height > 0) {
      storedVideoInfo = { width: videoInfo.width, height: videoInfo.height };
    }
    return resolveVideoPipContentSize({
      isLandscapeMode: this.isLandscapeMode,
      videoWinClass: this.videoWinClass,
      videoPixelSize: this.videoController.getVideoPixelSize(),
      storedVideoInfo: storedVideoInfo,
    });
  }

  /**
   * Surface 就绪后注册回桌面自动画中画（手机主窗口）。
   */
  private tryPrepareAutoPipOnHome(): void {
    if (!this.isPhoneConfig || this.windowType !== WindowType.MAIN_WINDOW) {
      return;
    }
    this.pipViewModel.prepareAutoPipOnHome()
      .catch((error: Error) => {
        HiLog.w(TAG, `tryPrepareAutoPipOnHome failed message=${error.message}`);
      });
  }

  /**
   * 退出视频页时恢复应用默认系统栏样式。
   */
  private restoreSystemBars(): void {
    if (this.isPCConfig) {
      return;
    }
    if (this.videoWinClass) {
      WindowUtil.restoreDefaultSystemBars(this.videoWinClass);
      return;
    }
    try {
      window.getLastWindow(getContext(this), (err, win) => {
        if (err.code) {
          HiLog.e(TAG, `Failed to restore system bars, getLastWindow: ${JSON.stringify(err)}`);
          return;
        }
        WindowUtil.restoreDefaultSystemBars(win);
      });
    } catch (exception) {
      HiLog.e(TAG, `Failed to restore system bars: ${JSON.stringify(exception)}`);
    }
  }

  build() {
    this.UnifiedVideoLayout()
  }

  /** 视频播放根布局：视频区独占 Column，控制区全部以 Stack 浮层叠加，避免显隐时挤压视频。 */
  @Builder
  UnifiedVideoLayout() {
    Column() {
      Stack({ alignContent: Alignment.Center }) {
        this.VideoInteractiveArea()

        this.VideoTapGestureOverlay()

        if (this.longPressStart) {
          this.LongPressToAccelerateText()
        }

        this.VideoControlsOverlay()

        this.VideoScreenLockSideButton()
      }
      .layoutWeight(1)
      .width(Constants.ALL_PERCENT)
    }
    .focusable(true)
    .onKeyEvent((event: KeyEvent) => {
      if (this.isScreenLocked) {
        return;
      }
      this.viewModel.showControlsAndScheduleHide(systemDateTime.getTime());
    })
    .onTouch((event: TouchEvent) => {
      if (!this.isPCConfig) {
        return;
      }
      if (event.type == TouchType.Down) {
        this.isTouchingPage = true;
      }
      if (event.type === TouchType.Up) {
        this.isTouchingPage = false;
        if (event.touches[0].x < 0 || event.touches[0].x > event.target.area.width ||
          event.touches[0].y < 0 || event.touches[0].y > event.target.area.height) {
          this.viewModel.hideControlsNow();
        }
      }
    })
    .width(Constants.ALL_PERCENT)
    .height(Constants.ALL_PERCENT)
    .backgroundColor(this.bgColor)
  }

  /** 视频画面与手势层：承载 XComponent、音量亮度手势和播放快捷键。 */
  @Builder
  VideoInteractiveArea() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.isMobileStop()) {
        Button({ buttonStyle: ButtonStyleMode.TEXTUAL, role: ButtonRole.NORMAL, type: ButtonType.Circle, }) {
          Image($r('app.media.audio_player_play'))
            .draggable(false)
            .width($r('app.float.play_progress_center_play_image_size'))
            .height($r('app.float.play_progress_center_play_image_size'))
        }
        .accessibilityText($r('app.string.play'))
        .accessibilityGroup(true)
        .accessibilityLevel('yes')
        .align(Alignment.Center)
        .margin({
          top: $r('app.float.play_progress_play_volume_image_margin_top'),
          bottom: $r('app.float.play_progress_play_volume_image_margin_bottom')
        })
        .onClick((event: ClickEvent) => {
          HiLog.i(TAG, `centerPlay clicked source=${event.source}`);
          this.videoController.switchPlayOrPause();
          this.viewModel.showControlsAndScheduleHide(systemDateTime.getTime());
        })
        .visibility((this.showVolumeProgress || this.isScreenLocked) ? Visibility.Hidden : Visibility.Visible)
        .draggable(false)
        .zIndex(Constants.ZINDEX_FOURTH)
        .id('video_play_button_center')
      }

      Stack() {
        Column() {
          Column() {
            AVVideoPlayer({
              surfaceId: this.surfaceId,
              playVideoModel: this.videoController,
              isFullScreen: this.isFullScreen || this.isPcFullScreen,
              breakHwcCompose: this.breakHwcCompose,
              // PiP 中关掉底边 8vp 黑条，否则小窗底部像黑色遮罩
              cropBottomGreenEdge: !this.pipSessionActive && (this.videoPixelWidth >= 2560 ||
                (this.videoPixelWidth > 0 && this.videoPixelHeight > 0 &&
                  this.videoPixelWidth / this.videoPixelHeight > 2.0) ||
                this.breakHwcCompose),
              concealSurface: this.concealVideoSurface,
              onXComponentControllerReady: (controller: XComponentController) => {
                HiLog.i(TAG, 'onXComponentControllerReady');
                this.pipViewModel.setXComponentController(controller);
              }
            })
              .focusOnTouch(true)
              .focusable(true)
              .height(this.videoHeightRatio)
              .width(this.videoWidthRatio)
              .clip(true)
              .backgroundColor(this.pipSessionActive ? Color.Transparent : Color.Black)
          }
          .alignItems(HorizontalAlign.Center)
          .justifyContent(FlexAlign.Center)
          .width('100%')
          .height('100%')
          .backgroundColor(this.pipSessionActive ? Color.Transparent : Color.Black)
          .clip(true)
        }
        .width('100%')
        .height('100%')
        .backgroundColor(this.pipSessionActive ? Color.Transparent : Color.Black)

        // 溢绿改由 AVVideoPlayer 恒定细遮罩处理；此处不再叠厚黑条，避免切向黑条弹出

        if (this.windowType !== WindowType.UI_EXTENSION_WINDOW) {
          VolumeAndBrightProgress({
            volume: $volume,
            volumePercentage: $volumePercentage,
            bright: $bright,
            showVolumeProgress: $showVolumeProgress,
            showBrightnessProgress: $showBrightnessProgress,
            avPlayerController: this.videoController,
          })
        }
      }
      .width(Constants.ALL_PERCENT)
      .height(Constants.ALL_PERCENT)
    }
    .id('video_play_stack_id')
    .accessibilityText($r('app.string.video'))
    .onKeyEvent((event: KeyEvent) => {
      if (this.isScreenLocked) {
        return;
      }
      HiLog.i(TAG, 'onKeyEvent trigger. keyCode: %{private}s type:%{private}s', String(event.keyCode),
        String(event.type));
      this.viewModel.showControlsAndScheduleHide(systemDateTime.getTime());
      if (event.type === KeyType.Down && event.keyCode === KeyCode.KEYCODE_SPACE) {
        this.videoController && this.videoController.switchPlayOrPause();
        event.stopPropagation();
      }
      if (event.type === KeyType.Down && event.keyCode === KeyCode.KEYCODE_ESCAPE) {
        HiLog.i(TAG, 'onKeyEvent trigger recover.');
        this.recoverWindow();
      }
    })
    .onAreaChange((oldValue: Area, newValue: Area) => {
      this.videoPlayerSize = {
        width: newValue.width as number,
        height: newValue.height as number
      }
      HiLog.i(TAG, `video area changed width=${this.videoPlayerSize.width} height=${this.videoPlayerSize.height}`);
      this.applyVideoLayoutRatios(this.videoPlayerSize);
    })
    .onAppear(() => {
      let res = focusControl.requestFocus('video_play_stack_id');
      HiLog.i(TAG, `requestFocus res : ${res}`);
    })
    .focusable(true)
    .accessibilityDefaultFocus(true)
    .onMouse((event: MouseEvent) => {
      if (this.isScreenLocked) {
        if (event.action === MouseAction.Move) {
          this.handleLockedScreenInteraction();
        }
        return;
      }
      if (event.action === MouseAction.Move) {
        HiLog.d(TAG, `onMouse moving source=${event.source}`);
        this.viewModel.showControlsAndScheduleHide(systemDateTime.getTime());
      }
    })
    .width(Constants.ALL_PERCENT)
    .height(Constants.ALL_PERCENT)
    .zIndex(Constants.ZINDEX_FIRST)
  }

  /** 长按倍速提示胶囊：竖屏在视频上方白区正中，横屏在屏幕上方正中。 */
  @Builder
  LongPressToAccelerateText() {
    Column() {
      Row() {
        SymbolGlyph(Constants.APP_BAR_ICON_FAST_FORWARD)
          .fontSize(VideoPlayerUiConstants.LONG_PRESS_SPEED_ICON_SIZE)
          .fontColor([Color.White])

        Text($r('app.string.fast_forwarding', VideoPlayerUiConstants.LONG_PRESS_SPEED_LABEL))
          .fontSize(VideoPlayerUiConstants.LONG_PRESS_SPEED_TEXT_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .margin({ left: VideoPlayerUiConstants.LONG_PRESS_SPEED_TEXT_ICON_GAP })
      }
      .height(VideoPlayerUiConstants.LONG_PRESS_SPEED_PILL_HEIGHT)
      .padding({
        left: VideoPlayerUiConstants.LONG_PRESS_SPEED_PILL_PADDING_H,
        right: VideoPlayerUiConstants.LONG_PRESS_SPEED_PILL_PADDING_H
      })
      .borderRadius(VideoPlayerUiConstants.LONG_PRESS_SPEED_PILL_RADIUS)
      .backgroundColor(VideoPlayerUiConstants.LONG_PRESS_SPEED_PILL_BG)
    }
    .width(Constants.ALL_PERCENT)
    .height(Constants.ALL_PERCENT)
    .alignItems(HorizontalAlign.Center)
    .padding({ top: this.longPressSpeedPillTopMargin })
    .zIndex(VideoPlayerUiConstants.LONG_PRESS_SPEED_PILL_Z_INDEX)
    .hitTestBehavior(HitTestMode.None)
  }
}
