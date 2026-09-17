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
import { HiLog } from './HiLog';
import { MediaFormatUtil } from './MediaFormatUtil';
import { MediaPlaybackFileOpener, MediaPlaybackOpenResult } from './MediaPlaybackFileOpener';
import { FileInfo } from './FileOperateInfo';

const TAG = 'Mp3DurationScanner';

/** 每次顺序读取的块大小（Layer III 单帧最大约 2.9KB，远小于块，读一次即可覆盖任意帧头） */
const READ_CHUNK_BYTES: number = 64 * 1024;
/** 首个帧同步字的最远搜索距离（ID3v2 之后允许少量前导杂音） */
const MAX_FIRST_FRAME_SEARCH_BYTES: number = 4096;
/** 帧边界失步后的重同步上限 */
const MAX_RESYNC_BYTES: number = 512;
/** 帧数防御上限（约 100 小时 44.1kHz 音频），防止异常文件死循环 */
const MAX_FRAMES: number = 50000000;
/** Xing/Info 头 flags 的 frames 位 */
const XING_FLAG_FRAMES: number = 0x01;
/** MPEG 版本位取值（(b1 >> 3) & 0x03），3=MPEG1 */
const MPEG_VERSION_1: number = 3;
/** Layer 位取值（(b1 >> 1) & 0x03），mp3 只处理 Layer III */
const MPEG_LAYER_3: number = 1;
/** 尾部允许的结算容差：失步位置距文件尾不超过该值时按已累计帧数结算（ID3v1 等尾随数据） */
const TAIL_TOLERANCE_BYTES: number = 1024;

/** 解析后的 MPEG Layer III 帧头信息 */
class Mp3FrameHeader {
  public frameLen: number;
  public sampleRate: number;
  public samplesPerFrame: number;
  public channelMode: number;
  public isMpeg1: boolean;

  constructor(frameLen: number, sampleRate: number, samplesPerFrame: number,
    channelMode: number, isMpeg1: boolean) {
    this.frameLen = frameLen;
    this.sampleRate = sampleRate;
    this.samplesPerFrame = samplesPerFrame;
    this.channelMode = channelMode;
    this.isMpeg1 = isMpeg1;
  }
}

/**
 * mp3 精确时长扫描：跳过 ID3v2 后逐帧遍历 MPEG Layer III 帧头，
 * 按"帧数 × 每帧采样数 / 采样率"得到真实时长。
 *
 * 背景：无 Xing/Info 头的 VBR 文件，demuxer 只能按首帧码率×文件大小估算，
 * 首帧码率高于全曲平均码率时估算明显偏短（进度条到顶而音频未播完）。
 * 有 Xing 头时直接采用其帧数字段，避免全文件遍历。
 *
 * 扫描使用独立打开的 fd（openReadOnly 每次都是全新文件描述），
 * 不与 AVPlayer / AVMetadataExtractor 共享文件偏移。
 */
export class Mp3DurationScanner {
  /** Layer III 码率表（kbps），按码率索引：0 为 free，15 非法 */
  private static readonly MPEG1_L3_BITRATES: Array<number> =
    [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320];
  private static readonly MPEG2_L3_BITRATES: Array<number> =
    [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160];
  /** 采样率表，按版本位索引：0=MPEG2.5, 1=保留, 2=MPEG2, 3=MPEG1 */
  private static readonly SAMPLE_RATES: Array<Array<number>> = [
    [11025, 12000, 8000],
    [0, 0, 0],
    [22050, 24000, 16000],
    [44100, 48000, 32000]
  ];

  /** 是否为 mp3 文件（按扩展名） */
  static isMp3File(fileName: string): boolean {
    return MediaFormatUtil.isMp3FileName(fileName);
  }

  /** 是否为 mp3 音源（展示名可能被 ID3 标题覆盖，结合 uri/path 判断） */
  static isMp3FileInfo(fileInfo: FileInfo): boolean {
    return MediaFormatUtil.isMp3Media(fileInfo.fileName, fileInfo.uri, fileInfo.path ?? '');
  }

  /**
   * 扫描 mp3 精确时长（毫秒）。仅处理 .mp3；扫描失败或文件异常时返回 0，
   * 调用方回退到原有 AVMetadataExtractor 估算链路（与原行为一致）。
   * 顺带保留原 fillDuration 链路的 size 兜底副作用（Picker 导入 stat 失败时 size 可能为 0）。
   *
   * @param fileInfo 目标文件信息（打开成功后回填 size，并写入扫描得到的 duration 由调用方负责）
   * @returns 精确时长毫秒数；0 表示无法确定
   */
  static async scanExactDurationMs(fileInfo: FileInfo): Promise<number> {
    const fileName = fileInfo.fileName;
    if (!Mp3DurationScanner.isMp3FileInfo(fileInfo)) {
      return 0;
    }
    const opened: MediaPlaybackOpenResult | null =
      await MediaPlaybackFileOpener.openReadOnly(fileInfo.uri, fileName);
    if (opened === null) {
      HiLog.w(TAG, `scanExactDurationMs open failed fileName=${fileName}`);
      return 0;
    }
    try {
      if (fileInfo.size <= 0 && opened.size > 0) {
        fileInfo.size = opened.size;
      }
      if (opened.size < 16) {
        return 0;
      }
      const duration = Mp3DurationScanner.walkFrames(opened.fd, opened.size, fileName);
      HiLog.i(TAG, `scanExactDurationMs result fileName=${fileName} duration=${duration}`);
      return duration;
    } catch (error) {
      HiLog.w(TAG, `scanExactDurationMs failed fileName=${fileName} error=${error}`);
      return 0;
    } finally {
      await opened.release();
    }
  }

  /**
   * 顺序遍历帧头累计精确时长（同步实现，IO 为分块顺序读）。
   *
   * @param fd 扫描专用只读 fd
   * @param fileSize 文件总字节数
   * @param fileName 显示文件名（日志用）
   * @returns 精确时长毫秒数；0 表示解析不可信
   */
  private static walkFrames(fd: number, fileSize: number, fileName: string): number {
    const bytes = new Uint8Array(READ_CHUNK_BYTES);
    // base: bytes[0] 对应的文件偏移；loaded: bytes 内有效字节数；pos: 下一个待解析字节的绝对文件偏移
    let base = 0;
    let loaded = 0;
    let pos = 0;

    // 保证 [pos, pos+need) 全部在缓冲内；不足则丢弃缓冲，从 pos 处 lseek 后整块读取
    const fill = (need: number): boolean => {
      if (pos + need <= base + loaded) {
        return true;
      }
      if (pos >= fileSize) {
        return false;
      }
      fs.lseek(fd, pos, fs.WhenceType.SEEK_SET);
      const readN: number = fs.readSync(fd, bytes.buffer, { length: READ_CHUNK_BYTES });
      if (readN <= 0) {
        return false;
      }
      base = pos;
      loaded = readN;
      return pos + need <= base + loaded;
    };

    // 跳过 ID3v2 头（synchsafe size）
    if (!fill(10)) {
      return 0;
    }
    if (bytes[0] === 0x49 && bytes[1] === 0x44 && bytes[2] === 0x33) { // 'ID3'
      const tagSize = ((bytes[6] & 0x7F) << 21) | ((bytes[7] & 0x7F) << 14) |
        ((bytes[8] & 0x7F) << 7) | (bytes[9] & 0x7F);
      pos = 10 + tagSize;
      if (pos >= fileSize) {
        return 0;
      }
    }

    // 定位首个可信帧头（允许少量前导杂音，并要求下一帧边界同样合法，防伪同步字）
    let searched = 0;
    let firstHeader: Mp3FrameHeader | null = null;
    while (searched < MAX_FIRST_FRAME_SEARCH_BYTES && pos + 4 < fileSize) {
      if (!fill(4)) {
        return 0;
      }
      const candidate = Mp3DurationScanner.parseFrameHeader(bytes, pos - base);
      if (candidate !== null) {
        const nextAbs = pos + candidate.frameLen;
        const savedPos = pos;
        pos = nextAbs;
        const secondOk = nextAbs + 4 <= fileSize && fill(4) &&
          Mp3DurationScanner.parseFrameHeader(bytes, nextAbs - base) !== null;
        pos = savedPos;
        // fill 可能在 nextAbs 处重填缓冲（base 前移），失效缓冲避免与 pos 错位
        base = 0;
        loaded = 0;
        if (secondOk) {
          firstHeader = candidate;
          break;
        }
      }
      pos++;
      searched++;
    }
    if (firstHeader === null) {
      HiLog.w(TAG, `walkFrames first frame not found fileName=${fileName}`);
      return 0;
    }

    let frames = 0;
    let totalMs = 0;
    let checkedXing = false;
    while (pos < fileSize && frames < MAX_FRAMES) {
      if (!fill(4)) {
        break;
      }
      const header = Mp3DurationScanner.parseFrameHeader(bytes, pos - base);
      if (header === null) {
        // 帧边界失步：向后限幅重同步
        let resyncSteps = 0;
        let found = false;
        while (resyncSteps < MAX_RESYNC_BYTES && pos + 4 < fileSize) {
          pos++;
          resyncSteps++;
          if (!fill(4)) {
            break;
          }
          if (Mp3DurationScanner.parseFrameHeader(bytes, pos - base) !== null) {
            found = true;
            break;
          }
        }
        if (!found) {
          // 中部失步视为不可信，交回调用方走估算回退；仅尾部尾随数据（ID3v1 等）按已累计结算
          if (fileSize - pos > TAIL_TOLERANCE_BYTES) {
            HiLog.w(TAG, `walkFrames resync failed mid-file fileName=${fileName} pos=${pos} frames=${frames}`);
            return 0;
          }
          break;
        }
        continue;
      }
      frames++;
      totalMs += header.samplesPerFrame * 1000 / header.sampleRate;
      if (!checkedXing) {
        checkedXing = true;
        // 首帧后探测 Xing/Info 头（含 4 字节帧头的偏移：MPEG1 单声道 21 / 双声道 36；
        // MPEG2/2.5 单声道 13 / 双声道 21），命中且带有效帧数时免去全文件遍历。
        // base 在 fill 后可能被重置为 pos，此处直接用闭包内最新的 base 计算索引。
        const xingOffset: number = header.isMpeg1 ?
          (header.channelMode === 3 ? 21 : 36) : (header.channelMode === 3 ? 13 : 21);
        const xingNeed: number = 4 + xingOffset + 12;
        if (pos + xingNeed <= fileSize && fill(xingNeed)) {
          const x = pos + 4 + xingOffset - base;
          const isXingTag = bytes[x] === 0x58 && bytes[x + 1] === 0x69 &&
            bytes[x + 2] === 0x6E && bytes[x + 3] === 0x67;
          const isInfoTag = bytes[x] === 0x49 && bytes[x + 1] === 0x6E &&
            bytes[x + 2] === 0x66 && bytes[x + 3] === 0x6F;
          if (isXingTag || isInfoTag) {
            const flags = (bytes[x + 4] << 24) | (bytes[x + 5] << 16) |
              (bytes[x + 6] << 8) | bytes[x + 7];
            if ((flags & XING_FLAG_FRAMES) !== 0) {
              const xingFrames = ((bytes[x + 8] << 24) | (bytes[x + 9] << 16) |
                (bytes[x + 10] << 8) | bytes[x + 11]) >>> 0;
              if (xingFrames > 0 && xingFrames < MAX_FRAMES) {
                HiLog.i(TAG, `walkFrames xing hit fileName=${fileName} frames=${xingFrames} sr=${header.sampleRate}`);
                return Math.round(xingFrames * header.samplesPerFrame * 1000 / header.sampleRate);
              }
            }
          }
        }
      }
      pos += header.frameLen;
    }
    return frames > 0 ? Math.round(totalMs) : 0;
  }

  /**
   * 解析 MPEG Layer III 帧头。同步字/版本/层/码率/采样率任一非法即返回 null。
   *
   * @param bytes 含帧头 4 字节的缓冲
   * @param idx 帧头在缓冲内的偏移
   * @returns 帧头信息；非法帧返回 null
   */
  private static parseFrameHeader(bytes: Uint8Array, idx: number): Mp3FrameHeader | null {
    const b0: number = bytes[idx];
    const b1: number = bytes[idx + 1];
    const b2: number = bytes[idx + 2];
    const b3: number = bytes[idx + 3];
    if (b0 !== 0xFF || (b1 & 0xE0) !== 0xE0) {
      return null;
    }
    const versionBits: number = (b1 >> 3) & 0x03;
    if (versionBits === 1) {
      return null;
    }
    const layerBits: number = (b1 >> 1) & 0x03;
    if (layerBits !== MPEG_LAYER_3) {
      return null;
    }
    const bitrateIndex: number = (b2 >> 4) & 0x0F;
    if (bitrateIndex === 0 || bitrateIndex === 15) {
      return null;
    }
    const sampleRateIndex: number = (b2 >> 2) & 0x03;
    if (sampleRateIndex === 3) {
      return null;
    }
    const padding: number = (b2 >> 1) & 0x01;
    const channelMode: number = (b3 >> 6) & 0x03;
    const isMpeg1 = versionBits === MPEG_VERSION_1;
    const sampleRate: number = Mp3DurationScanner.SAMPLE_RATES[versionBits][sampleRateIndex];
    const bitrateKbps: number = isMpeg1 ?
      Mp3DurationScanner.MPEG1_L3_BITRATES[bitrateIndex] : Mp3DurationScanner.MPEG2_L3_BITRATES[bitrateIndex];
    const samplesPerFrame: number = isMpeg1 ? 1152 : 576;
    const frameLen: number = Math.floor(samplesPerFrame * bitrateKbps * 1000 / (8 * sampleRate)) + padding;
    return new Mp3FrameHeader(frameLen, sampleRate, samplesPerFrame, channelMode, isMpeg1);
  }
}
