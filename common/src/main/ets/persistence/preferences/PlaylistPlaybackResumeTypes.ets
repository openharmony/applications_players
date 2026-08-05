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


/** 歌单续播快照变更监听（playlistId） */
export type PlaylistPlaybackResumeChangeListener = (playlistId: number) => void;

/** 歌单续播快照（仅音频歌单，视频不记忆进度） */
export interface PlaylistPlaybackResumeState {
  playlistId: number;
  trackUri: string;
  trackFileName: string;
  positionMs: number;
  savedAt: number;
  /** 歌单曲目 URI 顺序签名，用于校验歌单是否被编辑 */
  trackOrderSignature: string;
}

/** 音频起播可选参数：歌单来源与续播进度 */
export interface PlayAudioLaunchOptions {
  startPositionMs?: number;
  sourcePlaylistId?: number;
  /** 直接展示迷你播放条，不打开全屏页 */
  startMinimized?: boolean;
  /** prepared 后 seek 到进度但保持暂停 */
  startPaused?: boolean;
}
