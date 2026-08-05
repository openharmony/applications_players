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

import { FILE_SOURCE_URI_ROOTS, FileSourceUri } from '../storage/Constant';

/**
 * 公共媒体文件系统扫描根 URI。
 * 路径常量统一维护在 {@link FileSourceUri} / {@link FILE_SOURCE_URI_ROOTS}。
 */
export class MediaScanRoots {
  static getAllCandidateRoots(): string[] {
    return FILE_SOURCE_URI_ROOTS.slice();
  }

  /** URI 是否落在 FileSourceUri 定义的 file:// 根路径下 */
  static isUnderFileSourceUri(uri: string): boolean {
    if (!uri || !uri.startsWith('file://')) {
      return false;
    }
    for (let i = 0; i < FILE_SOURCE_URI_ROOTS.length; i++) {
      const root: string = FILE_SOURCE_URI_ROOTS[i];
      if (uri === root || uri.startsWith(`${root}/`)) {
        return true;
      }
    }
    return false;
  }

  /** 是否为媒体库 URI（file://media/...） */
  static isMediaLibraryUri(uri: string): boolean {
    return uri.startsWith(`${FileSourceUri.MEDIA}/`);
  }
}
