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
import { MediaViewUiConstants } from '../constants/MediaViewUiConstants';

export class MediaItemDisplayUtil {
  static isAudio(media: FileInfo): boolean {
    return media.mimeType.startsWith('audio/');
  }

  /** 是否已有封面 URI */
  static hasCustomThumbnail(media: FileInfo): boolean {
    return MediaItemDisplayUtil.getStoredUri(media).length > 0;
  }

  /** 首页 1:1 封面区背景色：视频深色、音频浅紫 */
  static getHomeThumbBackgroundColor(media: FileInfo): Resource {
    return MediaItemDisplayUtil.isAudio(media) ?
      MediaViewUiConstants.COLOR_AUDIO_THUMB_BG : MediaViewUiConstants.COLOR_VIDEO_THUMB_BG;
  }


  /**
   * 宫格封面宽高比：首页统一 1:1 方图。
   *
   * @param _media 媒体文件信息（保留参数以兼容调用方）
   * @returns 宽高比
   */
  static getGridCoverAspectRatio(_media: FileInfo): number {
    return MediaViewUiConstants.HOME_GRID_COVER_ASPECT_RATIO;
  }

  /**
   * 宫格封面 objectFit：1:1 容器内音频方图 Contain，视频 16:9 缩略图 Cover 裁切铺满。
   *
   * @param media 媒体文件信息
   * @returns ImageFit 模式
   */
  static getHomeThumbObjectFit(media: FileInfo): ImageFit {
    if (!MediaItemDisplayUtil.hasCustomThumbnail(media)) {
      return ImageFit.Contain;
    }
    return MediaItemDisplayUtil.isAudio(media) ? ImageFit.Contain : ImageFit.Cover;
  }

  /**
   * 无自定义缩略图时的占位图标
   * */
  static getPlaceholderIcon(media: FileInfo): Resource {
    return MediaItemDisplayUtil.isAudio(media) ? $r('app.media.ic_normal_music') : $r('app.media.ic_normal_video');
  }


  static getFormatLabel(media: FileInfo): string {
    const dotIndex: number = media.fileName.lastIndexOf('.');
    if (dotIndex > 0 && dotIndex < media.fileName.length - 1) {
      return media.fileName.substring(dotIndex + 1).toUpperCase();
    }
    return MediaItemDisplayUtil.isAudio(media) ?
      MediaViewUiConstants.DEFAULT_FALLBACK_FORMAT_AUDIO : MediaViewUiConstants.DEFAULT_FALLBACK_FORMAT_VIDEO;
  }


  static getThumbnail(media: FileInfo): string | Resource {
    const storedUri = MediaItemDisplayUtil.getStoredUri(media);
    if (storedUri.length > 0) {
      return MediaItemDisplayUtil.buildThumbnailUri(media, storedUri);
    }
    return MediaItemDisplayUtil.getPlaceholderIcon(media);
  }

  /** 读取封面 URI（音频 coverUri，视频 thumbUri） */
  static getStoredUri(media: FileInfo): string {
    if (MediaItemDisplayUtil.isAudio(media)) {
      return media.coverUri || '';
    }
    return media.thumbUri || '';
  }


  /**
   * 为 Image 组件拼装缩略图 URI；系统 media:// 已带查询参数时用 & 拼接，避免双 ? 导致加载失败
   *
   * @param media 媒体文件信息
   * @param baseUri 原始封面/缩略图 URI
   * @returns 可用于 Image.src 的 URI
   */
  static buildThumbnailUri(media: FileInfo, baseUri: string): string {
    if (!baseUri.startsWith('media://') && !baseUri.startsWith('file://')) {
      return baseUri;
    }
    // 系统媒体库 URI 在扫描阶段已由 SystemCache 附加完整查询串，直接复用
    if (baseUri.startsWith('media://') && baseUri.includes('oper=astc')) {
      return baseUri;
    }
    const timestamp: number = media.timesStampApp || Date.now();
    const modifiedMs: number = media.thumbnailModifiledMs || 0;
    const path: string = media.mediaPath || media.filePath || '';
    const isVideo: boolean = !MediaItemDisplayUtil.isAudio(media);
    const width: number = isVideo ? ThumbnailConfig.VIDEO_THUMB_WIDTH : 0;
    const height: number = isVideo ? ThumbnailConfig.VIDEO_THUMB_HEIGHT : 0;
    const query = `timestampApp=${timestamp}&thumbnailModifiledMs=${modifiedMs}&oper=astc&width=${width}&height=${height}&path=${encodeURIComponent(path)}`;
    const separator = baseUri.includes('?') ? '&' : '?';
    return `${baseUri}${separator}${query}`;
  }
}
