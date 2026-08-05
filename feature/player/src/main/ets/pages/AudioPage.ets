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
import { PlayerProgress } from '../component/PlayerProgress';
import { AudioPlayerController } from '../controller/AudioPlayerController';
import { AudioPlayer } from '../component/AudioPlayer';
import {
  Constants, LoadingStatus, ViewFileType, WindowType
} from '@ohos/common/src/main/ets/constants/ui/Constants';
import DeviceConfigUtil from '@ohos/common/src/main/ets/utils/DeviceConfigUtil';
import { PlayConstants } from '@ohos/common/src/main/ets/constants/player/PlayConstants';
import WindowUtil, { OrientationSnapshot } from '@ohos/common/src/main/ets/utils/WindowUtil';
import { appLocalStorage } from '@ohos/common/src/main/ets/storage/AppLocalStorage';
import { LocalStorageParam } from '@ohos/common/src/main/ets/constants/storage/StorageParam';
import { SafeAreaConstants } from '@ohos/common/src/main/ets/constants/ui/SafeAreaConstants';
import { ReportUtil } from '@ohos/common/src/main/ets/utils/ReportUtil';
import FileInfo from '@ohos/common/src/main/ets/model/FileInfo';
import { PlaybackHistoryRestoreCallback } from '@ohos/common';
import ToolbarItem, { ToolbarArray } from '@ohos/common/src/main/ets/model/ToolbarItem';
import { PreviewResultParams } from '@ohos/common/src/main/ets/player/Params';
import { KeyCode } from '@ohos.multimodalInput.keyCode';
import {
  EventName, ResultOpenState, TaskId
} from '@ohos/common/src/main/ets/constants/system/EventName';
import { TraceCategoryParam, TraceNameParam } from '@ohos/common/src/main/ets/constants/system/TraceParam';
import { HiLog } from '@ohos/common/src/main/ets/utils/HiLog';
import hiTraceMeter from '@ohos.hiTraceMeter';
import { TitleBar } from '../view/appBar/TitleBar';
import { AudioPlaybackSession } from '../session/AudioPlaybackSession';
import { AppThemeConstants } from '@ohos/common/src/main/ets/constants/ui/AppThemeConstants';
import { PlayerUiConstants } from '../constants/PlayerUiConstants';

let TAG = 'AudioPage'

@Component
export struct AudioPage {
  @State audioController: AudioPlayerController = AudioPlaybackSession.getInstance().getController();
  @Prop @Watch('onFileInfoChange') fileInfo: FileInfo;
  @Link loadingStatus: LoadingStatus;
  // 是否全屏
  @LocalStorageProp('isPcFullScreen') isPcFullScreen: boolean = false;
  // 当前页面的播放状态
  @State playState: number = PlayConstants.STATUS_START;
  @State isHideProgressAndTitle: boolean = false;
  // UIExtension场景下面场景大小
  @State uiExtensionAudioSize: window.Size = { width: 0, height: 0 };
  @StorageProp('isLandScape') @Watch('isLandScapeCallBack') isLandScape: boolean = false;
  @State windowType: WindowType = WindowType.MAIN_WINDOW;
  @LocalStorageProp(SafeAreaConstants.AVOID_CUTOUT_AREA_KEY) avoidArea: number = 0;
  @StorageProp(SafeAreaConstants.STATUS_BAR_HEIGHT_KEY) statusBarHeight: number = 0;
  @LocalStorageProp(SafeAreaConstants.AVOID_BOTTOM_AREA_KEY) avoidBottomArea: number = 0;
  @LocalStorageProp('windowSize') @Watch('windowSizeChange') windowSize: Size | undefined = undefined;
  private startTime: number = Date.now();
  // 校验PC配置
  private isPCConfig: boolean = DeviceConfigUtil.checkConfigForPC();
  // 校验Phone配置
  private isPhoneConfig: boolean = DeviceConfigUtil.checkConfigForPhone();
  // 校验 Pad 配置
  private isTabletConfig: boolean = DeviceConfigUtil.checkConfigForTablet();
  private storage: LocalStorage = appLocalStorage;
  // 窗口对象
  private windowClass: window.Window | undefined = this.storage?.get<window.Window>('windowClass');
  @StorageProp(AppThemeConstants.STORAGE_DARK_MODE) @Watch('onDarkModeChange') isDarkMode: boolean = false;
  /** 播放页背景：固定黑色背景色 */
  @State bgColor: Resource = $r('app.color.player_page_bg');
  @LocalStorageProp('swiperAudio') @Watch('onSwiperAudio') swiperAudio: boolean = true;
  @LocalStorageProp(LocalStorageParam.APP_IN_BACKGROUND) isAppInBackground: boolean = false;
  private viewFileType: ViewFileType = ViewFileType.SINGLE;
  private playEvent: number = -1;
  private context: Context | undefined = undefined;
  @LocalStorageLink('loadingEnd') loadingEnd: boolean = false;
  @State volumePercentage: number = PlayConstants.PLAY_PAGE_DEFAULT_VOLUME;
  @State showAudioSpeedMenu: boolean = false;
  @State currentSpeedLabel: string = '1.0X';
  @ObjectLink toolBarItems: ToolbarArray;
  public onClose?: () => void = undefined;
  public onMinimize?: () => void = undefined;
  onRestoreHistoryPlayback?: PlaybackHistoryRestoreCallback;
  onAudioQueueEmpty?: () => void;
  private activeUri: string = '';
  /** 进入播放页前的壳层方向，用于返回首页时恢复横竖屏 */
  private shellOrientationSnapshot: OrientationSnapshot | null = null;

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
    HiLog.i(TAG, `onFileInfoChange switch track uri=%{private}s`, this.fileInfo.uri);
    this.activeUri = this.fileInfo.uri;
    this.loadingStatus = LoadingStatus.LOAD_STATE_LOADING;
    this.audioController.switchToTrack(this.fileInfo);
  }

  // 横竖屏变化对应事件
  isLandScapeCallBack() {
  }

  // 窗口尺寸尺寸变化事件
  windowSizeChange() {
  }

  /**
   * 顶部状态栏避让：Nav 全屏页优先 AppStorage，LocalStorage 可能晚于首帧同步
   *
   * @returns 顶部安全区高度（vp）
   */
  private getTopSafeInset(): number {
    if (this.statusBarHeight > 0) {
      return this.statusBarHeight;
    }
    return this.avoidArea;
  }

  private applyPlayerSystemBars(): void {
    if (!this.windowClass || this.isPCConfig) {
      return;
    }
    WindowUtil.applyPlayerDarkSystemBars(this.windowClass);
  }

  /** 系统深浅色切换时同步播放器系统栏 */
  private onDarkModeChange(): void {
    HiLog.i(TAG, `onDarkModeChange isDarkMode=${this.isDarkMode}`);
    this.applyPlayerSystemBars();
  }

  /**
   * 按设备类型锁定或放开音频页旋转（手机竖屏，平板自动旋转）。
   */
  private applyPlaybackOrientation(): void {
    if (!this.windowClass || this.isPCConfig) {
      return;
    }
    /** 获取当前窗口的方向快照 */
    this.shellOrientationSnapshot = WindowUtil.captureOrientationSnapshot(this.windowClass);
    WindowUtil.applyAudioPlaybackOrientation(this.windowClass);
    /** 增加 landscape（是否横屏） 信息日志 */
    HiLog.i(TAG, `applyPlaybackOrientation landscape=${this.shellOrientationSnapshot.isLandscape} ` +
      `phone=${this.isPhoneConfig} tablet=${this.isTabletConfig}`);
  }

  private initWindowClass(): void {
    if (this.windowClass) {
      this.applyPlayerSystemBars();
      this.applyPlaybackOrientation();
      return;
    }
    try {
      window.getLastWindow(getContext(this), (err, win) => {
        if (err.code) {
          HiLog.e(TAG, 'Failed to getLastWindow: ' + JSON.stringify(err));
          return;
        }
        this.windowClass = win;
        this.storage?.setOrCreate<window.Window>('windowClass', win);
        this.applyPlayerSystemBars();
        this.applyPlaybackOrientation();
      });
    } catch (exception) {
      HiLog.e(TAG, 'Failed to getLastWindow catch: ' + JSON.stringify(exception));
    }
  }

  private restoreSystemBars(): void {
    if (this.isPCConfig) {
      return;
    }
    /** 使用完快照后将其清空（释放资源） */
    const snapshot = this.shellOrientationSnapshot;
    this.shellOrientationSnapshot = null;
    if (this.windowClass) {
      WindowUtil.restoreDefaultSystemBarsWithOrientation(this.windowClass, snapshot);
      return;
    }
    try {
      window.getLastWindow(getContext(this), (err, win) => {
        if (err.code) {
          HiLog.e(TAG, 'Failed to restore system bars, getLastWindow: ' + JSON.stringify(err));
          return;
        }
        WindowUtil.restoreDefaultSystemBarsWithOrientation(win, snapshot);
      });
    } catch (exception) {
      HiLog.e(TAG, 'Failed to restore system bars: ' + JSON.stringify(exception));
    }
  }

  changeSystemBar() {
    this.applyPlayerSystemBars();
  }

  onSwiperAudio() {
    HiLog.i(TAG, `onSwiperChange audio, ${this.swiperAudio} ${this.playState}`);
    if (this.viewFileType === ViewFileType.MULTIPLE && this.swiperAudio && !this.isAppInBackground &&
      this.playState === PlayConstants.STATUS_PAUSE && !this.isPCConfig) {
      this.playEvent = setTimeout(() => {
        this.audioController.play();
        clearTimeout(this.playEvent);
      }, Constants.MOUNTED_TASK_TIMEOUT);
    }
  }

  aboutToAppear() {
    this.initWindowClass();
    HiLog.i(TAG, `aboutToAppear`);
    hiTraceMeter.startAsyncTrace(hiTraceMeter.HiTraceOutputLevel.INFO,
      TraceNameParam.AUDIO_LOAD_PAGE, TaskId.LOAD_PAGE, TraceCategoryParam.PREVIEW_AUDIO_FILE);

    if (this.isPcFullScreen && this.windowClass) {
      WindowUtil.setPCWindowFullScreen(this.windowClass, false);
    }

    if (this.fileInfo === undefined || this.fileInfo === null || this.fileInfo.uri === undefined) {
      HiLog.e(TAG, 'file info is undefined');

      this.loadingStatus = LoadingStatus.LOAD_STATE_FAILED;
      let eventParams = new PreviewResultParams(this.fileInfo.mimeType, 3,
        Date.now() - this.startTime, this.fileInfo.fileSize);
      let recordParams: Record<string, Object> = {
        "mimeType": eventParams.mimeType,
        "openState": eventParams.openState,
        "costTime": eventParams.costTime,
        "fileSize": eventParams.fileSize
      };
      ReportUtil.reportFaultEvent(EventName.DFT_PREVIEW_RESULT, recordParams);
      hiTraceMeter.finishAsyncTrace(hiTraceMeter.HiTraceOutputLevel.INFO, TraceNameParam.AUDIO_LOAD_PAGE,
        TaskId.LOAD_PAGE);
      return;
    }

    this.audioController.fileInfo = this.fileInfo;
    this.audioController.initPlayPage(this);
    this.playState = this.audioController.getPlayState();
    this.activeUri = this.fileInfo.uri;
    this.context = getContext(this);

    hiTraceMeter.finishAsyncTrace(hiTraceMeter.HiTraceOutputLevel.INFO, TraceNameParam.AUDIO_LOAD_PAGE,
      TaskId.LOAD_PAGE);
  }

  aboutToDisappear() {
    HiLog.i(TAG, `aboutToDisappear`);
    HiLog.i(TAG, `aboutToDisappear restore shell orientation landscape=${this.shellOrientationSnapshot?.isLandscape}`);
    this.restoreSystemBars();
    const session = AudioPlaybackSession.getInstance();
    if (session.shouldReleaseOnPageDisappear()) {
      session.stopPlayback();
    } else {
      session.clearMinimizing();
    }
  }

  build() {
    Stack() {
      Column() {
        TitleBar({
          fileInfo: this.fileInfo,
          toolBarItems: this.toolBarItems,
          windowType: this.windowType,
          fileName: this.fileInfo?.fileName,
          hideFileName: true,
          forceDarkStyle: true,
          transparentTitleBar: true,
          onBack: () => {
            if (this.onMinimize) {
              HiLog.i(TAG, 'onBack minimize');
              this.onMinimize();
            } else if (this.onClose) {
              this.onClose();
            }
          }
        })

        Column() {
          AudioPlayer({
            fileInfo: this.fileInfo,
            audioController: this.audioController,
            playState: this.playState,
            loadingStatus: this.loadingStatus,
            windowType: this.windowType,
          })
            .id('audio_audio_player_id')
        }
        .layoutWeight(1)
        .width(PlayerUiConstants.AUDIO_PANEL_WIDTH)
        .height(0)
        .alignSelf(ItemAlign.Center)
        .padding({
          top: PlayerUiConstants.COVER_AREA_PADDING_TOP,
          bottom: PlayerUiConstants.COVER_AREA_PADDING_BOTTOM,
          left: this.avoidArea,
          right: this.avoidArea,
        })

        Column() {
          PlayerProgress({
            avPlayerController: this.audioController,
            playState: this.playState,
            isHideProgressAndTitle: this.isHideProgressAndTitle,
            type: 'audio',
            windowType: this.windowType,
            fileInfo: this.fileInfo,
            volumePercentage: this.volumePercentage,
            isAudio: true,
            speedLabel: $currentSpeedLabel,
            showSpeedMenu: $showAudioSpeedMenu,
            onRestoreHistoryPlayback: this.onRestoreHistoryPlayback,
            onAudioQueueEmpty: this.onAudioQueueEmpty,
          })
            .padding({
              left: this.avoidArea,
              right: this.avoidArea,
              bottom: this.avoidBottomArea > 0 ? this.avoidBottomArea : 0,
            })
            .id('audio_play_progress_id')
        }
        .width(PlayerUiConstants.AUDIO_PANEL_WIDTH)
        .alignSelf(ItemAlign.Center)
        .focusOnTouch(true)
        .onKeyEvent((event: KeyEvent) => {
          if (this.audioController.isDialog()) {
            return;
          }
          if (event.type === KeyType.Down && event.keyCode === KeyCode.KEYCODE_SPACE) {
            this.audioController.switchPlayOrPause();
            event.stopPropagation();
          }
        })
        .gesture(GestureGroup(
          GestureMode.Exclusive,
          TapGesture({ count: Constants.SINGLE_CLICK })
            .onAction(() => {
              HiLog.i(TAG, `SINGLE_CLICK`);
              this.audioController.switchPlayOrPause();
            }))
        )
      }
      .padding({ top: this.getTopSafeInset() })
      .id('audio_root_stack_id')
      .width(Constants.ALL_PERCENT)
      .height(Constants.ALL_PERCENT)
      .backgroundColor(this.bgColor)
    }
    .width(Constants.ALL_PERCENT)
    .height(Constants.ALL_PERCENT)
  }
}
