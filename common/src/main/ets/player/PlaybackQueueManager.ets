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
import { HiLog } from '../utils/HiLog';
import fs from '@ohos.file.fs';
import fileuri from '@ohos.file.fileuri';

const TAG = 'PlaybackQueueManager';

export enum PlaybackMediaKind {
  AUDIO = 'audio',
  VIDEO = 'video'
}

export type PlaybackTrackChangeListener = (uri: string, kind: PlaybackMediaKind) => void;

export type PlaybackQueueChangeListener = () => void;

/** 播放队列展示项（供半模态列表绑定） */
export interface PlaybackQueueEntry {
  index: number;
  uri: string;
  fileName: string;
  mimeType: string;
  isCurrent: boolean;
  /** 文件大小（字节），列表副标题 */
  fileSize?: number;
  /** 视频宽，用于分辨率文案 */
  picWidth?: number;
  /** 视频高，用于分辨率文案 */
  picHeight?: number;
}

export enum SkipPreviousResult {
  RESTART_CURRENT = 'restart_current',
  SWITCHED = 'switched'
}

/**
 * 播放队列：维护当前列表上下文与切歌索引，供播放器上一曲/下一曲与列表循环使用。
 */
export class PlaybackQueueManager {
  private static instance: PlaybackQueueManager | null = null;
  private queue: string[] = [];
  private currentIndex: number = -1;
  private mediaKind: PlaybackMediaKind = PlaybackMediaKind.AUDIO;
  private trackCache: Map<string, FileInfo> = new Map();
  private trackChangeListeners: PlaybackTrackChangeListener[] = [];
  private queueChangeListeners: PlaybackQueueChangeListener[] = [];
  private sourceName: string = '';
  private sourcePlaylistId: number = -1;

  private constructor() {
  }

  public static getInstance(): PlaybackQueueManager {
    if (PlaybackQueueManager.instance === null) {
      PlaybackQueueManager.instance = new PlaybackQueueManager();
    }
    return PlaybackQueueManager.instance;
  }

  public setTrackChangeListener(listener: PlaybackTrackChangeListener | null): void {
    this.trackChangeListeners = listener !== null ? [listener] : [];
  }

  public addTrackChangeListener(listener: PlaybackTrackChangeListener): void {
    if (this.trackChangeListeners.indexOf(listener) < 0) {
      this.trackChangeListeners.push(listener);
    }
  }

  public removeTrackChangeListener(listener: PlaybackTrackChangeListener): void {
    const pos = this.trackChangeListeners.indexOf(listener);
    if (pos >= 0) {
      this.trackChangeListeners.splice(pos, 1);
    }
  }

  public addQueueChangeListener(listener: PlaybackQueueChangeListener): void {
    if (this.queueChangeListeners.indexOf(listener) < 0) {
      this.queueChangeListeners.push(listener);
    }
  }

  public removeQueueChangeListener(listener: PlaybackQueueChangeListener): void {
    const pos = this.queueChangeListeners.indexOf(listener);
    if (pos >= 0) {
      this.queueChangeListeners.splice(pos, 1);
    }
  }

  public setQueue(items: FileInfo[], startUri: string, kind: PlaybackMediaKind, sourceName: string = '',
    sourcePlaylistId: number = -1): void {
    const uris: string[] = [];
    const seenNames = new Set<string>();
    this.trackCache.clear();
    for (let i = 0; i < items.length; i++) {
      const item = items[i];
      if (item.uri.length === 0) {
        continue;
      }
      // URI 去重 + 同名去重（Download/Documents 各一份时避免播放队列出现重复曲目）
      if (!uris.includes(item.uri) && !seenNames.has(item.fileName)) {
        uris.push(item.uri);
        seenNames.add(item.fileName);
        this.ensureTrackMeta(item);
        this.trackCache.set(item.uri, item);
      }
    }
    if (uris.length === 0 && startUri.length > 0) {
      uris.push(startUri);
    }
    this.queue = uris;
    this.mediaKind = kind;
    this.sourceName = sourceName;
    this.sourcePlaylistId = kind === PlaybackMediaKind.AUDIO ? sourcePlaylistId : -1;
    this.currentIndex = this.findIndex(startUri);
    // 同名去重后，点中的 URI 可能被丢掉，按 fileName 回落到保留项
    if (this.currentIndex < 0 && startUri.length > 0 && this.queue.length > 0) {
      let startName = '';
      for (let i = 0; i < items.length; i++) {
        if (items[i].uri === startUri) {
          startName = items[i].fileName;
          break;
        }
      }
      if (startName.length > 0) {
        for (let i = 0; i < this.queue.length; i++) {
          const track = this.trackCache.get(this.queue[i]);
          if (track !== undefined && track.fileName === startName) {
            this.currentIndex = i;
            break;
          }
        }
      }
    }
    if (this.currentIndex < 0 && this.queue.length > 0) {
      this.currentIndex = 0;
    }
    HiLog.i(TAG, `setQueue kind=${kind} count=${this.queue.length} index=${this.currentIndex}`);
    this.notifyQueueChange();
  }

  /**
   * 补齐队列曲目大小（扫描未带 fileSize 时用 stat 回填，供列表副标题）
   */
  private ensureTrackMeta(item: FileInfo): void {
    if (item.fileSize > 0) {
      return;
    }
    try {
      let path = item.filePath;
      if (path.length === 0 && item.uri.length > 0) {
        path = new fileuri.FileUri(item.uri).path;
      }
      if (path.length === 0) {
        return;
      }
      const stat = fs.statSync(path);
      if (stat.size > 0) {
        item.fileSize = stat.size;
      }
    } catch (_error) {
      // content URI 等路径可能无法 stat，保持 0
    }
  }

  public getSourceName(): string {
    return this.sourceName;
  }

  /** 队列来源歌单 ID（非歌单播放为 -1） */
  public getSourcePlaylistId(): number {
    return this.sourcePlaylistId;
  }

  /**
   * 移除队列指定项
   *
   * @param index 队列索引
   * @param silent 是否静默（不触发切歌通知，用于批量删除场景避免幽灵播放）
   * @returns 是否移除成功
   */
  public removeAt(index: number, silent: boolean = false): boolean {
    if (index < 0 || index >= this.queue.length) {
      HiLog.w(TAG, `removeAt aborted index=${index} count=${this.queue.length}`);
      return false;
    }
    const removedUri = this.queue[index];
    this.queue.splice(index, 1);
    this.trackCache.delete(removedUri);
    HiLog.i(TAG, `removeAt index=${index} remain=${this.queue.length} silent=${silent}`);
    if (this.queue.length === 0) {
      this.currentIndex = -1;
      this.notifyQueueChange();
      return true;
    }
    if (index < this.currentIndex) {
      this.currentIndex--;
    } else if (index === this.currentIndex) {
      if (this.currentIndex >= this.queue.length) {
        this.currentIndex = this.queue.length - 1;
      }
      if (!silent) {
        this.notifyTrackChange();
      }
    }
    this.notifyQueueChange();
    return true;
  }

  /**
   * 清空队列，保留当前正在播放曲目
   *
   * @returns 是否执行成功
   */
  public clearExceptCurrent(): boolean {
    const currentUri = this.getCurrentUri();
    if (currentUri.length === 0) {
      HiLog.w(TAG, 'clearExceptCurrent skipped: no current track');
      return false;
    }
    const currentTrack = this.trackCache.get(currentUri);
    this.queue = [currentUri];
    this.trackCache.clear();
    if (currentTrack !== undefined) {
      this.trackCache.set(currentUri, currentTrack);
    }
    this.currentIndex = 0;
    HiLog.i(TAG, 'clearExceptCurrent done remain=1');
    this.notifyQueueChange();
    return true;
  }

  /**
   * 清空整个播放队列（含当前曲目）
   *
   * @returns 是否执行成功
   */
  public clearAll(): boolean {
    this.queue = [];
    this.trackCache.clear();
    this.currentIndex = -1;
    this.sourceName = '';
    this.sourcePlaylistId = -1;
    HiLog.i(TAG, `clearAll kind=${this.mediaKind}`);
    this.notifyQueueChange();
    return true;
  }

  /**
   * 拖拽调整队列顺序
   *
   * @param from 原索引
   * @param to 目标索引
   * @param notifyChange 是否通知 UI 全量刷新
   * @returns 是否移动成功
   */
  public moveItem(from: number, to: number, notifyChange: boolean = true): boolean {
    if (from === to || from < 0 || to < 0 ||
      from >= this.queue.length || to >= this.queue.length) {
      HiLog.w(TAG, `moveItem skipped from=${from} to=${to} count=${this.queue.length}`);
      return false;
    }
    const movedUri = this.queue.splice(from, 1)[0];
    this.queue.splice(to, 0, movedUri);
    if (from === this.currentIndex) {
      this.currentIndex = to;
    } else if (from < this.currentIndex && to >= this.currentIndex) {
      this.currentIndex--;
    } else if (from > this.currentIndex && to <= this.currentIndex) {
      this.currentIndex++;
    }
    HiLog.i(TAG, `moveItem from=${from} to=${to} currentIndex=${this.currentIndex}`);
    if (notifyChange) {
      this.notifyQueueChange();
    }
    return true;
  }

  /**
   * 反转队列顺序
   */
  public reverseQueue(): void {
    if (this.queue.length <= 1) {
      HiLog.i(TAG, 'reverseQueue skipped: queue too short');
      return;
    }
    this.queue.reverse();
    this.currentIndex = this.queue.length - 1 - this.currentIndex;
    HiLog.i(TAG, `reverseQueue count=${this.queue.length} currentIndex=${this.currentIndex}`);
    this.notifyQueueChange();
  }

  public getMediaKind(): PlaybackMediaKind {
    return this.mediaKind;
  }

  public getCurrentIndex(): number {
    return this.currentIndex;
  }

  public getQueueLength(): number {
    return this.queue.length;
  }

  /**
   * 获取当前队列快照（含正在播放项标记）
   *
   * @returns 队列展示项列表
   */
  public getQueueSnapshot(): PlaybackQueueEntry[] {
    const entries: PlaybackQueueEntry[] = [];
    for (let i = 0; i < this.queue.length; i++) {
      const uri = this.queue[i];
      const track = this.trackCache.get(uri);
      const fileName = track !== undefined ? track.fileName : this.extractFileName(uri);
      const mimeType = track !== undefined ? track.mimeType :
        (this.mediaKind === PlaybackMediaKind.VIDEO ? 'video/*' : 'audio/*');
      const fileSize = track !== undefined && track.fileSize > 0 ? track.fileSize : 0;
      const picWidth = track !== undefined && track.picWidth > 0 ? track.picWidth : 0;
      const picHeight = track !== undefined && track.picHeight > 0 ? track.picHeight : 0;
      entries.push({
        index: i,
        uri: uri,
        fileName: fileName,
        mimeType: mimeType,
        isCurrent: i === this.currentIndex,
        fileSize: fileSize,
        picWidth: picWidth,
        picHeight: picHeight
      });
    }
    return entries;
  }

  /**
   * 跳转到队列指定索引并触发切歌
   *
   * @param index 目标索引
   * @returns 是否已切换
   */
  public playAt(index: number): boolean {
    if (index < 0 || index >= this.queue.length) {
      HiLog.w(TAG, `playAt aborted invalid index=${index} count=${this.queue.length}`);
      return false;
    }
    if (index === this.currentIndex) {
      HiLog.i(TAG, `playAt skipped same index=${index}`);
      return false;
    }
    this.currentIndex = index;
    HiLog.i(TAG, `playAt index=${index} count=${this.queue.length}`);
    this.notifyTrackChange();
    this.notifyQueueChange();
    return true;
  }

  public getTrack(uri: string): FileInfo | null {
    const cached = this.trackCache.get(uri);
    if (cached !== undefined) {
      return cached;
    }
    return null;
  }

  public getCurrentUri(): string {
    if (this.currentIndex < 0 || this.currentIndex >= this.queue.length) {
      return '';
    }
    return this.queue[this.currentIndex];
  }

  /**
   * 下一曲：队列有多首时切到下一首（末首后回到第一首）。
   *
   * @returns 是否已触发切歌
   */
  public skipToNext(): boolean {
    if (this.queue.length <= 1) {
      HiLog.i(TAG, 'skipToNext skipped: queue too short');
      return false;
    }
    this.currentIndex = (this.currentIndex + 1) % this.queue.length;
    this.notifyTrackChange();
    this.notifyQueueChange();
    return true;
  }

  /**
   * 上一曲：直接切到上一首（首首回绕到末首）；队列仅一首时重播当前曲。
   */
  public skipToPrevious(): SkipPreviousResult {
    if (this.queue.length <= 1) {
      HiLog.i(TAG, 'skipToPrevious restart: queue too short');
      return SkipPreviousResult.RESTART_CURRENT;
    }
    this.currentIndex = this.currentIndex <= 0 ? this.queue.length - 1 : this.currentIndex - 1;
    this.notifyTrackChange();
    this.notifyQueueChange();
    return SkipPreviousResult.SWITCHED;
  }

  /** 列表循环模式：播放完成后自动下一首 */
  public advanceForListLoop(): boolean {
    return this.skipToNext();
  }

  /**
   * 随机播放：从队列中随机选取下一首（尽量避免连续重复同一首）
   *
   * @returns 是否已触发切歌
   */
  public skipToRandomNext(): boolean {
    if (this.queue.length <= 1) {
      HiLog.i(TAG, 'skipToRandomNext skipped queue too short');
      return false;
    }
    let nextIndex = this.currentIndex;
    if (this.queue.length === 2) {
      nextIndex = 1 - this.currentIndex;
    } else {
      while (nextIndex === this.currentIndex) {
        nextIndex = Math.floor(Math.random() * this.queue.length);
      }
    }
    this.currentIndex = nextIndex;
    HiLog.i(TAG, `skipToRandomNext index=${this.currentIndex} count=${this.queue.length}`);
    this.notifyTrackChange();
    this.notifyQueueChange();
    return true;
  }

  /** 随机播放模式：播放完成后自动随机下一首 */
  public advanceForRandomPlay(): boolean {
    return this.skipToRandomNext();
  }

  /**
   * setQueue 后从当前索引起播：通知切歌监听并刷新队列 UI
   */
  public startCurrentTrack(): void {
    const uri = this.getCurrentUri();
    if (uri.length === 0) {
      HiLog.w(TAG, 'startCurrentTrack skipped empty queue');
      return;
    }
    HiLog.i(TAG, `startCurrentTrack index=${this.currentIndex} uri=${uri}`);
    this.notifyTrackChange();
    this.notifyQueueChange();
  }

  private findIndex(uri: string): number {
    for (let i = 0; i < this.queue.length; i++) {
      if (this.queue[i] === uri) {
        return i;
      }
    }
    return -1;
  }

  private notifyTrackChange(): void {
    const uri = this.getCurrentUri();
    if (uri.length === 0) {
      HiLog.w(TAG, `notifyTrackChange skipped empty uri listeners=${this.trackChangeListeners.length}`);
      return;
    }
    if (this.trackChangeListeners.length === 0) {
      HiLog.w(TAG, `notifyTrackChange skipped no listeners index=${this.currentIndex}`);
      return;
    }
    HiLog.i(TAG, `notifyTrackChange kind=${this.mediaKind} index=${this.currentIndex} listeners=${this.trackChangeListeners.length}`);
    for (let i = 0; i < this.trackChangeListeners.length; i++) {
      try {
        this.trackChangeListeners[i](uri, this.mediaKind);
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        HiLog.e(TAG, `notifyTrackChange listener failed message=${message}`);
      }
    }
  }

  private notifyQueueChange(): void {
    for (let i = 0; i < this.queueChangeListeners.length; i++) {
      try {
        this.queueChangeListeners[i]();
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        HiLog.e(TAG, `notifyQueueChange listener failed message=${message}`);
      }
    }
  }

  private extractFileName(uri: string): string {
    const slash = uri.lastIndexOf('/');
    return slash >= 0 ? uri.substring(slash + 1) : uri;
  }
}
