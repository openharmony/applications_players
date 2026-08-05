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


import FileInfo from '../../model/FileInfo';
import { PlaybackMediaKind } from '../../player/PlaybackQueueManager';

/** 历史播放单曲条目（最近点播） */
export interface PlaybackHistoryTrackItem {
  uri: string;
  fileName: string;
  mimeType: string;
  /** 文件大小（字节），列表下行展示 */
  fileSize?: number;
  /** 分辨率宽高，有则展示「大小 · 宽×高」 */
  picWidth?: number;
  picHeight?: number;
}

/** @deprecated 旧版历史歌单快照类型，保留导出兼容 */
export interface PlaybackHistoryPlaylist {
  id: string;
  name: string;
  sourceName: string;
  savedAt: number;
  mediaKind?: PlaybackMediaKind;
  tracks: PlaybackHistoryTrackItem[];
}

/** 从历史恢复播放：由产品层实现 setQueue + 打开对应播放器 */
export type PlaybackHistoryRestoreCallback = (
  tracks: FileInfo[],
  startUri: string,
  sourceName: string,
  mediaKind: PlaybackMediaKind
) => void;
