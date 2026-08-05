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
import { HiLog } from '@ohos/common/src/main/ets/utils/HiLog';
import { SearchPreferenceConst } from '../constants/SearchPreferenceConst';

const TAG = 'SearchPreference';

/**
 * 搜索历史与快捷搜索词条持久化（Preferences）
 */
export class SearchPreference {
  private static instance: SearchPreference | null = null;
  private preferenceInstance: preferences.Preferences | null = null;
  private context: common.UIAbilityContext | null = null;

  private constructor() {
  }

  /**
   * 获取 SearchPreference 单例
   *
   * @returns SearchPreference 实例
   */
  public static getInstance(): SearchPreference {
    if (!SearchPreference.instance) {
      SearchPreference.instance = new SearchPreference();
    }
    return SearchPreference.instance;
  }

  /**
   * 使用 Ability 上下文初始化 Preferences
   *
   * @param context MainAbility 上下文
   */
  public init(context: common.UIAbilityContext): void {
    this.context = context;
    if (!this.preferenceInstance) {
      this.loadPreference();
    }
  }

  private loadPreference(): void {
    if (!this.context) {
      HiLog.e(TAG, 'context is null, cannot load preference');
      return;
    }
    try {
      const options: preferences.Options = { name: SearchPreferenceConst.FILE_NAME };
      this.preferenceInstance = preferences.getPreferencesSync(this.context, options);
      HiLog.i(TAG, 'load preference success');
    } catch (err) {
      HiLog.e(TAG, `load preference err: ${String(err)}`);
    }
  }

  /**
   * 读取搜索历史（最新在前）
   *
   * @returns 历史关键词列表
   */
  public getHistoryList(): string[] {
    return this.readStringList(SearchPreferenceConst.KEY_HISTORY_LIST);
  }

  /**
   * 写入搜索历史
   *
   * @param history 历史关键词列表
   */
  public setHistoryList(history: string[]): void {
    this.writeStringList(SearchPreferenceConst.KEY_HISTORY_LIST, history);
  }

  /**
   * 读取快捷搜索词条；无数据时返回默认列表
   *
   * @returns 快捷搜索列表
   */
  public getQuickSearchList(): string[] {
    const stored = this.readStringList(SearchPreferenceConst.KEY_QUICK_LIST);
    if (stored.length === 0) {
      return SearchPreferenceConst.getDefaultQuickKeywords();
    }
    return stored;
  }

  /**
   * 写入快捷搜索词条
   *
   * @param quickList 快捷搜索列表
   */
  public setQuickSearchList(quickList: string[]): void {
    this.writeStringList(SearchPreferenceConst.KEY_QUICK_LIST, quickList);
  }

  /**
   * 清空搜索历史
   */
  public clearHistory(): void {
    this.setHistoryList([]);
    HiLog.i(TAG, 'clearHistory');
  }

  /**
   * 快捷搜索恢复为默认词条
   */
  public resetQuickSearchToDefault(): void {
    const defaults = SearchPreferenceConst.getDefaultQuickKeywords();
    this.setQuickSearchList(defaults.slice());
    HiLog.i(TAG, `resetQuickSearchToDefault count=${defaults.length}`);
  }

  private readStringList(key: string): string[] {
    if (!this.preferenceInstance) {
      return [];
    }
    try {
      const raw = this.preferenceInstance.getSync(key, '[]') as string;
      const parsed = JSON.parse(raw) as string[];
      if (!Array.isArray(parsed)) {
        return [];
      }
      return parsed.filter((item: string) => item.length > 0);
    } catch (err) {
      HiLog.e(TAG, `readStringList err key=${key}: ${String(err)}`);
      return [];
    }
  }

  private writeStringList(key: string, values: string[]): void {
    if (!this.preferenceInstance) {
      HiLog.w(TAG, 'preferenceInstance is null, cannot save');
      return;
    }
    try {
      const maxCount = key === SearchPreferenceConst.KEY_QUICK_LIST ?
        SearchPreferenceConst.MAX_QUICK_COUNT : SearchPreferenceConst.MAX_HISTORY_COUNT;
      const limited = values.slice(0, maxCount);
      this.preferenceInstance.putSync(key, JSON.stringify(limited));
      this.preferenceInstance.flush();
      HiLog.i(TAG, `writeStringList key=${key} count=${limited.length}`);
    } catch (err) {
      HiLog.e(TAG, `writeStringList err key=${key}: ${String(err)}`);
    }
  }
}
