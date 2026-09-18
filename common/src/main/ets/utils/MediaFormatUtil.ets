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
   * 按 AMR-NB 最低码率估算时长上限（毫秒）。
   * AMR 常无可靠 duration 索引，ffmpeg 按码率估算可能严重偏长；用最小帧长给出保守上限，
   * 供判断 demuxer 时长是否虚高。
   *
   * @param fileSizeBytes 文件字节数
   * @returns 估算上限毫秒；无法估算时返回 0
   */
  static estimateAmrDurationUpperBoundMs(fileSizeBytes: number): number {
    if (fileSizeBytes <= 0) {
      return 0;
    }
    // "#!AMR\n" 头约 6 字节；AMR-NB 帧 20ms，mode0 最小约 13 字节/帧
    const payload = Math.max(0, fileSizeBytes - 6);
    const amrNbFrameMs = 20;
    const amrNbMinFrameBytes = 13;
    return Math.floor(payload / amrNbMinFrameBytes) * amrNbFrameMs;
  }

  /**
   * 按 AMR-NB 常用通话码率（mode7 / 12.2kbps，约 32 字节/帧）估算时长。
   * demuxer 虚高时用该值做进度/seek，比上限更接近真机录音；若实际更长，播放中会随 timeUpdate 拉长。
   */
  static estimateAmrDurationTypicalMs(fileSizeBytes: number): number {
    if (fileSizeBytes <= 0) {
      return 0;
    }
    const payload = Math.max(0, fileSizeBytes - 6);
    const amrNbFrameMs = 20;
    const amrNbMode7FrameBytes = 32;
    return Math.floor(payload / amrNbMode7FrameBytes) * amrNbFrameMs;
  }

  /** 是否为 AMR 音频文件名 */
  static isAmrFileName(fileName: string): boolean {
    if (!fileName || fileName.length === 0) {
      return false;
    }
    const lower = fileName.toLowerCase();
    return lower.endsWith('.amr');
  }

  /**
   * 是否为 AMR 音源：同时看文件名与 URI/路径（列表展示名可能无扩展名）。
   */
  static isAmrMedia(fileName: string, uri: string, path: string = ''): boolean {
    if (MediaFormatUtil.isAmrFileName(fileName)) {
      return true;
    }
    if (uri && uri.toLowerCase().includes('.amr')) {
      return true;
    }
    if (path && path.toLowerCase().endsWith('.amr')) {
      return true;
    }
    return false;
  }

  /** 是否为 mp3 音频文件名 */
  static isMp3FileName(fileName: string): boolean {
    if (!fileName || fileName.length === 0) {
      return false;
    }
    const lower = fileName.toLowerCase();
    return lower.endsWith('.mp3');
  }

  /**
   * 是否为 mp3 音源：同时看文件名与 URI/路径（列表展示名可能无扩展名）。
   */
  static isMp3Media(fileName: string, uri: string, path: string = ''): boolean {
    if (MediaFormatUtil.isMp3FileName(fileName)) {
      return true;
    }
    if (uri && uri.toLowerCase().includes('.mp3')) {
      return true;
    }
    if (path && path.toLowerCase().endsWith('.mp3')) {
      return true;
    }
    return false;
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
