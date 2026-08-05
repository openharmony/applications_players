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

import fs from '@ohos.file.fs';

/** 魔数签名匹配规则 */
interface MagicPattern {
  offset: number;
  bytes: number[];
}

/** 播放器支持的扫描/导入媒体格式（单一来源） */
export class SupportedMediaFormats {
  static readonly AUDIO_SUFFIXES: string[] = ['.m4a', '.aac', '.mp3', '.ogg', '.wav', '.amr'];
  static readonly VIDEO_SUFFIXES: string[] = ['.mp4', '.mkv', '.ts'];

  /** 已知媒体文件的魔数签名（前 12 字节匹配规则） */
  private static readonly MAGIC_PATTERNS: MagicPattern[] = [
    // MP3: ID3 tag
    { offset: 0, bytes: [0x49, 0x44, 0x33] },
    // MP3: MPEG sync (11-bit)
    { offset: 0, bytes: [0xFF, 0xFB] },
    { offset: 0, bytes: [0xFF, 0xF3] },
    { offset: 0, bytes: [0xFF, 0xF2] },
    // AAC: ADTS sync
    { offset: 0, bytes: [0xFF, 0xF1] },
    { offset: 0, bytes: [0xFF, 0xF9] },
    // MP4/M4A: ftyp box
    { offset: 4, bytes: [0x66, 0x74, 0x79, 0x70] },
    // OGG: OggS
    { offset: 0, bytes: [0x4F, 0x67, 0x67, 0x53] },
    // WAV: RIFF
    { offset: 0, bytes: [0x52, 0x49, 0x46, 0x46] },
    // MKV: EBML
    { offset: 0, bytes: [0x1A, 0x45, 0xDF, 0xA3] },
    // TS: sync byte
    { offset: 0, bytes: [0x47] },
    // FLAC: fLaC
    { offset: 0, bytes: [0x66, 0x4C, 0x61, 0x43] },
  ];

  static getAllSuffixes(): string[] {
    return [...SupportedMediaFormats.AUDIO_SUFFIXES, ...SupportedMediaFormats.VIDEO_SUFFIXES];
  }

  static getFileSuffix(fileName: string): string {
    const lower = fileName.toLowerCase();
    const dotIndex = lower.lastIndexOf('.');
    if (dotIndex < 0) {
      return '';
    }
    return lower.substring(dotIndex);
  }

  static isSupportedAudio(fileName: string): boolean {
    const suffix = SupportedMediaFormats.getFileSuffix(fileName);
    return SupportedMediaFormats.AUDIO_SUFFIXES.includes(suffix);
  }

  static isSupportedVideo(fileName: string): boolean {
    const suffix = SupportedMediaFormats.getFileSuffix(fileName);
    return SupportedMediaFormats.VIDEO_SUFFIXES.includes(suffix);
  }

  static isSupportedMedia(fileName: string): boolean {
    return SupportedMediaFormats.isSupportedAudio(fileName) ||
      SupportedMediaFormats.isSupportedVideo(fileName);
  }

  /**
   * 读文件头魔数校验是否为合法媒体文件。
   * 用于拦截扩展名正确但内容非音视频的"伪文件"（如 .txt 改名为 .mp3）。
   *
   * @param filePath 文件路径或 URI
   * @returns 是否为合法媒体文件
   */
  static isValidMediaByHeader(filePath: string): boolean {
    try {
      const mediaFile: fs.File = fs.openSync(filePath, fs.OpenMode.READ_ONLY);
      const buffer = new ArrayBuffer(12);
      const bytesRead = fs.readSync(mediaFile.fd, buffer);
      fs.closeSync(mediaFile.fd);
      if (bytesRead < 4) {
        return false;
      }
      return SupportedMediaFormats.matchMediaHeader(new Uint8Array(buffer));
    } catch (_) {
      return false;
    }
  }

  private static matchMediaHeader(bytes: Uint8Array): boolean {
    for (const pattern of SupportedMediaFormats.MAGIC_PATTERNS) {
      if (bytes.length < pattern.offset + pattern.bytes.length) {
        continue;
      }
      let match = true;
      for (let i = 0; i < pattern.bytes.length; i++) {
        if (bytes[pattern.offset + i] !== pattern.bytes[i]) {
          match = false;
          break;
        }
      }
      if (match) {
        return true;
      }
    }
    return false;
  }
}
