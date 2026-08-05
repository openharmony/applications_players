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



import FileInfo from '@ohos/common/src/main/ets/model/FileInfo';
import { HiLog } from '@ohos/common/src/main/ets/utils/HiLog';
import { MainTabIndex, MainTabUiState, MainTabViewModel } from './MainTabViewModel';
import { PlaylistViewModel } from './PlaylistViewModel';
import { MediaDataSource, MediaType } from '@ohos/common/src/main/ets/datasource/MediaDataSource';
import { SortType } from '@ohos/common/src/main/ets/datasource/IMediaDataSource';
import { MediaAggregateViewModel } from '@ohos/media/src/main/ets/manager/MediaAggregateViewModel';
import { MediaPermissionManager, PermissionState } from '@ohos/common/src/main/ets/permission/MediaPermissionManager';
import { AppContext } from '@ohos/common/src/main/ets/context/AppContext';
import { AudioItem } from '@ohos/common/src/main/ets/model/AudioItem';
import { VideoItem } from '@ohos/common/src/main/ets/model/VideoItem';
import { ToolbarArray } from '@ohos/common/src/main/ets/model/ToolbarItem';
import { common } from '@kit.AbilityKit';
import { picker } from '@kit.CoreFileKit';
import { promptAction } from '@kit.ArkUI';
import { SupportedMediaFormats } from '@ohos/common/src/main/ets/constants/media/SupportedMediaFormats';
import { HomeViewConstants } from '../constants/HomeViewConstants';
import { FontScaleUtil } from '@ohos/common/src/main/ets/utils/FontScaleUtil';
import {
  PlaybackMediaKind,
  PlaybackQueueManager
} from '@ohos/common/src/main/ets/player/PlaybackQueueManager';
import { PlaybackHistoryManager } from '@ohos/common/src/main/ets/persistence/preferences/PlaybackHistoryManager';
import { PlaybackResumeContext } from '@ohos/common/src/main/ets/player/PlaybackResumeContext';
import {
  AudioMiniPlayerResumeStore,
  AudioMiniPlayerResumeSnapshot,
  AudioMiniPlayerResumeTrack
} from '@ohos/common/src/main/ets/persistence/preferences/AudioMiniPlayerResumeStore';
import { PlayAudioLaunchOptions } from '@ohos/common/src/main/ets/persistence/preferences/PlaylistPlaybackResumeTypes';
import { AudioPlaybackSession } from '@ohos/player/src/main/ets/session/AudioPlaybackSession';
import { appLocalStorage } from '@ohos/common/src/main/ets/storage/AppLocalStorage';
import { LocalStorageParam } from '@ohos/common/src/main/ets/constants/storage/StorageParam';
import { MediaProgressNotificationHelper } from '@ohos/common/src/main/ets/notification/MediaProgressNotificationHelper';
import { ExternalWantConstants } from '../constants/ExternalWantConstants';
import { ExternalWantResolver } from '../utils/ExternalWantResolver';
import { SearchViewModel } from '@ohos/search';
import { NavRouterHelper } from '../utils/NavRouterHelper';
import { AppNavRoutes } from '../constants/AppNavRoutes';

const TAG = 'HomeViewModel';

/**
 * 首页媒体列表区 UI 快照（由 HomeViewModel 同步，供 MediaAggregateView 绑定）
 */
export interface MediaListUiState {
  mediaType: MediaType;
  isLoading: boolean;
  hasMediaItems: boolean;
  showPermissionTip: boolean;
  /** 仅开放部分媒体权限时使用更明确的提示文案 */
  usePartialPermissionTip: boolean;
  isRequestingPermission: boolean;
  loadingHintText: string;
  showScanProgressDetail: boolean;
  mediaDataSource: MediaDataSource | null;
  /** 当前筛选下的实体列表快照，供 View 层 ForEach 直接绑定 */
  mediaItems: FileInfo[];
  listItemIsAudio: boolean;
  /** 列表刷新序号：筛选/排序/数据变更时递增，驱动列表区重建 */
  listRevision: number;
}

/**
 * 首页 UI 状态快照，供 DefaultIndexPage 通过 listener 同步 @State
 */
export interface HomeUiState {
  showSearchOverlay: boolean;
  showSettingsOverlay: boolean;
  /** 递增以通知顶栏关闭更多菜单（不表示菜单是否打开） */
  menuDismissSignal: number;
  showSortDialog: boolean;
  showPlayer: boolean;
  showMiniPlayer: boolean;
  showScanDialog: boolean;
  scanPercent: number;
  scanProgressTitle: string;
  currentFilter: string;
  isGridView: boolean;
  currentSortType: SortType;
  isDesc: boolean;
  nameSortDesc: boolean;
  dateSortDesc: boolean;
  sizeSortDesc: boolean;
  currentAudio: AudioItem | undefined;
  currentVideo: VideoItem | undefined;
  /** 首页发起新播放时递增，供 Player 原子触发播放入口 */
  audioPlayRevision: number;
  mediaList: MediaListUiState;
  /** 是否处于多选模式 */
  isSelectionMode: boolean;
  /** 已选中项 URI 列表 */
  selectedUris: string[];
  /** 已选中数量 */
  selectedCount: number;
  /** 当前展示列表是否已全选 */
  isAllSelected: boolean;
  /** 是否展示批量删除确认弹窗 */
  showDeleteConfirm: boolean;
}

/**
 * 首页 ViewModel：统一管理筛选、浮层、播放器、扫描进度及媒体展示状态
 */
export class HomeViewModel {
  private static instance: HomeViewModel;
  private mediaViewModel: MediaAggregateViewModel = MediaAggregateViewModel.getInstance();
  private toolBarItems: ToolbarArray = new ToolbarArray();
  private uiStateListeners: ((state: HomeUiState) => void)[] = [];
  private scanTimer: number = -1;
  private closeTimer: number = -1;
  private timeoutTimer: number = -1;

  private showSearchOverlay: boolean = false;
  private showSettingsOverlay: boolean = false;
  private showHomeMediaEditNav: boolean = false;
  private menuDismissSignal: number = 0;
  private showSortDialog: boolean = false;
  private showPlayer: boolean = false;
  private showMiniPlayer: boolean = false;
  private showScanDialog: boolean = false;
  private scanPercent: number = 0;
  private scanProgressTitle: string = HomeViewConstants.SCAN_PROGRESS_TITLE;
  private mediaProgressBusy: boolean = false;
  private currentFilter: string = HomeViewConstants.FILTER_ALL;
  private isGridView: boolean = true;
  private currentSortType: SortType = SortType.DATE;
  private isDesc: boolean = true;
  private nameSortDesc: boolean = true;
  private dateSortDesc: boolean = true;
  private sizeSortDesc: boolean = true;
  private currentAudio: AudioItem | undefined = undefined;
  private currentVideo: VideoItem | undefined = undefined;
  private audioPlayRevision: number = 0;
  private mediaListUi: MediaListUiState = HomeViewModel.createDefaultMediaListUiState();
  private listRevision: number = 0;
  private mediaObserverStarted: boolean = false;
  /** 主数据是否已至少加载过一次：为 true 后切换 Tab 仅内存过滤，不再自动重扫（避免删除后切换重新扫出已删项） */
  private masterDataLoaded: boolean = false;
  private mediaLoadTimerId: number = -1;
  private permissionState: PermissionState = PermissionState.PENDING;
  private isRequestingMediaPermission: boolean = false;
  private playbackQueueListenerRegistered: boolean = false;
  /** 后台队列切歌时延迟到回前台的 UI 同步标记 */
  private deferredQueueUiSync: boolean = false;
  private showDeleteConfirm: boolean = false;
  private mainTabListenerRegistered: boolean = false;
  private trackedMainTabIndex: number = MainTabIndex.HOME;

  private permissionListener: (state: PermissionState) => void = (state: PermissionState) => {
    const previousState = this.permissionState;
    this.permissionState = state;
    const wasAllowed = previousState === PermissionState.GRANTED || previousState === PermissionState.PARTIAL;
    const isAllowed = state === PermissionState.GRANTED || state === PermissionState.PARTIAL;
    if (!wasAllowed && isAllowed) {
      HiLog.i(TAG, `Permission updated to ${state}, reloading media list`);
      this.loadMediaForCurrentFilter();
    } else if (wasAllowed && !isAllowed) {
      HiLog.w(TAG, `Permission revoked to ${state}, refreshing to empty-permission UI`);
      this.syncMediaDisplayState();
    }
    this.syncMediaListUiState();
    this.notifyUiState();
  };
  private mediaDataChangeListener: (mediaType: MediaType, data: FileInfo[]) => void =
    (mediaType: MediaType, data: FileInfo[]) => {
      // 数据回调即代表主数据已产出（含加载/删除/导入/增量刷新），标记后切换 Tab 不再自动重扫
      this.masterDataLoaded = true;
      const currentType = this.getMediaTypeForFilter();
      if (mediaType === currentType) {
        HiLog.i(TAG, `Pipeline[data callback/5] mediaDataChangeListener type=${MediaType[mediaType]} count=${data.length}`);
        this.bumpListRevision();
        this.syncMediaDisplayState();
        this.syncMediaListUiState();
        this.mediaListUi.isLoading = false;
        this.notifyUiState();
      } else if (!this.mediaViewModel.getIsLoading() && this.mediaListUi.isLoading) {
        this.mediaListUi.isLoading = false;
        this.notifyUiState();
      }
    };
  private mediaProgressListener: (current: number, total: number) => void = (current: number, total: number) => {
    if (total > 0) {
      this.mediaListUi.showScanProgressDetail = true;
      this.mediaListUi.loadingHintText = `${HomeViewConstants.SCAN_PROGRESS_PREFIX}${current}/${total}`;
    } else {
      this.mediaListUi.showScanProgressDetail = false;
      this.mediaListUi.loadingHintText = '';
    }
    this.notifyUiState();
  };

  /** 离开首页 Tab 时关闭排序弹窗等临时浮层，并退出媒体编辑 Nav */
  private mainTabUiListener = (state: MainTabUiState): void => {
    if (this.trackedMainTabIndex === MainTabIndex.HOME && state.currentTabIndex !== MainTabIndex.HOME) {
      HiLog.i(TAG, 'mainTab leave HOME dismiss transient overlays');
      this.dismissTransientOverlays();
      if (NavRouterHelper.getTopRouteName() === AppNavRoutes.HOME_MEDIA_EDIT) {
        this.closeHomeMediaEdit();
      }
    }
    this.trackedMainTabIndex = state.currentTabIndex;
  };

  /** 缩略图异步生成完成后刷新列表项封面（uiMediaList 已更新，需同步到 Page @State） */
  private mediaThumbnailListener: (uri: string, fileInfo: FileInfo) => void =
    (uri: string, fileInfo: FileInfo): void => {
      const currentType: MediaType = this.getMediaTypeForFilter();
      const itemType: MediaType = fileInfo.mimeType.startsWith('audio/') ? MediaType.AUDIO : MediaType.VIDEO;
      if (currentType !== MediaType.UNKNOWN && currentType !== itemType) {
        return;
      }
      const visible = this.mediaListUi.mediaItems.some(item => item.uri === uri);
      if (!visible) {
        return;
      }
      HiLog.i(TAG, `Thumbnail ready uri=${uri} coverUri=${fileInfo.coverUri} thumbUri=${fileInfo.thumbUri}`);
      this.syncMediaListUiState();
      this.notifyUiState();
    };

  private constructor() {
  }

  /** 媒体列表区默认 UI 快照 */
  private static createDefaultMediaListUiState(): MediaListUiState {
    return {
      mediaType: MediaType.UNKNOWN,
      isLoading: true,
      hasMediaItems: false,
      showPermissionTip: false,
      usePartialPermissionTip: false,
      isRequestingPermission: false,
      loadingHintText: '',
      showScanProgressDetail: false,
      mediaDataSource: null,
      mediaItems: [],
      listItemIsAudio: false,
      listRevision: 0
    };
  }

  /**
   * 递增列表刷新序号，供 View 层强制列表区重建
   */
  private bumpListRevision(): void {
    this.listRevision++;
    this.mediaListUi.listRevision = this.listRevision;
    HiLog.i(TAG, `Pipeline[revision] listRevision=${this.listRevision}`);
  }

  /**
   * 获取 HomeViewModel 单例
   *
   * @returns HomeViewModel 实例
   */
  public static getInstance(): HomeViewModel {
    if (!HomeViewModel.instance) {
      HomeViewModel.instance = new HomeViewModel();
    }
    HomeViewModel.instance.ensurePlaybackQueueListener();
    return HomeViewModel.instance;
  }

  private ensurePlaybackQueueListener(): void {
    if (this.playbackQueueListenerRegistered) {
      return;
    }
    PlaybackQueueManager.getInstance().addTrackChangeListener((uri: string, kind: PlaybackMediaKind) => {
      this.playTrackFromQueue(uri, kind);
    });
    // 音频队列增删改后同步迷你条快照，避免切视频再回来时用旧 tracks 盖回当前队列
    PlaybackQueueManager.getInstance().addQueueChangeListener(() => {
      const queue = PlaybackQueueManager.getInstance();
      if (queue.getMediaKind() !== PlaybackMediaKind.AUDIO) {
        return;
      }
      if (queue.getQueueSnapshot().length === 0) {
        return;
      }
      this.persistMiniPlayerSession();
    });
    this.playbackQueueListenerRegistered = true;
    HiLog.i(TAG, 'PlaybackQueueManager listener registered');
  }

  private playTrackFromQueue(uri: string, kind: PlaybackMediaKind): void {
    const fileInfo = this.resolveFileInfoForQueue(uri, kind);
    if (fileInfo === null) {
      HiLog.e(TAG, `playTrackFromQueue failed to resolve uri=%{private}s`, uri);
      return;
    }
    const isAppInBackground = appLocalStorage.get<boolean>(LocalStorageParam.APP_IN_BACKGROUND) ?? false;
    if (kind === PlaybackMediaKind.AUDIO) {
      if (isAppInBackground) {
        this.applyQueueAudioStateQuiet(AudioItem.fromEntityFileInfo(fileInfo));
      } else {
        this.playAudio(AudioItem.fromEntityFileInfo(fileInfo), undefined, true);
      }
      return;
    }
    if (isAppInBackground) {
      this.applyQueueVideoStateQuiet(VideoItem.fromEntityFileInfo(fileInfo));
    } else {
      this.playVideo(VideoItem.fromEntityFileInfo(fileInfo), undefined, true);
    }
  }

  /**
   * 后台队列切歌：仅更新播放器绑定状态，整页 UI 延迟到回前台刷新
   *
   * @param audio 当前音频项
   */
  private applyQueueAudioStateQuiet(audio: AudioItem): void {
    this.currentAudio = audio;
    this.currentVideo = undefined;
    this.audioPlayRevision++;
    this.deferredQueueUiSync = true;
    HiLog.i(TAG, `applyQueueAudioStateQuiet title=${audio.title} revision=${this.audioPlayRevision}`);
  }

  /**
   * 后台视频队列切歌：仅更新状态，延迟 UI 刷新
   *
   * @param video 当前视频项
   */
  private applyQueueVideoStateQuiet(video: VideoItem): void {
    this.currentVideo = video;
    this.currentAudio = undefined;
    this.deferredQueueUiSync = true;
    HiLog.i(TAG, `applyQueueVideoStateQuiet title=${video.title}`);
  }

  /**
   * 应用回前台时补刷后台切歌期间积压的播放器 UI，并校正扫描/导入进度弹窗
   */
  public syncMediaProgressUiOnForeground(): void {
    if (this.mediaProgressBusy && !this.showScanDialog) {
      HiLog.i(TAG, 'syncMediaProgressUiOnForeground restore progress dialog');
      this.showScanDialog = true;
      this.refreshScanProgressFromTask();
    } else if (!this.mediaProgressBusy && this.showScanDialog) {
      HiLog.i(TAG, 'syncMediaProgressUiOnForeground hide stale scan dialog');
      this.showScanDialog = false;
      this.clearCloseTimerOnly();
    }
    this.restoreMiniPlayerSessionOnColdStart();
    this.flushDeferredQueueUiIfNeeded();
    this.notifyUiState();
  }

  /**
   * 应用进后台时隐藏进度弹窗，并持久化迷你播放条会话
   */
  public onAppBackgroundForMediaProgress(): void {
    this.persistMiniPlayerSession();
    if (!this.mediaProgressBusy || !this.showScanDialog) {
      return;
    }
    HiLog.i(TAG, 'onAppBackgroundForMediaProgress hide scan dialog');
    this.showScanDialog = false;
    this.notifyUiState();
  }

  /** 应用是否在后台 */
  private isAppInBackground(): boolean {
    return appLocalStorage.get<boolean>(LocalStorageParam.APP_IN_BACKGROUND) ?? false;
  }

  /**
   * 应用回前台时补刷后台切歌期间积压的播放器 UI
   */
  public flushDeferredQueueUiIfNeeded(): void {
    if (!this.deferredQueueUiSync) {
      return;
    }
    this.deferredQueueUiSync = false;
    HiLog.i(TAG, 'flushDeferredQueueUiIfNeeded');
    this.notifyUiState();
  }

  private initMiniPlayerResumeStore(): void {
    const context = AppContext.getInstance().getMainAbilityContext();
    if (context !== null) {
      AudioMiniPlayerResumeStore.getInstance().init(context);
    }
  }

  private buildMiniPlayerResumeSnapshot(): AudioMiniPlayerResumeSnapshot | null {
    const queue = PlaybackQueueManager.getInstance();
    const controller = AudioPlaybackSession.getInstance().getController();
    if (queue.getMediaKind() === PlaybackMediaKind.AUDIO) {
      const trackUri = this.currentAudio !== undefined ? this.currentAudio.uri : queue.getCurrentUri();
      if (trackUri.length === 0) {
        return null;
      }
      const tracks: AudioMiniPlayerResumeTrack[] = [];
      const entries = queue.getQueueSnapshot();
      // 构建 uri → coverUri 映射，从 mediaListUi.mediaItems 和 currentAudio 获取
      const coverMap = new Map<string, string>();
      for (const item of this.mediaListUi.mediaItems) {
        if (item.coverUri || item.thumbUri) {
          coverMap.set(item.uri, item.coverUri || item.thumbUri);
        }
      }
      if (this.currentAudio?.fileInfo.coverUri) {
        coverMap.set(this.currentAudio.uri, this.currentAudio.fileInfo.coverUri);
      }
      for (let i = 0; i < entries.length; i++) {
        const entry = entries[i];
        const coverUri = coverMap.get(entry.uri) || '';
        tracks.push({
          uri: entry.uri,
          fileName: entry.fileName,
          mimeType: entry.mimeType,
          coverUri: coverUri
        });
      }
      const coverCount = tracks.filter((t: AudioMiniPlayerResumeTrack) => t.coverUri.length > 0).length;
      HiLog.i(TAG, `buildMiniPlayerResumeSnapshot: tracks=${tracks.length}, coverCount=${coverCount}`);
      return {
        trackUri: trackUri,
        positionMs: controller.getPlaybackPositionMs(),
        sourceName: queue.getSourceName(),
        sourcePlaylistId: queue.getSourcePlaylistId(),
        tracks: tracks,
        savedAt: Date.now()
      };
    }
    // 视频全屏时迷你条已隐藏，但音频会话仍保留在 currentAudio + 快照
    if (this.currentAudio !== undefined) {
      this.initMiniPlayerResumeStore();
      const cached = AudioMiniPlayerResumeStore.getInstance().load();
      if (cached !== null && cached.tracks.length > 0) {
        return {
          trackUri: this.currentAudio.uri,
          positionMs: controller.getPlaybackPositionMs(),
          sourceName: cached.sourceName,
          sourcePlaylistId: cached.sourcePlaylistId,
          tracks: cached.tracks,
          savedAt: Date.now()
        };
      }
    }
    return null;
  }

  /** 持久化迷你条会话（仅快照，不归档历史；历史在 setQueue 替换队列时写入） */
  private persistMiniPlayerSession(): void {
    const snapshot = this.buildMiniPlayerResumeSnapshot();
    if (snapshot === null) {
      return;
    }
    this.initMiniPlayerResumeStore();
    AudioMiniPlayerResumeStore.getInstance().save(snapshot);
    const coverCount = snapshot.tracks.filter((t: AudioMiniPlayerResumeTrack) => t.coverUri.length > 0).length;
    HiLog.i(TAG, `persistMiniPlayerSession uri=${snapshot.trackUri} ms=${snapshot.positionMs} tracks=${snapshot.tracks.length} coverCount=${coverCount}`);
  }

  private clearMiniPlayerSession(): void {
    this.initMiniPlayerResumeStore();
    AudioMiniPlayerResumeStore.getInstance().clear();
  }

  /** 冷启动：从快照恢复迷你条（一律暂停） */
  private restoreMiniPlayerSessionOnColdStart(): void {
    if (this.showMiniPlayer || this.showPlayer) {
      return;
    }
    const controller = AudioPlaybackSession.getInstance().getController();
    if (controller.hasActivePlayback()) {
      return;
    }
    this.initMiniPlayerResumeStore();
    const saved = AudioMiniPlayerResumeStore.getInstance().load();
    if (saved === null || saved.trackUri.length === 0) {
      return;
    }
    const fileInfos: FileInfo[] = [];
    for (let i = 0; i < saved.tracks.length; i++) {
      const track = saved.tracks[i];
      const fileInfo = new FileInfo(track.fileName, track.uri, track.mimeType);
      // 恢复封面 URI
      if (track.coverUri) {
        fileInfo.coverUri = track.coverUri;
        fileInfo.thumbUri = track.coverUri;
      }
      fileInfos.push(fileInfo);
    }
    const coverCount = fileInfos.filter((f: FileInfo) => f.coverUri.length > 0).length;
    HiLog.i(TAG, `restoreMiniPlayerSessionOnColdStart: tracks=${fileInfos.length}, coverCount=${coverCount}`);
    let startTrack: FileInfo | null = null;
    for (let i = 0; i < fileInfos.length; i++) {
      if (fileInfos[i].uri === saved.trackUri) {
        startTrack = fileInfos[i];
        break;
      }
    }
    if (startTrack === null) {
      startTrack = fileInfos.length > 0 ? fileInfos[0] :
        this.resolveFileInfoForQueue(saved.trackUri, PlaybackMediaKind.AUDIO);
    }
    if (startTrack === null) {
      this.clearMiniPlayerSession();
      return;
    }
    HiLog.i(TAG, `restoreMiniPlayerSessionOnColdStart uri=${saved.trackUri} ms=${saved.positionMs}`);
    this.playAudio(
      AudioItem.fromEntityFileInfo(startTrack),
      fileInfos.length > 0 ? fileInfos : undefined,
      false,
      saved.sourceName,
      {
        startPositionMs: saved.positionMs,
        sourcePlaylistId: saved.sourcePlaylistId,
        startMinimized: true,
        startPaused: true
      }
    );
  }

  /**
   * 消费 MainAbility 写入的外部打开请求，切换 Tab 并拉起播放器。
   */
  public tryPlayPendingExternalFile(): void {
    const pending = AppStorage.get<boolean>(ExternalWantConstants.PENDING_PLAY_KEY) ?? false;
    if (!pending) {
      return;
    }
    const uri = AppStorage.get<string>(ExternalWantConstants.FILE_PATH_KEY) ?? '';
    if (uri.length === 0) {
      AppStorage.setOrCreate(ExternalWantConstants.PENDING_PLAY_KEY, false);
      HiLog.w(TAG, 'tryPlayPendingExternalFile aborted emptyUri');
      return;
    }
    AppStorage.setOrCreate(ExternalWantConstants.PENDING_PLAY_KEY, false);
    const mimeType = AppStorage.get<string>(ExternalWantConstants.FILE_TYPE_KEY) ?? '';
    const payload = ExternalWantResolver.fromStored(uri, mimeType);
    const fileInfo = ExternalWantResolver.toFileInfo(payload);
    const filter = payload.isAudio ? HomeViewConstants.FILTER_MUSIC : HomeViewConstants.FILTER_VIDEO;
    this.setFilter(filter);
    HiLog.i(TAG, `tryPlayPendingExternalFile uri=${uri} mime=${fileInfo.mimeType} isAudio=${payload.isAudio}`);
    if (payload.isAudio) {
      this.playAudio(AudioItem.fromEntityFileInfo(fileInfo));
    } else {
      this.playVideo(VideoItem.fromEntityFileInfo(fileInfo));
    }
  }

  private resolveFileInfoForQueue(uri: string, kind: PlaybackMediaKind): FileInfo | null {
    const cached = PlaybackQueueManager.getInstance().getTrack(uri);
    if (cached !== null) {
      return cached;
    }
    for (let i = 0; i < this.mediaListUi.mediaItems.length; i++) {
      if (this.mediaListUi.mediaItems[i].uri === uri) {
        return this.mediaListUi.mediaItems[i];
      }
    }
    if (kind === PlaybackMediaKind.AUDIO) {
      return this.createFallbackAudioFileInfo(uri);
    }
    return this.createFallbackVideoFileInfo(uri);
  }

  private createFallbackAudioFileInfo(uri: string): FileInfo {
    const slash = uri.lastIndexOf('/');
    const fileName = slash >= 0 ? uri.substring(slash + 1) : uri;
    return new FileInfo(fileName, uri, 'audio/*');
  }

  private createFallbackVideoFileInfo(uri: string): FileInfo {
    const slash = uri.lastIndexOf('/');
    const fileName = slash >= 0 ? uri.substring(slash + 1) : uri;
    return new FileInfo(fileName, uri, 'video/*');
  }

  private setupAudioPlaybackQueue(startUri: string): void {
    const items: FileInfo[] = [];
    for (let i = 0; i < this.mediaListUi.mediaItems.length; i++) {
      const item = this.mediaListUi.mediaItems[i];
      if (item.mimeType.startsWith('audio/')) {
        items.push(item);
      }
    }
    if (items.length === 0 || !items.some((item: FileInfo) => item.uri === startUri)) {
      const fallback = this.resolveFileInfoForQueue(startUri, PlaybackMediaKind.AUDIO);
      if (fallback !== null && !items.some((item: FileInfo) => item.uri === fallback.uri)) {
        items.push(fallback);
      }
    }
    PlaybackQueueManager.getInstance().setQueue(items, startUri, PlaybackMediaKind.AUDIO, '');
  }

  private setupVideoPlaybackQueue(startUri: string): void {
    const items: FileInfo[] = [];
    for (let i = 0; i < this.mediaListUi.mediaItems.length; i++) {
      const item = this.mediaListUi.mediaItems[i];
      if (item.mimeType.startsWith('video/')) {
        items.push(item);
      }
    }
    if (items.length === 0 || !items.some((item: FileInfo) => item.uri === startUri)) {
      const fallback = this.resolveFileInfoForQueue(startUri, PlaybackMediaKind.VIDEO);
      if (fallback !== null && !items.some((item: FileInfo) => item.uri === fallback.uri)) {
        items.push(fallback);
      }
    }
    PlaybackQueueManager.getInstance().setQueue(items, startUri, PlaybackMediaKind.VIDEO, '');
  }

  /**
   * 初始化首页：绑定 Ability 上下文并同步媒体展示状态
   *
   * @param context MainAbility 上下文，为 null 时跳过初始化
   */
  public init(context: common.UIAbilityContext | null): void {
    if (!context) {
      HiLog.w(TAG, 'init skipped: context is null');
      return;
    }
    this.mediaViewModel.init(context);
    // 注入媒体列表数据访问实例，消除 feature/search → feature/media 横向依赖
    SearchViewModel.getInstance().setMediaAccess(this.mediaViewModel);
    this.ensureMainTabListener();
    this.applyDefaultHomeSortIfNeeded();
    this.startMediaObserver();
    this.syncMediaDisplayState();
    this.syncMediaListUiState();
    this.loadMediaForCurrentFilter();
    HiLog.i(TAG, `HomeViewModel initialized, filter=${this.currentFilter}`);
    this.notifyUiState();
  }

  /**
   * 首页销毁时释放媒体列表监听与定时器
   */
  public onPageDestroy(): void {
    this.stopMediaObserver();
    this.clearMediaLoadTimer();
    this.cancelScanProgress();
    if (this.mainTabListenerRegistered) {
      MainTabViewModel.getInstance().removeUiStateListener(this.mainTabUiListener);
      this.mainTabListenerRegistered = false;
    }
  }

  public getMediaListUiState(): MediaListUiState {
    return this.mediaListUi;
  }

  public getUiState(): HomeUiState {
    return this.buildUiState();
  }

  public getToolBarItems(): ToolbarArray {
    return this.toolBarItems;
  }

  /**
   * 注册 UI 状态变更监听器
   *
   * @param listener 状态快照回调
   */
  public addUiStateListener(listener: (state: HomeUiState) => void): void {
    this.uiStateListeners.push(listener);
  }

  /**
   * 移除 UI 状态变更监听器
   *
   * @param listener 待移除的回调
   */
  public removeUiStateListener(listener: (state: HomeUiState) => void): void {
    const index = this.uiStateListeners.indexOf(listener);
    if (index !== -1) {
      this.uiStateListeners.splice(index, 1);
    }
  }

  /** 打开搜索页（NavPathStack） */
  public openSearchOverlay(): void {
    this.dismissTransientOverlays();
    if (NavRouterHelper.getTopRouteName() === AppNavRoutes.SEARCH) {
      return;
    }
    HiLog.i(TAG, 'Search overlay opened');
    NavRouterHelper.push(AppNavRoutes.SEARCH);
  }

  /** 关闭搜索页 */
  public closeSearchOverlay(): void {
    HiLog.i(TAG, 'Search overlay close requested');
    if (NavRouterHelper.getTopRouteName() === AppNavRoutes.SEARCH) {
      NavRouterHelper.pop();
    }
  }

  /**
   * 同步搜索页 Nav 显隐到 UI 状态（由 NavRouterHelper 在 push/pop 后调用）
   *
   * @param visible 是否显示
   */
  public syncSearchOverlayNavVisible(visible: boolean): void {
    if (this.showSearchOverlay === visible) {
      return;
    }
    this.showSearchOverlay = visible;
    this.notifyUiState();
  }

  /**
   * 同步搜索浮层显隐（用户通过 @Link 关闭时由 View 回写，保留兼容）
   *
   * @param visible 是否显示
   */
  public setSearchOverlayVisible(visible: boolean): void {
    if (this.showSearchOverlay === visible) {
      return;
    }
    if (!visible) {
      this.closeSearchOverlay();
      return;
    }
    this.openSearchOverlay();
  }

  /** 打开设置页（NavPathStack） */
  public openSettingsOverlay(): void {
    this.dismissTransientOverlays();
    if (NavRouterHelper.getTopRouteName() === AppNavRoutes.SETTINGS) {
      return;
    }
    HiLog.i(TAG, 'Settings overlay opened');
    NavRouterHelper.push(AppNavRoutes.SETTINGS);
  }

  /**
   * 关闭设置页
   */
  public closeSettingsOverlay(): void {
    HiLog.i(TAG, 'Settings overlay close requested');
    if (NavRouterHelper.getTopRouteName() === AppNavRoutes.SETTINGS) {
      NavRouterHelper.pop();
      return;
    }
    this.syncSettingsOverlayNavVisible(false);
  }

  /**
   * 同步设置页 Nav 显隐到 UI 状态
   *
   * @param visible 是否显示
   */
  public syncSettingsOverlayNavVisible(visible: boolean): void {
    if (this.showSettingsOverlay === visible) {
      return;
    }
    this.showSettingsOverlay = visible;
    this.notifyUiState();
  }

  /** 打开首页媒体编辑 Nav 页（多选模式） */
  public openHomeMediaEdit(): void {
    this.dismissTransientOverlays();
    if (NavRouterHelper.getTopRouteName() === AppNavRoutes.HOME_MEDIA_EDIT) {
      return;
    }
    HiLog.i(TAG, 'openHomeMediaEdit enter selection mode');
    this.mediaViewModel.enterSelectionMode();
    NavRouterHelper.push(AppNavRoutes.HOME_MEDIA_EDIT);
  }

  /** 关闭首页媒体编辑 Nav 页 */
  public closeHomeMediaEdit(): void {
    HiLog.i(TAG, 'closeHomeMediaEdit');
    if (NavRouterHelper.getTopRouteName() === AppNavRoutes.HOME_MEDIA_EDIT) {
      NavRouterHelper.pop();
      return;
    }
    this.syncHomeMediaEditNavVisible(false);
  }

  /**
   * 同步媒体编辑 Nav 显隐（由 NavRouterHelper 在 push/pop 后调用）
   *
   * @param visible 是否显示
   */
  public syncHomeMediaEditNavVisible(visible: boolean): void {
    if (this.showHomeMediaEditNav === visible) {
      if (!visible && this.mediaViewModel.getIsSelectionMode()) {
        this.mediaViewModel.exitSelectionMode();
        this.notifyUiState();
      }
      return;
    }
    this.showHomeMediaEditNav = visible;
    if (!visible) {
      this.showDeleteConfirm = false;
      this.mediaViewModel.exitSelectionMode();
    }
    HiLog.i(TAG, `syncHomeMediaEditNavVisible visible=${visible}`);
    this.notifyUiState();
  }

  /**
   * 同步设置浮层显隐（保留兼容）
   *
   * @param visible 是否显示
   */
  public setSettingsOverlayVisible(visible: boolean): void {
    if (this.showSettingsOverlay === visible) {
      return;
    }
    if (!visible) {
      this.closeSettingsOverlay();
      return;
    }
    this.openSettingsOverlay();
  }

  /** 打开排序弹窗 */
  public openSortDialog(): void {
    this.showSortDialog = true;
    this.notifyUiState();
  }

  /** 关闭排序弹窗 */
  public closeSortDialog(): void {
    if (!this.showSortDialog) {
      return;
    }
    this.showSortDialog = false;
    this.notifyUiState();
  }

  /**
   * 离开首页当前操作上下文时关闭排序弹窗与更多菜单
   *
   * @param notify 是否在变更后通知 UI
   * @returns 是否关闭了任一浮层
   */
  private dismissTransientOverlays(notify: boolean = true): void {
    const hadSortDialog = this.showSortDialog;
    if (hadSortDialog) {
      this.showSortDialog = false;
    }
    this.menuDismissSignal++;
    HiLog.i(TAG, `dismissTransientOverlays sortDialog=${hadSortDialog}`);
    if (notify) {
      this.notifyUiState();
    }
  }

  /** 注册底部 Tab 切换监听，离开首页 Tab 时关闭临时浮层 */
  private ensureMainTabListener(): void {
    if (this.mainTabListenerRegistered) {
      return;
    }
    this.trackedMainTabIndex = MainTabViewModel.getInstance().getCurrentTabIndex();
    MainTabViewModel.getInstance().addUiStateListener(this.mainTabUiListener);
    this.mainTabListenerRegistered = true;
  }

  /**
   * 切换媒体类型筛选（全部 / 音频 / 视频）
   *
   * @param filter 筛选键：all | music | video
   */
  public setFilter(filter: string): void {
    this.dismissTransientOverlays(false);
    if (this.currentFilter === filter) {
      this.notifyUiState();
      return;
    }
    this.currentFilter = filter;
    const mediaType = this.getMediaTypeForFilter();
    HiLog.i(TAG, `Pipeline[filter/2] setFilter filter=${filter} mediaType=${MediaType[mediaType]}`);
    this.handleMediaTypeChange();
    this.notifyUiState();
  }

  /**
   * 请求媒体访问权限并刷新列表
   */
  public async requestMediaPermission(): Promise<void> {
    if (this.isRequestingMediaPermission) {
      return;
    }
    this.isRequestingMediaPermission = true;
    this.mediaListUi.isRequestingPermission = true;
    this.notifyUiState();

    try {
      HiLog.i(TAG, 'User tapped media permission button');
      await this.mediaViewModel.requestPermissionAndReload(this.getMediaTypeForFilter());
      // 授权流程结束后强制刷新读权限缓存，确保提示条立刻按最新双读状态显隐
      await MediaPermissionManager.getInstance().getMediaReadAccess();
      this.permissionState = this.mediaViewModel.getPermissionState();
      this.syncMediaDisplayState();
      this.syncMediaListUiState();
    } catch (error) {
      HiLog.e(TAG, `Media permission request failed: ${error}`);
    } finally {
      this.isRequestingMediaPermission = false;
      this.mediaListUi.isRequestingPermission = false;
      this.notifyUiState();
    }
  }

  /**
   * 排序弹窗选中项：同类型切换升降序，不同类型默认降序
   *
   * @param sortType 排序字段
   */
  public selectSort(sortType: SortType, isDesc?: boolean): void {
    let nextIsDesc: boolean;
    if (isDesc !== undefined) {
      nextIsDesc = isDesc;
    } else if (this.currentSortType === sortType) {
      nextIsDesc = !this.isDesc;
    } else {
      nextIsDesc = this.getSortDirection(sortType);
    }
    HiLog.i(TAG, `Pipeline[sort/2] selectSort sortType=${sortType} isDesc=${nextIsDesc}`);
    this.sortBy(sortType, nextIsDesc);
    this.showSortDialog = false;
    this.notifyUiState();
  }

  public getFilter(): string {
    return this.currentFilter;
  }

  public getMediaTypeForFilter(): MediaType {
    return this.getMediaTypeForFilterValue(this.currentFilter);
  }

  /**
   * 将首页筛选键映射为 MediaType
   *
   * @param filter 筛选键：all | music | video
   * @returns 对应的 MediaType
   */
  public getMediaTypeForFilterValue(filter: string): MediaType {
    if (filter === HomeViewConstants.FILTER_MUSIC) {
      return MediaType.AUDIO;
    }
    if (filter === HomeViewConstants.FILTER_VIDEO) {
      return MediaType.VIDEO;
    }
    return MediaType.UNKNOWN;
  }

  /**
   * 更新列表排序并同步 UI 状态
   *
   * @param sortType 排序字段
   * @param isDesc 是否降序
   */
  public sortBy(sortType: SortType, isDesc: boolean): void {
    HiLog.i(TAG, `Pipeline[sort/3] sortBy delegating to MediaAggregateViewModel sortType=${sortType} isDesc=${isDesc}`);
    this.mediaViewModel.sortBy(sortType, isDesc);
    this.bumpListRevision();
    this.syncMediaDisplayState();
    this.syncMediaListUiState();
    this.notifyUiState();
  }

  /**
   * 显示设置字体缩放变更：递增列表 revision 以刷新首页媒体列表
   */
  public onFontScaleChanged(): void {
    const fontScale = AppStorage.get<number>(FontScaleUtil.STORAGE_KEY) ?? FontScaleUtil.DEFAULT_SCALE;
    HiLog.i(TAG, `Pipeline[fontScale/3] onFontScaleChanged fontScale=${fontScale}`);
    this.bumpListRevision();
    this.syncMediaListUiState();
    this.notifyUiState();
  }

  /**
   * 切换网格/列表视图
   * */
  public toggleViewMode(): void {
    this.mediaViewModel.toggleViewMode();
    this.syncMediaDisplayState();
    this.notifyUiState();
  }

  /**
   * 仅进入多选模式（遗留 API，现由 openHomeMediaEdit 统一入口）
   */
  public enterSelectionModeOnly(): void {
    this.openHomeMediaEdit();
  }

  /**
   * 以完整 URI 集合覆盖当前选择（拖动涂选回调）
   *
   * @param uris 目标选中 URI 列表
   */
  public replaceSelection(uris: string[]): void {
    this.mediaViewModel.replaceSelection(uris);
    this.notifyUiState();
  }

  /** 退出多选模式并清空选择 */
  public exitSelectionMode(): void {
    if (NavRouterHelper.getTopRouteName() === AppNavRoutes.HOME_MEDIA_EDIT) {
      this.closeHomeMediaEdit();
      return;
    }
    HiLog.i(TAG, 'Pipeline[multi-select/1] exitSelectionMode');
    this.mediaViewModel.exitSelectionMode();
    this.notifyUiState();
  }

  /**
   * 多选模式下切换某项选中态（点击 / 拖动滑选）
   *
   * @param uri 媒体 URI
   */
  public toggleSelect(uri: string): void {
    this.mediaViewModel.toggleSelection(uri);
    this.notifyUiState();
  }

  /** 全选 / 取消全选 */
  public toggleSelectAll(): void {
    HiLog.i(TAG, 'Pipeline[multi-select/1] toggleSelectAll');
    this.mediaViewModel.toggleSelectAll();
    this.notifyUiState();
  }

  /** 请求批量删除：有选中项时弹出确认弹窗 */
  public requestDeleteSelected(): void {
    if (this.mediaViewModel.getSelectedCount() === 0) {
      HiLog.w(TAG, 'Pipeline[multi-select] requestDeleteSelected no items selected');
      return;
    }
    this.showDeleteConfirm = true;
    this.notifyUiState();

  }

  /**
   * 列表滑动删除：拉到底直接软删（不弹框，不删本地源文件）
   *
   * @param uri 媒体 URI
   */
  public async deleteMediaBySwipe(uri: string): Promise<void> {
    if (uri.length === 0) {
      return;
    }
    HiLog.i(TAG, `Pipeline[swipe delete] deleteMediaBySwipe uri=${uri}`);
    await this.preparePlaybackForRemovedMedia([uri]);
    await this.mediaViewModel.deleteByUris([uri], false);
    this.bumpListRevision();
    this.syncMediaListUiState();
    this.notifyUiState();
  }

  /** 取消批量删除确认 */
  public cancelDeleteSelected(): void {
    this.showDeleteConfirm = false;
    this.notifyUiState();
  }

  /**
   * 确认批量删除：多选场景弹框确认后执行
   */
  public async confirmDeleteSelected(): Promise<void> {
    this.showDeleteConfirm = false;
    this.notifyUiState();
    const uris = this.mediaViewModel.getSelectedUris();
    if (uris.length === 0) {
      HiLog.w(TAG, 'Pipeline[delete] confirmDeleteSelected no URIs to delete');
      return;
    }
    await this.preparePlaybackForRemovedMedia(uris);
    const removed = await this.mediaViewModel.deleteSelected();
    HiLog.i(TAG, `Pipeline[delete] confirmDeleteSelected removed=${removed}`);
    this.bumpListRevision();
    this.syncMediaListUiState();
    this.notifyUiState();
  }

  /**
   * 媒体从库中移除前：从播放队列剔除；若正在播放则停止
   * 使用 silent=true 避免触发切歌通知导致幽灵播放
   *
   * @param uris 待移除 URI 列表
   */
  private async preparePlaybackForRemovedMedia(uris: string[]): Promise<void> {
    const queue = PlaybackQueueManager.getInstance();
    for (let i = 0; i < uris.length; i++) {
      const uri = uris[i];
      // 静默移除队列中的歌曲（不触发切歌通知）
      while (true) {
        const snapshot = queue.getQueueSnapshot();
        let index = -1;
        for (let j = 0; j < snapshot.length; j++) {
          if (snapshot[j].uri === uri) {
            index = j;
            break;
          }
        }
        if (index < 0) {
          break;
        }
        queue.removeAt(index, true);
      }
      if (this.currentAudio?.uri === uri) {
        await this.stopAudioPlayback(true);
      } else if (this.currentVideo?.uri === uri) {
        this.showPlayer = false;
        this.currentVideo = undefined;
        if (this.currentAudio === undefined) {
          this.showMiniPlayer = false;
        }
      }
    }
  }

  /**
   * 打开播放器并播放音频
   *
   * @param audio 音频项
   * @param queueItems 可选播放队列（如播放列表详情），不传则从首页媒体列表构建
   * @param skipQueueSetup 为 true 时跳过队列重建（切歌回调内部使用）
   * @param queueSourceName 队列来源名称（如歌单名），不传则由 setQueue 默认逻辑决定
   */
  public playAudio(audio: AudioItem, queueItems?: FileInfo[], skipQueueSetup: boolean = false,
    queueSourceName?: string, launchOptions?: PlayAudioLaunchOptions): void {
    if (!skipQueueSetup) {
      this.dismissTransientOverlays();
      if (queueItems !== undefined && queueItems.length > 0) {
        const sourceName = queueSourceName !== undefined ? queueSourceName : '';
        const playlistId = launchOptions?.sourcePlaylistId ?? -1;
        PlaybackQueueManager.getInstance()
          .setQueue(queueItems, audio.uri, PlaybackMediaKind.AUDIO, sourceName, playlistId);
      } else {
        this.setupAudioPlaybackQueue(audio.uri);
      }
    }
    const startMs = launchOptions?.startPositionMs ?? 0;
    const startPaused = launchOptions?.startPaused === true;
    const startMinimized = launchOptions?.startMinimized === true;
    if (startMs > 0 || startPaused) {
      PlaybackResumeContext.setPendingStartMs(startMs);
      if (startPaused) {
        PlaybackResumeContext.setPendingStartPaused(true);
      }
    }
    this.currentAudio = audio;
    this.currentVideo = undefined;
    this.audioPlayRevision++;
    this.recordRecentAudioPlay(audio);
    if (skipQueueSetup && this.showMiniPlayer) {
      // 队列自动切歌时保持迷你条模式
    } else if (startMinimized) {
      this.showPlayer = false;
      this.showMiniPlayer = true;
    } else {
      this.showMiniPlayer = false;
      this.showPlayer = true;
    }
    HiLog.i(TAG, `Play audio: ${audio.title} revision=${this.audioPlayRevision}`);
    if (this.showPlayer) {
      NavRouterHelper.openPlayerRoute(AppNavRoutes.AUDIO_PLAYER);
    }
    this.notifyUiState();
  }

  /**
   * 写入最近点播单曲历史（历史播放 Tab 展示）
   *
   * @param audio 当前起播音频
   */
  private recordRecentAudioPlay(audio: AudioItem): void {
    if (audio.uri.length === 0) {
      return;
    }
    const fileName = audio.fileName.length > 0 ? audio.fileName : audio.title;
    let mimeType = audio.mimeType;
    if (!mimeType.startsWith('audio/')) {
      mimeType = audio.fileInfo.mimeType.length > 0 ? audio.fileInfo.mimeType : 'audio/*';
    }
    PlaybackHistoryManager.getInstance().recordTrack({
      uri: audio.uri,
      fileName: fileName,
      mimeType: mimeType,
      fileSize: audio.size > 0 ? audio.size : audio.fileInfo.size,
      picWidth: audio.fileInfo.picWidth,
      picHeight: audio.fileInfo.picHeight
    });
  }

  /**
   * 从历史歌单恢复播放：重建队列并打开对应全屏播放器
   *
   * @param tracks 历史曲目列表
   * @param startUri 起播 URI
   * @param sourceName 队列来源名称
   * @param kind 媒体类型
   */
  public restoreHistoryPlayback(tracks: FileInfo[], startUri: string, sourceName: string,
    kind: PlaybackMediaKind): void {
    HiLog.i(TAG, `restoreHistoryPlayback kind=${kind} startUri=${startUri} count=${tracks.length}`);
    if (tracks.length === 0) {
      HiLog.w(TAG, 'restoreHistoryPlayback aborted empty tracks');
      return;
    }
    let startTrack: FileInfo | null = null;
    for (let i = 0; i < tracks.length; i++) {
      if (tracks[i].uri === startUri) {
        startTrack = tracks[i];
        break;
      }
    }
    if (startTrack === null) {
      startTrack = tracks[0];
    }
    if (kind === PlaybackMediaKind.VIDEO) {
      this.playVideo(VideoItem.fromEntityFileInfo(startTrack), tracks, false, sourceName);
    } else {
      this.playAudio(AudioItem.fromEntityFileInfo(startTrack), tracks, false, sourceName);
    }
    HiLog.i(TAG, `restoreHistoryPlayback applied source=${sourceName} file=${startTrack.fileName}`);
  }

  /**
   * 打开播放器并播放视频
   *
   * @param video 视频项
   * @param queueItems 可选播放队列，不传则从首页媒体列表构建
   * @param skipQueueSetup 为 true 时跳过队列重建（切歌回调内部使用）
   * @param queueSourceName 队列来源名称
   */
  public playVideo(video: VideoItem, queueItems?: FileInfo[], skipQueueSetup: boolean = false,
    queueSourceName?: string): void {
    const hadAudioSession = this.currentAudio !== undefined;
    if (!skipQueueSetup) {
      if (hadAudioSession) {
        this.persistMiniPlayerSession();
      }
      this.dismissTransientOverlays();
      if (queueItems !== undefined && queueItems.length > 0) {
        const sourceName = queueSourceName !== undefined ? queueSourceName : '';
        PlaybackQueueManager.getInstance().setQueue(queueItems, video.uri, PlaybackMediaKind.VIDEO, sourceName);
      } else {
        this.setupVideoPlaybackQueue(video.uri);
      }
    }
    this.currentVideo = video;
    if (hadAudioSession) {
      AudioPlaybackSession.getInstance().markMinimizing(true);
      AudioPlaybackSession.getInstance().getController().pause();
    } else {
      this.currentAudio = undefined;
      void AudioPlaybackSession.getInstance().stopPlayback();
    }
    this.showMiniPlayer = false;
    this.showPlayer = true;
    HiLog.i(TAG, `Play video: ${video.title} hadAudioSession=${hadAudioSession}`);
    NavRouterHelper.openPlayerRoute(AppNavRoutes.VIDEO_PLAYER);
    this.notifyUiState();
  }

  /**
   * 根据 FileInfo 类型打开播放器
   *
   * @param fileInfo 媒体文件信息
   */
  public playFromFileInfo(fileInfo: FileInfo): void {
    if (ExternalWantResolver.isAudioMedia(fileInfo.mimeType, fileInfo.fileName)) {
      this.playAudio(AudioItem.fromEntityFileInfo(fileInfo));
    } else {
      this.playVideo(VideoItem.fromEntityFileInfo(fileInfo));
    }
  }

  /**
   * 关闭全屏播放器（Nav pop + 状态同步）
   */
  public closeFullScreenPlayer(): void {
    HiLog.i(TAG, 'closeFullScreenPlayer');
    NavRouterHelper.closePlayerRoute();
  }

  /**
   * 同步播放器 Nav 显隐到 UI 状态
   *
   * @param visible 是否显示全屏播放器
   */
  public syncPlayerNavVisible(visible: boolean): void {
    if (visible) {
      if (!this.showPlayer) {
        this.showPlayer = true;
        this.notifyUiState();
      }
      return;
    }
    if (!this.showPlayer) {
      return;
    }
    this.showPlayer = false;
    this.currentVideo = undefined;
    if (this.currentAudio !== undefined) {
      this.ensureAudioQueueRestoredForMiniPlayer();
      // 全屏音频 Nav 关闭（含系统返回）：收起迷你条并继续播放，而非 stop
      if (!this.showMiniPlayer) {
        AudioPlaybackSession.getInstance().markMinimizing(true);
        this.showMiniPlayer = true;
      }
      HiLog.i(TAG, `syncPlayerNavVisible minimize title=${this.currentAudio.title}`);
      PlaylistViewModel.getInstance().syncDetailResumeUi();
    } else if (!this.showMiniPlayer) {
      void AudioPlaybackSession.getInstance().stopPlayback();
    }
    this.notifyUiState();
  }

  /**
   * 音频播放 Nav 即将出栈：在 AudioPage aboutToDisappear 前标记最小化，避免释放 AVPlayer
   */
  public prepareAudioPlayerMinimizeBeforePop(): void {
    if (this.currentAudio === undefined) {
      return;
    }
    AudioPlaybackSession.getInstance().markMinimizing(true);
    this.showMiniPlayer = true;
    HiLog.i(TAG, `prepareAudioPlayerMinimizeBeforePop title=${this.currentAudio.title}`);
  }

  /**
   * 同步播放器显隐（用户关闭播放器时由 View 回写）
   *
   * @param visible 是否显示
   */
  public setPlayerVisible(visible: boolean): void {
    if (this.showPlayer === visible) {
      return;
    }
    if (!visible) {
      this.closeFullScreenPlayer();
      return;
    }
    this.syncPlayerNavVisible(true);
  }

  /**
   * 全屏音频页返回：收起为底部迷你播放条，保持播放
   */
  public minimizeAudioPlayer(): void {
    if (this.currentAudio === undefined) {
      HiLog.w(TAG, 'minimizeAudioPlayer aborted no currentAudio');
      return;
    }
    this.prepareAudioPlayerMinimizeBeforePop();
    NavRouterHelper.closePlayerRoute();
    this.showPlayer = false;
    HiLog.i(TAG, `minimizeAudioPlayer title=${this.currentAudio.title}`);
    PlaylistViewModel.getInstance().syncDetailResumeUi();
    this.notifyUiState();
  }

  /**
   * 点击迷你条：展开全屏音频播放页
   */
  public expandAudioPlayer(): void {
    if (this.currentAudio === undefined) {
      HiLog.w(TAG, 'expandAudioPlayer aborted no currentAudio');
      return;
    }
    this.ensureAudioQueueRestoredForMiniPlayer();
    this.dismissTransientOverlays();
    this.showMiniPlayer = false;
    this.showPlayer = true;
    NavRouterHelper.openPlayerRoute(AppNavRoutes.AUDIO_PLAYER);
    HiLog.i(TAG, `expandAudioPlayer title=${this.currentAudio.title}`);
    this.notifyUiState();
  }

  /**
   * 用户从播放队列彻底移除最后一首：隐藏迷你条并清除冷启动快照
   */
  public dismissMiniPlayerPermanently(): void {
    HiLog.i(TAG, 'dismissMiniPlayerPermanently');
    this.stopAudioPlayback(true);
  }

  /**
   * 迷你条展示音频队列前：若 Manager 仍为视频队列，则从快照恢复音频队列
   */
  public ensureAudioQueueRestoredForMiniPlayer(): void {
    const queue = PlaybackQueueManager.getInstance();
    if (queue.getMediaKind() === PlaybackMediaKind.AUDIO && queue.getQueueSnapshot().length > 0) {
      return;
    }
    if (this.currentAudio === undefined) {
      return;
    }
    this.initMiniPlayerResumeStore();
    const saved = AudioMiniPlayerResumeStore.getInstance().load();
    if (saved === null || saved.tracks.length === 0) {
      return;
    }
    const fileInfos: FileInfo[] = [];
    for (let i = 0; i < saved.tracks.length; i++) {
      const track = saved.tracks[i];
      const fileInfo = new FileInfo(track.fileName, track.uri, track.mimeType);
      if (track.coverUri) {
        fileInfo.coverUri = track.coverUri;
        fileInfo.thumbUri = track.coverUri;
      }
      fileInfos.push(fileInfo);
    }
    const startUri = this.currentAudio.uri.length > 0 ? this.currentAudio.uri : saved.trackUri;
    PlaybackQueueManager.getInstance()
      .setQueue(fileInfos, startUri, PlaybackMediaKind.AUDIO, saved.sourceName, saved.sourcePlaylistId);
    HiLog.i(TAG, `ensureAudioQueueRestoredForMiniPlayer count=${fileInfos.length}
                  fileInfo=${JSON.stringify(fileInfos)}`);
  }

  /**
   * 停止音频播放并隐藏迷你条
   *
   * @param clearMiniPlayerSession 为 true 时清除冷启动快照（删曲/队列清空）
   */
  public async stopAudioPlayback(clearMiniPlayerSession: boolean = false): Promise<void> {
    HiLog.i(TAG, `stopAudioPlayback clearSession=${clearMiniPlayerSession}`);
    if (clearMiniPlayerSession) {
      this.clearMiniPlayerSession();
    } else {
      this.persistMiniPlayerSession();
    }
    this.showMiniPlayer = false;
    this.showPlayer = false;
    this.currentAudio = undefined;
    // 先通知 UI 卸载迷你条/后台宿主，再 release AVPlayer，避免宿主仍挂载时 release 卡住
    NavRouterHelper.closePlayerRoute();
    this.notifyUiState();
    setTimeout(() => {
      void AudioPlaybackSession.getInstance().stopPlayback();
    }, 0);
  }

  /**
   * 打开文档选择器导入媒体，展示进度弹窗与系统实况通知
   */
  public async importMediaFilesAndScan(): Promise<void> {
    if (this.mediaProgressBusy) {
      HiLog.w(TAG, 'importMediaFilesAndScan skipped: progress busy');
      return;
    }

    const hasSystemPermission = await MediaPermissionManager.getInstance().hasSystemMediaPermission();
    if (!hasSystemPermission) {
      HiLog.w(TAG, 'importMediaFilesAndScan blocked: no system media permission');
      promptAction.showToast({ message: $r('app.string.media_permission_tip') });
      await this.requestMediaPermission();
      return;
    }

    const selectedUris = await this.pickMediaUris(this.currentFilter);
    if (selectedUris.length === 0) {
      return;
    }

    await this.beginMediaProgress(HomeViewConstants.IMPORT_PROGRESS_TITLE);
    try {
      const importResult = await this.mediaViewModel.importMediaFromPicker(selectedUris,
        (processed: number, total: number) => {
          this.updateMediaProgressPercent(processed, total);
        });
      if (importResult.skipped > 0) {
        promptAction.showToast({ message: $r('app.string.media_import_unsupported') });
      }
      if (importResult.imported > 0) {
        this.syncMediaListUiState();
        HiLog.i(TAG, `importMediaFilesAndScan finished, imported=${importResult.imported}, skipped=${importResult.skipped}`);
        this.notifyUiState();
        await this.endMediaProgressSuccess(
          HomeViewConstants.IMPORT_COMPLETE_TITLE,
          HomeViewConstants.IMPORT_COMPLETE_TEXT
        );
      } else {
        await this.endMediaProgressFailure();
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      HiLog.e(TAG, `importMediaFilesAndScan failed: ${message}`);
      await this.endMediaProgressFailure();
    }
  }

  /**
   * 触发媒体扫描并展示进度弹窗与系统实况通知
   *
   * @param forceRefresh 是否强制重新扫描
   */
  public startScan(forceRefresh: boolean = true): void {
    if (this.mediaProgressBusy) {
      HiLog.w(TAG, 'startScan skipped: progress busy');
      return;
    }
    this.beginMediaProgress(HomeViewConstants.SCAN_PROGRESS_TITLE).then(() => {
      this.runScanWithProgress(forceRefresh);
    }).catch((error: Error) => {
      HiLog.e(TAG, `startScan begin progress failed: ${error.message}`);
    });
  }

  private runScanWithProgress(forceRefresh: boolean): void {
    const mediaType = this.getMediaTypeForFilter();
    this.mediaViewModel.loadMediaFiles(mediaType, forceRefresh).then(async () => {
      this.stopScanPolling();
      this.clearTimeoutTimer();
      const detail = this.mediaViewModel.getScanProgressDetail();
      const total = detail.total > 0 ? detail.total : 100;
      const processed = detail.total > 0 ? detail.total : 100;
      this.scanPercent = 100;
      this.syncMediaListUiState();
      HiLog.i(TAG, `Scan finished progress=100 processed=${processed}/${total}`);
      this.notifyUiState();
      await MediaProgressNotificationHelper.updateProgress(100, processed, total);
      await this.endMediaProgressSuccess(
        HomeViewConstants.SCAN_COMPLETE_TITLE,
        HomeViewConstants.SCAN_COMPLETE_TEXT
      );
    }).catch(async (error: Error) => {
      HiLog.e(TAG, `Scan loadMediaFiles failed: ${error.message}`);
      await this.endMediaProgressFailure();
    });

    this.scanTimer = setInterval(() => {
      this.refreshScanProgressFromTask();
    }, HomeViewConstants.SCAN_POLL_INTERVAL_MS);

    this.timeoutTimer = setTimeout(() => {
      HiLog.w(TAG, 'Scan dialog dismissed by timeout');
      this.endMediaProgressFailure();
    }, HomeViewConstants.SCAN_TIMEOUT_MS);
  }

  /**
   * 从 ScanTaskPool 读取真实 processed/total 并刷新 UI 与实况通知
   */
  private refreshScanProgressFromTask(): void {
    const detail = this.mediaViewModel.getScanProgressDetail();
    if (detail.total > 0) {
      this.updateMediaProgressPercent(detail.processed, detail.total);
      return;
    }
    if (detail.percent > 0) {
      this.updateMediaProgressPercent(detail.percent, 100);
    }
  }

  /** 取消扫描/导入进度并关闭进度弹窗 */
  public cancelScanProgress(): void {
    this.endMediaProgressFailure();
  }

  private async beginMediaProgress(title: string): Promise<void> {
    this.clearScanTimers();
    this.mediaProgressBusy = true;
    this.scanProgressTitle = title;
    this.showScanDialog = true;
    this.scanPercent = 0;
    this.notifyUiState();

    const context = AppContext.getInstance().getMainAbilityContext();
    await MediaProgressNotificationHelper.ensureNotificationEnabled(context);
    await MediaProgressNotificationHelper.startProgress(title, context);
  }

  /**
   * 刷新扫描/导入进度 UI 与实况通知
   *
   * @param processed 已处理数量
   * @param total 总数量
   */
  private updateMediaProgressPercent(processed: number, total: number): void {
    const percent = total > 0 ? Math.floor(processed * 100 / total) : processed;
    this.scanPercent = percent;
    this.notifyUiState();
    MediaProgressNotificationHelper.updateProgress(percent, processed, total).catch((error: Error) => {
      HiLog.w(TAG, `updateProgress notification failed: ${error.message}`);
    });
  }

  private async endMediaProgressSuccess(completeTitle: string, completeText: string): Promise<void> {
    this.stopScanPolling();
    this.clearTimeoutTimer();
    this.clearCloseTimerOnly();
    this.scanPercent = 100;
    this.mediaProgressBusy = false;
    const context = AppContext.getInstance().getMainAbilityContext();
    await MediaProgressNotificationHelper.finishProgress(completeTitle, completeText, context);
    if (this.isAppInBackground()) {
      this.showScanDialog = false;
      this.notifyUiState();
      HiLog.i(TAG, 'endMediaProgressSuccess dismissed dialog in background');
      return;
    }
    this.notifyUiState();
    this.closeTimer = setTimeout(() => {
      this.showScanDialog = false;
      this.closeTimer = -1;
      this.notifyUiState();
    }, HomeViewConstants.SCAN_CLOSE_DELAY_MS);
  }

  private async endMediaProgressFailure(): Promise<void> {
    this.clearScanTimers();
    this.showScanDialog = false;
    this.scanPercent = 0;
    this.mediaProgressBusy = false;
    const context = AppContext.getInstance().getMainAbilityContext();
    await MediaProgressNotificationHelper.cancelProgress(context);
    this.notifyUiState();
  }

  /**
   * 拉起 DocumentViewPicker 选择媒体文件（多选 ≤100，Documents 等已授权目录）
   */
  private async pickMediaUris(filter: string): Promise<string[]> {
    const context = AppContext.getInstance().getMainAbilityContext();
    if (!context) {
      HiLog.e(TAG, 'pickMediaUris failed: context is null');
      return [];
    }

    try {
      const documentPicker = new picker.DocumentViewPicker(context);
      const selectOptions = new picker.DocumentSelectOptions();
      selectOptions.maxSelectNumber = HomeViewConstants.IMPORT_MAX_SELECT_COUNT;

      if (filter === HomeViewConstants.FILTER_MUSIC) {
        selectOptions.fileSuffixFilters = SupportedMediaFormats.AUDIO_SUFFIXES.slice();
      } else if (filter === HomeViewConstants.FILTER_VIDEO) {
        selectOptions.fileSuffixFilters = SupportedMediaFormats.VIDEO_SUFFIXES.slice();
      } else {
        selectOptions.fileSuffixFilters = SupportedMediaFormats.getAllSuffixes();
      }

      const selectedUris = await documentPicker.select(selectOptions);
      if (!selectedUris || selectedUris.length === 0) {
        HiLog.i(TAG, 'pickMediaUris cancelled or no files selected');
        return [];
      }

      HiLog.i(TAG, `pickMediaUris selected ${selectedUris.length} files`);
      return selectedUris;
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      HiLog.e(TAG, `pickMediaUris failed: ${message}`);
      return [];
    }
  }

  /** 从 MediaAggregateViewModel 同步网格视图与排序状态 */
  private syncMediaDisplayState(): void {
    this.isGridView = this.mediaViewModel.getIsGridView();
    this.currentSortType = this.mediaViewModel.getCurrentSortType();
    this.isDesc = this.mediaViewModel.getIsDesc();
    this.setSortDirection(this.currentSortType, this.isDesc);
  }

  private applyDefaultHomeSortIfNeeded(): void {
    const sortByStr = AppStorage.get<string>('sortBy') ?? '';
    if (sortByStr.length > 0) {
      return;
    }
    this.mediaViewModel.sortBy(SortType.DATE, true);
    this.currentSortType = SortType.DATE;
    this.isDesc = true;
    this.setSortDirection(SortType.DATE, true);
    HiLog.i(TAG, 'Home default sort reset to date descending');
  }

  private getSortDirection(sortType: SortType): boolean {
    switch (sortType) {
      case SortType.NAME:
        return this.nameSortDesc;
      case SortType.DATE:
        return this.dateSortDesc;
      case SortType.SIZE:
        return this.sizeSortDesc;
      default:
        return true;
    }
  }

  private setSortDirection(sortType: SortType, isDesc: boolean): void {
    switch (sortType) {
      case SortType.NAME:
        this.nameSortDesc = isDesc;
        break;
      case SortType.DATE:
        this.dateSortDesc = isDesc;
        break;
      case SortType.SIZE:
        this.sizeSortDesc = isDesc;
        break;
      default:
        break;
    }
  }

  /** 注册媒体列表相关监听（权限、数据、扫描进度） */
  private startMediaObserver(): void {
    if (this.mediaObserverStarted) {
      return;
    }
    this.permissionState = MediaPermissionManager.getInstance().getPermissionState();
    MediaPermissionManager.getInstance().addPermissionListener(this.permissionListener);
    this.mediaViewModel.addDataChangeListener(this.mediaDataChangeListener);
    this.mediaViewModel.addThumbnailUpdateListener(this.mediaThumbnailListener);
    this.mediaViewModel.addProgressListener(this.mediaProgressListener);
    this.mediaObserverStarted = true;
  }

  /** 注销媒体列表相关监听 */
  private stopMediaObserver(): void {
    if (!this.mediaObserverStarted) {
      return;
    }
    MediaPermissionManager.getInstance().removePermissionListener(this.permissionListener);
    this.mediaViewModel.removeDataChangeListener(this.mediaDataChangeListener);
    this.mediaViewModel.removeThumbnailUpdateListener(this.mediaThumbnailListener);
    this.mediaViewModel.removeProgressListener(this.mediaProgressListener);
    this.mediaObserverStarted = false;
  }

  /** @Watch 等价逻辑：切换全部/音频/视频筛选 */
  private handleMediaTypeChange(): void {
    const mediaType = this.getMediaTypeForFilter();
    const dataSource = this.mediaViewModel.getMediaDataSource();
    const masterCount = dataSource ? dataSource.getDataArray().length : 0;
    HiLog.i(TAG, `Pipeline[filter/3] handleMediaTypeChange mediaType=${MediaType[mediaType]} masterCount=${masterCount} loaded=${this.masterDataLoaded}`);
    // 已加载过主数据则始终内存过滤：即使删空也不自动重扫，重新加载仅由刷新按钮触发
    if (dataSource && (masterCount > 0 || this.masterDataLoaded)) {
      HiLog.i(TAG, `Pipeline[filter/4] switchMediaType in-memory filter (no rescan)`);
      this.mediaViewModel.switchMediaType(mediaType);
      this.bumpListRevision();
      this.syncMediaDisplayState();
      this.syncMediaListUiState();
    } else {
      HiLog.i(TAG, `Pipeline[filter/4] Master data not loaded, running debounced scan`);
      this.debouncedLoadMedia();
    }
  }

  /** 防抖加载，避免快速切换筛选时重复扫描 */
  private debouncedLoadMedia(): void {
    HiLog.i(TAG, `Pipeline[filter/4] debouncedLoadMedia waiting ${HomeViewConstants.MEDIA_LOAD_DEBOUNCE_MS}ms`);
    if (this.mediaLoadTimerId !== -1) {
      clearTimeout(this.mediaLoadTimerId);
    }
    this.mediaLoadTimerId = setTimeout(() => {
      this.mediaLoadTimerId = -1;
      this.loadMediaForCurrentFilter();
    }, HomeViewConstants.MEDIA_LOAD_DEBOUNCE_MS);
  }

  private clearMediaLoadTimer(): void {
    if (this.mediaLoadTimerId !== -1) {
      clearTimeout(this.mediaLoadTimerId);
      this.mediaLoadTimerId = -1;
    }
  }

  /** 加载当前筛选对应的媒体列表 */
  private async loadMediaForCurrentFilter(): Promise<void> {
    const mediaType = this.getMediaTypeForFilter();
    try {
      HiLog.i(TAG, `Starting media file load: ${MediaType[mediaType]}`);
      if (!this.mediaViewModel.isReady()) {
        HiLog.w(TAG, 'MediaAggregateViewModel not ready, waiting for init');
        await this.waitForMediaViewModelReady();
      }
      this.mediaListUi.isLoading = true;
      this.notifyUiState();
      await this.mediaViewModel.loadMediaFiles(mediaType);
      this.syncMediaDisplayState();
      this.syncMediaListUiState();
      this.notifyUiState();
    } catch (error) {
      HiLog.e(TAG, `Media file load failed: ${error}`);
      this.mediaListUi.isLoading = false;
      this.notifyUiState();
    }
  }

  private async waitForMediaViewModelReady(): Promise<void> {
    let retries = 0;
    while (retries < HomeViewConstants.VM_READY_MAX_RETRIES) {
      if (this.mediaViewModel.isReady()) {
        return;
      }
      await new Promise<void>(resolve => setTimeout(resolve, HomeViewConstants.VM_READY_POLL_MS));
      retries++;
    }
    HiLog.e(TAG, 'MediaAggregateViewModel init timeout');
  }

  /** 同步媒体列表区 UI 快照 */
  private syncMediaListUiState(): void {
    const mediaType = this.getMediaTypeForFilter();
    const mediaList = this.mediaViewModel.getMediaList();
    this.permissionState = this.mediaViewModel.getPermissionState();
    this.mediaListUi.mediaType = mediaType;
    this.mediaListUi.isLoading = this.mediaViewModel.getIsLoading();
    this.mediaListUi.hasMediaItems = mediaList.length > 0;
    // 提示条只看媒体读权限：双读齐全即隐藏（不因写权限未齐而继续展示）
    const readAccess = MediaPermissionManager.getInstance().getCachedMediaReadAccess();
    this.mediaListUi.showPermissionTip = !readAccess.hasAll;
    this.mediaListUi.usePartialPermissionTip = readAccess.hasAny && !readAccess.hasAll;
    this.mediaListUi.isRequestingPermission = this.isRequestingMediaPermission;
    this.mediaListUi.mediaDataSource = this.mediaViewModel.getMediaDataSource();
    // 每次同步新数组引用，确保 Page @State 触发 ForEach 刷新
    this.mediaListUi.mediaItems = mediaList.slice();
    this.mediaListUi.listItemIsAudio = mediaType === MediaType.AUDIO;
    this.mediaListUi.listRevision = this.listRevision;

    const chunk = this.mediaViewModel.getChunkProgress();
    if (chunk.total > 0) {
      this.mediaListUi.showScanProgressDetail = true;
      this.mediaListUi.loadingHintText = `${HomeViewConstants.SCAN_PROGRESS_PREFIX}${chunk.current}/${chunk.total}`;
    } else if (!this.mediaListUi.isLoading) {
      this.mediaListUi.showScanProgressDetail = false;
      this.mediaListUi.loadingHintText = '';
    }
    HiLog.i(TAG, `Pipeline[sync/6] syncMediaListUiState mediaType=${MediaType[mediaType]} count=${mediaList.length} revision=${this.listRevision}`);
  }

  /**
   * 构建当前 UI 状态快照
   *
   * @returns HomeUiState 对象
   */
  private buildUiState(): HomeUiState {
    return {
      showSearchOverlay: this.showSearchOverlay,
      showSettingsOverlay: this.showSettingsOverlay,
      menuDismissSignal: this.menuDismissSignal,
      showSortDialog: this.showSortDialog,
      showPlayer: this.showPlayer,
      showMiniPlayer: this.showMiniPlayer,
      showScanDialog: this.showScanDialog,
      scanPercent: this.scanPercent,
      scanProgressTitle: this.scanProgressTitle,
      currentFilter: this.currentFilter,
      isGridView: this.isGridView,
      currentSortType: this.currentSortType,
      isDesc: this.isDesc,
      nameSortDesc: this.nameSortDesc,
      dateSortDesc: this.dateSortDesc,
      sizeSortDesc: this.sizeSortDesc,
      currentAudio: this.currentAudio,
      currentVideo: this.currentVideo,
      audioPlayRevision: this.audioPlayRevision,
      mediaList: this.mediaListUi,
      isSelectionMode: this.mediaViewModel.getIsSelectionMode(),
      selectedUris: this.mediaViewModel.getSelectedUris(),
      selectedCount: this.mediaViewModel.getSelectedCount(),
      isAllSelected: this.mediaViewModel.isAllSelected(),
      showDeleteConfirm: this.showDeleteConfirm
    };
  }

  /** 通知所有 UI 状态监听器 */
  private notifyUiState(): void {
    const state = this.buildUiState();
    HiLog.i(TAG, `Pipeline[notify/7] notifyUiState filter=${state.currentFilter} count=${state.mediaList.mediaItems.length} revision=${state.mediaList.listRevision}`);
    this.syncMainTabBarVisibility();
    for (const listener of this.uiStateListeners) {
      try {
        listener(state);
      } catch (error) {
        HiLog.e(TAG, `UiState listener failed: ${error}`);
      }
    }
  }

  /** 首页子页面（搜索/设置/编辑）打开时隐藏底部 Tab；迷你条模式同步歌单 Tab 显隐 */
  private syncMainTabBarVisibility(): void {
    const atRoot = !this.showSearchOverlay && !this.showSettingsOverlay && !this.showHomeMediaEditNav;
    MainTabViewModel.getInstance().setHomeAtRoot(atRoot);
    const boostPlaylistTabBar = this.showMiniPlayer && !this.showPlayer;
    MainTabViewModel.getInstance().setMiniPlayerTabBarBoost(boostPlaylistTabBar);
  }

  /** 停止扫描进度轮询定时器 */
  private stopScanPolling(): void {
    if (this.scanTimer !== -1) {
      clearInterval(this.scanTimer);
      this.scanTimer = -1;
    }
  }

  /** 清除扫描超时定时器 */
  private clearTimeoutTimer(): void {
    if (this.timeoutTimer !== -1) {
      clearTimeout(this.timeoutTimer);
      this.timeoutTimer = -1;
    }
  }

  /** 清除进度弹窗延迟关闭定时器 */
  private clearCloseTimerOnly(): void {
    if (this.closeTimer !== -1) {
      clearTimeout(this.closeTimer);
      this.closeTimer = -1;
    }
  }

  /** 清除扫描相关的全部定时器 */
  private clearScanTimers(): void {
    this.stopScanPolling();
    this.clearCloseTimerOnly();
    this.clearTimeoutTimer();
  }
}
