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
import { FileInfo as FileOperateFileInfo } from '@ohos/common/src/main/ets/utils/FileOperateInfo';
import { HiLog } from '@ohos/common/src/main/ets/utils/HiLog';
import { PlaylistCoverUtil } from '../utils/PlaylistCoverUtil';
import {
  PlaylistConfirmMode,
  PlaylistNameDialogMode,
  PlaylistScreen,
  PlaylistToastConstants,
  PlaylistItem,
  PlaylistDataSource,
  PlaylistTrackDataSource,
  PlaylistNameInputUtil
} from '@ohos/playlist';
import { MediaDbManager, PlaylistRecord } from '@ohos/common/src/main/ets/persistence/rdb/MediaDbManager';
import { AudioItem } from '@ohos/common/src/main/ets/model/AudioItem';
import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { HomeViewModel } from './HomeViewModel';
import { MainTabViewModel } from './MainTabViewModel';
import { PlaylistPlaybackResumeManager } from '@ohos/common/src/main/ets/persistence/preferences/PlaylistPlaybackResumeManager';
import { PlayAudioLaunchOptions, PlaylistPlaybackResumeChangeListener } from '@ohos/common/src/main/ets/persistence/preferences/PlaylistPlaybackResumeTypes';
import { PlayConstants } from '@ohos/common/src/main/ets/constants/player/PlayConstants';
import { SearchMatchEngine, SearchScorer } from '@ohos/search';
import { PlaybackMediaKind, PlaybackQueueManager } from '@ohos/common/src/main/ets/player/PlaybackQueueManager';
import { AudioPlaybackSession } from '@ohos/player/src/main/ets/session/AudioPlaybackSession';
import { NavRouterHelper } from '../utils/NavRouterHelper';
import { AppNavRoutes } from '../constants/AppNavRoutes';

export { PlaylistItem } from '@ohos/playlist';

const TAG = 'PlaylistViewModel';

/** 详情页续播条 UI 解析结果 */
interface DetailResumeOffer {
  showResumeBar: boolean;
  resumeTrackLabel: string;
}

/**
 * 播放列表页 UI 状态快照
 */
export interface PlaylistUiState {
  playlists: PlaylistItem[];
  isEmpty: boolean;
  currentScreen: PlaylistScreen;
  detailPlaylistId: number;
  detailName: string;
  detailTrackCount: number;
  isDetailEmpty: boolean;
  selectedUris: string[];
  selectedPlaylistIds: number[];
  nameDialogMode: PlaylistNameDialogMode;
  nameDialogInitialName: string;
  confirmDialogMode: PlaylistConfirmMode;
  confirmTargetId: number;
  confirmTargetCount: number;
  addAudioSearchKeyword: string;
  isAddAudioEmpty: boolean;
  /** 当前歌单已包含的音频 URI（添加页展示「已添加」） */
  addAudioInPlaylistUris: string[];
  showResumeBar: boolean;
  resumeTrackLabel: string;
}

/**
 * 播放列表页 ViewModel：列表 CRUD、详情、添加音频与多选删除
 */
export class PlaylistViewModel {
  private static instance: PlaylistViewModel;
  private uiStateListeners: ((state: PlaylistUiState) => void)[] = [];
  private dbManager: MediaDbManager | null = null;
  private context: common.UIAbilityContext | null = null;
  private initialized: boolean = false;

  private playlists: PlaylistItem[] = [];
  private playlistDataSource: PlaylistDataSource = new PlaylistDataSource();
  private detailTrackDataSource: PlaylistTrackDataSource = new PlaylistTrackDataSource();
  private addAudioDataSource: PlaylistTrackDataSource = new PlaylistTrackDataSource();
  private currentScreen: PlaylistScreen = PlaylistScreen.LIST;
  private detailPlaylistId: number = -1;
  private detailName: string = '';
  private selectedUriSet: Set<string> = new Set();
  private selectedPlaylistIdSet: Set<number> = new Set();
  private nameDialogMode: PlaylistNameDialogMode = PlaylistNameDialogMode.NONE;
  private nameDialogInitialName: string = '';
  private renameTargetId: number = -1;
  /** 每次打开名称弹窗递增，避免异步提交完成时误关新一轮弹窗 */
  private nameDialogSession: number = 0;
  private confirmDialogMode: PlaylistConfirmMode = PlaylistConfirmMode.NONE;
  private confirmTargetId: number = -1;
  private confirmTargetCount: number = 0;
  private addAudioTracks: FileInfo[] = [];
  private addAudioSearchKeyword: string = '';
  private addAudioAppliedKeyword: string = '';
  /** 添加音频页：当前歌单已有曲目 URI */
  private addAudioInPlaylistUriSet: Set<string> = new Set();
  private readonly resumeManager: PlaylistPlaybackResumeManager = PlaylistPlaybackResumeManager.getInstance();
  /** 本次会话内用户点 X 隐藏续播条（杀进程后清空；播放中隐藏不影响持久化） */
  private sessionDismissedPlaylistIds: Set<number> = new Set();
  private resumeListenerRegistered: boolean = false;
  private lastNotifiedDetailResumeBar: boolean = false;
  private lastNotifiedDetailResumeLabel: string = '';
  private detailTrackRemoveInFlight: boolean = false;
  private playlistDeleteInFlight: boolean = false;

  private constructor() {
  }

  /**
   * 获取 PlaylistViewModel 单例
   *
   * @returns PlaylistViewModel 实例
   */
  public static getInstance(): PlaylistViewModel {
    if (!PlaylistViewModel.instance) {
      PlaylistViewModel.instance = new PlaylistViewModel();
    }
    return PlaylistViewModel.instance;
  }

  /**
   * 初始化数据库上下文（页面 aboutToAppear 时调用）
   *
   * @param context UIAbility 上下文
   */
  public init(context: common.UIAbilityContext | null): void {
    this.ensureResumeChangeListener();
    if (!context || this.initialized) {
      return;
    }
    this.context = context;
    this.dbManager = MediaDbManager.getInstance(context);
    this.resumeManager.init(context);
    this.initialized = true;
    HiLog.i(TAG, `init completed`);
    this.loadPlaylists();
  }

  public getUiState(): PlaylistUiState {
    return this.buildUiState();
  }

  /**
   * 获取播放列表宫格 LazyForEach 数据源（单例引用，勿在 View 中重复 new）
   *
   * @returns 播放列表数据源
   */
  public getPlaylistDataSource(): PlaylistDataSource {
    return this.playlistDataSource;
  }

  /**
   * 获取详情页曲目 LazyForEach 数据源
   *
   * @returns 详情曲目数据源
   */
  public getDetailTrackDataSource(): PlaylistTrackDataSource {
    return this.detailTrackDataSource;
  }

  /**
   * 获取添加音频页 LazyForEach 数据源
   *
   * @returns 可选音频数据源
   */
  public getAddAudioDataSource(): PlaylistTrackDataSource {
    return this.addAudioDataSource;
  }

  /**
   * 注册 UI 状态监听器
   *
   * @param listener 状态快照回调
   */
  public addUiStateListener(listener: (state: PlaylistUiState) => void): void {
    this.uiStateListeners.push(listener);
  }

  /**
   * 移除 UI 状态监听器
   *
   * @param listener 待移除的回调
   */
  public removeUiStateListener(listener: (state: PlaylistUiState) => void): void {
    const index = this.uiStateListeners.indexOf(listener);
    if (index !== -1) {
      this.uiStateListeners.splice(index, 1);
    }
  }

  /** 详情页回到前台时刷新续播条 */
  public syncDetailResumeUi(): void {
    if (this.currentScreen !== PlaylistScreen.DETAIL || this.detailPlaylistId < 0) {
      return;
    }
    HiLog.i(TAG, `syncDetailResumeUi playlistId=${this.detailPlaylistId}`);
    this.notifyUiState();
  }

  /** 从数据库加载全部播放列表 */
  public async loadPlaylists(): Promise<void> {
    if (!this.dbManager) {
      HiLog.w(TAG, `loadPlaylists skipped db not ready`);
      return;
    }
    const records = await this.dbManager.getAllPlaylists();
    const playlistIds = records.map((record: PlaylistRecord) => record.id);
    const firstUriMap = await this.dbManager.getPlaylistFirstTrackUriMap(playlistIds);
    const mapped = records.map((record: PlaylistRecord) => this.mapRecordToPlaylistItem(record));
    const enriched: PlaylistItem[] = [];
    for (let i = 0; i < mapped.length; i++) {
      const item = mapped[i];
      const firstUri = firstUriMap.get(item.id);
      const coverUri = await this.resolveCoverForPlaylist(item.id, firstUri);
      HiLog.i(TAG, `loadPlaylists item id=${item.id} count=${item.count} cover=${coverUri.length > 0}`);
      enriched.push({
        id: item.id,
        name: item.name,
        count: item.count,
        coverUri
      });
    }
    this.playlists = enriched;
    this.syncPlaylistDataSource();
    HiLog.i(TAG, `loadPlaylists count=${this.playlists.length}`);
    this.notifyUiState();
  }

  /** 打开创建播放列表名称弹窗 */
  public openCreateDialog(): void {
    this.nameDialogSession++;
    this.nameDialogMode = PlaylistNameDialogMode.CREATE;
    this.nameDialogInitialName = '';
    this.renameTargetId = -1;
    HiLog.i(TAG, 'openCreateDialog');
    this.notifyUiState();
  }

  /**
   * 打开重命名弹窗
   *
   * @param item 目标播放列表
   */
  public openRenameDialog(item: PlaylistItem): void {
    this.nameDialogSession++;
    this.nameDialogMode = PlaylistNameDialogMode.RENAME;
    this.nameDialogInitialName = item.name;
    this.renameTargetId = item.id;
    HiLog.i(TAG, `openRenameDialog id=${item.id}`);
    this.notifyUiState();
  }

  /** 关闭名称弹窗 */
  public closeNameDialog(): void {
    this.nameDialogMode = PlaylistNameDialogMode.NONE;
    this.nameDialogInitialName = '';
    this.renameTargetId = -1;
    this.notifyUiState();
  }

  /**
   * 提交名称弹窗（创建或重命名）
   *
   * @param name 用户输入的名称
   */
  public async submitNameDialog(name: string): Promise<void> {
    const normalized = PlaylistNameInputUtil.sanitize(name);
    if (normalized.length === 0 || !this.dbManager) {
      return;
    }
    // 先快照弹窗上下文，避免 CustomDialog close 触发 cancel 后 mode/target 被清空
    const submitSession = this.nameDialogSession;
    const dialogMode = this.nameDialogMode;
    const renameTargetId = this.renameTargetId;
    if (dialogMode === PlaylistNameDialogMode.CREATE) {
      const rowId = await this.dbManager.createPlaylist(normalized);
      if (rowId < 0) {
        HiLog.e(TAG, `createPlaylist failed name=${normalized}`);
        return;
      }
      const newItem: PlaylistItem = {
        id: rowId,
        name: normalized,
        count: 0,
        coverUri: ''
      };
      this.playlists.push(newItem);
      this.playlistDataSource.addItem(newItem);
      HiLog.i(TAG, `createPlaylist name=${normalized} id=${rowId}`);
    } else if (dialogMode === PlaylistNameDialogMode.RENAME && renameTargetId >= 0) {
      await this.dbManager.renamePlaylist(renameTargetId, normalized);
      if (this.detailPlaylistId === renameTargetId) {
        this.detailName = normalized;
      }
      const index = this.playlistDataSource.findIndexById(renameTargetId);
      if (index >= 0) {
        const existing = this.playlistDataSource.getData(index);
        const updated: PlaylistItem = {
          id: renameTargetId,
          name: normalized,
          count: existing.count,
          coverUri: existing.coverUri
        };
        const playlistIndex = this.playlists.findIndex((item: PlaylistItem) => item.id === renameTargetId);
        if (playlistIndex >= 0) {
          this.playlists[playlistIndex] = updated;
        }
        this.playlistDataSource.updateItemAt(index, updated);
      }
      HiLog.i(TAG, `renamePlaylist id=${renameTargetId} name=${normalized}`);
    }
    if (this.nameDialogSession === submitSession) {
      this.closeNameDialog();
    }
    if (this.currentScreen === PlaylistScreen.DETAIL && this.detailPlaylistId >= 0) {
      HiLog.i(TAG, `Submit name dialog reloadDetailTracks`);
      await this.reloadDetailTracks();
    }
  }

  /**
   * 打开删除播放列表确认弹窗
   *
   * @param item 目标播放列表
   */
  public openDeletePlaylistConfirm(item: PlaylistItem): void {
    this.confirmDialogMode = PlaylistConfirmMode.DELETE_PLAYLIST;
    this.confirmTargetId = item.id;
    this.confirmTargetCount = 1;
    HiLog.i(TAG, `openDeletePlaylistConfirm id=${item.id}`);
    this.notifyUiState();
  }

  /**
   * 歌单列表左滑删除：按 id 定位后直接删库并刷新列表（对齐详情页曲目滑动删除）
   *
   * @param item 目标歌单
   */
  public async deletePlaylistBySwipe(item: PlaylistItem): Promise<void> {
    if (!this.dbManager || item.id < 0) {
      return;
    }
    if (this.playlistDeleteInFlight) {
      HiLog.w(TAG, `deletePlaylistBySwipe skipped in flight id=${item.id}`);
      return;
    }
    this.playlistDeleteInFlight = true;
    try {
      const deletedId = item.id;
      const index = this.playlistDataSource.findIndexById(deletedId);
      if (index < 0) {
        HiLog.w(TAG, `deletePlaylistBySwipe not found id=${deletedId}`);
        return;
      }
      HiLog.i(TAG, `deletePlaylistBySwipe id=${deletedId} name=${item.name}`);
      await this.dbManager.deletePlaylist(deletedId);
      this.resumeManager.removeByPlaylistId(deletedId);
      if (this.detailPlaylistId === deletedId) {
        await this.backToList();
      }
      this.playlists = this.playlists.filter((playlist: PlaylistItem) => playlist.id !== deletedId);
      const currentIndex = this.playlistDataSource.findIndexById(deletedId);
      if (currentIndex < 0) {
        this.notifyUiState();
        return;
      }
      if (!this.playlistDataSource.removeItemById(deletedId)) {
        this.playlistDataSource.setData(this.playlists);
      }
      this.notifyUiState();
    } finally {
      this.playlistDeleteInFlight = false;
    }
  }

  /** 关闭确认弹窗 */
  public closeConfirmDialog(): void {
    this.confirmDialogMode = PlaylistConfirmMode.NONE;
    this.confirmTargetId = -1;
    this.confirmTargetCount = 0;
    this.notifyUiState();
  }

  /** 确认弹窗点击确定 */
  public async confirmDialogAction(): Promise<void> {
    if (!this.dbManager) {
      return;
    }
    if (this.confirmDialogMode === PlaylistConfirmMode.DELETE_PLAYLIST && this.confirmTargetId >= 0) {
      const deletedId = this.confirmTargetId;
      await this.dbManager.deletePlaylist(deletedId);
      this.resumeManager.removeByPlaylistId(deletedId);
      if (this.detailPlaylistId === deletedId) {
        this.backToList();
      }
      this.playlists = this.playlists.filter((item: PlaylistItem) => item.id !== deletedId);
      this.playlistDataSource.removeItemById(deletedId);
      HiLog.i(TAG, `deletePlaylist id=${deletedId}`);
    } else if (this.confirmDialogMode === PlaylistConfirmMode.DELETE_TRACKS) {
      const uris = Array.from(this.selectedUriSet);
      await this.dbManager.removePlaylistItems(this.detailPlaylistId, uris);
      this.backFromEdit();
      HiLog.i(TAG, `removePlaylistItems playlistId=${this.detailPlaylistId} count=${uris.length}`);
      await this.reloadDetailTracks();
      await this.patchPlaylistItemCover(this.detailPlaylistId);
    } else if (this.confirmDialogMode === PlaylistConfirmMode.DELETE_PLAYLISTS) {
      const deletedIds = Array.from(this.selectedPlaylistIdSet);
      for (const deletedId of deletedIds) {
        await this.dbManager.deletePlaylist(deletedId);
        this.resumeManager.removeByPlaylistId(deletedId);
      }
      if (deletedIds.includes(this.detailPlaylistId)) {
        // 详情页打开且当前歌单被删：需 pop 全部歌单子页回到 Tab 列表
        this.playlists = this.playlists.filter((item: PlaylistItem) => !this.selectedPlaylistIdSet.has(item.id));
        this.playlistDataSource.setData(this.playlists);
        this.clearListSelectSelection();
        await this.backToList();
      } else {
        this.playlists = this.playlists.filter((item: PlaylistItem) => !this.selectedPlaylistIdSet.has(item.id));
        this.playlistDataSource.setData(this.playlists);
        this.clearListSelectSelection();
        // 多选页删除后留在当前 Nav 页；仅全部删光时自动退出多选
        if (this.playlists.length === 0) {
          this.backFromListSelect();
        }
      }
      HiLog.i(TAG, `deletePlaylists count=${deletedIds.length}`);
    }
    this.closeConfirmDialog();
  }

  /**
   * 进入播放列表详情
   *
   * @param item 播放列表项
   */
  public async openPlaylistDetail(item: PlaylistItem): Promise<void> {
    // 列表 Tab 不销毁，Nav 进详情前须主动关 CustomDialog，否则会叠在详情页上
    if (this.nameDialogMode !== PlaylistNameDialogMode.NONE) {
      HiLog.i(TAG, `openPlaylistDetail dismissNameDialog id=${item.id} mode=${this.nameDialogMode}`);
      this.closeNameDialog();
    }
    if (this.confirmDialogMode !== PlaylistConfirmMode.NONE) {
      HiLog.i(TAG, `openPlaylistDetail dismissConfirmDialog id=${item.id}`);
      this.closeConfirmDialog();
    }
    this.detailPlaylistId = item.id;
    this.detailName = item.name;
    this.currentScreen = PlaylistScreen.DETAIL;
    this.selectedUriSet.clear();
    HiLog.i(TAG, `openPlaylistDetail id=${item.id}`);
    // 勿在 reload 前 notify：曲目仍为空时会先渲染空态，reload 后再出续播条+列表，引发布局二次跳变
    await this.reloadDetailTracks();
    NavRouterHelper.push(AppNavRoutes.PLAYLIST_DETAIL);
  }

  /** 从详情或添加页返回列表 */
  public async backToList(): Promise<void> {
    const playlistId = this.detailPlaylistId;
    NavRouterHelper.popAllPlaylistRoutes();
    this.currentScreen = PlaylistScreen.LIST;
    this.detailPlaylistId = -1;
    this.detailName = '';
    this.detailTrackDataSource.setData([]);
    this.addAudioTracks = [];
    this.addAudioDataSource.setData([]);
    this.addAudioSearchKeyword = '';
    this.addAudioAppliedKeyword = '';
    this.addAudioInPlaylistUriSet.clear();
    this.clearEditSelection();
    this.clearListSelectSelection();
    this.lastNotifiedDetailResumeBar = false;
    this.lastNotifiedDetailResumeLabel = '';
    HiLog.i(TAG, `backToList playlistId=${playlistId}`);
    if (playlistId >= 0) {
      await this.patchPlaylistItemCover(playlistId);
    }
    this.notifyUiState();
  }

  /** 从添加音频页返回详情 */
  public backFromAddAudio(): void {
    this.currentScreen = PlaylistScreen.DETAIL;
    this.addAudioSearchKeyword = '';
    this.addAudioAppliedKeyword = '';
    this.applyAddAudioFilter();
    NavRouterHelper.pop();
    HiLog.i(TAG, `backFromAddAudio`);
    this.notifyUiState();
  }

  /** 打开添加音频页并加载可选音频 */
  public async openAddAudioPage(): Promise<void> {
    if (!this.dbManager || this.detailPlaylistId < 0) {
      return;
    }
    this.currentScreen = PlaylistScreen.ADD_AUDIO;
    this.addAudioSearchKeyword = '';
    this.addAudioAppliedKeyword = '';
    const rawTracks = await this.dbManager.queryMediaMetadata(1);
    this.addAudioTracks = [];
    for (const raw of rawTracks) {
      raw.mimeType = 'audio/*';
      const track = FileInfo.fromFileOperateFileInfo(raw);
      // 添加音频页与首页共用封面来源：DB 为空时合并内存扫描与系统 media:// 缩略图
      PlaylistCoverUtil.applyAvailableCovers(track);
      this.addAudioTracks.push(track);
    }
    await this.refreshAddAudioInPlaylistUris();
    this.applyAddAudioFilter();
    const withCover = this.addAudioTracks.filter((item: FileInfo) => item.coverUri.length > 0).length;
    HiLog.i(TAG, `openAddAudioPage candidates=${this.addAudioTracks.length} withCover=${withCover} inPlaylist=${this.addAudioInPlaylistUriSet.size}`);
    NavRouterHelper.push(AppNavRoutes.PLAYLIST_ADD_AUDIO);
    this.notifyUiState();
  }

  /**
   * 刷新添加页「已在歌单」URI 集合（来自当前详情歌单曲目）
   */
  private async refreshAddAudioInPlaylistUris(): Promise<void> {
    this.addAudioInPlaylistUriSet.clear();
    if (!this.dbManager || this.detailPlaylistId < 0) {
      return;
    }
    const uris = await this.dbManager.getPlaylistItems(this.detailPlaylistId);
    for (let i = 0; i < uris.length; i++) {
      this.addAudioInPlaylistUriSet.add(uris[i]);
    }
  }

  /**
   * 添加音频页搜索框文本变更（不触发过滤）
   *
   * @param keyword 搜索词
   */
  public updateAddAudioSearchText(keyword: string): void {
    this.addAudioSearchKeyword = keyword;
    this.addAudioAppliedKeyword = keyword.trim();
    this.applyAddAudioFilter();
    this.notifyUiState();
  }

  /** @deprecated 即时搜索已合并到 updateAddAudioSearchText，保留空实现避免外部残留调用 */
  public submitAddAudioSearch(): void {
    this.updateAddAudioSearchText(this.addAudioSearchKeyword);
  }

  /**
   * 将音频添加到当前播放列表
   *
   * @param fileInfo 音频文件
   */
  public async addAudioToCurrentPlaylist(fileInfo: FileInfo): Promise<void> {
    if (!this.dbManager || this.detailPlaylistId < 0) {
      return;
    }
    if (this.addAudioInPlaylistUriSet.has(fileInfo.uri)) {
      HiLog.i(TAG, `addAudio skip already in playlist uri=${fileInfo.uri}`);
      return;
    }
    const exists = await this.dbManager.isUriInPlaylist(this.detailPlaylistId, fileInfo.uri);
    if (exists) {
      this.addAudioInPlaylistUriSet.add(fileInfo.uri);
      this.notifyUiState();
      HiLog.i(TAG, `addAudio sync already in playlist uri=${fileInfo.uri}`);
      return;
    }
    const position = await this.dbManager.getNextPlaylistItemPosition(this.detailPlaylistId);
    await this.dbManager.addToPlaylist(this.detailPlaylistId, fileInfo.uri, position);
    this.addAudioInPlaylistUriSet.add(fileInfo.uri);
    promptAction.showToast({ message: PlaylistToastConstants.ADD_SUCCESS });
    HiLog.i(TAG, `addAudio uri=${fileInfo.uri} position=${position}`);
    await this.reloadDetailTracks();
    await this.patchPlaylistItemCover(this.detailPlaylistId);
    this.notifyUiState();
  }

  /**
   * 播放整个播放列表（从第一首开始）
   *
   * @param item 播放列表项
   */
  public async playPlaylist(item: PlaylistItem): Promise<void> {
    if (!this.dbManager) {
      return;
    }
    const uris = await this.dbManager.getPlaylistItems(item.id);
    if (uris.length === 0) {
      promptAction.showToast({ message: PlaylistToastConstants.PLAY_EMPTY });
      return;
    }
    const tracks: FileInfo[] = [];
    for (let i = 0; i < uris.length; i++) {
      const fileInfo = await this.resolveFileInfo(uris[i]);
      if (fileInfo) {
        tracks.push(fileInfo);
      }
    }
    if (tracks.length === 0) {
      promptAction.showToast({ message: PlaylistToastConstants.PLAY_EMPTY });
      return;
    }
    this.clearResumeMemoryForExplicitPlay(item.id);
    this.startDetailPlaylistPlayback(tracks, tracks[0].uri, item.name, 0, item.id);
    HiLog.i(TAG, `playPlaylist id=${item.id} count=${tracks.length}`);
  }

  /**
   * 从指定曲目起播当前歌单队列，并打开音频播放页（setQueue 会归档切换前的队列）
   *
   * @param tracks 歌单曲目列表
   * @param startUri 起播曲目 URI
   * @param playlistName 歌单名称（写入播放队列来源）
   */
  private startDetailPlaylistPlayback(tracks: FileInfo[], startUri: string, playlistName: string,
    startPositionMs: number = 0, playlistId?: number): void {
    if (tracks.length === 0) {
      promptAction.showToast({ message: PlaylistToastConstants.PLAY_EMPTY });
      HiLog.w(TAG, 'startDetailPlaylistPlayback aborted empty tracks');
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
    const effectivePlaylistId = playlistId !== undefined ? playlistId : this.detailPlaylistId;
    const launchOptions: PlayAudioLaunchOptions = {
      startPositionMs: startPositionMs,
      sourcePlaylistId: effectivePlaylistId
    };
    HomeViewModel.getInstance().playAudio(
      AudioItem.fromEntityFileInfo(startTrack),
      tracks,
      false,
      playlistName,
      launchOptions
    );
    HiLog.i(TAG, `startDetailPlaylistPlayback playlist=${playlistName} start=${startTrack.fileName} count=${tracks.length} ms=${startPositionMs}`);
    this.notifyUiState();
  }

  /**
   * 详情页继续播放：从记忆的曲目与进度起播
   */
  public continueResumePlayback(): void {
    HiLog.i(TAG, `continueResumePlayback playlistId=${this.detailPlaylistId}`);
    if (this.detailPlaylistId < 0) {
      HiLog.w(TAG, 'continueResumePlayback aborted no playlist');
      return;
    }
    const tracks = this.detailTrackDataSource.getDataArray();
    const uris = tracks.map((track: FileInfo) => track.uri);
    const state = this.resumeManager.getByPlaylistId(this.detailPlaylistId);
    if (state === null || !this.resumeManager.isResumeCompatible(state, uris)) {
      HiLog.w(TAG, 'continueResumePlayback aborted invalid resume state');
      this.notifyUiState();
      return;
    }
    this.startDetailPlaylistPlayback(tracks, state.trackUri, this.detailName, state.positionMs);
  }

  /**
   * 用户点击续播条关闭：播放中仅本会话隐藏；未播放时永久清除记忆
   */
  public dismissResumePlayback(): void {
    HiLog.i(TAG, `dismissResumePlayback playlistId=${this.detailPlaylistId}`);
    if (this.detailPlaylistId < 0) {
      return;
    }
    if (this.isSourcePlaylistActivelyPlaying(this.detailPlaylistId)) {
      this.sessionDismissedPlaylistIds.add(this.detailPlaylistId);
      HiLog.i(TAG, `dismissResumePlayback session hide playlistId=${this.detailPlaylistId}`);
    } else {
      this.resumeManager.removeByPlaylistId(this.detailPlaylistId);
      this.sessionDismissedPlaylistIds.delete(this.detailPlaylistId);
      HiLog.i(TAG, `dismissResumePlayback permanent clear playlistId=${this.detailPlaylistId}`);
    }
    this.notifyUiState();
  }

  /**
   * 详情页播放全部：从第一首起播
   */
  public playAllDetail(): void {
    HiLog.i(TAG, `playAllDetail playlistId=${this.detailPlaylistId}`);
    const tracks = this.detailTrackDataSource.getDataArray();
    if (tracks.length === 0) {
      promptAction.showToast({ message: PlaylistToastConstants.PLAY_EMPTY });
      return;
    }
    this.clearResumeMemoryForExplicitPlay(this.detailPlaylistId);
    this.startDetailPlaylistPlayback(tracks, tracks[0].uri, this.detailName, 0);
  }

  /**
   * 播放详情页中单曲（队列仍为当前歌单全集）
   *
   * @param fileInfo 音频文件
   */
  public playTrack(fileInfo: FileInfo): void {
    HiLog.i(TAG, `playTrack uri=${fileInfo.uri}`);
    this.clearResumeMemoryForExplicitPlay(this.detailPlaylistId);
    const tracks = this.detailTrackDataSource.getDataArray();
    this.startDetailPlaylistPlayback(
      tracks.length > 0 ? tracks : [fileInfo],
      fileInfo.uri,
      this.detailName
    );
  }

  /**
   * 首页宫格拖拽调整播放列表顺序
   *
   * @param from 原索引
   * @param to 目标索引
   */
  public reorderPlaylist(from: number, to: number): void {
    const items = this.playlistDataSource.getDataArray();
    HiLog.i(TAG, `reorderPlaylist start from=${from} to=${to} before=${items.map((item) => item.name).join('>')}`);
    if (!this.playlistDataSource.moveItemWithoutNotify(from, to)) {
      HiLog.w(TAG, `reorderPlaylist aborted from=${from} to=${to}`);
      return;
    }
    this.playlists = this.playlistDataSource.getDataArray();
    HiLog.i(TAG, `reorderPlaylist memoryUpdated after=${this.playlists.map((item) => item.name).join('>')}`);
    this.persistPlaylistOrder();
  }

  /**
   * 详情页拖拽调整曲目顺序
   *
   * @param from 原索引
   * @param to 目标索引
   */
  public reorderDetailTrack(from: number, to: number): void {
    const beforeOrder = this.detailTrackDataSource.getDataArray()
      .map((track: FileInfo) => track.fileName)
      .join('>');
    HiLog.i(TAG, `reorderDetailTrack start from=${from} to=${to} playlistId=${this.detailPlaylistId} before=${beforeOrder}`);
    // List.onMove 已由框架更新 UI，此处只同步内存顺序，勿 notifyDataMove（否则会视觉回弹）
    if (!this.detailTrackDataSource.moveItemWithoutNotify(from, to)) {
      HiLog.w(TAG, `reorderDetailTrack aborted from=${from} to=${to} playlistId=${this.detailPlaylistId}`);
      return;
    }
    const afterOrder = this.detailTrackDataSource.getDataArray()
      .map((track: FileInfo) => track.fileName)
      .join('>');
    HiLog.i(TAG, `reorderDetailTrack memoryUpdated from=${from} to=${to} after=${afterOrder}`);
    this.persistDetailTrackOrder();
  }

  /**
   * 详情页滑动删除单曲：按 URI 定位，删除时重新 indexOf（对齐联系人 deleteAction）
   *
   * @param uri 曲目 URI
   */
  public async removeDetailTrackByUri(uri: string): Promise<void> {
    if (uri.length === 0 || !this.dbManager || this.detailPlaylistId < 0) {
      return;
    }
    if (this.detailTrackRemoveInFlight) {
      HiLog.w(TAG, `removeDetailTrackByUri skipped in flight uri=${uri}`);
      return;
    }
    this.detailTrackRemoveInFlight = true;
    try {
      const index = this.detailTrackDataSource.findIndexByUri(uri);
      if (index < 0) {
        HiLog.w(TAG, `removeDetailTrackByUri not found uri=${uri} playlistId=${this.detailPlaylistId}`);
        return;
      }
      HiLog.i(TAG, `removeDetailTrackByUri index=${index} uri=${uri} playlistId=${this.detailPlaylistId}`);
      await this.dbManager.removePlaylistItems(this.detailPlaylistId, [uri]);
      const currentIndex = this.detailTrackDataSource.findIndexByUri(uri);
      if (currentIndex < 0) {
        await this.reloadDetailTracks();
        await this.patchPlaylistItemCover(this.detailPlaylistId);
        this.notifyUiState();
        return;
      }
      if (!this.detailTrackDataSource.removeItemAt(currentIndex)) {
        await this.reloadDetailTracks();
        await this.patchPlaylistItemCover(this.detailPlaylistId);
        this.notifyUiState();
        return;
      }
      await this.syncPlaybackQueueAfterTrackRemoved(uri);
      await this.patchPlaylistItemCover(this.detailPlaylistId);
      this.syncDetailPlaylistResumeAfterTrackOrderChange();
      this.notifyUiState();
    } finally {
      this.detailTrackRemoveInFlight = false;
    }
  }

  /**
   * 若当前播放队列来自本歌单，移除对应曲目；队列清空时停止播放
   *
   * @param uri 曲目 URI
   */
  private async syncPlaybackQueueAfterTrackRemoved(uri: string): Promise<void> {
    const queue = PlaybackQueueManager.getInstance();
    if (queue.getSourcePlaylistId() !== this.detailPlaylistId) {
      return;
    }
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
      queue.removeAt(index);
    }
    if (queue.getQueueSnapshot().length === 0) {
      await HomeViewModel.getInstance().stopAudioPlayback(true);
    }
  }

  /** 打开歌单列表多选 Nav 页（菜单「选择」） */
  public openListSelectPage(initialItem?: PlaylistItem): void {
    this.currentScreen = PlaylistScreen.LIST_SELECT;
    this.selectedPlaylistIdSet.clear();
    if (initialItem !== undefined && initialItem.id >= 0) {
      this.selectedPlaylistIdSet.add(initialItem.id);
    }
    NavRouterHelper.push(AppNavRoutes.PLAYLIST_LIST_SELECT);
    HiLog.i(TAG, `openListSelectPage initialId=${initialItem?.id ?? -1}`);
    this.notifyUiState();
  }

  /** 从歌单列表多选页返回列表 */
  public backFromListSelect(): void {
    this.currentScreen = PlaylistScreen.LIST;
    this.clearListSelectSelection();
    NavRouterHelper.pop();
    HiLog.i(TAG, 'backFromListSelect');
    this.notifyUiState();
  }

  /**
   * 切换歌单选中状态（列表多选页）
   *
   * @param playlistId 歌单 id
   */
  public togglePlaylistSelection(playlistId: number): void {
    if (this.selectedPlaylistIdSet.has(playlistId)) {
      this.selectedPlaylistIdSet.delete(playlistId);
    } else {
      this.selectedPlaylistIdSet.add(playlistId);
    }
    this.notifyUiState();
  }

  /** 全选或取消全选歌单列表多选页 */
  public toggleSelectAllPlaylists(): void {
    const items = this.playlistDataSource.getDataArray();
    const isAllSelected = items.length > 0 && this.selectedPlaylistIdSet.size === items.length;
    this.selectedPlaylistIdSet.clear();
    if (!isAllSelected) {
      for (const item of items) {
        this.selectedPlaylistIdSet.add(item.id);
      }
    }
    HiLog.i(TAG, `toggleSelectAllPlaylists selected=${this.selectedPlaylistIdSet.size} wasAll=${isAllSelected}`);
    this.notifyUiState();
  }

  /** 打开删除选中歌单确认弹窗 */
  public openDeleteSelectedPlaylistsConfirm(): void {
    if (this.selectedPlaylistIdSet.size === 0) {
      return;
    }
    this.confirmDialogMode = PlaylistConfirmMode.DELETE_PLAYLISTS;
    this.confirmTargetId = -1;
    this.confirmTargetCount = this.selectedPlaylistIdSet.size;
    HiLog.i(TAG, `openDeleteSelectedPlaylistsConfirm count=${this.confirmTargetCount}`);
    this.notifyUiState();
  }

  private clearListSelectSelection(): void {
    this.selectedPlaylistIdSet.clear();
  }

  /** 打开编辑页（从详情页编辑按钮进入） */
  public openEditPage(): void {
    if (this.detailPlaylistId < 0) {
      return;
    }
    this.currentScreen = PlaylistScreen.EDIT;
    this.selectedUriSet.clear();
    NavRouterHelper.push(AppNavRoutes.PLAYLIST_EDIT);
    HiLog.i(TAG, `openEditPage playlistId=${this.detailPlaylistId}`);
    this.notifyUiState();
  }

  /** 从编辑页返回详情页 */
  public backFromEdit(): void {
    this.currentScreen = PlaylistScreen.DETAIL;
    this.selectedUriSet.clear();
    NavRouterHelper.pop();
    HiLog.i(TAG, `backFromEdit`);
    this.notifyUiState();
  }

  /** 清空编辑页选中状态（不切换页面） */
  private clearEditSelection(): void {
    this.selectedUriSet.clear();
  }

  /**
   * 切换曲目选中状态（编辑页）
   *
   * @param uri 曲目 URI
   */
  public toggleTrackSelection(uri: string): void {
    if (this.selectedUriSet.has(uri)) {
      this.selectedUriSet.delete(uri);
    } else {
      this.selectedUriSet.add(uri);
    }
    this.notifyUiState();
  }

  /** 全选或取消全选编辑页曲目 */
  public toggleSelectAllTracks(): void {
    const detailTracks = this.detailTrackDataSource.getDataArray();
    const isAllSelected = detailTracks.length > 0 &&
      this.selectedUriSet.size === detailTracks.length;
    if (isAllSelected) {
      this.selectedUriSet.clear();
    } else {
      this.selectedUriSet.clear();
      for (const track of detailTracks) {
        this.selectedUriSet.add(track.uri);
      }
    }
    HiLog.i(TAG, `toggleSelectAll selected=${this.selectedUriSet.size} all=${isAllSelected}`);
    this.notifyUiState();
  }

  /** 打开删除选中曲目确认弹窗 */
  public openDeleteTracksConfirm(): void {
    if (this.selectedUriSet.size === 0) {
      return;
    }
    this.confirmDialogMode = PlaylistConfirmMode.DELETE_TRACKS;
    this.confirmTargetCount = this.selectedUriSet.size;
    HiLog.i(TAG, `openDeleteTracksConfirm count=${this.confirmTargetCount}`);
    this.notifyUiState();
  }

  /** 将内存列表同步到 LazyForEach 数据源 */
  private syncPlaylistDataSource(): void {
    this.playlistDataSource.setData(this.playlists);
  }

  private mapRecordToPlaylistItem(record: PlaylistRecord): PlaylistItem {
    return {
      id: record.id,
      name: record.name,
      count: record.itemCount,
      coverUri: ''
    };
  }

  /** 将当前宫格播放列表顺序写回数据库 */
  private async persistPlaylistOrder(): Promise<void> {
    if (!this.dbManager) {
      HiLog.w(TAG, `persistPlaylistOrder skipped db not ready`);
      return;
    }
    const items = this.playlistDataSource.getDataArray();
    const order = items.map((item) => item.name).join('>');
    HiLog.i(TAG, `persistPlaylistOrder start count=${items.length} order=${order}`);
    const success = await this.dbManager.updatePlaylistPositions(items.map((item) => item.id));
    if (!success) {
      HiLog.e(TAG, `persistPlaylistOrder failed order=${order}`);
      await this.loadPlaylists();
      return;
    }
    HiLog.i(TAG, `persistPlaylistOrder success order=${order}`);
  }

  /** 将当前详情曲目顺序写回数据库 */
  private async persistDetailTrackOrder(): Promise<void> {
    if (!this.dbManager || this.detailPlaylistId < 0) {
      HiLog.w(TAG, `persistDetailTrackOrder skipped dbReady=${this.dbManager !== null} playlistId=${this.detailPlaylistId}`);
      return;
    }
    const tracks = this.detailTrackDataSource.getDataArray();
    const uris = tracks.map((track: FileInfo) => track.uri);
    const order = tracks.map((track: FileInfo) => track.fileName).join('>');
    HiLog.i(TAG, `persistDetailTrackOrder start playlistId=${this.detailPlaylistId} count=${uris.length} order=${order}`);
    const success = await this.dbManager.updatePlaylistItemPositions(this.detailPlaylistId, uris);
    if (!success) {
      HiLog.e(TAG, `persistDetailTrackOrder failed playlistId=${this.detailPlaylistId} order=${order}`);
      await this.reloadDetailTracks();
      return;
    }
    HiLog.i(TAG, `persistDetailTrackOrder success playlistId=${this.detailPlaylistId} order=${order}`);
    this.syncDetailPlaylistResumeAfterTrackOrderChange();
  }

  /**
   * 曲目顺序变更后同步续播签名，避免因排序与快照不一致而隐藏续播条
   */
  private syncDetailPlaylistResumeAfterTrackOrderChange(): void {
    if (this.detailPlaylistId < 0) {
      return;
    }
    const state = this.resumeManager.getByPlaylistId(this.detailPlaylistId);
    if (state === null) {
      return;
    }
    const uris = this.detailTrackDataSource.getDataArray().map((track: FileInfo) => track.uri);
    if (uris.indexOf(state.trackUri) < 0) {
      HiLog.i(TAG, `syncDetailPlaylistResumeAfterTrackOrderChange remove missing track playlistId=${this.detailPlaylistId}`);
      this.resumeManager.removeByPlaylistId(this.detailPlaylistId);
      this.notifyUiState();
      return;
    }
    const signature = PlaylistPlaybackResumeManager.buildTrackOrderSignature(uris);
    this.resumeManager.updateTrackOrderSignature(this.detailPlaylistId, signature);
  }

  /**
   * 解析歌单首曲封面（详情页优先内存曲目，否则按 URI 查库）
   *
   * @param playlistId 歌单 id
   * @param firstUri 已知首曲 uri（批量加载时传入，可省一次查库）
   * @returns 封面 URI，无封面时为空串
   */
  private async resolveCoverForPlaylist(playlistId: number, firstUri?: string): Promise<string> {
    let track: FileInfo | null = null;
    if (this.detailPlaylistId === playlistId) {
      const tracks = this.detailTrackDataSource.getDataArray();
      if (tracks.length > 0) {
        track = tracks[0];
      }
    }
    if (track === null) {
      const uri = firstUri !== undefined && firstUri.length > 0 ?
        firstUri : await this.getFirstTrackUri(playlistId);
      if (uri.length === 0) {
        return '';
      }
      track = await this.resolveFileInfo(uri);
    }
    if (track === null) {
      return '';
    }
    return await PlaylistCoverUtil.resolveCoverUri(track, this.context);
  }

  /**
   * 查询歌单首曲 URI
   *
   * @param playlistId 歌单 id
   * @returns 首曲 uri，无曲目时为空串
   */
  private async getFirstTrackUri(playlistId: number): Promise<string> {
    if (!this.dbManager) {
      return '';
    }
    const uris = await this.dbManager.getPlaylistItems(playlistId);
    return uris.length > 0 ? uris[0] : '';
  }

  /**
   * 仅更新宫格列表中单个歌单的封面与曲目数（排序/增删曲目后，避免全量 loadPlaylists）
   *
   * @param playlistId 歌单 id
   */
  private async patchPlaylistItemCover(playlistId: number): Promise<void> {
    const index = this.playlistDataSource.findIndexById(playlistId);
    if (index < 0) {
      HiLog.w(TAG, `patchPlaylistItemCover skipped id=${playlistId}`);
      return;
    }
    const existing = this.playlistDataSource.getData(index);
    const coverUri = await this.resolveCoverForPlaylist(playlistId);
    const trackCount = await this.resolvePlaylistTrackCount(playlistId);
    const updated: PlaylistItem = {
      id: existing.id,
      name: existing.name,
      count: trackCount,
      coverUri
    };
    this.playlists[index] = updated;
    this.playlistDataSource.updateItemAt(index, updated);
    HiLog.i(TAG, `patchPlaylistItemCover id=${playlistId} count=${trackCount} cover=${coverUri.length > 0}`);
  }

  /**
   * 查询歌单曲目数（以数据库为准，避免宫格与详情内存不一致）
   *
   * @param playlistId 歌单 id
   */
  private async resolvePlaylistTrackCount(playlistId: number): Promise<number> {
    if (!this.dbManager) {
      if (this.detailPlaylistId === playlistId) {
        return this.detailTrackDataSource.totalCount();
      }
      const index = this.playlistDataSource.findIndexById(playlistId);
      return index >= 0 ? this.playlists[index].count : 0;
    }
    const uris = await this.dbManager.getPlaylistItems(playlistId);
    return uris.length;
  }

  private async reloadDetailTracks(): Promise<void> {
    if (!this.dbManager || this.detailPlaylistId < 0) {
      HiLog.i(TAG, `reloadDetailTracks   if`);
      this.detailTrackDataSource.setData([]);
      this.notifyUiState();
      return;
    }
    const uris = await this.dbManager.getPlaylistItems(this.detailPlaylistId);
    const tracks: FileInfo[] = [];
    for (const uri of uris) {
      const info = await this.resolveFileInfo(uri);
      if (info) {
        tracks.push(info);
      }
    }
    this.detailTrackDataSource.setData(tracks);
    const withCover = tracks.filter((item: FileInfo) => item.coverUri.length > 0).length;
    const order = tracks.map((track: FileInfo) => track.fileName).join('>');
    HiLog.i(TAG, `reloadDetailTracks count=${tracks.length} withCover=${withCover} playlistId=${this.detailPlaylistId} order=${order}`);
    const resumeOffer = this.resolveDetailResumeOffer(this.detailPlaylistId);
    HiLog.i(TAG,
      `reloadDetailTracks resumeOffer showResumeBar=${resumeOffer.showResumeBar} resumeLabel=${resumeOffer.resumeTrackLabel}`);
    this.notifyUiState();
  }

  private async resolveFileInfo(uri: string): Promise<FileInfo | null> {
    if (!this.dbManager) {
      return null;
    }
    let track: FileInfo | null = null;
    const fromDb: FileOperateFileInfo | null = await this.dbManager.queryMediaMetadataByUri(uri);
    if (fromDb) {
      fromDb.mimeType = 'audio/*';
      track = FileInfo.fromFileOperateFileInfo(fromDb);
    } else {
      const slash = uri.lastIndexOf('/');
      const fileName = slash >= 0 ? uri.substring(slash + 1) : uri;
      const fallback = new FileOperateFileInfo();
      fallback.uri = uri;
      fallback.path = uri;
      fallback.fileName = fileName;
      fallback.mimeType = 'audio/*';
      track = FileInfo.fromFileOperateFileInfo(fallback);
    }
    // 详情/编辑/播放队列共用：DB 封面为空时合并内存扫描与系统 media:// 缩略图
    PlaylistCoverUtil.applyAvailableCovers(track);
    HiLog.i(TAG, `resolveFileInfo uri=${uri} hasCover=${track.coverUri.length > 0}`);
    return track;
  }

  /**
   * 添加音频页过滤：与首页搜索相同的前缀 / 拼音首字母匹配逻辑
   */
  private applyAddAudioFilter(): void {
    const keywords: string[] = SearchScorer.parseKeywords(this.addAudioAppliedKeyword);
    let filtered: FileInfo[] = [];
    if (keywords.length === 0) {
      filtered = this.addAudioTracks.slice();
    } else {
      filtered = this.addAudioTracks.filter((item: FileInfo) => {
        for (let i = 0; i < keywords.length; i++) {
          if (!SearchMatchEngine.matchFileName(item.fileName, keywords[i]).matched) {
            return false;
          }
        }
        return true;
      });
    }
    this.addAudioDataSource.setData(filtered);
  }

  /**
   * 解析详情页续播条显隐与文案（buildUiState / 续播落盘回调共用）
   *
   * @param playlistId 歌单 ID
   */
  private resolveDetailResumeOffer(playlistId: number): DetailResumeOffer {
    const tracks = this.detailTrackDataSource.getDataArray();
    const uris = tracks.map((track: FileInfo) => track.uri);
    const resumeState = playlistId >= 0 ? this.resumeManager.getByPlaylistId(playlistId) : null;
    let showResumeBar = this.resumeManager.isResumeOfferVisible(resumeState, uris);
    if (showResumeBar && (this.sessionDismissedPlaylistIds.has(playlistId) ||
      this.isSourcePlaylistActivelyPlaying(playlistId))) {
      showResumeBar = false;
    }
    let resumeTrackLabel = '';
    if (showResumeBar && resumeState !== null) {
      const matched = tracks.find((track: FileInfo) => track.uri === resumeState.trackUri);
      resumeTrackLabel = matched !== undefined ? matched.fileName : resumeState.trackFileName;
    }
    return { showResumeBar, resumeTrackLabel };
  }

  private buildUiState(): PlaylistUiState {
    const selectedUris = Array.from(this.selectedUriSet);
    const detailTrackCount = this.detailTrackDataSource.totalCount();
    const addAudioTrackCount = this.addAudioDataSource.totalCount();
    const resumeOffer = this.resolveDetailResumeOffer(this.detailPlaylistId);
    return {
      playlists: this.playlists.slice(),
      isEmpty: this.playlists.length === 0,
      currentScreen: this.currentScreen,
      detailPlaylistId: this.detailPlaylistId,
      detailName: this.detailName,
      detailTrackCount: detailTrackCount,
      isDetailEmpty: detailTrackCount === 0,
      selectedUris: selectedUris,
      selectedPlaylistIds: Array.from(this.selectedPlaylistIdSet),
      nameDialogMode: this.nameDialogMode,
      nameDialogInitialName: this.nameDialogInitialName,
      confirmDialogMode: this.confirmDialogMode,
      confirmTargetId: this.confirmTargetId,
      confirmTargetCount: this.confirmTargetCount,
      addAudioSearchKeyword: this.addAudioSearchKeyword,
      isAddAudioEmpty: addAudioTrackCount === 0,
      addAudioInPlaylistUris: Array.from(this.addAudioInPlaylistUriSet),
      showResumeBar: resumeOffer.showResumeBar,
      resumeTrackLabel: resumeOffer.resumeTrackLabel
    };
  }

  private notifyUiState(): void {
    const state = this.buildUiState();
    if (state.currentScreen === PlaylistScreen.DETAIL) {
      if (state.showResumeBar !== this.lastNotifiedDetailResumeBar ||
        state.resumeTrackLabel !== this.lastNotifiedDetailResumeLabel) {
        HiLog.i(TAG,
          `notifyUiState detail playlistId=${state.detailPlaylistId} trackCount=${state.detailTrackCount} showResumeBar=${state.showResumeBar} resumeLabel=${state.resumeTrackLabel}`);
        this.lastNotifiedDetailResumeBar = state.showResumeBar;
        this.lastNotifiedDetailResumeLabel = state.resumeTrackLabel;
      }
    }
    this.syncMainTabBarVisibility();
    for (const listener of this.uiStateListeners) {
      try {
        listener(state);
      } catch (error) {
        HiLog.e(TAG, `UiState listener failed: ${error}`);
      }
    }
  }

  /** 播放列表进入详情/编辑/添加音频时隐藏底部 Tab */
  private syncMainTabBarVisibility(): void {
    const atRoot = this.currentScreen === PlaylistScreen.LIST;
    MainTabViewModel.getInstance().setPlaylistAtRoot(atRoot);
  }

  /**
   * 系统返回/Nav 出栈后同步歌单 currentScreen（与栈顶路由对齐）
   *
   * @param poppedRoute 被弹出的路由名
   */
  public syncAfterPlaylistNavPop(poppedRoute: string): void {
    HiLog.i(TAG, `syncAfterPlaylistNavPop popped=${poppedRoute} top=${NavRouterHelper.getTopRouteName()}`);
    const top: string = NavRouterHelper.getTopRouteName();
    if (top === AppNavRoutes.PLAYLIST_EDIT) {
      this.currentScreen = PlaylistScreen.EDIT;
    } else if (top === AppNavRoutes.PLAYLIST_LIST_SELECT) {
      this.currentScreen = PlaylistScreen.LIST_SELECT;
    } else if (top === AppNavRoutes.PLAYLIST_ADD_AUDIO) {
      this.currentScreen = PlaylistScreen.ADD_AUDIO;
    } else if (top === AppNavRoutes.PLAYLIST_DETAIL) {
      this.currentScreen = PlaylistScreen.DETAIL;
    } else if (!AppNavRoutes.isPlaylistRoute(top)) {
      this.currentScreen = PlaylistScreen.LIST;
      this.detailPlaylistId = -1;
      this.detailName = '';
      this.detailTrackDataSource.setData([]);
      this.addAudioTracks = [];
      this.addAudioDataSource.setData([]);
      this.addAudioSearchKeyword = '';
      this.addAudioAppliedKeyword = '';
      this.addAudioInPlaylistUriSet.clear();
      this.clearEditSelection();
      this.clearListSelectSelection();
      this.lastNotifiedDetailResumeBar = false;
      this.lastNotifiedDetailResumeLabel = '';
    }
    this.notifyUiState();
  }

  /** 注册续播持久化变更监听，保存后立即刷新详情页续播条 */
  private ensureResumeChangeListener(): void {
    if (this.resumeListenerRegistered) {
      return;
    }
    this.resumeManager.addChangeListener(this.handleResumePersisted);
    this.resumeListenerRegistered = true;
    HiLog.i(TAG, 'resume change listener registered');
  }

  private handleResumePersisted: PlaylistPlaybackResumeChangeListener = (playlistId: number): void => {
    if (this.currentScreen !== PlaylistScreen.DETAIL || this.detailPlaylistId !== playlistId) {
      return;
    }
    const offer = this.resolveDetailResumeOffer(playlistId);
    HiLog.i(TAG,
      `handleResumePersisted playlistId=${playlistId} showResumeBar=${offer.showResumeBar} resumeLabel=${offer.resumeTrackLabel}`);
    this.notifyUiState();
  };

  /**
   * 用户主动起播（非续播条）：清除旧快照，续播进度改由 AVPlayer 播放过程中落盘
   *
   * @param playlistId 歌单 ID
   */
  private clearResumeMemoryForExplicitPlay(playlistId: number): void {
    if (playlistId < 0) {
      return;
    }
    this.resumeManager.removeByPlaylistId(playlistId);
    this.sessionDismissedPlaylistIds.delete(playlistId);
    HiLog.i(TAG, `clearResumeMemoryForExplicitPlay playlistId=${playlistId}`);
  }

  /**
   * 指定歌单是否正在播放或暂停（stop 后仍允许展示续播条）
   *
   * @param playlistId 歌单 ID
   */
  private isSourcePlaylistActivelyPlaying(playlistId: number): boolean {
    if (playlistId < 0) {
      return false;
    }
    if (PlaybackQueueManager.getInstance().getSourcePlaylistId() !== playlistId) {
      return false;
    }
    if (PlaybackQueueManager.getInstance().getMediaKind() !== PlaybackMediaKind.AUDIO) {
      return false;
    }
    const controller = AudioPlaybackSession.getInstance().getController();
    if (!controller.hasActivePlayback()) {
      return false;
    }
    const playState = controller.playState;
    return playState === PlayConstants.STATUS_START || playState === PlayConstants.STATUS_PAUSE;
  }
}
