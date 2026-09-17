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

/** 压缩包内媒体条目：archiveUri 指向压缩包，innerPath 为包内相对路径 */
export interface ArchiveInnerMediaRef {
  archiveUri: string;
  innerPath: string;
}

const ARCHIVE_INNER_MARKERS: string[] = ['.zip/', '.7z/', '.rar/', '.tar/', '.gz/', '.gzip/'];
const ARCHIVE_PREVIEW_DIR = '/.archive_preview_';

/**
 * 解析文件管理器传入的压缩包内虚拟 URI（如 file://docs/.../a.zip/dir/video.mp4）。
 */
export class ArchiveMediaUriHelper {
  /**
   * 是否为文件管理器临时解压目录 URI。
   */
  public static isArchivePreviewUri(uri: string): boolean {
    return uri.indexOf(ARCHIVE_PREVIEW_DIR) >= 0;
  }

  /**
   * 是否为压缩包内虚拟路径 URI。
   */
  public static isArchiveInnerUri(uri: string): boolean {
    return ArchiveMediaUriHelper.parseArchiveInnerUri(uri) !== null;
  }

  /**
   * 将压缩包内虚拟 URI 拆分为压缩包 URI 与包内相对路径。
   */
  public static parseArchiveInnerUri(uri: string): ArchiveInnerMediaRef | null {
    if (uri.length === 0) {
      return null;
    }
    const lowerUri = uri.toLowerCase();
    for (let i = 0; i < ARCHIVE_INNER_MARKERS.length; i++) {
      const marker = ARCHIVE_INNER_MARKERS[i];
      const markerIndex = lowerUri.indexOf(marker);
      if (markerIndex < 0) {
        continue;
      }
      const archiveUri = uri.substring(0, markerIndex + marker.length - 1);
      const innerPath = uri.substring(markerIndex + marker.length);
      if (archiveUri.length === 0 || innerPath.length === 0) {
        return null;
      }
      return {
        archiveUri: archiveUri,
        innerPath: innerPath
      };
    }
    return null;
  }
}
