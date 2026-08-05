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


import media from '@ohos.multimedia.media';
import { HiLog } from './HiLog';
import { FileInfo } from '../utils/FileOperateInfo';
import { SupportedMediaFormats } from '../constants/media/SupportedMediaFormats';
import { MediaPlaybackFileOpener } from './MediaPlaybackFileOpener';

const TAG = 'MediaMetadataResolver';

/**
 * 统一 AVMetadata 解析：扫描、Picker 导入、文件监听补全 duration 均走此入口。
 * 全项目 duration 单位为毫秒（与 UserFileScanner / MediaFormatUtil 一致）。
 */
export class MediaMetadataResolver {
  static async fillDuration(fileInfo: FileInfo): Promise<void> {
    if (fileInfo.duration > 0) {
      return;
    }

    const isVideo = SupportedMediaFormats.isSupportedVideo(fileInfo.fileName);
    const opened = await MediaPlaybackFileOpener.openReadOnly(fileInfo.uri, fileInfo.fileName);
    if (opened) {
      try {
        if (fileInfo.size <= 0 && opened.size > 0) {
          fileInfo.size = opened.size;
        }
        const filled = await MediaMetadataResolver.extractViaFd(opened.fd, opened.size, isVideo);
        if (filled > 0) {
          fileInfo.duration = filled;
          HiLog.i(TAG, `fillDuration fd fileName=${fileInfo.fileName} duration=${filled}`);
          return;
        }
      } finally {
        await opened.release();
      }
    }

    const urlFilled = await MediaMetadataResolver.extractViaUrl(fileInfo.uri, isVideo);
    if (urlFilled > 0) {
      fileInfo.duration = urlFilled;
      HiLog.i(TAG, `fillDuration url fileName=${fileInfo.fileName} duration=${urlFilled}`);
      return;
    }

    HiLog.w(TAG, `fillDuration failed to get duration: ${fileInfo.fileName}`);
  }

  static applyAvMetadataToFileInfo(fileInfo: FileInfo, metadata: media.AVMetadata): void {
    const isVideo = SupportedMediaFormats.isSupportedVideo(fileInfo.fileName);
    const durationMs = MediaMetadataResolver.parseDurationMs(metadata, isVideo);
    if (durationMs > 0) {
      fileInfo.duration = durationMs;
    }

    if (!isVideo) {
      return;
    }

    const width = metadata.videoWidth;
    if (width && width.length > 0) {
      fileInfo.picWidth = Number(width[0]);
    }
    const height = metadata.videoHeight;
    if (height && height.length > 0) {
      fileInfo.picHeight = Number(height[0]);
    }
  }

  /**
   * 解析 AVMetadata.duration 为毫秒。
   * 视频字段在 fdSrc 场景下可能返回 string 而非 string[]，对 string 使用 [0] 会误取首字符。
   */
  static parseDurationMs(metadata: media.AVMetadata, isVideo: boolean): number {
    const raw = metadata.duration;
    if (raw === undefined || raw === null) {
      return 0;
    }
    if (isVideo) {
      return MediaMetadataResolver.parseVideoDuration(raw);
    }
    return Number(raw as string);
  }

  private static parseVideoDuration(raw: string | string[]): number {
    if (Array.isArray(raw)) {
      if (raw.length === 0) {
        return 0;
      }
      return Number(raw[0]);
    }
    const text = raw as string;
    if (text.length === 0) {
      return 0;
    }
    return Number(text);
  }

  private static async extractViaFd(fd: number, size: number, isVideo: boolean): Promise<number> {
    let extractor: media.AVMetadataExtractor | undefined = undefined;
    try {
      extractor = await media.createAVMetadataExtractor();
      const fdSrc: media.AVFileDescriptor = {
        fd: fd,
        offset: 0,
        length: size
      };
      extractor.fdSrc = fdSrc;
      const metadata = await extractor.fetchMetadata();
      if (!metadata) {
        return 0;
      }
      return MediaMetadataResolver.parseDurationMs(metadata, isVideo);
    } catch (error) {
      HiLog.w(TAG, `extractViaFd failed: ${error}`);
      return 0;
    } finally {
      if (extractor) {
        await extractor.release();
      }
    }
  }

  private static async extractViaUrl(uri: string, isVideo: boolean): Promise<number> {
    let extractor: media.AVMetadataExtractor | undefined = undefined;
    try {
      extractor = await media.createAVMetadataExtractor();
      extractor.setUrlSource(uri);
      const metadata = await extractor.fetchMetadata();
      if (!metadata) {
        return 0;
      }
      return MediaMetadataResolver.parseDurationMs(metadata, isVideo);
    } catch (error) {
      HiLog.w(TAG, `extractViaUrl failed uri=${uri}: ${error}`);
      return 0;
    } finally {
      if (extractor) {
        await extractor.release();
      }
    }
  }
}
