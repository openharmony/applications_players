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


import { PlaylistConstants } from '../constants/PlaylistConstants';

/**
 * 歌单名称输入校验：禁止空格与 \\ / : * ? " < > |，最长 40 字符。
 */
export class PlaylistNameInputUtil {
  private static readonly STRIP_INVALID_REGEX: RegExp = /[\s\\/:*?"<>|]/g;

  /**
   * 清洗并截断歌单名称（初始名回显、提交兜底）。
   *
   * @param name 原始名称
   * @returns 合法名称
   */
  static sanitize(name: string): string {
    const cleaned = name.replace(PlaylistNameInputUtil.STRIP_INVALID_REGEX, '');
    if (cleaned.length <= PlaylistConstants.MAX_NAME_LENGTH) {
      return cleaned;
    }
    return cleaned.substring(0, PlaylistConstants.MAX_NAME_LENGTH);
  }
}
