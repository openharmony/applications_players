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


import { FileInfo } from '../utils/FileOperateInfo';
import { ThumbnailConfig } from './ThumbnailConfig';
import { HiLog } from '../utils/HiLog';

const TAG = 'SystemCache';

export class SystemCache {
  static getThumbnailUri(fileInfo: FileInfo): string {
    if (!fileInfo.uri) {
      return '';
    }
    if (!fileInfo.uri.startsWith('media://')) {
      return '';
    }

    try {
      const timestampApp = fileInfo.timesStampApp || Date.now();
      const thumbnailModifiledMs = fileInfo.thumbnailModifiledMs || fileInfo.mtime || 0;
      const path = fileInfo.path || fileInfo.uri;

      const thumbnailUri = fileInfo.uri +
        `?timestampApp=${timestampApp}` +
        `&thumbnailModifiledMs=${thumbnailModifiledMs}` +
        `&oper=astc&width=-1&height=-1&path=${path}`;

      HiLog.d(TAG, `Generated system cache URI: ${thumbnailUri}`);
      return thumbnailUri;
    } catch (error) {
      HiLog.e(TAG, `Failed to generate system cache URI: ${fileInfo.uri}, error: ${error}`);
      return '';
    }
  }

  static isMediaLibraryFile(uri: string): boolean {
    if (!uri) {
      return false;
    }
    return uri.startsWith('media://');
  }
}
