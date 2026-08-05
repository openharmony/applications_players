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


export class MediaFormatUtil {
  static formatDuration(duration: number): string {
    if (!duration || duration === 0) {
      return '--:--';
    }

    const totalSeconds = Math.floor(duration / 1000);
    const hours = Math.floor(totalSeconds / 3600);
    const minutes = Math.floor((totalSeconds % 3600) / 60);
    const seconds = totalSeconds % 60;

    if (hours > 0) {
      return `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
    }

    return `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
  }

  static formatFileSize(bytes: number): string {
    if (!bytes || bytes === 0) {
      return '0 B';
    }

    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    const index = Math.floor(Math.log(bytes) / Math.log(1024));
    const size = bytes / Math.pow(1024, index);

    return `${size.toFixed(2)} ${units[index]}`;
  }

  /**
   * 与系统文件管理器一致的十进制容量展示（1 KB = 1000 B，1 MB = 1_000_000 B）。
   */
  static formatFileSizeDecimal(bytes: number): string {
    if (!bytes || bytes === 0) {
      return '0 B';
    }
    if (bytes < 1000) {
      return `${bytes} B`;
    }
    if (bytes < 1_000_000) {
      return `${(bytes / 1000).toFixed(2)} KB`;
    }
    if (bytes < 1_000_000_000) {
      return `${(bytes / 1_000_000).toFixed(2)} MB`;
    }
    return `${(bytes / 1_000_000_000).toFixed(2)} GB`;
  }

  static formatBitrate(bitrate: number): string {
    if (!bitrate || bitrate === 0) {
      return '-- kbps';
    }

    return `${Math.round(bitrate / 1000)} kbps`;
  }

  /**
   * 标准分辨率档位文案（360P / 480P / 720P / 1080P / 2K / 4K / 8K）。
   * 按短边优先、长边兜底判定，兼容横竖屏。
   *
   * @param width 像素宽
   * @param height 像素高
   * @returns 标准分辨率；无法识别时返回空串
   */
  static formatStandardResolution(width: number, height: number): string {
    const w: number = width > 0 ? width : 0;
    const h: number = height > 0 ? height : 0;
    if (w <= 0 && h <= 0) {
      return '';
    }
    const shortSide: number = (w > 0 && h > 0) ? Math.min(w, h) : (w > 0 ? w : h);
    const longSide: number = Math.max(w, h);

    if (shortSide >= 4320 || longSide >= 7680) {
      return '8K';
    }
    if (shortSide >= 2160 || longSide >= 3840) {
      return '4K';
    }
    if (shortSide >= 1440 || longSide >= 2560) {
      return '2K';
    }
    if (shortSide >= 1080 || longSide >= 1920) {
      return '1080P';
    }
    if (shortSide >= 720 || longSide >= 1280) {
      return '720P';
    }
    if (shortSide >= 480 || longSide >= 854) {
      return '480P';
    }
    if (shortSide >= 360 || longSide >= 640) {
      return '360P';
    }
    return '';
  }
}
