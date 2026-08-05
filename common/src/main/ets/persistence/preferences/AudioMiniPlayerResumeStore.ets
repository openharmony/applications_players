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

const TAG = 'AudioMiniPlayerResumeStore';
const PREF_FILE_NAME = 'audio_mini_player_resume_pref';
const PREF_KEY_SNAPSHOT = 'mini_player_snapshot';

/** 迷你播放条会话曲目 */
export interface AudioMiniPlayerResumeTrack {
  uri: string;
  fileName: string;
  mimeType: string;
  coverUri: string;
}

/** 迷你播放条冷启动恢复快照 */
export interface AudioMiniPlayerResumeSnapshot {
  trackUri: string;
  positionMs: number;
  sourceName: string;
  sourcePlaylistId: number;
  tracks: AudioMiniPlayerResumeTrack[];
  savedAt: number;
}

/**
 * 迷你播放条会话持久化：杀进程后恢复底部播放条、队列与进度（一律暂停）
 */
export class AudioMiniPlayerResumeStore {
  private static instance: AudioMiniPlayerResumeStore | null = null;
  private preferenceInstance: preferences.Preferences | null = null;
  private context: common.UIAbilityContext | null = null;
  private cachedSnapshot: AudioMiniPlayerResumeSnapshot | null = null;

  private constructor() {
  }

  public static getInstance(): AudioMiniPlayerResumeStore {
    if (AudioMiniPlayerResumeStore.instance === null) {
      AudioMiniPlayerResumeStore.instance = new AudioMiniPlayerResumeStore();
    }
    return AudioMiniPlayerResumeStore.instance;
  }

  public init(context: common.UIAbilityContext): void {
    this.context = context;
    if (this.preferenceInstance === null) {
      this.loadPreference();
    }
    this.cachedSnapshot = this.readSnapshotFromPref();
    HiLog.i(TAG, `init hasSnapshot=${this.cachedSnapshot !== null}`);
  }

  public save(snapshot: AudioMiniPlayerResumeSnapshot): void {
    this.cachedSnapshot = snapshot;
    this.persistSnapshot();
    HiLog.i(TAG, `save uri=${snapshot.trackUri} ms=${snapshot.positionMs} tracks=${snapshot.tracks.length}`);
  }

  public load(): AudioMiniPlayerResumeSnapshot | null {
    if (this.cachedSnapshot !== null) {
      return this.cachedSnapshot;
    }
    this.cachedSnapshot = this.readSnapshotFromPref();
    return this.cachedSnapshot;
  }

  public clear(): void {
    this.cachedSnapshot = null;
    if (this.preferenceInstance === null && this.context !== null) {
      this.loadPreference();
    }
    if (this.preferenceInstance === null) {
      return;
    }
    try {
      this.preferenceInstance.delete(PREF_KEY_SNAPSHOT);
      this.preferenceInstance.flush();
      HiLog.i(TAG, 'clear snapshot');
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      HiLog.e(TAG, `clear failed message=${message}`);
    }
  }

  private loadPreference(): void {
    if (this.context === null) {
      return;
    }
    try {
      this.preferenceInstance = preferences.getPreferencesSync(this.context, { name: PREF_FILE_NAME });
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      HiLog.e(TAG, `loadPreference failed message=${message}`);
    }
  }

  private readSnapshotFromPref(): AudioMiniPlayerResumeSnapshot | null {
    if (this.preferenceInstance === null) {
      return null;
    }
    try {
      const raw = this.preferenceInstance.getSync(PREF_KEY_SNAPSHOT, '') as string;
      if (raw.length === 0) {
        return null;
      }
      const parsed = JSON.parse(raw) as AudioMiniPlayerResumeSnapshot;
      if (parsed.trackUri === undefined || parsed.trackUri.length === 0) {
        return null;
      }
      return parsed;
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      HiLog.e(TAG, `readSnapshotFromPref failed message=${message}`);
      return null;
    }
  }

  private persistSnapshot(): void {
    if (this.preferenceInstance === null || this.cachedSnapshot === null) {
      HiLog.w(TAG, 'persistSnapshot skipped preference or snapshot null');
      return;
    }
    try {
      this.preferenceInstance.putSync(PREF_KEY_SNAPSHOT, JSON.stringify(this.cachedSnapshot));
      this.preferenceInstance.flush();
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      HiLog.e(TAG, `persistSnapshot failed message=${message}`);
    }
  }
}
