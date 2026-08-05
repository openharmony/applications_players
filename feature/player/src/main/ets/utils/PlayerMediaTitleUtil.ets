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


export interface MediaTitleInfo {
  title: string;
  artist: string;
}

export class PlayerMediaTitleUtil {
  static parseFromFileName(fileName: string): MediaTitleInfo {
    if (!fileName) {
      return { title: '', artist: '' };
    }
    const nameWithoutExt = fileName.replace(/\.[^.]+$/, '');
    const separators: string[] = [' - ', ' – ', '-', '–'];
    for (let i = 0; i < separators.length; i++) {
      const sep = separators[i];
      const idx = nameWithoutExt.indexOf(sep);
      if (idx > 0) {
        return {
          title: nameWithoutExt.substring(0, idx).trim(),
          artist: nameWithoutExt.substring(idx + sep.length).trim()
        };
      }
    }
    return { title: nameWithoutExt, artist: '' };
  }
}
