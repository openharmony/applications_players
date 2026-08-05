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


import fileAccess from '@ohos.file.fileAccess';
import fs from '@ohos.file.fs';
import Want from '@ohos.app.ability.Want';
import { HiLog } from '../utils/HiLog';
import { FileInfo } from '../utils/FileOperateInfo';
import { FileUtil } from '../utils/FileUtil';
import { MediaScanRoots } from '../constants/media/MediaScanRoots';
import { SupportedMediaFormats } from '../constants/media/SupportedMediaFormats';
import { MediaMetadataResolver } from '../utils/MediaMetadataResolver';
import type common from '@ohos.app.ability.common';

const TAG = 'PublicStorageScanner';

/** 公共存储扫描结果 */
export interface PublicScanResult {
  /** 扫描到的文件列表 */
  files: FileInfo[];
  /** duration 提取失败的文件列表（供重试队列使用） */
  durationFailedFiles: FileInfo[];
}

const AUDIO_SUFFIXES: string[] = SupportedMediaFormats.AUDIO_SUFFIXES.slice();
const VIDEO_SUFFIXES: string[] = SupportedMediaFormats.VIDEO_SUFFIXES.slice();
const MEDIA_SUFFIXES: string[] = SupportedMediaFormats.getAllSuffixes();

/** 内卡文件管理 FileExtensionAbility（无参 createFileAccessHelper 需 GET_BUNDLE_INFO_PRIVILEGED） */
const FILE_ACCESS_WANTS: Want[] = [
  {
    bundleName: 'com.ohos.UserFile.ExternalFileManager',
    abilityName: 'FileExtensionAbility'
  }
];

/**
 * 通过 File Access Framework 扫描公共存储，补充 UserFile / 图库索引未收录的文件。
 */
export class PublicStorageScanner {
  private context: common.Context;
  private fileAccessHelper: fileAccess.FileAccessHelper | null = null;
  private useFileUtilFallback: boolean = false;

  constructor(context: common.Context) {
    this.context = context;
  }

  private async ensureHelper(): Promise<boolean> {
    if (this.fileAccessHelper) {
      return true;
    }
    if (this.useFileUtilFallback) {
      return false;
    }

    try {
      this.fileAccessHelper = fileAccess.createFileAccessHelper(this.context, FILE_ACCESS_WANTS);
      HiLog.i(TAG, 'FileAccessHelper created successfully (ExternalFileManager)');
      return true;
    } catch (error) {
      HiLog.w(TAG, `ExternalFileManager bind failed: ${error}`);
    }

    try {
      const wantInfos = await fileAccess.getFileAccessAbilityInfo();
      if (wantInfos.length > 0) {
        this.fileAccessHelper = fileAccess.createFileAccessHelper(this.context, wantInfos);
        HiLog.i(TAG, `FileAccessHelper created successfully (getFileAccessAbilityInfo: ${wantInfos.length})`);
        return true;
      }
    } catch (error) {
      HiLog.w(TAG, `getFileAccessAbilityInfo failed: ${error}`);
    }

    HiLog.w(TAG, 'FileAccessHelper unavailable, falling back to FileUtil path scanning');
    this.useFileUtilFallback = true;
    return false;
  }

  static resolveAccessibleDirectories(): string[] {
    const accessible: string[] = [];
    for (const uri of MediaScanRoots.getAllCandidateRoots()) {
      try {
        fs.accessSync(uri);
        accessible.push(uri);
      } catch (error) {
        HiLog.d(TAG, `Directory not accessible: ${uri}`);
      }
    }
    return accessible;
  }

  /**
   * 扫描所有公共存储目录的媒体文件
   *
   * @returns 扫描结果，包含文件列表和 duration 提取失败的文件列表
   */
  async scanAllMediaFiles(): Promise<PublicScanResult> {
    const roots: string[] = MediaScanRoots.getAllCandidateRoots();
    HiLog.i(TAG, `Public storage scan: ${roots.length} root directories`);

    const hasHelper = await this.ensureHelper();
    const allFiles: FileInfo[] = [];

    for (const rootUri of roots) {
      try {
        let files: FileInfo[] = [];
        if (hasHelper && this.fileAccessHelper) {
          files = await PublicStorageScanner.scanViaFileAccess(this.fileAccessHelper, rootUri);
        } else {
          files = await PublicStorageScanner.scanViaFileUtil(rootUri);
        }
        HiLog.i(TAG, `${rootUri}: ${files.length} media files`);
        allFiles.push(...files);
      } catch (error) {
        HiLog.e(TAG, `Failed to scan directory ${rootUri}: ${error}`);
      }
    }

    const merged = PublicStorageScanner.deduplicateAndMarkPublic(allFiles);
    HiLog.i(TAG, `Public storage scan complete: ${merged.length} files`);

    // 补充 duration：PublicStorageScanner 不走 AVMetadataExtractor，需要单独填充
    const durationFailedFiles = await PublicStorageScanner.fillMissingDuration(merged);

    return { files: merged, durationFailedFiles };
  }

  private static async scanViaFileAccess(
    helper: fileAccess.FileAccessHelper,
    rootUri: string
  ): Promise<FileInfo[]> {
    const dirInfo = await helper.getFileInfoFromUri(rootUri);
    return PublicStorageScanner.collectFromScanFile(dirInfo);
  }

  private static collectFromScanFile(dirInfo: fileAccess.FileInfo): FileInfo[] {
    const results: FileInfo[] = [];
    try {
      const iterator = dirInfo.scanFile({ suffix: MEDIA_SUFFIXES });
      if (!iterator) {
        return results;
      }
      let isDone = false;
      while (!isDone) {
        const step = iterator.next();
        isDone = step.done;
        if (!isDone && step.value) {
          const converted: FileInfo | null = PublicStorageScanner.convertFileAccessInfo(step.value);
          if (converted) {
            results.push(converted);
          }
        }
      }
    } catch (error) {
      HiLog.e(TAG, `scanFile failed: ${error}`);
    }
    return results;
  }

  /** FileAccess 不可用时的回退：通过 FileUri 物理路径递归 listFile */
  private static async scanViaFileUtil(rootUri: string): Promise<FileInfo[]> {
    const results: FileInfo[] = [];
    try {
      HiLog.e(TAG, `FileUtil trying recursive scan first `);
      // 先尝试递归扫描
      const relativeNames = await FileUtil.getSubFileNameByUriWithFs(rootUri, true);
      for (const relativeName of relativeNames) {
        if (!PublicStorageScanner.isMediaFileName(relativeName)) {
          continue;
        }
        const fileUri = PublicStorageScanner.joinUri(rootUri, relativeName);
        const fileInfo: FileInfo | null = PublicStorageScanner.buildFileInfoFromUri(fileUri, relativeName);
        if (fileInfo) {
          results.push(fileInfo);
        }
      }
      // 递归扫描返回 0 个文件时，手动遍历子目录（fs.listFile 递归对 file://docs 可能不可靠）
      if (results.length === 0) {
        HiLog.e(TAG, `FileUtil manually traversing subdirectories `);
        await PublicStorageScanner.scanSubdirectoriesRecursive(rootUri, results);
      }
    } catch (error) {
      HiLog.e(TAG, `FileUtil fallback scan failed ${rootUri}: ${error}`);
    }
    return results;
  }

  /** 手动递归遍历子目录，收集媒体文件 */
  private static async scanSubdirectoriesRecursive(dirUri: string, results: FileInfo[]): Promise<void> {
    const MAX_DEPTH = 5;
    try {
      const children = await FileUtil.getSubFileNameByUriWithFs(dirUri, false);
      for (const child of children) {
        const childUri = PublicStorageScanner.joinUri(dirUri, child);
        // 尝试作为文件判断
        if (PublicStorageScanner.isMediaFileName(child)) {
          const fileInfo: FileInfo | null = PublicStorageScanner.buildFileInfoFromUri(childUri, child);
          if (fileInfo) {
            results.push(fileInfo);
          }
          continue;
        }
        // 尝试作为目录递归（通过 stat 判断是否为目录）
        const stat = fs.statSync(childUri);
        if (stat.isDirectory() && MAX_DEPTH > 0) {
          await PublicStorageScanner.scanSubdirectory(childUri, results, MAX_DEPTH - 1);
        }
      }
    } catch (error) {
      HiLog.d(TAG, `scanSubdirectoriesRecursive failed ${dirUri}: ${error?.message}`);
    }
  }

  /** 递归扫描子目录（带深度限制） */
  private static async scanSubdirectory(dirUri: string, results: FileInfo[], depth: number): Promise<void> {
    if (depth <= 0) {
      return;
    }
    try {
      const children = await FileUtil.getSubFileNameByUriWithFs(dirUri, false);
      for (const child of children) {
        const childUri = PublicStorageScanner.joinUri(dirUri, child);
        if (PublicStorageScanner.isMediaFileName(child)) {
          const fileInfo: FileInfo | null = PublicStorageScanner.buildFileInfoFromUri(childUri, child);
          if (fileInfo) {
            results.push(fileInfo);
          }
          continue;
        }

        const stat = fs.statSync(childUri);
        if (stat.isDirectory()) {
          await PublicStorageScanner.scanSubdirectory(childUri, results, depth - 1);
        }
      }
    } catch (error) {
      HiLog.d(TAG, `scanSubdirectory failed ${dirUri}: ${error}`);
    }
  }

  private static buildFileInfoFromUri(fileUri: string, fileName: string): FileInfo | null {
    try {
      const fileInfo: FileInfo = new FileInfo();
      fileInfo.uri = fileUri;
      fileInfo.path = FileUtil.getPathFromUri(fileUri);
      fileInfo.fileName = fileName.includes('/') ? fileName.substring(fileName.lastIndexOf('/') + 1) : fileName;
      fileInfo.thumbGenerated = false;
      fileInfo.isExternalStorageDeviceFile = true;

      const stat = fs.statSync(fileUri);
      fileInfo.size = stat.size;
      fileInfo.mtime = stat.mtime;
      fileInfo.ctime = stat.ctime;

      fileInfo.mimeType = PublicStorageScanner.isAudioFile(fileInfo.fileName) ? 'audio/*' :
        (PublicStorageScanner.isVideoFile(fileInfo.fileName) ? 'video/*' : '');
      return fileInfo;
    } catch (error) {
      HiLog.d(TAG, `stat failed: ${fileUri}, ${error}`);
      return null;
    }
  }

  private static convertFileAccessInfo(faInfo: fileAccess.FileInfo): FileInfo | null {
    if (!faInfo.fileName || faInfo.fileName.length === 0) {
      return null;
    }

    const fileInfo: FileInfo = new FileInfo();
    fileInfo.uri = faInfo.uri;
    fileInfo.path = FileUtil.getPathFromUri(faInfo.uri);
    fileInfo.fileName = faInfo.fileName;
    fileInfo.size = faInfo.size;
    fileInfo.mtime = faInfo.mtime;
    fileInfo.ctime = faInfo.mtime;
    fileInfo.thumbGenerated = false;
    fileInfo.isExternalStorageDeviceFile = true;

    fileInfo.mimeType = PublicStorageScanner.isAudioFile(faInfo.fileName) ? 'audio/*' :
      (PublicStorageScanner.isVideoFile(faInfo.fileName) ? 'video/*' : '');
    return fileInfo;
  }

  private static isMediaFileName(name: string): boolean {
    const baseName = name.includes('/') ? name.substring(name.lastIndexOf('/') + 1) : name;
    return PublicStorageScanner.isAudioFile(baseName) || PublicStorageScanner.isVideoFile(baseName);
  }

  private static isAudioFile(fileName: string): boolean {
    const lower = fileName.toLowerCase();
    for (const ext of AUDIO_SUFFIXES) {
      if (lower.endsWith(ext)) {
        return true;
      }
    }
    return false;
  }

  private static isVideoFile(fileName: string): boolean {
    const lower = fileName.toLowerCase();
    for (const ext of VIDEO_SUFFIXES) {
      if (lower.endsWith(ext)) {
        return true;
      }
    }
    return false;
  }

  /** 拼接 file://docs URI，避免 root 与 segment 之间的双斜杠 */
  static joinUri(base: string, segment: string): string {
    const normalizedBase = base.endsWith('/') ? base.slice(0, -1) : base;
    const normalizedSeg = segment.startsWith('/') ? segment.slice(1) : segment;
    return `${normalizedBase}/${normalizedSeg}`;
  }

  private static deduplicateAndMarkPublic(files: FileInfo[]): FileInfo[] {
    const uriSet = new Set<string>();
    const merged: FileInfo[] = [];
    for (const file of files) {
      if (uriSet.has(file.uri)) {
        continue;
      }
      uriSet.add(file.uri);
      file.isExternalStorageDeviceFile = true;
      merged.push(file);
    }
    return merged;
  }

  /**
   * 批量补充缺失的 duration：对 duration <= 0 的文件逐个调用 MediaMetadataResolver。
   * 并发限制为 MAX_CONCURRENT_FILL 避免同时打开过多 fd。
   */
  /**
   * 批量补充缺失的 duration：对 duration <= 0 的文件逐个调用 MediaMetadataResolver。
   * 并发限制为 MAX_CONCURRENT_FILL 避免同时打开过多 fd。
   *
   * @param files 待处理的文件列表
   * @returns 仍然缺失 duration 的文件列表（供重试队列使用）
   */
  private static async fillMissingDuration(files: FileInfo[]): Promise<FileInfo[]> {
    const MAX_CONCURRENT_FILL = 4;
    const pending = files.filter(f => f.duration <= 0);
    if (pending.length === 0) {
      return [];
    }
    HiLog.i(TAG, `Filling duration: ${pending.length} files`);

    for (let i = 0; i < pending.length; i += MAX_CONCURRENT_FILL) {
      const batch = pending.slice(i, i + MAX_CONCURRENT_FILL);
      await Promise.all(batch.map(async (fileInfo) => {
        try {
          await MediaMetadataResolver.fillDuration(fileInfo);
          if (fileInfo.duration > 0) {
            HiLog.d(TAG, `Duration filled: path=${fileInfo.path}, file=${fileInfo.fileName} = ${fileInfo.duration}ms`);
          }
        } catch (error) {
          HiLog.w(TAG, `Duration fill failed: path=${fileInfo.path}, file=${fileInfo.fileName}, ${error}`);
        }
      }));
    }

    // 返回仍然缺失 duration 的文件列表
    const failedFiles = files.filter(f => f.duration <= 0);
    if (failedFiles.length > 0) {
      HiLog.w(TAG, `Still ${failedFiles.length} files missing duration after fill`);
    }
    return failedFiles;
  }
}
