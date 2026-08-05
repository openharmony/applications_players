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



import FileInfo from '@ohos/common/src/main/ets/model/FileInfo';
import { BasicDataSource } from '@ohos/common';
import { HiLog } from '@ohos/common/src/main/ets/utils/HiLog';

const TAG = 'PlaylistTrackDataSource';

/**
 * 播放列表曲目 LazyForEach 数据源（详情页 / 添加音频页共用）
 */
export class PlaylistTrackDataSource extends BasicDataSource {
  private dataArray: FileInfo[] = [];

  public totalCount(): number {
    return this.dataArray.length;
  }

  /**
   * 按索引获取曲目（LazyForEach 回调）
   *
   * @param index 数据索引
   * @returns 音频文件信息
   */
  public getData(index: number): FileInfo {
    return this.dataArray[index];
  }

  /**
   * 全量替换数据并通知 LazyForEach 刷新
   *
   * @param data 曲目数组
   */
  public setData(data: FileInfo[]): void {
    this.dataArray = data.slice();
    this.notifyDataReload();
    const order = this.dataArray.map((item: FileInfo) => item.fileName).join('>');
    HiLog.i(TAG, `setData count=${this.dataArray.length} order=${order}`);
  }

  /**
   * 获取当前数据快照
   *
   * @returns 曲目数组副本
   */
  public getDataArray(): FileInfo[] {
    return this.dataArray.slice();
  }

  /**
   * 按 URI 查找曲目索引（滑动删除时实时解析，避免 LazyForEach index 闭包过期）
   *
   * @param uri 曲目 URI
   * @returns 索引，未找到为 -1
   */
  public findIndexByUri(uri: string): number {
    for (let i = 0; i < this.dataArray.length; i++) {
      if (this.dataArray[i].uri === uri) {
        return i;
      }
    }
    return -1;
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
    const order = this.dataArray.map((item: FileInfo) => item.fileName).join('>');
    HiLog.i(TAG, `moveItemWithoutNotify from=${from} to=${to} moved=${moved.fileName} order=${order}`);
    return true;
  }

  /**
   * 编程式换位：更新数据并通知 LazyForEach 交换（非 List.onMove 场景）
   *
   * @param from 原索引
   * @param to 目标索引
   * @returns 是否移动成功
   */
  public moveItem(from: number, to: number): boolean {
    if (!this.moveItemWithoutNotify(from, to)) {
      return false;
    }
    this.notifyDataMove(from, to);
    HiLog.i(TAG, `moveItem notifyDataMove from=${from} to=${to}`);
    return true;
  }

  /**
   * 按索引移除曲目并通知 LazyForEach 删除
   *
   * @param index 数据索引
   * @returns 是否移除成功
   */
  public removeItemAt(index: number): boolean {
    if (index < 0 || index >= this.dataArray.length) {
      HiLog.w(TAG, `removeItemAt skipped index=${index} count=${this.dataArray.length}`);
      return false;
    }
    const removed = this.dataArray.splice(index, 1)[0];
    this.notifyDataDelete(index);
    HiLog.i(TAG, `removeItemAt index=${index} removed=${removed.fileName} remain=${this.dataArray.length}`);
    return true;
  }
}
