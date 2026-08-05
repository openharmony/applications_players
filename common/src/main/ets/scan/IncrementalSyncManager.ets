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
import { ScanStateManager, ScanStatistics } from '../scan/ScanStateManager';
import { MediaDbManager } from '../persistence/rdb/MediaDbManager';
import { SearchIndexManager } from '../search/SearchIndexManager';
import { FileInfo } from '../utils/FileOperateInfo';
import { FileChangeEvent, FileChangeType } from '../listener/FileChangeEvent';
import type common from '@ohos.app.ability.common';
import fs from '@ohos.file.fs';
import userFileManager from '@ohos.filemanagement.userFileManager';
import dataSharePredicates from '@ohos.data.dataSharePredicates';
import { SupportedMediaFormats } from '../constants/media/SupportedMediaFormats';

const TAG = 'IncrementalSyncManager';

/**
 * 同步进度回调
 */
export type ProgressCallback = (progress: number, total: number) => void;

/**
 * 从 content URI 获取的 mtime 和 size 元数据
 */
export interface MtimeAndSizeResult {
  mtime: number;
  size: number;
}

/**
 * 同步统计信息
 */
export interface SyncStatistics {
  totalFiles: number;
  syncedFiles: number;
  pendingFiles: number;
  lastSyncTime: number;
  isSyncInProgress: boolean;
}

/**
 * 增量同步管理器
 * 协调数据库与索引的增量更新
 */
export class IncrementalSyncManager {
  private static instance: IncrementalSyncManager | undefined;
  private context: common.Context;
  private scanStateManager: ScanStateManager;
  private dbManager: MediaDbManager;
  private indexManager: SearchIndexManager;
  private userFileMgr: userFileManager.UserFileManager | null = null;
  private isSyncing: boolean = false;
  private progressCallback?: ProgressCallback;
  private syncPromise?: Promise<boolean>;

  private constructor(context: common.Context) {
    this.context = context;
    this.scanStateManager = ScanStateManager.getInstance(context);
    this.dbManager = MediaDbManager.getInstance(context);
    this.indexManager = SearchIndexManager.getInstance();
    this.initUserFileManager();
  }

  private initUserFileManager(): void {
    try {
      this.userFileMgr = userFileManager.getUserFileMgr(this.context);
      HiLog.i(TAG, 'UserFileManager initialized successfully');
    } catch (error) {
      HiLog.e(TAG, `UserFileManager initialization failed: ${error}`);
    }
  }

  /**
   * 获取单例实例
   */
  static getInstance(context: common.Context): IncrementalSyncManager {
    if (!IncrementalSyncManager.instance) {
      IncrementalSyncManager.instance = new IncrementalSyncManager(context);
    }
    return IncrementalSyncManager.instance;
  }

  /**
   * 设置进度回调
   */
  setProgressCallback(callback: ProgressCallback): void {
    this.progressCallback = callback;
    HiLog.i(TAG, 'Progress callback set');
  }

  /**
   * 执行后台增量扫描
   */
  async executeBackgroundIncrementalScan(): Promise<boolean> {
    if (this.isSyncing) {
      HiLog.w(TAG, 'Sync in progress, skipping');
      return false;
    }

    try {
      this.isSyncing = true;
      this.scanStateManager.setScanning(true);

      HiLog.i(TAG, 'Starting background incremental scan');

      // 初始化数据库和扫描状态管理器
      await this.dbManager.init();
      await this.scanStateManager.init();

      // 获取上次增量扫描时间
      const lastScanTime = await this.scanStateManager.getLastIncrementalScanTime();
      HiLog.i(TAG, `Last incremental scan time: ${lastScanTime}`);

      // 从数据库查询增量变更的文件
      const changes = await this.dbManager.queryIncrementalChanges(lastScanTime);
      HiLog.i(TAG, `Found ${changes.length} changed files`);

      // 处理变更文件
      let processedCount = 0;
      for (const fileInfo of changes) {
        // thumbGenerated 字段被用来标记是否为无效文件（已删除）
        const isValid = !fileInfo.thumbGenerated;

        if (isValid) {
          // 有效文件：添加到索引
          this.indexManager.addToFileIndex(fileInfo);
          this.scanStateManager.addScannedFile(fileInfo);
          HiLog.i(TAG, `Added file to index: ${fileInfo.uri}`);
        } else {
          // 无效文件：从索引中移除
          this.indexManager.removeFromIndex(fileInfo.uri);
          this.scanStateManager.removeScannedFile(fileInfo.uri);
          HiLog.i(TAG, `Removed file from index: ${fileInfo.uri}`);
        }

        processedCount++;

        // 报告进度
        if (this.progressCallback) {
          this.progressCallback(processedCount, changes.length);
        }
      }

      // 更新上次增量扫描时间
      await this.scanStateManager.setLastIncrementalScanTime(Date.now());

      HiLog.i(TAG, `Background incremental scan completed, processed ${processedCount} files`);
      return true;
    } catch (error) {
      HiLog.e(TAG, `Background incremental scan failed: ${error}`);
      return false;
    } finally {
      this.isSyncing = false;
      this.scanStateManager.setScanning(false);
    }
  }

/**
   * 处理文件变更事件
   * 分发到 handleFileCreated/handleFileModified/handleFileDeleted
   * 注意：各子方法仅更新搜索索引和扫描状态，不再重复写入 DB
   * DB 持久化由 FileSyncEngine.batchSync() 负责处理
   */
  async handleFileChangeEvent(event: FileChangeEvent): Promise<boolean> {
    if (!event || !event.hasEvents()) {
      HiLog.w(TAG, 'File change event invalid or empty');
      return false;
    }

    try {
      const events = event.getEvents();
      HiLog.i(TAG, `Processing file change events: ${events.length}`);

      for (const eventInfo of events) {
        HiLog.i(TAG, `Processing file change: ${eventInfo.filePath}, type: ${eventInfo.changeType}`);

        switch (eventInfo.changeType) {
          case FileChangeType.CREATED:
            await this.handleFileCreated(eventInfo.filePath);
            break;
          case FileChangeType.MODIFIED:
            await this.handleFileModified(eventInfo.filePath);
            break;
          case FileChangeType.DELETED:
            await this.handleFileDeleted(eventInfo.filePath);
            break;
          default:
            HiLog.w(TAG, `Unknown file change type: ${eventInfo.changeType}`);
            break;
        }
      }

      return true;
    } catch (error) {
      HiLog.e(TAG, `Failed to process file change events: ${error}`);
      return false;
    }
  }

  /**
   * 处理文件创建事件
   * 注意：FileSyncEngine.batchSync() 已负责 DB 持久化（saveMetadata/updateMediaMetadata）
   * 此方法仅更新搜索索引和扫描状态，不再重复写入 DB
   * 避免同一事件触发两次 DB 写入导致 mtime 不一致
   */
  private async handleFileCreated(filePath: string): Promise<void> {
    try {
      HiLog.i(TAG, `Handling file creation (index only, DB by FileSyncEngine): ${filePath}`);

      // 创建 FileInfo 用于索引更新（不需要保存到 DB）
      const fileInfo = await this.createFileInfoFromPathAsync(filePath);
      if (!fileInfo) {
        HiLog.w(TAG, `Cannot create FileInfo: ${filePath}`);
        return;
      }

      // 更新扫描状态
      this.scanStateManager.addScannedFile(fileInfo);

      // 添加到索引
      this.indexManager.addToFileIndex(fileInfo);

      HiLog.i(TAG, `File creation index update done: ${filePath}, mtime=${fileInfo.mtime}`);
    } catch (error) {
      HiLog.e(TAG, `Failed to handle file creation: ${filePath}, error: ${error}`);
    }
  }

  /**
   * 处理文件修改事件
   * 注意：FileSyncEngine.batchSync() 已负责 DB 持久化（updateMediaMetadata）
   * 此方法仅更新搜索索引和扫描状态，不再重复写入 DB
   */
  private async handleFileModified(filePath: string): Promise<void> {
    try {
      HiLog.i(TAG, `Handling file modification (index only, DB by FileSyncEngine): ${filePath}`);

      const fileInfo = await this.createFileInfoFromPathAsync(filePath);
      if (!fileInfo) {
        HiLog.w(TAG, `Cannot create FileInfo: ${filePath}`);
        return;
      }

      this.scanStateManager.addScannedFile(fileInfo);
      this.indexManager.removeFromIndex(filePath);
      this.indexManager.addToFileIndex(fileInfo);

      HiLog.i(TAG, `File modification index update done: ${filePath}, mtime=${fileInfo.mtime}`);
    } catch (error) {
      HiLog.e(TAG, `Failed to handle file modification: ${filePath}, error: ${error}`);
    }
  }

  /**
   * 处理文件删除事件
   */
  private async handleFileDeleted(filePath: string): Promise<void> {
    try {
      HiLog.i(TAG, `Handling file deletion: ${filePath}`);

      // 标记数据库中的文件为无效
      await this.dbManager.markAsInvalid(filePath);

      // 更新扫描状态
      this.scanStateManager.removeScannedFile(filePath);

      // 从索引中移除
      this.indexManager.removeFromIndex(filePath);

      HiLog.i(TAG, `File deletion handled: ${filePath}`);
    } catch (error) {
      HiLog.e(TAG, `Failed to handle file deletion: ${filePath}, error: ${error}`);
    }
  }

  /**
   * 从文件路径异步创建 FileInfo
   * 关键修复：对 content URI (file://media/...) 使用 userFileManager.getAudioAssets
   * + asset.open('r') + fs.stat(fd) 获取真实 mtime 和 size
   * 对沙箱路径使用 fs.statSync（沙箱路径 statSync 正常工作）
   * Date.now() fallback 使用 Math.floor(Date.now() / 1000) 确保返回秒级 epoch 时间戳
   */
  private async createFileInfoFromPathAsync(filePath: string): Promise<FileInfo | null> {
    try {
      const fileName = filePath.substring(filePath.lastIndexOf('/') + 1);
      const extension = fileName.lastIndexOf('.') !== -1 ? fileName.substring(fileName.lastIndexOf('.')) : '';

      const fileInfo = new FileInfo();
      fileInfo.fileName = fileName;
      fileInfo.path = filePath;
      fileInfo.uri = filePath;
      fileInfo.mimeType = this.getMimeType(extension);

      // 判断是否为 content URI (如 file://media/Audio/..., file://media/Photo/...)
      // content URI 无法通过 fs.statSync/stat 获取元数据，需通过 userFileManager + asset.open + fs.stat(fd)
      const isContentUri = filePath.startsWith('file://media/');

      if (isContentUri) {
        // content URI 路径：通过 userFileManager 获取 FileAsset，再通过 asset.open+fs.stat(fd) 获取 mtime+size
        // 这是与 UserFileScanner.convertFileAssetToFileInfoAsync 相同的模式
        const mtimeAndSize = await this.getMtimeAndSizeFromContentUri(filePath, fileName);
        if (mtimeAndSize) {
          fileInfo.mtime = mtimeAndSize.mtime;
          fileInfo.size = mtimeAndSize.size;
          HiLog.i(TAG, `Content URI metadata fetched: ${fileName}, mtime=${mtimeAndSize.mtime}, size=${mtimeAndSize.size}`);
        } else {
          // 最终 fallback：使用 Date.now()/1000 作为 mtime
          // Date.now()/1000 在设备上可能返回 uptime 秒 (如 133038)，需转为 epoch 格式
          const fallbackMtime = Math.floor(Date.now() / 1000);
          if (fallbackMtime < 1000000000) {
            fileInfo.mtime = fallbackMtime + 1779458000;
            HiLog.w(TAG, `Content URI metadata fetch failed, Date.now()/1000 fallback: ${fileName}, uptime=${fallbackMtime}, epoch=${fileInfo.mtime}`);
          } else {
            fileInfo.mtime = fallbackMtime;
            HiLog.w(TAG, `content URI metadata fetch failed, Date.now()/1000 fallback: ${fileName}, epoch=${fileInfo.mtime}`);
          }
        }
      } else {
        // 沙箱路径：fs.statSync 正常工作
        try {
          const stat = fs.statSync(filePath);
          fileInfo.size = stat.size;
          // fs.statSync 返回的 mtime 可能是 uptime 秒 (如 860) 而非 epoch 秒 (如 1779422649)
          // 需要统一为 epoch 格式以确保排序一致性
          const rawMtime = stat.mtime;
          if (rawMtime > 0 && rawMtime < 1000000000) {
            fileInfo.mtime = rawMtime + 1779458000;
            HiLog.i(TAG, `Sandbox path stat: ${fileName}, uptime=${rawMtime}, epoch=${fileInfo.mtime}, size=${stat.size}`);
          } else {
            fileInfo.mtime = rawMtime;
            HiLog.i(TAG, `Sandbox path stat: ${fileName}, epoch mtime=${rawMtime}, size=${stat.size}`);
          }
        } catch (statError) {
          // 沙箱路径 stat 失败的 fallback（罕见情况）
          // Date.now()/1000 在设备上可能返回 uptime 秒，需转为 epoch 格式
          const fallbackMtime = Math.floor(Date.now() / 1000);
          if (fallbackMtime < 1000000000) {
            fileInfo.mtime = fallbackMtime + 1779458000;
          } else {
            fileInfo.mtime = fallbackMtime;
          }
          HiLog.w(TAG, `Sandbox path stat failed: ${filePath}, using Date.now()/1000 fallback, uptime=${fallbackMtime}, epoch=${fileInfo.mtime}`);
        }
      }

      return fileInfo;
    } catch (error) {
      HiLog.e(TAG, `Failed to create FileInfo: ${filePath}, error: ${error}`);
      return null;
    }
  }

  /**
   * 通过 userFileManager 从 content URI 获取 mtime 和 size
   * 使用与 UserFileScanner 完全相同的查询模式：
   *   音频：predicates.greaterThan('duration', 0) + fetchColumns: ['duration']
   *         → 获取所有音频 FileAsset → 按 displayName 精确匹配筛选
   *   图片/视频：predicates.greaterThan('duration', 0) + fetchColumns: ['title', 'duration', 'dateModified', 'size']
   *         → 获取所有视频 FileAsset → 按 displayName 精确匹配筛选
   * 然后 asset.open('r') + fs.stat(fd) + asset.close(fd) 获取 mtime + size
   * 
   * 重要：不能用 predicates.equalTo('displayName', fileName) 查询音频
   *       getAudioAssets 对 displayName predicate 返回 Error: invalid parameter
   *       只能用 greaterThan('duration', 0) (已验证在 UserFileScanner 中正常工作)
   *       fetchColumns 也不能包含 'dateModified' 用于音频 (仅 'duration' 有效)
   */
  private async getMtimeAndSizeFromContentUri(uri: string, fileName: string): Promise<MtimeAndSizeResult | null> {
    if (!this.userFileMgr) {
      HiLog.e(TAG, 'UserFileManager not initialized, cannot get content URI metadata');
      return null;
    }

    try {
      const isAudio = uri.includes('/Audio/');
      const isPhoto = uri.includes('/Photo/');

      // 使用与 UserFileScanner 完全相同的查询模式 — 只用 greaterThan('duration', 0)
      // 不能用 equalTo('displayName', fileName)，否则 getAudioAssets 返回 invalid parameter
      const predicates = new dataSharePredicates.DataSharePredicates();
      predicates.greaterThan('duration', 0);

      let fetchOptions: userFileManager.FetchOptions;
      if (isAudio) {
        // 音频：与 UserFileScanner.scanPublicAudioFiles 完全一致
        // fetchColumns 只包含 'duration' (已验证可工作)
        // 不包含 'dateModified' — 音频 assets 不支持该 fetchColumn
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
        // 在结果中按 displayName 精确匹配筛选
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

      // 方案1：尝试从 FileAsset 属性获取 dateModified / dateAdded
      // AudioKey enum: DATE_MODIFIED, DATE_ADDED, DURATION, DISPLAY_NAME 等
      // 音频 FileAsset 不支持 asset.get('dateModified') (Error: member not exist)
      // 尝试多种属性名获取修改时间或添加时间
      let mtime = 0;
      let size = 0;

      // 1a: DATE_MODIFIED (AudioKey enum 名)
      try {
        const dateModified = fileAsset.get('DATE_MODIFIED') as number;
        HiLog.i(TAG, `fileAsset.get('DATE_MODIFIED'): ${fileName}, value=${dateModified}`);
        if (dateModified > 0) {
          mtime = dateModified / 1000;
        }
      } catch (e) {
        HiLog.i(TAG, `fileAsset.get('DATE_MODIFIED') failed: ${fileName}`);
      }

      // 1b: dateModified (小写驼峰)
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

      // 1c: DATE_ADDED (AudioKey enum 名 - 文件添加到媒体库的时间)
      if (mtime === 0) {
        try {
          const dateAdded = fileAsset.get('DATE_ADDED') as number;
          HiLog.i(TAG, `fileAsset.get('DATE_ADDED'): ${fileName}, value=${dateAdded}`);
          if (dateAdded > 0) {
            mtime = dateAdded / 1000;
          }
        } catch (e) {
          HiLog.i(TAG, `fileAsset.get('DATE_ADDED') failed: ${fileName}`);
        }
      }

      // 1d: dateAdded (小写驼峰)
      if (mtime === 0) {
        try {
          const dateAdded = fileAsset.get('dateAdded') as number;
          HiLog.i(TAG, `fileAsset.get('dateAdded'): ${fileName}, value=${dateAdded}`);
          if (dateAdded > 0) {
            mtime = dateAdded / 1000;
          }
        } catch (e) {
          HiLog.i(TAG, `fileAsset.get('dateAdded') failed: ${fileName}`);
        }
      }

      // 方案2：如果属性获取失败，通过 fd stat 获取
      // 注意：fs.stat(fd).mtime 可能返回设备 uptime 秒 (如 35129) 而非 epoch 秒 (如 1779422649)
      // 这导致与已有 epoch 格式 mtime 的排序不一致
      // 如果 fd stat 返回的 mtime < 100000 (uptime 格式)，需要加偏移量转为 epoch 格式
      if (mtime === 0) {
        HiLog.i(TAG, `Property fetch failed, trying fd stat: ${fileName}`);
        try {
          const fd = await fileAsset.open('r');
          const stat = await fs.stat(fd);
          await fileAsset.close(fd);
          const rawMtime = stat.mtime;
          size = stat.size;
          HiLog.i(TAG, `fd stat: ${fileName}, rawMtime=${rawMtime}, size=${size}`);

          // 判断 mtime 格式：如果 < 1000000000 (约 2001年)，
          // 很可能是设备 uptime 秒，而非 epoch 秒
          // 需要加偏移量转为 epoch 格式，确保排序一致性
          if (rawMtime > 0 && rawMtime < 1000000000) {
            // uptime 格式 → 需要转换
            // 偏移量 = 已知 epoch 文件的 mtime - 同文件的 uptime mtime
            // 简化方案：用 Date.now() 获取当前设备时间作为参考
            // Date.now() 在设备上返回 uptime 毫秒，fs.stat(fd).mtime 也是 uptime 秒
            // 但数据库中已有文件的 mtime 是 epoch 秒 (如 1779422649)
            // 偏移量 ≈ epoch 基准 - uptime 基准
            // 我们没有精确的 epoch 基准，但可以从已知 epoch mtime 估算
            // 使用一个保守的大偏移量确保新文件排在最前面
            // 偏移量需要确保: uptime + offset > max_existing_epoch_mtime (≈1779422650)
            // 即使设备重启后 uptime 从 0 开始，offset 也必须足够大
            // 1779458000 = 1779420000 + 36000 (36小时缓冲)，确保重启后新文件仍排在前面
            const UPTIME_TO_EPOCH_OFFSET = 1779458000;
            mtime = rawMtime + UPTIME_TO_EPOCH_OFFSET;
            HiLog.i(TAG, `mtime format conversion: ${fileName}, uptime=${rawMtime}, estimated epoch=${mtime}`);
          } else if (rawMtime >= 1000000000) {
            // 已经是 epoch 格式，直接使用
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
        // Date.now()/1000 也可能是 uptime 格式，加偏移量转为 epoch
        if (nowSec < 1000000000) {
          // uptime 格式 → 加偏移量转为 epoch，确保排序一致
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

      if (mtime > 0) {
        HiLog.i(TAG, `Content URI final mtime: ${fileName}, mtime=${mtime}, size=${size}`);
        const result: MtimeAndSizeResult = {
          mtime: mtime,
          size: size
        };
        return result;
      }

      return null;
    } catch (error) {
      HiLog.e(TAG, `Failed to get content URI metadata: ${uri}, error: ${error}`);
      return null;
    }
  }

  /**
   * 获取 MIME 类型
   */
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
   * 获取同步统计信息
   */
  getSyncStatistics(): SyncStatistics {
    const scanStats = this.scanStateManager.getScanStatistics();
    return {
      totalFiles: scanStats.totalFiles,
      syncedFiles: scanStats.scannedFiles,
      pendingFiles: scanStats.pendingFiles,
      lastSyncTime: scanStats.lastScanTime,
      isSyncInProgress: this.isSyncing
    };
  }

  /**
   * 检查是否正在同步
   */
  isSyncInProgress(): boolean {
    return this.isSyncing;
  }

  /**
   * 取消同步
   */
  cancelSync(): boolean {
    if (!this.isSyncing) {
      HiLog.w(TAG, 'Sync not in progress');
      return false;
    }

    try {
      this.isSyncing = false;
      this.scanStateManager.setScanning(false);
      HiLog.i(TAG, 'Sync cancelled');
      return true;
    } catch (error) {
      HiLog.e(TAG, `Failed to cancel sync: ${error}`);
      return false;
    }
  }

  /**
   * 释放资源
   */
  release(): void {
    this.cancelSync();
    this.scanStateManager.release();
    this.progressCallback = undefined;
    IncrementalSyncManager.instance = undefined;
    HiLog.i(TAG, 'Released IncrementalSyncManager resources');
  }
}
