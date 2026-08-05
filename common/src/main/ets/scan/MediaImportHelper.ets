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


import fs from '@ohos.file.fs';
import { HiLog } from '../utils/HiLog';
import { FileInfo } from '../utils/FileOperateInfo';
import { FileUtil } from '../utils/FileUtil';
import FileMimeTypeUtil from '../utils/FileMimeTypeUtil';
import { MediaScanRoots } from '../constants/media/MediaScanRoots';
import { SupportedMediaFormats } from '../constants/media/SupportedMediaFormats';
import { MediaMetadataResolver } from '../utils/MediaMetadataResolver';

const TAG = 'MediaImportHelper';

/** Picker URI 解析结果 */
export interface MediaImportParseResult {
  files: FileInfo[];
  skippedCount: number;
}

/** Picker 导入结果 */
export class MediaImportResult {
  public imported: number = 0;
  public skipped: number = 0;

  constructor(imported: number = 0, skipped: number = 0) {
    this.imported = imported;
    this.skipped = skipped;
  }
}

/**
 * 从 DocumentViewPicker 返回的 URI 构造 FileInfo。
 * 须落在 FileSourceUri 路径下，且为 SupportedMediaFormats 支持的后缀。
 */
export class MediaImportHelper {
  static isImportableFileUri(uri: string): boolean {
    return MediaScanRoots.isUnderFileSourceUri(uri);
  }

  /** @deprecated 保留旧名，行为同 {@link isImportableFileUri} */
  static isAuthorizedPickerUri(uri: string): boolean {
    return MediaImportHelper.isImportableFileUri(uri);
  }

  static isMediaFileName(fileName: string): boolean {
    return SupportedMediaFormats.isSupportedMedia(fileName);
  }

  static buildFileInfoFromPickerUri(uri: string): FileInfo | null {
    let cleanUri = uri.trim();
    if (cleanUri.endsWith('/')) {
      cleanUri = cleanUri.slice(0, -1);
    }
    if (!MediaImportHelper.isImportableFileUri(cleanUri)) {
      HiLog.w(TAG, `Skipping non-FileSourceUri path: ${uri}`);
      return null;
    }

    const canonicalUri: string = FileUtil.normalizeMediaUri(cleanUri);
    if (!MediaImportHelper.isImportableFileUri(canonicalUri)) {
      HiLog.w(TAG, `Skipping non-FileSourceUri path: ${uri}`);
      return null;
    }

    const fileName: string = FileUtil.getFileNameFromUri(canonicalUri);
    if (!fileName || !MediaImportHelper.isMediaFileName(fileName)) {
      HiLog.w(TAG, `Skipping unsupported format file: ${fileName}`);
      return null;
    }

    try {
      const fileInfo = new FileInfo();
      fileInfo.uri = canonicalUri;
      fileInfo.path = FileUtil.getPathFromUri(canonicalUri);
      fileInfo.fileName = fileName;
      fileInfo.thumbGenerated = false;
      fileInfo.isExternalStorageDeviceFile = true;

      const stat = MediaImportHelper.statPickerUri(canonicalUri, cleanUri);
      if (stat) {
        fileInfo.size = stat.size;
        fileInfo.mtime = stat.mtime;
        fileInfo.ctime = stat.ctime;
      } else if (MediaScanRoots.isMediaLibraryUri(canonicalUri)) {
        MediaImportHelper.applyFallbackMetadata(fileInfo);
        HiLog.w(TAG, `file://media stat unavailable, using fallback metadata: ${canonicalUri}`);
      } else {
        return null;
      }

      const mime = FileMimeTypeUtil.getMimeType(fileName, false, 0);
      if (mime.mimeType.length > 0) {
        fileInfo.mimeType = mime.mimeType;
      } else if (SupportedMediaFormats.isSupportedAudio(fileName)) {
        fileInfo.mimeType = 'audio/*';
      } else {
        fileInfo.mimeType = 'video/*';
      }
      return fileInfo;
    } catch (error) {
      HiLog.e(TAG, `Failed to build import FileInfo: ${canonicalUri}, ${error}`);
      return null;
    }
  }

  static parsePickerUris(uris: string[]): MediaImportParseResult {
    const results: FileInfo[] = [];
    const uriSet = new Set<string>();
    let skippedCount = 0;
    for (const rawUri of uris) {
      const fileInfo = MediaImportHelper.buildFileInfoFromPickerUri(rawUri);
      if (!fileInfo) {
        skippedCount++;
        continue;
      }
      if (uriSet.has(fileInfo.uri)) {
        continue;
      }
      uriSet.add(fileInfo.uri);
      results.push(fileInfo);
    }
    HiLog.i(TAG, `Picker URI parse: input=${uris.length}, valid=${results.length}, skipped=${skippedCount}`);
    return { files: results, skippedCount };
  }

  static buildFileInfoListFromUris(uris: string[]): FileInfo[] {
    return MediaImportHelper.parsePickerUris(uris).files;
  }

  /**
   * Picker 导入第二步：在 stat 构造 FileInfo 后，统一解析 duration（及缺失的 size）。
   */
  static async resolvePickerMetadata(fileInfo: FileInfo): Promise<void> {
    await MediaMetadataResolver.fillDuration(fileInfo);
  }

  /** 解析 Picker URI 并补全元数据（导入主流程入口） */
  static async parseAndResolvePickerUris(uris: string[]): Promise<MediaImportParseResult> {
    const parseResult = MediaImportHelper.parsePickerUris(uris);
    for (let i = 0; i < parseResult.files.length; i++) {
      await MediaImportHelper.resolvePickerMetadata(parseResult.files[i]);
    }
    return parseResult;
  }

  private static applyFallbackMetadata(fileInfo: FileInfo): void {
    const nowSec = Math.floor(Date.now() / 1000);
    fileInfo.size = 0;
    fileInfo.mtime = nowSec;
    fileInfo.ctime = nowSec;
  }

  /** canonicalUri stat 失败时回退 Picker 原始 URI */
  private static statPickerUri(canonicalUri: string, fallbackUri: string): fs.Stat | null {
    try {
      return fs.statSync(canonicalUri);
    } catch (error) {
      HiLog.w(TAG, `canonicalUri stat failed, trying original URI: ${canonicalUri}, ${error}`);
      try {
        return fs.statSync(fallbackUri);
      } catch (fallbackError) {
        HiLog.e(TAG, `stat failed: canonical=${canonicalUri}, fallback=${fallbackUri}, ${fallbackError}`);
        return null;
      }
    }
  }
}
