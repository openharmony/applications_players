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


import { BasicDataSource, PlaybackQueueEntry } from '@ohos/common';
import { HiLog } from '@ohos/common/src/main/ets/utils/HiLog';

const TAG = 'PlaybackQueueDataSource';

/**
 * 播放队列半模态 LazyForEach 数据源
 */
export class PlaybackQueueDataSource extends BasicDataSource {
  private dataArray: PlaybackQueueEntry[] = [];

  public totalCount(): number {
    return this.dataArray.length;
  }

  /**
   * 按索引获取队列项
   *
   * @param index 数据索引
   * @returns 队列展示项
   */
  public getData(index: number): PlaybackQueueEntry {
    return this.dataArray[index];
  }

  /**
   * 全量替换队列并通知 LazyForEach 刷新
   *
   * @param data 队列展示项
   */
  public setData(data: PlaybackQueueEntry[]): void {
    const next: PlaybackQueueEntry[] = [];
    for (let i = 0; i < data.length; i++) {
      const item = data[i];
      next.push({
        index: item.index,
        uri: item.uri,
        fileName: item.fileName,
        mimeType: item.mimeType,
        isCurrent: item.isCurrent,
        fileSize: item.fileSize !== undefined ? item.fileSize : 0,
        picWidth: item.picWidth !== undefined ? item.picWidth : 0,
        picHeight: item.picHeight !== undefined ? item.picHeight : 0
      });
    }
    this.dataArray = next;
    this.notifyDataReload();
    const summary = this.dataArray.map((entry: PlaybackQueueEntry) => entry.fileName).join('>');
    HiLog.i(TAG, `setData count=${this.dataArray.length} order=${summary}`);
  }

  /**
   * List.onMove 拖拽排序：仅更新内存顺序，不 notify（框架已处理 UI 位移）
   *
   * @param from 原索引
   * @param to 目标索引
   * @returns 是否移动成功
   */
  public moveItemWithoutNotify(from: number, to: number): boolean {
    if (from === to || from < 0 || to < 0 ||
      from >= this.dataArray.length || to >= this.dataArray.length) {
      HiLog.w(TAG, `moveItemWithoutNotify skipped from=${from} to=${to} count=${this.dataArray.length}`);
      return false;
    }
    const moved = this.dataArray.splice(from, 1)[0];
    this.dataArray.splice(to, 0, moved);
    for (let i = 0; i < this.dataArray.length; i++) {
      this.dataArray[i].index = i;
      this.dataArray[i].isCurrent = false;
    }
    const order = this.dataArray.map((item: PlaybackQueueEntry) => item.fileName).join('>');
    HiLog.i(TAG, `moveItemWithoutNotify from=${from} to=${to} order=${order}`);
    return true;
  }

  /**
   * 同步当前播放项标记
   *
   * @param currentIndex 当前索引
   */
  public syncCurrentIndex(currentIndex: number): void {
    for (let i = 0; i < this.dataArray.length; i++) {
      this.dataArray[i].isCurrent = i === currentIndex;
    }
  }
}
