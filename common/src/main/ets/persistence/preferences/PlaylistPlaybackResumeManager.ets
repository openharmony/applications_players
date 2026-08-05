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
import { PlaylistPlaybackResumeState, PlaylistPlaybackResumeChangeListener } from './PlaylistPlaybackResumeTypes';

const TAG = 'PlaylistPlaybackResumeManager';
const PREF_FILE_NAME = 'playlist_playback_resume_pref';
const PREF_KEY_RESUME_MAP = 'resume_by_playlist';
/** 低于该进度不展示续播条（避免起播瞬间 position=0 误提示） */
const MIN_RESUME_OFFER_POSITION_MS: number = 3000;

/**
 * 歌单续播进度持久化：按 playlistId 保存当前曲目与进度，进程被杀后仍可恢复
 */
export class PlaylistPlaybackResumeManager {
  private static instance: PlaylistPlaybackResumeManager | null = null;
  private preferenceInstance: preferences.Preferences | null = null;
  private context: common.UIAbilityContext | null = null;
  private memoryCache: Map<number, PlaylistPlaybackResumeState> = new Map();
  private changeListeners: PlaylistPlaybackResumeChangeListener[] = [];

  private constructor() {
  }

  public static getInstance(): PlaylistPlaybackResumeManager {
    if (PlaylistPlaybackResumeManager.instance === null) {
      PlaylistPlaybackResumeManager.instance = new PlaylistPlaybackResumeManager();
    }
    return PlaylistPlaybackResumeManager.instance;
  }

  /**
   * 绑定 UIAbility 上下文并加载续播快照
   *
   * @param context UIAbility 上下文
   */
  public init(context: common.UIAbilityContext): void {
    this.context = context;
    if (this.preferenceInstance === null) {
      this.loadPreference();
    }
    this.memoryCache = this.readResumeMapFromPref();
    HiLog.i(TAG, `init count=${this.memoryCache.size}`);
  }

  /**
   * 构建歌单曲目顺序签名
   *
   * @param uris 曲目 URI 列表
   * @returns 签名串
   */
  public static buildTrackOrderSignature(uris: string[]): string {
    return uris.join('>');
  }

  /**
   * 注册续播快照变更监听（保存/清除后通知 UI 刷新）
   *
   * @param listener 回调
   */
  public addChangeListener(listener: PlaylistPlaybackResumeChangeListener): void {
    if (this.changeListeners.indexOf(listener) < 0) {
      this.changeListeners.push(listener);
    }
  }

  /**
   * 移除续播快照变更监听
   *
   * @param listener 回调
   */
  public removeChangeListener(listener: PlaylistPlaybackResumeChangeListener): void {
    const index = this.changeListeners.indexOf(listener);
    if (index >= 0) {
      this.changeListeners.splice(index, 1);
    }
  }

  /**
   * 读取歌单续播快照
   *
   * @param playlistId 歌单 ID
   * @returns 快照，无则 null
   */
  public getByPlaylistId(playlistId: number): PlaylistPlaybackResumeState | null {
    if (playlistId < 0) {
      return null;
    }
    if (this.memoryCache.size === 0 && this.preferenceInstance !== null) {
      this.memoryCache = this.readResumeMapFromPref();
    }
    const state = this.memoryCache.get(playlistId);
    return state !== undefined ? state : null;
  }

  /**
   * 是否可向用户展示续播条
   *
   * @param state 续播快照
   * @param currentUris 当前歌单 URI 顺序
   * @returns 是否有效且进度达标
   */
  public isResumeOfferVisible(state: PlaylistPlaybackResumeState | null, currentUris: string[]): boolean {
    if (state === null || currentUris.length === 0) {
      return false;
    }
    if (!this.isResumeCompatible(state, currentUris)) {
      return false;
    }
    if (state.positionMs < MIN_RESUME_OFFER_POSITION_MS) {
      return false;
    }
    return true;
  }

  /**
   * 校验续播快照与当前歌单是否仍匹配（曲目仍在列表即可，排序变化不隐藏续播条）
   *
   * @param state 续播快照
   * @param currentUris 当前歌单 URI 列表
   * @returns 是否可续播
   */
  public isResumeCompatible(state: PlaylistPlaybackResumeState, currentUris: string[]): boolean {
    return currentUris.indexOf(state.trackUri) >= 0;
  }

  /**
   * 歌单曲目顺序变更后同步续播快照签名（拖拽排序后保持记忆有效）
   *
   * @param playlistId 歌单 ID
   * @param trackOrderSignature 新顺序签名
   */
  public updateTrackOrderSignature(playlistId: number, trackOrderSignature: string): void {
    if (playlistId < 0 || trackOrderSignature.length === 0) {
      return;
    }
    const state = this.memoryCache.get(playlistId);
    if (state === undefined) {
      return;
    }
    if (state.trackOrderSignature === trackOrderSignature) {
      return;
    }
    const updated: PlaylistPlaybackResumeState = {
      playlistId: state.playlistId,
      trackUri: state.trackUri,
      trackFileName: state.trackFileName,
      positionMs: state.positionMs,
      savedAt: Date.now(),
      trackOrderSignature: trackOrderSignature
    };
    this.memoryCache.set(playlistId, updated);
    this.persistResumeMap();
    HiLog.i(TAG, `updateTrackOrderSignature playlistId=${playlistId}`);
  }

  /**
   * 保存或更新歌单续播进度
   *
   * @param playlistId 歌单 ID
   * @param trackUri 当前曲目 URI
   * @param trackFileName 当前曲目文件名
   * @param positionMs 播放进度（毫秒）
   * @param trackOrderSignature 曲目顺序签名
   */
  public saveResume(playlistId: number, trackUri: string, trackFileName: string, positionMs: number,
    trackOrderSignature: string): void {
    if (playlistId < 0 || trackUri.length === 0 || trackOrderSignature.length === 0) {
      return;
    }
    if (this.preferenceInstance === null) {
      HiLog.w(TAG, `saveResume skipped pref not ready playlistId=${playlistId}`);
      return;
    }
    const safeMs = positionMs > 0 ? positionMs : 0;
    const state: PlaylistPlaybackResumeState = {
      playlistId: playlistId,
      trackUri: trackUri,
      trackFileName: trackFileName,
      positionMs: safeMs,
      savedAt: Date.now(),
      trackOrderSignature: trackOrderSignature
    };
    this.memoryCache.set(playlistId, state);
    this.persistResumeMap();
    HiLog.i(TAG, `saveResume playlistId=${playlistId} file=${trackFileName} ms=${safeMs}`);
    this.notifyChange(playlistId);
  }

  /**
   * 用户点击 X：清除指定歌单续播记忆
   *
   * @param playlistId 歌单 ID
   */
  public removeByPlaylistId(playlistId: number): void {
    if (playlistId < 0) {
      return;
    }
    if (!this.memoryCache.has(playlistId)) {
      return;
    }
    this.memoryCache.delete(playlistId);
    this.persistResumeMap();
    HiLog.i(TAG, `removeByPlaylistId playlistId=${playlistId}`);
    this.notifyChange(playlistId);
  }

  private notifyChange(playlistId: number): void {
    for (let i = 0; i < this.changeListeners.length; i++) {
      try {
        this.changeListeners[i](playlistId);
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        HiLog.e(TAG, `notifyChange listener failed message=${message}`);
      }
    }
  }

  private loadPreference(): void {
    if (this.context === null) {
      HiLog.w(TAG, 'loadPreference skipped context null');
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

  private readResumeMapFromPref(): Map<number, PlaylistPlaybackResumeState> {
    const map: Map<number, PlaylistPlaybackResumeState> = new Map();
    if (this.preferenceInstance === null) {
      return map;
    }
    try {
      const raw = this.preferenceInstance.getSync(PREF_KEY_RESUME_MAP, '{}') as string;
      if (raw.length <= 2) {
        return map;
      }
      const parsed = JSON.parse(raw) as Record<string, PlaylistPlaybackResumeState>;
      const keys = Object.keys(parsed);
      for (let i = 0; i < keys.length; i++) {
        const key = keys[i];
        const state = parsed[key];
        if (state !== undefined && typeof state.playlistId === 'number') {
          map.set(state.playlistId, state);
        }
      }
      return map;
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      HiLog.e(TAG, `readResumeMapFromPref failed message=${message}`);
      return map;
    }
  }

  private persistResumeMap(): void {
    if (this.preferenceInstance === null) {
      HiLog.w(TAG, 'persistResumeMap skipped preference null');
      return;
    }
    try {
      const record: Record<string, PlaylistPlaybackResumeState> = {};
      this.memoryCache.forEach((state: PlaylistPlaybackResumeState, playlistId: number) => {
        record[String(playlistId)] = state;
      });
      this.preferenceInstance.putSync(PREF_KEY_RESUME_MAP, JSON.stringify(record));
      this.preferenceInstance.flushSync();
      HiLog.i(TAG, `persistResumeMap count=${this.memoryCache.size}`);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      HiLog.e(TAG, `persistResumeMap failed message=${message}`);
    }
  }
}
