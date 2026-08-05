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

export class SearchPreferenceConst {
  static readonly FILE_NAME: string = 'search_history';
  static readonly KEY_HISTORY_LIST: string = 'searchHistoryList';
  static readonly KEY_QUICK_LIST: string = 'quickSearchList';
  static readonly MAX_HISTORY_COUNT: number = 20;
  static readonly MAX_QUICK_COUNT: number = 10;

  public static getDefaultQuickKeywords(): string[] {
    return ['mp3', 'mp4', '播客'];
  }
}
