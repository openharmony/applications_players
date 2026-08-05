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


import preferences from '@ohos.data.preferences';
import { common } from '@kit.AbilityKit';
import { HiLog } from '../../utils/HiLog';
import { SortType } from '../../datasource/IMediaDataSource';

const TAG = 'MediaSortPreference';
const FILE_NAME = 'media_sort_preference';
const KEY_SORT_TYPE = 'sortType';
const KEY_IS_DESC = 'isDesc';

export class MediaSortPreference {
  private static instance: MediaSortPreference;
  private preferenceInstance: preferences.Preferences | null = null;
  private context: common.UIAbilityContext | null = null;

  private constructor() {}

  public static getInstance(): MediaSortPreference {
    if (!MediaSortPreference.instance) {
      MediaSortPreference.instance = new MediaSortPreference();
    }
    return MediaSortPreference.instance;
  }

  public init(context: common.UIAbilityContext): void {
    this.context = context;
    // 只在 preferenceInstance 为 null 时才加载，避免重复加载导致读取缓存数据
    if (!this.preferenceInstance) {
      this.loadPreference();
    }
  }

  // 强制重新加载偏好实例（用于读取最新保存的值）
  public async refreshPreference(): Promise<void> {
    if (!this.context) {
      HiLog.e(TAG, 'context is null, cannot refresh preference');
      return;
    }
    try {
      // 先清除当前实例的缓存
      this.preferenceInstance = null;
      
      // 使用异步 API 获取新的 Preferences 实例
      const options: preferences.Options = { name: FILE_NAME };
      this.preferenceInstance = await preferences.getPreferences(this.context, options);
      HiLog.i(TAG, 'refresh preference success (forced reload)');
    } catch (err) {
      HiLog.e(TAG, `refresh preference err: ${err}`);
    }
  }

  private loadPreference(): void {
    if (!this.context) {
      HiLog.e(TAG, 'context is null, cannot load preference');
      return;
    }
    try {
      const options: preferences.Options = { name: FILE_NAME };
      this.preferenceInstance = preferences.getPreferencesSync(this.context, options);
      HiLog.i(TAG, 'load preference success');
    } catch (err) {
      HiLog.e(TAG, `load preference err: ${err}`);
    }
  }

  public getSortType(): SortType {
    if (!this.preferenceInstance) {
      HiLog.w(TAG, 'preferenceInstance is null, return default');
      return SortType.DATE;
    }
    try {
      const sortTypeStr = this.preferenceInstance.getSync(KEY_SORT_TYPE, SortType.DATE) as string;
      HiLog.i(TAG, `getSortType: ${sortTypeStr}`);
      return sortTypeStr as SortType;
    } catch (err) {
      HiLog.e(TAG, `getSortType err: ${err}`);
      return SortType.DATE;
    }
  }

  public setIsDesc(isDesc: boolean): void {
    if (!this.preferenceInstance) {
      HiLog.w(TAG, 'preferenceInstance is null, cannot save');
      return;
    }
    try {
      this.preferenceInstance.putSync(KEY_IS_DESC, isDesc);
      this.preferenceInstance.flush();
      HiLog.i(TAG, `setIsDesc: ${isDesc}`);
    } catch (err) {
      HiLog.e(TAG, `setIsDesc err: ${err}`);
    }
  }

  public getIsDesc(): boolean {
    if (!this.preferenceInstance) {
      HiLog.w(TAG, 'preferenceInstance is null, return default');
      return true;
    }
    try {
      const isDesc = this.preferenceInstance.getSync(KEY_IS_DESC, true) as boolean;
      HiLog.i(TAG, `getIsDesc: ${isDesc}`);
      return isDesc;
    } catch (err) {
      HiLog.e(TAG, `getIsDesc err: ${err}`);
      return true;
    }
  }

  public saveSortPreference(sortType: SortType, isDesc: boolean): void {
    if (!this.preferenceInstance) {
      HiLog.w(TAG, 'preferenceInstance is null, cannot save');
      return;
    }
    try {
      this.preferenceInstance.putSync(KEY_SORT_TYPE, sortType);
      this.preferenceInstance.putSync(KEY_IS_DESC, isDesc);
      this.preferenceInstance.flush();
      HiLog.i(TAG, `saveSortPreference: ${sortType}, isDesc: ${isDesc}`);
    } catch (err) {
      HiLog.e(TAG, `saveSortPreference err: ${err}`);
    }
  }
}
