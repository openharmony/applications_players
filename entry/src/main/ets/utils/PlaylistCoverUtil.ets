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


import { common } from '@kit.AbilityKit';
import FileInfo from '@ohos/common/src/main/ets/model/FileInfo';
import { FileInfo as FileOperateFileInfo } from '@ohos/common/src/main/ets/utils/FileOperateInfo';
import { HiLog } from '@ohos/common/src/main/ets/utils/HiLog';
import { ThumbnailManager } from '@ohos/common/src/main/ets/thumbnail/ThumbnailManager';
import { SystemCache } from '@ohos/common/src/main/ets/thumbnail/SystemCache';
import { MediaItemDisplayUtil } from '@ohos/common/src/main/ets/utils/MediaItemDisplayUtil';
import { MediaAggregateViewModel } from '@ohos/media/src/main/ets/manager/MediaAggregateViewModel';

const TAG = 'PlaylistCoverUtil';

/**
 * 歌单封面解析：优先内存扫描结果，其次系统 media:// 缩略图，最后 ThumbnailManager
 */
export class PlaylistCoverUtil {
  /**
   * 同步合并内存缓存与系统 media:// 封面（列表展示用，不触发生成）
   *
   * @param track 待补全封面的音频文件
   */
  public static applyAvailableCovers(track: FileInfo): void {
    PlaylistCoverUtil.applyInMemoryCover(track);
    if (!MediaItemDisplayUtil.hasCustomThumbnail(track)) {
      PlaylistCoverUtil.applySystemCover(track);
    }
  }

  /**
   * 将首曲 FileInfo 解析为可用于 Image.src 的封面 URI
   *
   * @param track 首曲文件信息
   * @param context 用于缩略图生成（可为 null，则跳过生成）
   * @returns 封面 URI，无封面时返回空串
   */
  public static async resolveCoverUri(track: FileInfo, context: common.Context | null): Promise<string> {
    PlaylistCoverUtil.applyAvailableCovers(track);
    if (!MediaItemDisplayUtil.hasCustomThumbnail(track) && context !== null) {
      await PlaylistCoverUtil.tryGenerateCover(track, context);
    }
    const thumb: string | Resource = MediaItemDisplayUtil.getThumbnail(track);
    if (typeof thumb === 'string' && thumb.length > 0) {
      return thumb;
    }
    HiLog.i(TAG, `resolveCoverUri empty fileName=${track.fileName}`);
    return '';
  }

  /** 从首页媒体列表合并已扫描的封面字段 */
  private static applyInMemoryCover(track: FileInfo): void {
    const cached = MediaAggregateViewModel.getInstance().findMediaByUri(track.uri);
    if (cached === undefined) {
      return;
    }
    if (cached.coverUri.length > 0) {
      track.coverUri = cached.coverUri;
    }
    if (cached.thumbUri.length > 0) {
      track.thumbUri = cached.thumbUri;
    }
    if (cached.thumbGenerated) {
      track.thumbGenerated = cached.thumbGenerated;
    }
    if (cached.timesStampApp > 0) {
      track.timesStampApp = cached.timesStampApp;
    }
    if (cached.thumbnailModifiledMs > 0) {
      track.thumbnailModifiledMs = cached.thumbnailModifiledMs;
    }
    if (cached.filePath.length > 0) {
      track.filePath = cached.filePath;
    }
    if (cached.mediaPath.length > 0) {
      track.mediaPath = cached.mediaPath;
    }
  }

  /** 系统媒体库 URI 直接拼装缩略图地址 */
  private static applySystemCover(track: FileInfo): void {
    if (!SystemCache.isMediaLibraryFile(track.uri)) {
      return;
    }
    const operateInfo = PlaylistCoverUtil.toOperateFileInfo(track);
    const systemUri = SystemCache.getThumbnailUri(operateInfo);
    if (systemUri.length > 0) {
      track.coverUri = systemUri;
      track.thumbUri = systemUri;
    }
  }

  /** 尝试通过 ThumbnailManager 生成/读取封面 */
  private static async tryGenerateCover(track: FileInfo, context: common.Context): Promise<void> {
    try {
      const operateInfo = PlaylistCoverUtil.toOperateFileInfo(track);
      const generated = await ThumbnailManager.getInstance(context).generateThumbnail(operateInfo);
      if (generated.length > 0) {
        track.coverUri = generated;
        track.thumbUri = generated;
        track.thumbGenerated = true;
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      HiLog.w(TAG, `tryGenerateCover failed fileName=${track.fileName} message=${message}`);
    }
  }

  /** entity FileInfo → fileoperate FileInfo（缩略图模块入参） */
  private static toOperateFileInfo(track: FileInfo): FileOperateFileInfo {
    const operateInfo = new FileOperateFileInfo();
    operateInfo.uri = track.uri;
    operateInfo.fileName = track.fileName;
    operateInfo.mimeType = track.mimeType;
    operateInfo.coverUri = track.coverUri;
    operateInfo.thumbUri = track.thumbUri;
    operateInfo.thumbGenerated = track.thumbGenerated;
    operateInfo.path = track.filePath.length > 0 ? track.filePath : track.mediaPath;
    operateInfo.timesStampApp = track.timesStampApp;
    operateInfo.thumbnailModifiledMs = track.thumbnailModifiledMs;
    operateInfo.mtime = track.updateTime;
    operateInfo.size = track.fileSize;
    return operateInfo;
  }
}
