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


import { HiLog } from '../utils/HiLog';
import { FileChangeEvent, FileChangeType } from './FileChangeEvent';
import { IFileSyncEngine, FileSyncCallback } from './IFileChangeListener';
import { FileSyncTaskPool, SyncFileInfo } from './FileSyncTaskPool';
import { MediaDbManager } from '../persistence/rdb/MediaDbManager';
import { FileInfo } from '../utils/FileOperateInfo';
import type common from '@ohos.app.ability.common';
import userFileManager from '@ohos.filemanagement.userFileManager';
import dataSharePredicates from '@ohos.data.dataSharePredicates';
import fs from '@ohos.file.fs';
import { SupportedMediaFormats } from '../constants/media/SupportedMediaFormats';


const TAG = 'FileSyncEngine';

export class SyncResult {
  public totalFiles: number = 0;
  public processedFiles: number = 0;
  public successCount: number = 0;
  public failCount: number = 0;
  public skippedCount: number = 0;
}

export class FileSyncEngine implements IFileSyncEngine {
  private context: common.Context;
  private dbManager: MediaDbManager;
  private callback: FileSyncCallback | null = null;
  private syncInProgress: boolean = false;
  private cancelRequested: boolean = false;
  private userFileMgr: userFileManager.UserFileManager | null = null;
  private mediaExtensions: Set<string> = new Set(SupportedMediaFormats.getAllSuffixes());

  constructor(context: common.Context) {
    this.context = context;
    this.dbManager = MediaDbManager.getInstance(context);
    this.initUserFileManager();
    HiLog.i(TAG, 'FileSyncEngine created');
  }

  private initUserFileManager(): void {
    try {
      this.userFileMgr = userFileManager.getUserFileMgr(this.context);
      HiLog.i(TAG, 'UserFileManager initialized successfully');
    } catch (error) {
      HiLog.e(TAG, `UserFileManager initialization failed: ${error}`);
    }
  }

  public async syncFileCreated(filePath: string): Promise<boolean> {
    if (this.cancelRequested) {
      return false;
    }

    HiLog.i(TAG, `Syncing created file: ${filePath}`);

    const info = await FileSyncTaskPool.getFileInfo(filePath);
    if (!info) {
      HiLog.e(TAG, `Failed to get file info: ${filePath}`);
      return false;
    }

    if (!this.isMediaFile(info.extension)) {
      HiLog.d(TAG, `Skipped non-media file: ${filePath}`);
      return false;
    }

    if (info.isDirectory) {
      HiLog.d(TAG, `Skipped directory: ${filePath}`);
      return false;
    }

    const fileInfo = this.convertSyncInfoToFileInfo(info);

    try {
      const success = await this.dbManager.saveMetadata(fileInfo);
      if (success && this.callback && this.callback.onFileProcessed) {
        this.callback.onFileProcessed(filePath, true);
      }
      return success;
    } catch (error) {
      HiLog.e(TAG, `Failed to sync created file: ${filePath}, error: ${error}`);
      if (this.callback && this.callback.onFileProcessed) {
        this.callback.onFileProcessed(filePath, false);
      }
      return false;
    }
  }

  public async syncFileModified(filePath: string): Promise<boolean> {
    if (this.cancelRequested) {
      return false;
    }

    HiLog.i(TAG, `Syncing modified file: ${filePath}`);

    const info = await FileSyncTaskPool.getFileInfo(filePath);
    if (!info) {
      const exists = await FileSyncTaskPool.checkFileExists(filePath);
      if (!exists) {
        return await this.syncFileDeleted(filePath);
      }
      return false;
    }

    if (!this.isMediaFile(info.extension)) {
      return false;
    }

    const fileInfo = this.convertSyncInfoToFileInfo(info);

    try {
      const existingInfo: FileInfo | null = await this.dbManager.getMetadata(filePath);
      if (existingInfo) {
        const success = await this.dbManager.updateMediaMetadata(fileInfo);
        if (success && this.callback && this.callback.onFileProcessed) {
          this.callback.onFileProcessed(filePath, true);
        }
        return success;
      } else {
        const success = await this.dbManager.saveMetadata(fileInfo);
        if (success && this.callback && this.callback.onFileProcessed) {
          this.callback.onFileProcessed(filePath, true);
        }
        return success;
      }
    } catch (error) {
      HiLog.e(TAG, `Failed to sync modified file: ${filePath}, error: ${error}`);
      if (this.callback && this.callback.onFileProcessed) {
        this.callback.onFileProcessed(filePath, false);
      }
      return false;
    }
  }

  public async syncFileDeleted(filePath: string): Promise<boolean> {
    if (this.cancelRequested) {
      return false;
    }

    HiLog.i(TAG, `Syncing deleted file: ${filePath}`);

    try {
      const existingInfo: FileInfo | null = await this.dbManager.getMetadata(filePath);
      if (existingInfo) {
        const success = await this.dbManager.markAsInvalid(filePath);
        if (success && this.callback && this.callback.onFileProcessed) {
          this.callback.onFileProcessed(filePath, true);
        }
        return success;
      }
      return true;
    } catch (error) {
      HiLog.e(TAG, `Failed to sync deleted file: ${filePath}, error: ${error}`);
      if (this.callback && this.callback.onFileProcessed) {
        this.callback.onFileProcessed(filePath, false);
      }
      return false;
    }
  }

  public async batchSync(event: FileChangeEvent): Promise<number> {
    if (this.cancelRequested) {
      return 0;
    }

    this.syncInProgress = true;
    this.cancelRequested = false;

    if (this.callback && this.callback.onSyncStart) {
      this.callback.onSyncStart();
    }

    const result = new SyncResult();
    const events = event.getEvents();
    result.totalFiles = events.length;

    HiLog.i(TAG, `Starting batch sync: ${result.totalFiles} events`);

    const createdPaths: string[] = [];
    const modifiedPaths: string[] = [];
    const deletedPaths: string[] = [];
    const movedInPaths: string[] = [];
    const movedOutPaths: string[] = [];

    for (const evt of events) {
      switch (evt.changeType) {
        case FileChangeType.CREATED:
          createdPaths.push(evt.filePath);
          break;
        case FileChangeType.MODIFIED:
        case FileChangeType.CLOSED_WRITE:
          modifiedPaths.push(evt.filePath);
          break;
        case FileChangeType.DELETED:
          deletedPaths.push(evt.filePath);
          break;
        case FileChangeType.MOVED_IN:
          movedInPaths.push(evt.filePath);
          break;
        case FileChangeType.MOVED_OUT:
          movedOutPaths.push(evt.filePath);
          break;
      }
    }

    for (const path of deletedPaths) {
      if (this.cancelRequested) break;
      const success = await this.syncFileDeleted(path);
      result.processedFiles++;
      if (success) result.successCount++;
      else result.failCount++;
    }

    for (const path of movedOutPaths) {
      if (this.cancelRequested) break;
      const success = await this.syncFileDeleted(path);
      result.processedFiles++;
      if (success) result.successCount++;
      else result.failCount++;
    }

    const fileInfos = await FileSyncTaskPool.batchGetFileInfo([...createdPaths, ...modifiedPaths, ...movedInPaths]);

    // 关键修复：content URI 路径 (file://media/...) 在 @Concurrent TaskPool 中无法 fs.statSync
    // 需要在主线程通过 userFileManager + asset.open+fs.stat(fd) 获取 FileInfo
    // 找出 TaskPool 未成功处理的 content URI 路径，补充处理
    // 注意：TaskPool 对 content URI 返回 null（fs.statSync 失败），所以所有 content URI 都在 fileInfos 中缺失
    const allPaths = [...createdPaths, ...modifiedPaths, ...movedInPaths];
    const processedPaths = new Set(fileInfos.map(info => info.path));
    const contentUriPaths: string[] = [];
    for (const path of allPaths) {
      if (path.startsWith('file://media/') && !processedPaths.has(path)) {
        contentUriPaths.push(path);
      }
    }

    if (contentUriPaths.length > 0) {
      HiLog.i(TAG, `Supplementing content URI paths: ${contentUriPaths.length}`);
      for (const contentPath of contentUriPaths) {
        if (this.cancelRequested) break;
        const syncInfo = await this.getSyncFileInfoForContentUri(contentPath);
        if (syncInfo) {
          fileInfos.push(syncInfo);
          HiLog.i(TAG, `Content URI supplement succeeded: ${contentPath}, mtime=${syncInfo.mtime}, size=${syncInfo.size}`);
        } else {
          HiLog.w(TAG, `Content URI supplement failed: ${contentPath}`);
        }
      }
    }

    for (const info of fileInfos) {
      if (this.cancelRequested) break;
      if (!this.isMediaFile(info.extension)) {
        result.processedFiles++;
        result.skippedCount++;
        continue;
      }

      const fileInfo = this.convertSyncInfoToFileInfo(info);
      const existingInfo: FileInfo | null = await this.dbManager.getMetadata(info.uri);

      let success: boolean;
      if (existingInfo) {
        success = await this.dbManager.updateMediaMetadata(fileInfo);
      } else {
        success = await this.dbManager.saveMetadata(fileInfo);
      }

      result.processedFiles++;
      if (success) result.successCount++;
      else result.failCount++;

      if (this.callback && this.callback.onFileProcessed) {
        this.callback.onFileProcessed(info.path, success);
      }
    }

    const remainingPaths = createdPaths.length + modifiedPaths.length + movedInPaths.length - fileInfos.length;
    // remainingPaths 现在只包含 TaskPool 和 content URI fallback 都未处理的路径
    for (let i = 0; i < remainingPaths && !this.cancelRequested; i++) {
      result.processedFiles++;
      result.failCount++;
    }

    this.syncInProgress = false;

    if (this.callback) {
      if (this.cancelRequested) {
        if (this.callback.onSyncError) {
          this.callback.onSyncError(new Error('Sync cancelled'));
        }
      } else if (this.callback.onSyncComplete) {
        this.callback.onSyncComplete(result.processedFiles);
      }
    }

    HiLog.i(TAG, `Batch sync completed: processed=${result.processedFiles}, success=${result.successCount}, fail=${result.failCount}, skipped=${result.skippedCount}`);

    return result.successCount;
  }

  public setSyncCallback(callback: FileSyncCallback): void {
    this.callback = callback;
  }

  public cancelSync(): void {
    this.cancelRequested = true;
    HiLog.i(TAG, 'Sync cancellation requested');
  }

  public isSyncing(): boolean {
    return this.syncInProgress;
  }

  private isMediaFile(extension: string): boolean {
    return this.mediaExtensions.has(extension.toLowerCase());
  }

  /**
   * mtime 格式统一化：fs.statSync 和 fs.stat(fd) 在设备上可能返回 uptime 秒 (如 134667)
   * 而数据库中已有文件的 mtime 是 epoch 秒 (如 1779592667)
   * 需要将 uptime 格式转为 epoch 格式，确保排序一致性
   * 阈值 1000000000 (约 2001年)：小于此值视为 uptime 格式
   * 偏移量 1779458000 = 1779420000 + 36000 (36小时缓冲)
   */
  private static readonly UPTIME_TO_EPOCH_OFFSET = 1779458000;
  private static readonly MTIME_EPOCH_THRESHOLD = 1000000000;

  private normalizeMtime(rawMtime: number): number {
    if (rawMtime > 0 && rawMtime < FileSyncEngine.MTIME_EPOCH_THRESHOLD) {
      // uptime 格式 → 加偏移量转为 epoch
      const epoch = rawMtime + FileSyncEngine.UPTIME_TO_EPOCH_OFFSET;
      HiLog.i(TAG, `mtime format conversion: uptime=${rawMtime}, epoch=${epoch}`);
      return epoch;
    }
    // epoch 格式或无效值 → 直接返回
    return rawMtime;
  }

  private convertSyncInfoToFileInfo(info: SyncFileInfo): FileInfo {
    const fileInfo = new FileInfo();
    fileInfo.fileName = info.fileName;
    fileInfo.path = info.path;
    fileInfo.uri = info.uri;
    fileInfo.size = info.size;
    fileInfo.mtime = this.normalizeMtime(info.mtime);
    fileInfo.duration = info.duration || 0;
    fileInfo.thumbGenerated = false;
    fileInfo.mimeType = this.getMimeType(info.extension);
    return fileInfo;
  }

  private getMimeType(extension: string): string {
    const ext = extension.toLowerCase();
    if (SupportedMediaFormats.AUDIO_SUFFIXES.includes(ext)) {
      return 'audio/*';
    }
    if (SupportedMediaFormats.VIDEO_SUFFIXES.includes(ext)) {
      return 'video/*';
    }
    return 'application/octet-stream';
  }

  /**
   * 从 content URI 获取 SyncFileInfo (主线程方法)
   * content URI (如 file://media/Audio/...) 无法在 @Concurrent TaskPool 中通过 fs.statSync 获取元数据
   * 需要在主线程通过 userFileManager.getAudioAssets/getPhotoAssets 获取 FileAsset，
   * 再通过 asset.open('r') + fs.stat(fd) + asset.close(fd) 获取真实 mtime 和 size
   * 这与 UserFileScanner 和 IncrementalSyncManager 使用相同的模式
   */
  private async getSyncFileInfoForContentUri(uri: string): Promise<SyncFileInfo | null> {
    if (!this.userFileMgr) {
      HiLog.e(TAG, 'UserFileManager not initialized, cannot get content URI metadata');
      return null;
    }

    try {
      const fileName = uri.substring(uri.lastIndexOf('/') + 1);
      const extension = fileName.lastIndexOf('.') !== -1 ? fileName.substring(fileName.lastIndexOf('.')) : '';
      const isAudio = uri.includes('/Audio/');
      const isPhoto = uri.includes('/Photo/');

      // 使用与 UserFileScanner 完全相同的查询模式
      // 只用 greaterThan('duration', 0) — 不能用 equalTo('displayName', fileName)
      // 否则 getAudioAssets 返回 Error: invalid parameter
      const predicates = new dataSharePredicates.DataSharePredicates();
      predicates.greaterThan('duration', 0);

      let fetchOptions: userFileManager.FetchOptions;
      if (isAudio) {
        // 音频：与 UserFileScanner.scanPublicAudioFiles 完全一致
        fetchOptions = {
          fetchColumns: ['duration'],
          predicates: predicates
        };
      } else {
// 图片/视频：使用 fetchColumns: ['duration'] + greaterThan('duration', 0) predicate
      // getPhotoAssets 不接受 ['title', 'dateModified', 'size'] 等 fetchColumns (会报 invalid parameter)
      // 但 ['duration'] 有效 (与 getAudioAssets 的 fetchColumns 格式一致)
      // predicates.greaterThan('duration', 0) 已设置，直接过滤出视频 (duration > 0)
        fetchOptions = {
          fetchColumns: ['duration'],
          predicates: predicates
        };
      }

      let fileAsset: userFileManager.FileAsset | null = null;

      if (isAudio) {
        const fetchResult = await this.userFileMgr.getAudioAssets(fetchOptions);
        const assets = await fetchResult.getAllObject();
        HiLog.i(TAG, `getAudioAssets returned ${assets.length} audio assets, searching: ${fileName}`);
        for (const asset of assets) {
          if (asset.displayName === fileName) {
            fileAsset = asset;
            break;
          }
        }
        fetchResult.close();
      } else if (isPhoto) {
        const fetchResult = await this.userFileMgr.getPhotoAssets(fetchOptions);
        const assets = await fetchResult.getAllObject();
        HiLog.i(TAG, `getPhotoAssets returned ${assets.length} image/video assets, searching: ${fileName}`);
        for (const asset of assets) {
          if (asset.displayName === fileName) {
            fileAsset = asset;
            break;
          }
        }
        fetchResult.close();
      } else {
        HiLog.w(TAG, `Unknown content URI type: ${uri}`);
        return null;
      }

      if (!fileAsset) {
        HiLog.w(TAG, `FileAsset not found: ${fileName}, URI: ${uri}`);
        return null;
      }

      HiLog.i(TAG, `Found FileAsset: ${fileName}, getting mtime+size`);

      // 方案1：尝试从 FileAsset 属性获取 dateModified
      let mtime = 0;
      let size = 0;

      try {
        const dateModified = fileAsset.get('DATE_MODIFIED') as number;
        HiLog.i(TAG, `fileAsset.get('DATE_MODIFIED'): ${fileName}, value=${dateModified}`);
        if (dateModified > 0) {
          mtime = dateModified / 1000;
        }
      } catch (e) {
        HiLog.i(TAG, `fileAsset.get('DATE_MODIFIED') failed: ${fileName}`);
      }

      if (mtime === 0) {
        try {
          const dateModified = fileAsset.get('dateModified') as number;
          HiLog.i(TAG, `fileAsset.get('dateModified'): ${fileName}, value=${dateModified}`);
          if (dateModified > 0) {
            mtime = dateModified / 1000;
          }
        } catch (e) {
          HiLog.i(TAG, `fileAsset.get('dateModified') failed: ${fileName}`);
        }
      }

      // 方案2：如果属性获取失败，通过 fd stat 获取
      if (mtime === 0) {
        HiLog.i(TAG, `Property fetch failed, trying fd stat: ${fileName}`);
        try {
          const fd = await fileAsset.open('r');
          HiLog.i(TAG, `fileAsset.open('r') succeeded: ${fileName}, fd=${fd}`);
          const stat = await fs.stat(fd);
          HiLog.i(TAG, `fs.stat(fd) succeeded: ${fileName}, mtime=${stat.mtime}, size=${stat.size}`);
          await fileAsset.close(fd);
          const rawMtime = stat.mtime;
          size = stat.size;
          // fs.stat(fd).mtime 格式不一致：某些返回 epoch 秒(1779422649)
          // 某些返回 uptime 秒(860)，需要统一为 epoch 格式以确保排序一致
          // 阈值 1000000000 (约 2001年)：小于此值视为 uptime 格式
          if (rawMtime > 0 && rawMtime < 1000000000) {
            // uptime 格式 → 加偏移量转为 epoch
            // 偏移量需要确保: uptime + offset > max_existing_epoch_mtime (≈1779422650)
            // 即使设备重启后 uptime 从 0 开始，offset 也必须足够大
            // 1779458000 = 1779420000 + 36000 (36小时缓冲)，确保重启后新文件仍排在前面
            const UPTIME_TO_EPOCH_OFFSET = 1779458000;
            mtime = rawMtime + UPTIME_TO_EPOCH_OFFSET;
            HiLog.i(TAG, `mtime format conversion: ${fileName}, uptime=${rawMtime}, estimated epoch=${mtime}`);
          } else if (rawMtime >= 1000000000) {
            mtime = rawMtime;
            HiLog.i(TAG, `mtime epoch format: ${fileName}, mtime=${mtime}`);
          }
        } catch (fdError) {
          HiLog.e(TAG, `fd stat failed: ${fileName}, error: ${fdError}`);
        }
      }

      // 方案3：如果所有方法都失败，使用 Date.now()/1000 fallback + 偏移量
      if (mtime === 0) {
        const nowSec = Math.floor(Date.now() / 1000);
        HiLog.w(TAG, `All methods failed, Date.now()/1000 fallback: ${fileName}, nowSec=${nowSec}`);
        if (nowSec < 1000000000) {
          mtime = nowSec + 1779458000;
        } else {
          mtime = nowSec;
        }
      }

      // size: 尝试从属性获取
      if (size === 0) {
        try {
          const assetSize = fileAsset.get('size') as number;
          if (assetSize > 0) {
            size = assetSize;
          }
        } catch (e) {
          // size 属性获取失败
        }
      }

      // duration: 尝试从属性获取
      let duration = 0;
      try {
        const assetDuration = fileAsset.get('duration') as number;
        if (assetDuration > 0) {
          duration = assetDuration;
        }
      } catch (e) {
        HiLog.i(TAG, `duration property fetch failed: ${fileName}`);
      }

      if (mtime > 0) {
        HiLog.i(TAG, `Content URI final mtime: ${fileName}, mtime=${mtime}, size=${size}, duration=${duration}`);
        return {
          fileName: fileName,
          path: uri,
          uri: uri,
          size: size,
          mtime: mtime,
          duration: duration,
          isDirectory: false,
          extension: extension.toLowerCase()
        };
      }

      return null;
    } catch (error) {
      HiLog.e(TAG, `Failed to get content URI SyncFileInfo: ${uri}, error: ${error}`);
      return null;
    }
  }

  public getSyncResult(): SyncResult {
    return new SyncResult();
  }
}
