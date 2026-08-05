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


import { HiLog } from '@ohos/common/src/main/ets/utils/HiLog';
import FileInfo from '@ohos/common/src/main/ets/model/FileInfo';
import {
  PlaybackMediaKind,
  PlaybackQueueManager
} from '@ohos/common/src/main/ets/player/PlaybackQueueManager';

/**
 * 后台播控切歌时由 PlaybackSession 驱动控制器的统一契约
 */
export interface IPlaybackQueueControlTarget {
  getActiveUri(): string;
  switchToTrack(fileInfo: FileInfo): Promise<void>;
  updateAvSessionMetadata(): Promise<void>;
}

/**
 * 音视频播控会话公共逻辑：队列 URI 解析、后台切歌分发（与 AVSession 桥接解耦）
 */
export class PlaybackControlSessionHelper {
  /**
   * 从播放队列缓存或 URI 构造 FileInfo
   *
   * @param uri 媒体 URI
   * @param kind 音频或视频
   * @returns FileInfo
   */
  static resolveQueueFileInfo(uri: string, kind: PlaybackMediaKind): FileInfo {
    const cached = PlaybackQueueManager.getInstance().getTrack(uri);
    if (cached !== null) {
      return cached;
    }
    const slash = uri.lastIndexOf('/');
    const fileName = slash >= 0 ? uri.substring(slash + 1) : uri;
    const mimeType = kind === PlaybackMediaKind.VIDEO ? 'video/*' : 'audio/*';
    return new FileInfo(fileName, uri, mimeType);
  }

  /**
   * 队列曲目变更：驱动目标控制器切源或刷新播控元数据
   *
   * @param logTag 日志 TAG
   * @param uri 当前曲目 URI
   * @param kind 队列媒体类型
   * @param expectedKind 本 Session 关注的媒体类型
   * @param target 播放控制器（未绑定时为 null）
   */
  static handleQueueTrackChange(
    logTag: string,
    uri: string,
    kind: PlaybackMediaKind,
    expectedKind: PlaybackMediaKind,
    target: IPlaybackQueueControlTarget | null
  ): void {
    if (kind !== expectedKind || uri.length === 0 || target === null) {
      return;
    }
    const fileInfo = PlaybackControlSessionHelper.resolveQueueFileInfo(uri, kind);
    const activeUri = target.getActiveUri();
    HiLog.i(logTag, `handleQueueTrackChange uri=${uri} activeUri=${activeUri}`);
    if (activeUri !== fileInfo.uri) {
      HiLog.i(logTag, `handleQueueTrackChange switch uri=${uri}`);
      target.switchToTrack(fileInfo);
      return;
    }
    target.updateAvSessionMetadata();
  }
}
