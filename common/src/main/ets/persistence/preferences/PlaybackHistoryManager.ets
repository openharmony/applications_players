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


import preferences from '@ohos.data.preferences';
import { common } from '@kit.AbilityKit';
import { HiLog } from '../../utils/HiLog';
import { PlaybackHistoryTrackItem } from './PlaybackHistoryTypes';

const TAG = 'PlaybackHistoryManager';
const PREF_FILE_NAME = 'playback_history_pref';
/** 单曲最近播放列表（与旧版歌单快照 key 隔离，避免解析冲突） */
const PREF_KEY_RECENT_TRACKS = 'history_recent_tracks';
const MAX_RECENT_TRACK_COUNT: number = 50;

export type PlaybackHistoryChangeListener = () => void;

/**
 * 历史播放：按单曲记录最近点播音频（去重置顶，Preferences 持久化）
 */
export class PlaybackHistoryManager {
  private static instance: PlaybackHistoryManager | null = null;
  private preferenceInstance: preferences.Preferences | null = null;
  private context: common.UIAbilityContext | null = null;
  private memoryCache: PlaybackHistoryTrackItem[] = [];
  private loadedFromPref: boolean = false;
  private changeListeners: PlaybackHistoryChangeListener[] = [];

  private constructor() {
  }

  public static getInstance(): PlaybackHistoryManager {
    if (PlaybackHistoryManager.instance === null) {
      PlaybackHistoryManager.instance = new PlaybackHistoryManager();
    }
    return PlaybackHistoryManager.instance;
  }

  /**
   * 绑定 UIAbility 上下文并加载单曲历史（仅首次读盘）
   *
   * @param context UIAbility 上下文
   */
  public init(context: common.UIAbilityContext): void {
    this.context = context;
    if (this.preferenceInstance === null) {
      this.loadPreference();
    }
    if (!this.loadedFromPref) {
      this.memoryCache = this.readTracksFromPref();
      this.loadedFromPref = true;
      HiLog.i(TAG, `init firstLoad count=${this.memoryCache.length}`);
      return;
    }
    HiLog.i(TAG, `init reuseMemory count=${this.memoryCache.length}`);
  }

  public addChangeListener(listener: PlaybackHistoryChangeListener): void {
    if (this.changeListeners.indexOf(listener) < 0) {
      this.changeListeners.push(listener);
    }
  }

  public removeChangeListener(listener: PlaybackHistoryChangeListener): void {
    const pos = this.changeListeners.indexOf(listener);
    if (pos >= 0) {
      this.changeListeners.splice(pos, 1);
    }
  }

  /**
   * 获取最近播放单曲（新 → 旧）
   */
  public getRecentTracks(): PlaybackHistoryTrackItem[] {
    if (!this.loadedFromPref && this.preferenceInstance !== null) {
      this.memoryCache = this.readTracksFromPref();
      this.loadedFromPref = true;
    }
    return this.memoryCache.slice();
  }

  /**
   * 记录一首最近点播音频：同 URI 去重并置顶
   *
   * @param track 曲目信息
   */
  public recordTrack(track: PlaybackHistoryTrackItem): void {
    if (track.uri.length === 0) {
      HiLog.w(TAG, 'recordTrack skipped empty uri');
      return;
    }
    if (this.preferenceInstance === null && this.context !== null) {
      this.loadPreference();
    }
    let mimeType = track.mimeType;
    if (!mimeType.startsWith('audio/') && !mimeType.startsWith('video/')) {
      mimeType = 'audio/*';
    }
    // 历史播放 Tab 仅展示音频
    if (mimeType.startsWith('video/')) {
      HiLog.i(TAG, `recordTrack skipped video uri=${track.uri}`);
      return;
    }
    const nextItem: PlaybackHistoryTrackItem = {
      uri: track.uri,
      fileName: track.fileName.length > 0 ? track.fileName : this.extractFileName(track.uri),
      mimeType: mimeType.startsWith('audio/') ? mimeType : 'audio/*',
      fileSize: track.fileSize !== undefined ? track.fileSize : 0,
      picWidth: track.picWidth !== undefined ? track.picWidth : 0,
      picHeight: track.picHeight !== undefined ? track.picHeight : 0
    };
    const filtered = this.getRecentTracks().filter((item: PlaybackHistoryTrackItem) => item.uri !== nextItem.uri);
    const nextList = [nextItem].concat(filtered);
    if (nextList.length > MAX_RECENT_TRACK_COUNT) {
      nextList.length = MAX_RECENT_TRACK_COUNT;
    }
    this.persistTracks(nextList);
    HiLog.i(TAG, `recordTrack fileName=${nextItem.fileName} total=${nextList.length}`);
  }

  /**
   * 按 URI 删除一条最近播放
   *
   * @param uri 曲目 URI
   */
  public removeByUri(uri: string): void {
    const filtered = this.getRecentTracks().filter((item: PlaybackHistoryTrackItem) => item.uri !== uri);
    this.persistTracks(filtered);
    HiLog.i(TAG, `removeByUri remain=${filtered.length}`);
  }

  /** 清空最近播放 */
  public clearAll(): void {
    this.persistTracks([]);
    HiLog.i(TAG, 'clearAll');
  }

  private extractFileName(uri: string): string {
    const slash = uri.lastIndexOf('/');
    return slash >= 0 ? uri.substring(slash + 1) : uri;
  }

  private loadPreference(): void {
    if (this.context === null) {
      HiLog.w(TAG, 'loadPreference skipped: context null');
      return;
    }
    try {
      const options: preferences.Options = { name: PREF_FILE_NAME };
      this.preferenceInstance = preferences.getPreferencesSync(this.context, options);
      HiLog.i(TAG, 'loadPreference success');
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      HiLog.e(TAG, `loadPreference failed message=${message}`);
    }
  }

  private readTracksFromPref(): PlaybackHistoryTrackItem[] {
    if (this.preferenceInstance === null) {
      return [];
    }
    try {
      const raw = this.preferenceInstance.getSync(PREF_KEY_RECENT_TRACKS, '[]') as string;
      if (raw.length <= 2) {
        return [];
      }
      const parsed = JSON.parse(raw) as PlaybackHistoryTrackItem[];
      if (!Array.isArray(parsed)) {
        return [];
      }
      const result: PlaybackHistoryTrackItem[] = [];
      for (let i = 0; i < parsed.length; i++) {
        const item = parsed[i];
        if (item === undefined || item.uri === undefined || item.uri.length === 0) {
          continue;
        }
        result.push({
          uri: item.uri,
          fileName: item.fileName !== undefined ? item.fileName : this.extractFileName(item.uri),
          mimeType: item.mimeType !== undefined && item.mimeType.length > 0 ? item.mimeType : 'audio/*',
          fileSize: item.fileSize !== undefined ? item.fileSize : 0,
          picWidth: item.picWidth !== undefined ? item.picWidth : 0,
          picHeight: item.picHeight !== undefined ? item.picHeight : 0
        });
      }
      return result;
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      HiLog.e(TAG, `readTracksFromPref failed message=${message}`);
      return [];
    }
  }

  private persistTracks(tracks: PlaybackHistoryTrackItem[]): void {
    this.memoryCache = tracks.slice();
    this.loadedFromPref = true;
    if (this.preferenceInstance === null) {
      HiLog.w(TAG, 'persistTracks memoryOnly: preference null');
      this.notifyChange();
      return;
    }
    try {
      this.preferenceInstance.putSync(PREF_KEY_RECENT_TRACKS, JSON.stringify(tracks));
      this.preferenceInstance.flushSync();
      HiLog.i(TAG, `persistTracks count=${tracks.length}`);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      HiLog.e(TAG, `persistTracks failed message=${message}`);
    }
    this.notifyChange();
  }

  private notifyChange(): void {
    for (let i = 0; i < this.changeListeners.length; i++) {
      try {
        this.changeListeners[i]();
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        HiLog.e(TAG, `notifyChange failed message=${message}`);
      }
    }
  }
}
