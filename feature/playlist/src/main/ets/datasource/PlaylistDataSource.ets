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



import { BasicDataSource } from '@ohos/common';
import { HiLog } from '@ohos/common/src/main/ets/utils/HiLog';
import { PlaylistItem } from '../model/PlaylistItem';

const TAG = 'PlaylistDataSource';

/**
 * 播放列表宫格 LazyForEach 数据源
 */
export class PlaylistDataSource extends BasicDataSource {
  private dataArray: PlaylistItem[] = [];

  public totalCount(): number {
    return this.dataArray.length;
  }

  /**
   * 按索引获取播放列表项（LazyForEach 回调）
   *
   * @param index 数据索引
   * @returns 播放列表卡片项
   */
  public getData(index: number): PlaylistItem {
    return this.dataArray[index];
  }

  /**
   * 全量替换数据并通知 LazyForEach 刷新
   *
   * @param data 播放列表数组
   */
  public setData(data: PlaylistItem[]): void {
    this.dataArray = data.slice();
    this.notifyDataReload();
    HiLog.i(TAG, `setData count=${this.dataArray.length}`);
  }

  /**
   * 追加一条播放列表并通知 LazyForEach 增量插入
   *
   * @param item 新播放列表项
   */
  public addItem(item: PlaylistItem): void {
    this.dataArray.push(item);
    this.notifyDataAdd(this.dataArray.length - 1);
    HiLog.i(TAG, `addItem id=${item.id} count=${this.dataArray.length}`);
  }

  /**
   * 按索引更新播放列表项并通知 LazyForEach 单项刷新
   *
   * @param index 数据索引
   * @param item 更新后的播放列表项
   */
  public updateItemAt(index: number, item: PlaylistItem): void {
    if (index < 0 || index >= this.dataArray.length) {
      HiLog.w(TAG, `updateItemAt skipped index=${index} count=${this.dataArray.length}`);
      return;
    }
    this.dataArray[index] = item;
    this.notifyDataChange(index);
    HiLog.i(TAG, `updateItemAt index=${index} id=${item.id}`);
  }

  /**
   * 按播放列表 id 查找索引
   *
   * @param id 播放列表 id
   * @returns 索引，未找到时为 -1
   */
  public findIndexById(id: number): number {
    for (let i = 0; i < this.dataArray.length; i++) {
      if (this.dataArray[i].id === id) {
        return i;
      }
    }
    return -1;
  }

  /**
   * 按播放列表 id 删除并通知 LazyForEach 单项移除
   *
   * @param id 播放列表 id
   * @returns 是否删除成功
   */
  public removeItemById(id: number): boolean {
    const index = this.findIndexById(id);
    if (index < 0) {
      HiLog.w(TAG, `removeItemById skipped id=${id}`);
      return false;
    }
    this.dataArray.splice(index, 1);
    this.notifyDataDelete(index);
    HiLog.i(TAG, `removeItemById id=${id} count=${this.dataArray.length}`);
    return true;
  }

  /**
   * 获取当前数据快照
   *
   * @returns 播放列表数组副本
   */
  public getDataArray(): PlaylistItem[] {
    return this.dataArray.slice();
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
    const order = this.dataArray.map((item: PlaylistItem) => item.name).join('>');
    HiLog.i(TAG, `moveItemWithoutNotify from=${from} to=${to} moved=${moved.name} order=${order}`);
    return true;
  }
}
