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


import {
  PlaybackHistoryChangeListener,
  PlaybackHistoryManager,
  PlaybackHistoryRestoreCallback,
  PlaybackHistoryTrackItem,
  PlaybackMediaKind,
  PlaybackQueueChangeListener,
  PlaybackQueueEntry,
  PlaybackQueueManager
} from '@ohos/common';
import FileInfo from '@ohos/common/src/main/ets/model/FileInfo';
import { common } from '@kit.AbilityKit';
import { PlayConstants } from '@ohos/common/src/main/ets/constants/player/PlayConstants';
import { HiLog } from '@ohos/common/src/main/ets/utils/HiLog';
import { PlaybackQueueDataSource } from '../datasource/PlaybackQueueDataSource';
import { AVPlayerController } from '../controller/AVPlayerController';
import { AudioPlaybackSession } from '../session/AudioPlaybackSession';
import { PlaybackQueueSheetConstants } from '../constants/PlaybackQueueSheetConstants';
import { PlayingEqualizerConstants } from '../constants/PlayingEqualizerConstants';

const TAG = 'PlaybackQueueSheetViewModel';

/** 播放队列半模态 UI 状态快照 */
export interface PlaybackQueueSheetUiState {
  currentIndex: number;
  queueCount: number;
  sourceName: string;
  isMediaPlaying: boolean;
  longPressUri: string;
  equalizerAnimTick: number;
  /** 最近点播单曲列表（新 → 旧） */
  historyTracks: PlaybackHistoryTrackItem[];
}

/**
 * 播放队列半模态 ViewModel：从 PlaybackQueueManager 同步队列并处理点选切歌
 */
export class PlaybackQueueSheetViewModel {
  private static instance: PlaybackQueueSheetViewModel | null = null;
  private readonly queueManager: PlaybackQueueManager = PlaybackQueueManager.getInstance();
  private readonly historyManager: PlaybackHistoryManager = PlaybackHistoryManager.getInstance();
  private readonly dataSource: PlaybackQueueDataSource = new PlaybackQueueDataSource();
  private uiListeners: ((state: PlaybackQueueSheetUiState) => void)[] = [];
  private revision: number = 0;
  private currentIndex: number = -1;
  private sourceName: string = '';
  private isMediaPlaying: boolean = false;
  private longPressUri: string = '';
  private equalizerAnimTick: number = 0;
  private historyTracks: PlaybackHistoryTrackItem[] = [];
  private isAudio: boolean = true;
  private avPlayerController: AVPlayerController = new AVPlayerController();
  private panelActive: boolean = false;
  private playStateSyncTimer: number = -1;
  private equalizerAnimTimer: number = -1;
  private longPressClearTimer: number = -1;
  private queueChangeListener: PlaybackQueueChangeListener = () => {
    this.refreshQueue();
  };
  private historyChangeListener: PlaybackHistoryChangeListener = () => {
    this.loadRecentHistoryTracks();
  };
  private listenerAttached: boolean = false;
  private historyListenerAttached: boolean = false;
  private historyRestoreHandler: PlaybackHistoryRestoreCallback | null = null;
  private audioQueueEmptyHandler: (() => void) | null = null;

  private constructor() {
  }

  public static getInstance(): PlaybackQueueSheetViewModel {
    if (PlaybackQueueSheetViewModel.instance === null) {
      PlaybackQueueSheetViewModel.instance = new PlaybackQueueSheetViewModel();
    }
    return PlaybackQueueSheetViewModel.instance;
  }

  public getDataSource(): PlaybackQueueDataSource {
    return this.dataSource;
  }

  public addUiListener(listener: (state: PlaybackQueueSheetUiState) => void): void {
    if (this.uiListeners.indexOf(listener) < 0) {
      this.uiListeners.push(listener);
    }
  }

  public removeUiListener(listener: (state: PlaybackQueueSheetUiState) => void): void {
    const pos = this.uiListeners.indexOf(listener);
    if (pos >= 0) {
      this.uiListeners.splice(pos, 1);
    }
  }

  /** 订阅队列变更并拉取最新快照 */
  public attachQueueListener(): void {
    if (this.listenerAttached) {
      return;
    }
    this.queueManager.addQueueChangeListener(this.queueChangeListener);
    this.listenerAttached = true;
    HiLog.i(TAG, 'attachQueueListener');
  }

  /** 取消订阅队列变更 */
  public detachQueueListener(): void {
    if (!this.listenerAttached) {
      return;
    }
    this.queueManager.removeQueueChangeListener(this.queueChangeListener);
    this.listenerAttached = false;
    HiLog.i(TAG, 'detachQueueListener');
  }

  private attachHistoryListener(): void {
    if (this.historyListenerAttached) {
      return;
    }
    this.historyManager.addChangeListener(this.historyChangeListener);
    this.historyListenerAttached = true;
    HiLog.i(TAG, 'attachHistoryListener');
  }

  private detachHistoryListener(): void {
    if (!this.historyListenerAttached) {
      return;
    }
    this.historyManager.removeChangeListener(this.historyChangeListener);
    this.historyListenerAttached = false;
    HiLog.i(TAG, 'detachHistoryListener');
  }

  /**
   * 半模态展示：订阅队列、同步播放态并启动轮询
   *
   * @param isAudio 是否音频队列
   * @param controller 视频等非音频场景的控制器
   * @param context UIAbility 上下文，用于初始化历史播放存储
   */
  public onPanelAppear(isAudio: boolean, controller: AVPlayerController, context?: common.UIAbilityContext): void {
    if (context !== undefined) {
      this.historyManager.init(context);
    }
    this.isAudio = isAudio;
    this.avPlayerController = controller;
    this.panelActive = true;
    this.attachQueueListener();
    this.attachHistoryListener();
    this.refreshQueue();
    this.loadRecentHistoryTracks();
    this.syncPlayState();
    this.startPlayStateSync();
    HiLog.i(TAG, `onPanelAppear isAudio=${isAudio}`);
  }

  /** 半模态关闭：停止轮询并清理长按态 */
  public onPanelDisappear(): void {
    this.panelActive = false;
    this.stopPlayStateSync();
    this.stopEqualizerAnim();
    this.isMediaPlaying = false;
    this.clearLongPressEffect();
    this.detachQueueListener();
    this.detachHistoryListener();
    this.historyRestoreHandler = null;
    this.audioQueueEmptyHandler = null;
    HiLog.i(TAG, 'onPanelDisappear');
  }

  /**
   * 注册历史歌单恢复回调（由产品层提供 setQueue + 打开播放器）
   *
   * @param handler 恢复处理器，半模态关闭时自动清空
   */
  public setHistoryRestoreHandler(handler: PlaybackHistoryRestoreCallback | null): void {
    this.historyRestoreHandler = handler;
  }

  /** 音频队列清空且无曲可播时回调（删除最后一首当前曲时触发） */
  public setAudioQueueEmptyHandler(handler: (() => void) | null): void {
    this.audioQueueEmptyHandler = handler;
  }

  /**
   * 长按开始：仅标记拖拽项以显示浅灰底，不做缩放动画
   *
   * @param uri 队列项 URI
   * @param fileName 文件名（日志用）
   */
  public onLongPressStart(uri: string, fileName: string): void {
    if (this.longPressUri === uri) {
      return;
    }
    this.longPressUri = uri;
    this.notifyUiState();
    HiLog.i(TAG, `onLongPressStart fileName=${fileName}`);
  }

  /** 长按结束：延迟清理，避免抢在 onMove 前刷新导致拖拽回弹 */
  public onLongPressEnd(): void {
    if (this.longPressClearTimer >= 0) {
      clearTimeout(this.longPressClearTimer);
    }
    this.longPressClearTimer = setTimeout(() => {
      this.clearLongPressEffect();
      this.longPressClearTimer = -1;
    }, 0);
  }

  /**
   * 判断 URI 是否为当前播放项（由 View 传入 @State currentIndex 以触发刷新）
   *
   * @param uri 曲目 URI
   * @param currentIndex 当前播放索引
   */
  public matchesCurrentUri(uri: string, currentIndex: number): boolean {
    if (currentIndex < 0 || currentIndex >= this.dataSource.totalCount()) {
      return false;
    }
    return this.dataSource.getData(currentIndex).uri === uri;
  }

  /**
   * LazyForEach 列表项 key：使用稳定 URI，依赖 notifyDataReload 刷新，避免 revision 全量失效导致半旧半新
   *
   * @param entry 队列项
   */
  public buildQueueItemKey(entry: PlaybackQueueEntry): string {
    return entry.uri;
  }

  /** 清除长按拖拽标记与待执行定时器 */
  private clearLongPressEffect(): void {
    if (this.longPressClearTimer >= 0) {
      clearTimeout(this.longPressClearTimer);
      this.longPressClearTimer = -1;
    }
    if (this.longPressUri.length === 0) {
      return;
    }
    this.longPressUri = '';
    this.notifyUiState();
  }

  /** 音频队列与全屏/迷你条共用会话控制器，避免 bindSheet 内控制器丢引用 */
  private resolvePlaybackController(): AVPlayerController {
    if (this.isAudio) {
      return AudioPlaybackSession.getInstance().getController();
    }
    return this.avPlayerController;
  }

  /** 是否处于播放态（与迷你条封面旋转判据一致） */
  private isPlaybackActive(): boolean {
    const controller = this.resolvePlaybackController();
    if (controller.getPlayState() === PlayConstants.STATUS_START) {
      return true;
    }
    return controller.isMediaPlaying();
  }

  /** 从控制器同步播放态，并联动竖条动画 */
  private syncPlayState(): void {
    const active = this.isPlaybackActive();
    this.isMediaPlaying = active;
    if (active && this.panelActive) {
      this.startEqualizerAnim();
    } else {
      this.stopEqualizerAnim();
    }
  }

  /** 播放中定时推进竖条动画帧（仅刷新均衡器相关字段，避免每帧重写历史列表） */
  private startEqualizerAnim(): void {
    if (this.equalizerAnimTimer >= 0) {
      return;
    }
    this.equalizerAnimTimer = setInterval(() => {
      if (!this.panelActive || !this.isMediaPlaying) {
        this.stopEqualizerAnim();
        return;
      }
      this.equalizerAnimTick++;
      this.notifyEqualizerOnly();
    }, PlayingEqualizerConstants.BAR_ANIM_FRAME_MS);
  }

  /** 停止竖条动画帧推进 */
  private stopEqualizerAnim(): void {
    if (this.equalizerAnimTimer >= 0) {
      clearInterval(this.equalizerAnimTimer);
      this.equalizerAnimTimer = -1;
    }
  }

  /** 半模态可见期间轮询播放态，驱动竖条跳动 */
  private startPlayStateSync(): void {
    if (this.playStateSyncTimer >= 0) {
      return;
    }
    this.playStateSyncTimer = setInterval(() => {
      if (!this.panelActive) {
        return;
      }
      const active = this.isPlaybackActive();
      if (active !== this.isMediaPlaying) {
        this.isMediaPlaying = active;
        if (active) {
          this.startEqualizerAnim();
        } else {
          this.stopEqualizerAnim();
        }
        this.notifyUiState();
      }
    }, PlaybackQueueSheetConstants.PLAY_STATE_POLL_MS);
  }

  /** 停止播放态轮询 */
  private stopPlayStateSync(): void {
    if (this.playStateSyncTimer >= 0) {
      clearInterval(this.playStateSyncTimer);
      this.playStateSyncTimer = -1;
    }
  }

  /**
   * 从 PlaybackQueueManager 刷新队列列表
   */
  public refreshQueue(): void {
    const snapshot = this.queueManager.getQueueSnapshot();
    this.currentIndex = this.queueManager.getCurrentIndex();
    this.sourceName = this.queueManager.getSourceName();
    this.revision++;
    // 先写入数据源（含 isCurrent），再通知 Panel，避免 queueCount 仍为旧值导致空态
    this.dataSource.setData(snapshot);
    this.syncPlayState();
    this.notifyUiState();
    HiLog.i(TAG, `refreshQueue count=${snapshot.length} currentIndex=${this.currentIndex} source=${this.sourceName} rev=${this.revision}`);
  }

  /**
   * 按 URI 解析当前队列索引（避免 LazyForEach 复用节点后 entry.index 过期）
   *
   * @param uri 曲目 URI
   */
  private resolveIndexByUri(uri: string): number {
    const count = this.dataSource.totalCount();
    for (let i = 0; i < count; i++) {
      if (this.dataSource.getData(i).uri === uri) {
        return i;
      }
    }
    return -1;
  }

  /**
   * 点击队列项切歌
   *
   * @param uri 曲目 URI
   */
  public playQueueItemByUri(uri: string): void {
    const index = this.resolveIndexByUri(uri);
    if (index < 0) {
      HiLog.w(TAG, `playQueueItemByUri not found uri=${uri}`);
      return;
    }
    HiLog.i(TAG, `playQueueItemByUri index=${index} uri=${uri}`);
    this.queueManager.playAt(index);
  }

  /**
   * 按 URI 从队列移除指定项
   * 当前播放项：移除并切到下一首；仅剩一首时再点则清空队列并隐藏迷你条
   *
   * @param uri 曲目 URI
   */
  public removeQueueItemByUri(uri: string): void {
    const index = this.resolveIndexByUri(uri);
    if (index < 0) {
      HiLog.w(TAG, `removeQueueItemByUri not found uri=${uri}`);
      return;
    }
    const isCurrent = this.queueManager.getCurrentUri() === uri;
    if (isCurrent) {
      const queueSize = this.queueManager.getQueueSnapshot().length;
      if (queueSize === 1) {
        HiLog.i(TAG, `removeQueueItemByUri current clearAll uri=${uri}`);
        const isAudioQueue = this.queueManager.getMediaKind() === PlaybackMediaKind.AUDIO;
        this.queueManager.clearAll();
        this.refreshQueue();
        if (isAudioQueue && this.audioQueueEmptyHandler !== null) {
          this.audioQueueEmptyHandler();
        }
        return;
      }
    }
    HiLog.i(TAG, `removeQueueItemByUri index=${index} uri=${uri}`);
    this.queueManager.removeAt(index);
    this.refreshQueue();
  }

  /**
   * 清空队列（保留当前正在播放曲目）
   */
  public clearQueueExceptCurrent(): void {
    HiLog.i(TAG, 'clearQueueExceptCurrent');
    this.queueManager.clearExceptCurrent();
    this.refreshQueue();
  }

  /**
   * 按 URI 批量从播放队列移除（降序 silent 删除，避免多次切歌）
   *
   * @param uris 待删除曲目 URI 列表
   */
  public removeQueueItemsByUris(uris: string[]): void {
    if (uris.length === 0) {
      HiLog.w(TAG, 'removeQueueItemsByUris aborted empty');
      return;
    }
    const snapshot = this.queueManager.getQueueSnapshot();
    if (uris.length >= snapshot.length) {
      HiLog.i(TAG, `removeQueueItemsByUris clearAll selected=${uris.length} total=${snapshot.length}`);
      const isAudioQueue = this.queueManager.getMediaKind() === PlaybackMediaKind.AUDIO;
      this.queueManager.clearAll();
      this.refreshQueue();
      if (isAudioQueue && this.audioQueueEmptyHandler !== null) {
        this.audioQueueEmptyHandler();
      }
      return;
    }
    const currentUri = this.queueManager.getCurrentUri();
    const deletingCurrent = uris.indexOf(currentUri) >= 0;
    const indices: number[] = [];
    for (let i = 0; i < uris.length; i++) {
      const idx = this.resolveIndexByUri(uris[i]);
      if (idx >= 0) {
        indices.push(idx);
      }
    }
    indices.sort((a: number, b: number) => b - a);
    HiLog.i(TAG, `removeQueueItemsByUris start count=${indices.length} deletingCurrent=${deletingCurrent}`);
    for (let i = 0; i < indices.length; i++) {
      const isLast = i === indices.length - 1;
      const silent = !(isLast && deletingCurrent);
      this.queueManager.removeAt(indices[i], silent);
    }
    this.refreshQueue();
    HiLog.i(TAG,
      `removeQueueItemsByUris done remain=${this.queueManager.getQueueSnapshot().length}`);
  }

  /**
   * 加载最近点播单曲列表
   */
  public loadRecentHistoryTracks(): void {
    this.historyTracks = this.historyManager.getRecentTracks();
    HiLog.i(TAG, `loadRecentHistoryTracks count=${this.historyTracks.length}`);
    this.notifyUiState();
  }

  /**
   * 从最近播放中移除单曲
   *
   * @param uri 曲目 URI
   */
  public removeHistoryTrack(uri: string): void {
    HiLog.i(TAG, `removeHistoryTrack uri=${uri}`);
    this.historyManager.removeByUri(uri);
    this.loadRecentHistoryTracks();
  }

  /**
   * 清空最近播放
   */
  public clearHistoryTracks(): void {
    HiLog.i(TAG, 'clearHistoryTracks');
    this.historyManager.clearAll();
    this.loadRecentHistoryTracks();
  }

  /**
   * 点击最近播放单曲：以最近列表为队列并起播
   *
   * @param track 被点击曲目
   */
  public playHistoryTrack(track: PlaybackHistoryTrackItem): void {
    HiLog.i(TAG, `playHistoryTrack uri=${track.uri}`);
    const recent = this.historyManager.getRecentTracks();
    if (recent.length === 0) {
      HiLog.w(TAG, 'playHistoryTrack aborted empty history');
      return;
    }
    const queueItems: FileInfo[] = [];
    let hasTarget = false;
    for (let i = 0; i < recent.length; i++) {
      queueItems.push(this.buildFileInfoFromHistoryTrack(recent[i]));
      if (recent[i].uri === track.uri) {
        hasTarget = true;
      }
    }
    if (!hasTarget) {
      queueItems.unshift(this.buildFileInfoFromHistoryTrack(track));
    }
    if (this.historyRestoreHandler !== null) {
      HiLog.i(TAG, `playHistoryTrack delegate count=${queueItems.length}`);
      this.historyRestoreHandler(queueItems, track.uri, '', PlaybackMediaKind.AUDIO);
    } else {
      this.queueManager.setQueue(queueItems, track.uri, PlaybackMediaKind.AUDIO, '');
      this.queueManager.startCurrentTrack();
      HiLog.i(TAG, `playHistoryTrack fallback count=${queueItems.length}`);
    }
  }

  /**
   * 历史曲目转 FileInfo，供 setQueue 写入 trackCache
   *
   * @param track 历史曲目
   */
  private buildFileInfoFromHistoryTrack(track: PlaybackHistoryTrackItem): FileInfo {
    let mimeType = track.mimeType;
    if (!mimeType.startsWith('audio/') && !mimeType.startsWith('video/')) {
      mimeType = 'audio/*';
    }
    const fileSize = track.fileSize !== undefined ? track.fileSize : 0;
    const info = new FileInfo(track.fileName, track.uri, mimeType, fileSize);
    info.picWidth = track.picWidth !== undefined ? track.picWidth : 0;
    info.picHeight = track.picHeight !== undefined ? track.picHeight : 0;
    return info;
  }

  /**
   * 切换到历史播放 Tab 时刷新最近播放列表
   */
  public onHistoryTabSelected(): void {
    HiLog.i(TAG, 'onHistoryTabSelected');
    this.loadRecentHistoryTracks();
  }

  /**
   * 反转队列顺序
   */
  public reverseQueue(): void {
    HiLog.i(TAG, 'reverseQueue');
    this.queueManager.reverseQueue();
  }

  /**
   * 拖拽调整队列顺序
   *
   * @param from 原索引
   * @param to 目标索引
   */
  public reorderQueue(from: number, to: number): void {
    HiLog.i(TAG, `reorderQueue start from=${from} to=${to}`);
    if (!this.queueManager.moveItem(from, to, false)) {
      HiLog.w(TAG, `reorderQueue aborted from=${from} to=${to}`);
      return;
    }
    if (!this.dataSource.moveItemWithoutNotify(from, to)) {
      HiLog.w(TAG, `reorderQueue dataSource failed from=${from} to=${to}`);
      this.refreshQueue();
      return;
    }
    this.dataSource.syncCurrentIndex(this.queueManager.getCurrentIndex());
    this.currentIndex = this.queueManager.getCurrentIndex();
    this.revision++;
    this.onLongPressEnd();
    this.notifyUiState();
  }

  /** 仅刷新均衡器相关 @State，避免每帧 slice 历史列表 */
  private notifyEqualizerOnly(): void {
    const state: PlaybackQueueSheetUiState = {
      currentIndex: this.currentIndex,
      queueCount: this.dataSource.totalCount(),
      sourceName: this.sourceName,
      isMediaPlaying: this.isMediaPlaying,
      longPressUri: this.longPressUri,
      equalizerAnimTick: this.equalizerAnimTick,
      historyTracks: this.historyTracks
    };
    for (let i = 0; i < this.uiListeners.length; i++) {
      try {
        this.uiListeners[i](state);
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        HiLog.e(TAG, `notifyEqualizerOnly failed message=${message}`);
      }
    }
  }

  private notifyUiState(): void {
    const state: PlaybackQueueSheetUiState = {
      currentIndex: this.currentIndex,
      queueCount: this.dataSource.totalCount(),
      sourceName: this.sourceName,
      isMediaPlaying: this.isMediaPlaying,
      longPressUri: this.longPressUri,
      equalizerAnimTick: this.equalizerAnimTick,
      historyTracks: this.historyTracks.slice()
    };
    for (let i = 0; i < this.uiListeners.length; i++) {
      try {
        this.uiListeners[i](state);
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        HiLog.e(TAG, `notifyUiState failed message=${message}`);
      }
    }
  }
}
