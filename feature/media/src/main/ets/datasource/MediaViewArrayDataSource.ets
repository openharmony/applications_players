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

/**
 * 轻量 IDataSource 适配器：桥接 @Prop 数组与 LazyForEach。
 * 仅用于 MediaAggregateView 的列表/宫格渲染优化，避免 ForEach 创建全量组件实例。
 */
export class MediaViewArrayDataSource implements IDataSource {
  private data: FileInfo[] = [];
  private listeners: DataChangeListener[] = [];

  public totalCount(): number {
    return this.data.length;
  }

  public getData(index: number): FileInfo {
    return this.data[index];
  }

  public registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
  }

  public unregisterDataChangeListener(listener: DataChangeListener): void {
    const pos = this.listeners.indexOf(listener);
    if (pos >= 0) {
      this.listeners.splice(pos, 1);
    }
  }

  /** @Prop 数组变更时调用，通知 LazyForEach 刷新 */
  public replaceData(newData: FileInfo[]): void {
    this.data = newData;
    this.listeners.forEach((listener: DataChangeListener) => {
      listener.onDataReloaded();
    });
  }
}
