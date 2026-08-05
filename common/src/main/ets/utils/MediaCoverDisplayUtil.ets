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


import FileInfo from '../model/FileInfo';
import { ThumbnailConfig } from '../thumbnail/ThumbnailConfig';

import { AppThemeConstants } from '../constants/ui/AppThemeConstants';

/** 与首页 MediaGridItem 一致的音频封面/占位展示逻辑（基于 entity/FileInfo） */
export class MediaCoverDisplayUtil {
  static readonly AUDIO_PLACEHOLDER_BG: Resource = AppThemeConstants.AUDIO_THUMB_BACKGROUND;
  static readonly PLACEHOLDER_ICON_OPACITY: number = 0.4;
  static readonly PLAYER_PLACEHOLDER_ICON_SIZE: number = 72;

  static isAudio(fileInfo: FileInfo): boolean {
    return fileInfo.mimeType.startsWith('audio/');
  }

  /** 读取封面 URI（音频 coverUri，视频 thumbUri），与 MediaItemDisplayUtil 一致 */
  static getStoredCoverUri(fileInfo: FileInfo): string {
    if (MediaCoverDisplayUtil.isAudio(fileInfo)) {
      const coverUri = fileInfo.coverUri;
      return coverUri.length > 0 ? coverUri : '';
    }
    const thumbUri = fileInfo.thumbUri;
    return thumbUri.length > 0 ? thumbUri : '';
  }

  static hasStoredCover(fileInfo: FileInfo): boolean {
    return MediaCoverDisplayUtil.getStoredCoverUri(fileInfo).length > 0;
  }

  static getAudioPlaceholderIcon(): Resource {
    return $r('app.media.ic_normal_music');
  }

  static buildCoverUri(fileInfo: FileInfo, baseUri: string): string {
    if (!baseUri.startsWith('media://') && !baseUri.startsWith('file://')) {
      return baseUri;
    }
    if (baseUri.startsWith('media://') && baseUri.includes('oper=astc')) {
      return baseUri;
    }
    const timestamp = fileInfo.timesStampApp || Date.now();
    const modifiedMs = fileInfo.thumbnailModifiledMs || 0;
    const path = fileInfo.mediaPath.length > 0 ? fileInfo.mediaPath : fileInfo.filePath;
    const isVideo = !MediaCoverDisplayUtil.isAudio(fileInfo);
    const width = isVideo ? ThumbnailConfig.VIDEO_THUMB_WIDTH : 0;
    const height = isVideo ? ThumbnailConfig.VIDEO_THUMB_HEIGHT : 0;
    const query = `timestampApp=${timestamp}&thumbnailModifiledMs=${modifiedMs}&oper=astc&width=${width}&height=${height}&path=${encodeURIComponent(path)}`;
    const separator = baseUri.includes('?') ? '&' : '?';
    return `${baseUri}${separator}${query}`;
  }

  static getAudioCoverUri(fileInfo: FileInfo): string {
    const storedUri = MediaCoverDisplayUtil.getStoredCoverUri(fileInfo);
    if (storedUri.length === 0) {
      return '';
    }
    return MediaCoverDisplayUtil.buildCoverUri(fileInfo, storedUri);
  }
}
