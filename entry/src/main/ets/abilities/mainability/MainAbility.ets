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

import { AbilityConstant, Configuration, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { notificationManager } from '@kit.NotificationKit';

import { SafeAreaConstants } from '@ohos/common/src/main/ets/constants/ui/SafeAreaConstants';
import { LocalStorageParam } from '@ohos/common/src/main/ets/constants/storage/StorageParam';
import { MediaCacheManager } from '@ohos/common/src/main/ets/cache/MediaCacheManager';
import { MediaProgressNotificationHelper } from '@ohos/common/src/main/ets/notification/MediaProgressNotificationHelper';
import { AudioMiniPlayerResumeStore } from '@ohos/common/src/main/ets/persistence/preferences/AudioMiniPlayerResumeStore';
import { PlaybackHistoryManager } from '@ohos/common/src/main/ets/persistence/preferences/PlaybackHistoryManager';
import { PlaylistPlaybackResumeManager } from '@ohos/common/src/main/ets/persistence/preferences/PlaylistPlaybackResumeManager';
import { MediaPermissionManager } from '@ohos/common/src/main/ets/permission/MediaPermissionManager';
import { AppContext } from '@ohos/common/src/main/ets/context/AppContext';
import { appLocalStorage } from '@ohos/common/src/main/ets/storage/AppLocalStorage';
import { ThumbnailManager } from '@ohos/common/src/main/ets/thumbnail/ThumbnailManager';
import { AppThemeModeHelper } from '@ohos/common/src/main/ets/utils/AppThemeModeHelper';
import { DisplaySettingsPreference } from '@ohos/common/src/main/ets/persistence/preferences/DisplaySettingsPreference';
import { FontScaleUtil } from '@ohos/common/src/main/ets/utils/FontScaleUtil';
import { HiLog } from '@ohos/common/src/main/ets/utils/HiLog';
import { HiTrace } from '@ohos/common/src/main/ets/utils/HiTrace';
import WindowUtil from '@ohos/common/src/main/ets/utils/WindowUtil';
import { MediaAggregateViewModel } from '@ohos/media/src/main/ets/manager/MediaAggregateViewModel';
import { AudioPlaybackSession } from '@ohos/player/src/main/ets/session/AudioPlaybackSession';
import { PlaybackCallInterruptGuard } from '@ohos/player/src/main/ets/session/PlaybackCallInterruptGuard';
import { PlaybackVideoScreenLockGuard } from '@ohos/player/src/main/ets/session/PlaybackVideoScreenLockGuard';
import { VideoPlaybackSession } from '@ohos/player/src/main/ets/session/VideoPlaybackSession';

import { ExternalWantConstants } from '../../constants/ExternalWantConstants';
import { ExternalWantResolver } from '../../utils/ExternalWantResolver';
import { HomeViewModel } from '../../viewmodel/HomeViewModel';

const TAG = 'MainAbility';
const FILE_PATH_KEY = ExternalWantConstants.FILE_PATH_KEY;
const FILE_TYPE_KEY = ExternalWantConstants.FILE_TYPE_KEY;
const DEFAULT_TAB_KEY = ExternalWantConstants.DEFAULT_TAB_KEY;
const WANT_ACTION_KEY = 'wantAction';
const SORT_BY_KEY = 'sortBy';
const SORT_DESC_KEY = 'sortDesc';
/** 旧版音频单行播放通知 ID，启动时清理残留 */
const LEGACY_AUDIO_PLAYBACK_NOTIFICATION_ID: number = 88004;

// Action constants for tab selection
const WANT_ACTION_AUDIO = 'com.ohos.players.action.AUDIO';
const WANT_ACTION_VIDEO = 'com.ohos.players.action.VIDEO';
const WANT_ACTION_IMAGE = 'com.ohos.players.action.IMAGE';

export default class MainAbility extends UIAbility {
  private filePath: string = '';
  private fileType: string = '';

  /**
   * Parse Want action to tab name
   * 
   * @param action - Want action string
   * @returns Tab name (AUDIO, VIDEO, IMAGE) or default AUDIO
   */
  public static parseActionToTab(action?: string): string {
    if (!action) {
      return 'AUDIO'; // Default tab
    }

    switch (action) {
      case WANT_ACTION_AUDIO:
        return 'AUDIO';
      case WANT_ACTION_VIDEO:
        return 'VIDEO';
      case WANT_ACTION_IMAGE:
        return 'IMAGE';
      default:
        HiLog.w(TAG, 'Unknown action: %{public}s, using default AUDIO', action);
        return 'AUDIO';
    }
  }

  /**
   * Handle Want action for tab selection
   * 
   * @param want - Want object from onCreate/onNewWant
   */
  private handleWantAction(want: Want): void {
    // Store want action if provided
    if (want.action) {
      AppStorage.setOrCreate(WANT_ACTION_KEY, want.action);
      HiLog.i(TAG, 'Want action stored: %{public}s', want.action);
    }

    // Parse action to tab name and store
    const tabName = MainAbility.parseActionToTab(want.action);
    AppStorage.setOrCreate(DEFAULT_TAB_KEY, tabName);
    HiLog.i(TAG, 'Default tab set: %{public}s', tabName);
  }

  /**
   * 解析外部应用「打开方式」Want，写入 AppStorage 供首页播放。
   *
   * @param want 系统传入的 Want
   * @returns 是否识别为外部音视频打开
   */
  private processIncomingWant(want: Want): boolean {
    const payload = ExternalWantResolver.resolve(want);
    if (payload === null) {
      return false;
    }
    AppStorage.setOrCreate(FILE_PATH_KEY, payload.uri);
    AppStorage.setOrCreate(FILE_TYPE_KEY, payload.mimeType);
    AppStorage.setOrCreate(ExternalWantConstants.PENDING_PLAY_KEY, true);
    AppStorage.setOrCreate(DEFAULT_TAB_KEY, payload.isAudio ? 'AUDIO' : 'VIDEO');
    this.filePath = payload.uri;
    this.fileType = payload.mimeType;
    if (want.action) {
      AppStorage.setOrCreate(WANT_ACTION_KEY, want.action);
      HiLog.i(TAG, `processIncomingWant action=${want.action}`);
    }
    HiLog.i(TAG, `processIncomingWant uri=${payload.uri} mime=${payload.mimeType}`);
    return true;
  }

  /**
   * 从 Want 读取排序参数写入 AppStorage。
   *
   * @param want 系统传入的 Want
   */
  private applySortWantParameters(want: Want): void {
    if (want.parameters?.['sortBy']) {
      const sortBy = want.parameters['sortBy'] as string;
      AppStorage.setOrCreate(SORT_BY_KEY, sortBy);
      HiLog.i(TAG, `Sort by parameter: ${sortBy}`);
    }
    if (want.parameters?.['sortDesc'] !== undefined) {
      const sortDescParam = want.parameters['sortDesc'];
      const sortDesc = (sortDescParam === true || sortDescParam === 'true');
      AppStorage.setOrCreate(SORT_DESC_KEY, sortDesc);
      HiLog.i(TAG, `Sort descending parameter: ${String(sortDesc)}`);
    }
  }

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    HiLog.i(TAG, 'Ability onCreate');
    // 冷启动须先注册 AppStorage 键，后续 WindowUtil 才能用 set 刷新并驱动 @StorageLink
    AppStorage.setOrCreate<number>(SafeAreaConstants.STATUS_BAR_HEIGHT_KEY, 0);
    AppStorage.setOrCreate<number>(SafeAreaConstants.NAVI_INDICATOR_HEIGHT_KEY, 0);
    // 尽早注册队列切歌监听，后台播控中心切歌时不依赖 UI @Watch
    AudioPlaybackSession.getInstance();
    VideoPlaybackSession.getInstance();
    PlaybackCallInterruptGuard.register();
    PlaybackVideoScreenLockGuard.register();

    const hasExternalMedia = this.processIncomingWant(want);
    if (!hasExternalMedia) {
      this.handleWantAction(want);
    }
    this.applySortWantParameters(want);
    MediaProgressNotificationHelper.addNotificationSlots();
    void notificationManager.cancel(LEGACY_AUDIO_PLAYBACK_NOTIFICATION_ID);
    AppThemeModeHelper.syncFromConfiguration(this.context.config);
  }

  /**
   * 系统深浅色切换时同步主题并刷新系统栏
   *
   * @param newConfig 新配置
   */
  onConfigurationUpdate(newConfig: Configuration): void {
    HiLog.i(TAG, `onConfigurationUpdate colorMode=${newConfig.colorMode}`);
    AppThemeModeHelper.syncFromConfiguration(newConfig);
    if (this.context?.windowStage) {
      this.context.windowStage.getMainWindow()
        .then((mainWindow: window.Window) => {
          WindowUtil.refreshAppMainSystemBars(mainWindow);
        })
        .catch((error: BusinessError) => {
          HiLog.w(TAG, `refreshAppMainSystemBars failed message=${error.message}`);
        });
    }
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    HiLog.i(TAG, 'Ability onNewWant');

    const hasExternalMedia = this.processIncomingWant(want);
    if (!hasExternalMedia) {
      this.handleWantAction(want);
    }
    this.applySortWantParameters(want);

    try {
      const viewModel = MediaAggregateViewModel.getInstance();
      if (viewModel) {
        viewModel.applySortFromAppStorage();
        HiLog.i(TAG, 'onNewWant: Applied sort from AppStorage to ViewModel');
      }
    } catch (error) {
      const errMsg = error instanceof Error ? error.message : String(error);
      HiLog.e(TAG, `onNewWant: Failed to apply sort: ${errMsg}`);
    }

    if (want.parameters?.['defaultTab']) {
      const defaultTab = want.parameters['defaultTab'] as string;
      AppStorage.setOrCreate(DEFAULT_TAB_KEY, defaultTab);
      HiLog.i(TAG, `Default tab from Want: ${defaultTab}`);
    }

    if (hasExternalMedia) {
      HomeViewModel.getInstance().tryPlayPendingExternalFile();
    }
  }

  onDestroy(): void {
    HiLog.i(TAG, 'Ability onDestroy');

    // Cleanup MediaAggregateViewModel (FileMonitor, listeners)
    try {
      const viewModel = MediaAggregateViewModel.getInstance();
      viewModel.destroy().then(() => {
        HiLog.i(TAG, 'MediaAggregateViewModel destroyed');
      }).catch((error: Error) => {
        HiLog.e(TAG, `Failed to destroy MediaAggregateViewModel: ${error.message}`);
      });
    } catch (error) {
      const errMsg = error instanceof Error ? error.message : String(error);
      HiLog.e(TAG, `MediaAggregateViewModel cleanup error: ${errMsg}`);
    }

    // Release all cached resources to prevent memory leaks
    try {
      const thumbnailManager = ThumbnailManager.getInstance();
      thumbnailManager.releaseAll();
      HiLog.i(TAG, 'ThumbnailManager resources released');
    } catch (error) {
      HiLog.e(TAG, `Failed to release ThumbnailManager: ${error}`);
    }

    try {
      const mediaCacheManager = MediaCacheManager.getInstance();
      mediaCacheManager.clearCache();
      HiLog.i(TAG, 'MediaCacheManager resources released');
    } catch (error) {
      HiLog.e(TAG, `Failed to release MediaCacheManager: ${error}`);
    }
  }

  async onWindowStageCreate(windowStage: window.WindowStage): Promise<void> {
    HiLog.i(TAG, 'Ability onWindowStageCreate');
    let mainWindow: window.Window | undefined = undefined;
    try {
      mainWindow = await windowStage.getMainWindow();
    } catch (error) {
      const err = error as BusinessError;
      HiLog.e(TAG, `getMainWindow failed message=${err.message}`);
    }
    windowStage.loadContent('pages/Index', (err: BusinessError) => {
      if (err?.code) {
        HiLog.e(TAG, `Failed to load content. Cause: ${JSON.stringify(err)}`);
        return;
      }
      HiLog.i(TAG, 'Succeeded in loading Index page.');
      if (mainWindow !== undefined) {
        appLocalStorage.setOrCreate(LocalStorageParam.WINDOW_CLASS, mainWindow);
        WindowUtil.applyAppImmersiveMode(mainWindow)
          .then(() => {
            HiLog.i(TAG, 'App immersive mode applied after loadContent');
          })
          .catch((applyError: BusinessError) => {
            HiLog.w(TAG, `applyAppImmersiveMode after loadContent failed message=${applyError.message}`);
          });
      }
    });
  }

  onWindowStageDestroy(): void {
    HiLog.i(TAG, 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    HiTrace.begin(TAG, 'Ability onForeground');
    appLocalStorage.setOrCreate<boolean>(LocalStorageParam.APP_IN_BACKGROUND, false);

    const permissionMgr: MediaPermissionManager = MediaPermissionManager.getInstance();
    AppContext.getInstance().setMainAbilityContext(this.context);
    AppContext.getInstance().setAppContext(this.context.getApplicationContext());
    AppContext.getInstance().setCommonContext(this.context);

    DisplaySettingsPreference.getInstance().init(this.context);
    PlaybackHistoryManager.getInstance().init(this.context);
    PlaylistPlaybackResumeManager.getInstance().init(this.context);
    AudioMiniPlayerResumeStore.getInstance().init(this.context);
    permissionMgr.initMediaPermissionPreference(this.context);
    AppStorage.setOrCreate(FontScaleUtil.STORAGE_KEY,
      DisplaySettingsPreference.getInstance().getFontScale());
    HiLog.i(TAG, `Display settings initialized, fontScale=${DisplaySettingsPreference.getInstance().getFontScale()}`);

    if (this.context?.windowStage) {
      this.context.windowStage.getMainWindow()
        .then((mainWindow: window.Window) => {
          appLocalStorage.setOrCreate(LocalStorageParam.WINDOW_CLASS, mainWindow);
          // PiP 进/出或视频页：禁止壳层刷色，否则迁窗会闪一下
          if (WindowUtil.isPipTransitionQuiet() || WindowUtil.isVideoPlayerPageActive()) {
            HiLog.i(TAG, 'onForeground skip chrome for video/pip transition');
            return WindowUtil.applyVideoWindowBackgroundColor(mainWindow);
          }
          return WindowUtil.reapplyAppWindowChrome(mainWindow);
        })
        .then(() => {
          HiLog.i(TAG, 'reapplyAppWindowChrome onForeground done');
        })
        .catch((error: BusinessError) => {
          HiLog.w(TAG, `reapplyAppWindowChrome onForeground failed message=${error.message}`);
        });
    }
    HomeViewModel.getInstance().syncMediaProgressUiOnForeground();
    AudioPlaybackSession.getInstance().getController().flushPendingInterruptResume();
    VideoPlaybackSession.getInstance().getActiveController()?.flushPendingInterruptResume();

    // Initialize ThumbnailManager to ensure instance exists before onDestroy
    try {
      ThumbnailManager.getInstance(this.context);
      HiLog.i(TAG, 'ThumbnailManager initialized in onForeground');
    } catch (error) {
      HiLog.e(TAG, `ThumbnailManager init failed: ${error}`);
    }

    // 每次回前台都必须复核系统权限：用户可能已在系统设置中关闭存储权限。
    // 禁止因内存缓存为 GRANTED 而跳过同步，否则会继续扫描公共目录且不弹授权窗。
    const cachedState = permissionMgr.getPermissionState();
    HiLog.i(TAG, `Cached permission state before sync: ${cachedState}`);

    // 以系统读权限为准同步业务态：PARTIAL（仅音乐和音频等）也应保留，禁止强制改写为 DENIED
    permissionMgr.syncPermissionState()
      .then((state) => {
        HiLog.i(TAG, `Permission sync result: ${state}`);
      })
      .catch((error: Error) => {
        HiLog.e(TAG, `Permission sync failed: ${error.message}`);
      });

    // 首次启动时申请通知权限（fire-and-forget，不阻塞启动流程）
    MediaProgressNotificationHelper.ensureNotificationEnabled(this.context)
      .then((enabled: boolean) => {
        HiLog.i(TAG, `Notification permission on launch: ${enabled ? 'GRANTED' : 'DENIED'}`);
      })
      .catch((error: Error) => {
        HiLog.w(TAG, `Notification permission request on launch failed: ${error.message}`);
      });

    HiTrace.end(TAG, 'Ability onForeground');
  }

  onBackground(): void {
    HiLog.i(TAG, 'Ability onBackground');
    HomeViewModel.getInstance().onAppBackgroundForMediaProgress();
    AudioPlaybackSession.getInstance().getController().persistPlaylistResumeSnapshot();
    appLocalStorage.setOrCreate<boolean>(LocalStorageParam.APP_IN_BACKGROUND, true);
  }
}
