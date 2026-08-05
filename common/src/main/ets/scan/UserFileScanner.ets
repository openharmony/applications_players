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
import { HiTrace } from '../utils/HiTrace';
import { FileInfo } from '../utils/FileOperateInfo';
import userFileManager from '@ohos.filemanagement.userFileManager';
import dataSharePredicates from '@ohos.data.dataSharePredicates';
import type common from '@ohos.app.ability.common';
import { MediaType } from '../datasource/IMediaDataSource';
import fs from '@ohos.file.fs';
import { SupportedMediaFormats } from '../constants/media/SupportedMediaFormats';

const TAG = 'UserFileScanner';

export class UserFileScanner {
  private static readonly BATCH_SIZE: number = 20;
  private context: common.Context;
  private userFileMgr: userFileManager.UserFileManager | null = null;

  constructor(context: common.Context) {
    HiTrace.begin(TAG, 'create UserFileScanner');
    this.context = context;
    this.initUserFileManager();
    HiTrace.end(TAG, 'create UserFileScanner');
  }

  private initUserFileManager(): void {
    if (!this.userFileMgr) {
      try {
        this.userFileMgr = userFileManager.getUserFileMgr(this.context);
        HiLog.i(TAG, 'UserFileManager init success');
      } catch (error) {
        HiLog.e(TAG, 'UserFileManager init error: ' + error);
      }
    }
  }

  async scanPublicAudioFiles(): Promise<FileInfo[]> {
    try {
      HiLog.i(TAG, 'Starting public directory audio scan');

      if (!this.userFileMgr) {
        HiLog.e(TAG, 'UserFileManager not initialized');
        return [];
      }

      const predicates: dataSharePredicates.DataSharePredicates = 
        new dataSharePredicates.DataSharePredicates();
      predicates.greaterThan('duration', 0);

      const fetchOptions: userFileManager.FetchOptions = {
        fetchColumns: ['duration'],
        predicates: predicates
      };

      const fetchResult = await this.userFileMgr.getAudioAssets(fetchOptions);
      const fileAssets = await fetchResult.getAllObject();
      
      HiLog.i(TAG, `Audio files found (duration>0): ${fileAssets.length}`);

      const audioFiles = await this.batchConvertWithSize(fileAssets, MediaType.AUDIO);
      
      HiLog.i(TAG, 'Public directory audio scan completed: ' + audioFiles.length + ' files');
      return audioFiles;
    } catch (error) {
      HiLog.e(TAG, 'Public directory audio scan failed: ' + error);
      return [];
    }
  }

  async scanPublicVideoFiles(): Promise<FileInfo[]> {
    try {
      HiLog.i(TAG, 'Starting public directory video scan');
      
      if (!this.userFileMgr) {
        HiLog.e(TAG, 'UserFileManager not initialized');
        return [];
      }

      // 修复：getPhotoAssets 需要包含 'duration' 在 fetchColumns 中，
      // 否则 asset.get('duration') 返回 0，导致所有资产被过滤掉（0个视频文件）
      // 使用 greaterThan('duration', 0) predicate 直接过滤出视频（duration > 0）
      // 这样不需要在 JS 中逐个检查 duration，且 predicate 已被证明不会导致 invalid parameter
      // 注意：不能使用 ['title', 'dateModified', 'size'] 等 fetchColumns（会报 invalid parameter）
      // 只用 ['duration'] — 与 getAudioAssets 的 fetchColumns 格式一致
      const predicates: dataSharePredicates.DataSharePredicates = 
        new dataSharePredicates.DataSharePredicates();
      predicates.greaterThan('duration', 0);

      const fetchOptions: userFileManager.FetchOptions = {
        fetchColumns: ['duration'],
        predicates: predicates
      };

      const fetchResult = await this.userFileMgr.getPhotoAssets(fetchOptions);
      const fileAssets = await fetchResult.getAllObject();
      
      HiLog.i(TAG, `Video files found (duration>0): ${fileAssets.length}`);

      const videoFiles = await this.batchConvertWithSize(fileAssets, MediaType.VIDEO);
      
      HiLog.i(TAG, 'Public directory video scan completed: ' + videoFiles.length + ' files');
      return videoFiles;
    } catch (error) {
      HiLog.e(TAG, 'Public directory video scan failed: ' + error);
      return [];
    }
  }

  async scanAllPublicMediaFiles(): Promise<FileInfo[]> {
    try {
      HiLog.i(TAG, 'Starting all public media file scan');
      
      const results = await Promise.all([
        this.scanPublicAudioFiles(),
        this.scanPublicVideoFiles()
      ]);
      const audioFiles = results[0];
      const videoFiles = results[1];
      
      const allFiles: FileInfo[] = [...audioFiles, ...videoFiles];
      HiLog.i(TAG, 'All public media scan completed: ' + allFiles.length + ' files');
      return allFiles;
    } catch (error) {
      HiLog.e(TAG, 'Public directory media scan failed: ' + error);
      return [];
    }
  }

  private async batchConvertWithSize(
    assets: userFileManager.FileAsset[],
    mediaType: MediaType
  ): Promise<FileInfo[]> {
    if (assets.length === 0) {
      return [];
    }

    const results: FileInfo[] = [];
    const batchSize = UserFileScanner.BATCH_SIZE;
    const totalBatches = Math.ceil(assets.length / batchSize);

    HiLog.i(TAG, `Starting batch processing: total=${assets.length}, batches=${totalBatches}, batch size=${batchSize}`);

    for (let i = 0; i < totalBatches; i++) {
      const start = i * batchSize;
      const end = Math.min(start + batchSize, assets.length);
      const batch = assets.slice(start, end);

      const batchPromises: Promise<FileInfo>[] = [];
      for (const asset of batch) {
        batchPromises.push(this.convertFileAssetToFileInfoAsync(asset, mediaType));
      }

      try {
        const batchResults: FileInfo[] = await Promise.all(batchPromises);
        for (const fileInfo of batchResults) {
          if (UserFileScanner.isSupportedAsset(fileInfo, mediaType)) {
            results.push(fileInfo);
          }
        }
        HiLog.i(TAG, `Batch ${i + 1}/${totalBatches} done, processed ${results.length}/${assets.length} files`);
      } catch (error) {
        HiLog.e(TAG, `Batch ${i + 1} processing failed: ${error}`);
        for (const asset of batch) {
          try {
            const fileInfo = await this.convertFileAssetToFileInfoAsync(asset, mediaType);
            if (UserFileScanner.isSupportedAsset(fileInfo, mediaType)) {
              results.push(fileInfo);
            }
          } catch (e) {
            HiLog.e(TAG, `Single file processing failed: ${asset.displayName}`);
          }
        }
      }
    }

    return results;
  }

private async convertFileAssetToFileInfoAsync(
    asset: userFileManager.FileAsset,
    mediaType: MediaType
  ): Promise<FileInfo> {
    const fileInfo: FileInfo = new FileInfo();

    fileInfo.fileName = asset.displayName;
    fileInfo.uri = asset.uri;
    fileInfo.path = asset.uri;
    fileInfo.mimeType = mediaType === MediaType.AUDIO ? 'audio/*' : 'video/*';
    fileInfo.isExternalStorageDeviceFile = true;
    fileInfo.thumbGenerated = false;

    // 获取 duration (fetchColumns 中包含，对音频和视频均可获取)
    try {
      fileInfo.duration = asset.get('duration') as number || 0;
    } catch (e) {
      HiLog.e(TAG, `Failed to get duration: ${asset.displayName}, error: ${e}`);
      fileInfo.duration = 0;
    }

    // 尝试从 asset.get('dateModified') 获取 mtime (视频 fetchColumns 包含此列)
    // 音频 FileAsset 不支持此属性，需通过 fs.stat(fd) 获取
    let mtimeFromAsset = false;
    let ctimeFromAsset = false;
    try {
      const dateModified = asset.get('dateModified') as number;
      if (dateModified > 0) {
        fileInfo.mtime = dateModified / 1000; // 毫秒转秒
        mtimeFromAsset = true;
      }
    } catch (e) {
      // 音频 FileAsset 不支持 dateModified，将通过 fd stat 获取
    }

    try {
      const dateAdded = asset.get('DATE_ADDED') as number;
      if (dateAdded > 0) {
        fileInfo.ctime = dateAdded / 1000;
        ctimeFromAsset = true;
      }
    } catch (e) {
    }

    if (!ctimeFromAsset) {
      try {
        const dateAdded = asset.get('dateAdded') as number;
        if (dateAdded > 0) {
          fileInfo.ctime = dateAdded / 1000;
          ctimeFromAsset = true;
        }
      } catch (e) {
      }
    }

    // 尝试从 asset.get('size') 获取 size (视频 fetchColumns 包含此列)
    // 音频 FileAsset 不支持此属性，需通过 fs.stat(fd) 获取
    let sizeFromAsset = false;
    try {
      const size = asset.get('size') as number;
      if (size && size > 0) {
        fileInfo.size = size;
        sizeFromAsset = true;
      }
    } catch (e) {
      // 音频 FileAsset 不支持 size，将通过 fd stat 获取
    }

    // 如果 mtime 或 size 未通过 asset.get() 获取成功，通过 fd stat 补充获取
    if (!mtimeFromAsset || !sizeFromAsset) {
      try {
        const fd = await asset.open('r');
        const stat = await fs.stat(fd);
        await asset.close(fd);
        if (!mtimeFromAsset) {
          const rawMtime = stat.mtime; // fs.stat.mtime 单位为秒，但格式可能不一致
          // mtime 格式统一：fs.stat(fd).mtime 在设备上可能返回两种格式：
          // 1. epoch 秒 (> 1000000000，如 1779422649) — 正确的 Unix epoch 格式
          // 2. uptime 秒 (< 1000000000，如 862, 35801) — 设备启动以来的秒数
          // uptime 格式的 mtime 排序会排在 epoch 格式之后，导致新文件不在列表首位
          // 偏移量 1779458000 = 1779420000 + 36000 (36小时缓冲，应对设备重启边界情况)
          if (rawMtime < 1000000000) {
            fileInfo.mtime = rawMtime + 1779458000;
            HiLog.i(TAG, `mtime format conversion: ${asset.displayName}, uptime=${rawMtime}, epoch=${fileInfo.mtime}`);
          } else {
            fileInfo.mtime = rawMtime;
          }
        }
        if (!ctimeFromAsset) {
          fileInfo.ctime = fileInfo.mtime;
        }
        if (!sizeFromAsset) {
          fileInfo.size = stat.size;
        }
        HiLog.i(TAG, `fd stat: ${asset.displayName}, mtime=${fileInfo.mtime}, size=${fileInfo.size}`);
      } catch (e) {
        HiLog.e(TAG, `Failed to get file metadata via fd: ${asset.displayName}, error: ${e}`);
      }
    }

    if (mediaType === MediaType.VIDEO) {
      try {
        fileInfo.picWidth = asset.get('width') as number || 0;
      } catch (e) {
        fileInfo.picWidth = 0;
      }
      try {
        fileInfo.picHeight = asset.get('height') as number || 0;
      } catch (e) {
        fileInfo.picHeight = 0;
      }
    }

    return fileInfo;
  }

  private static isSupportedAsset(fileInfo: FileInfo, mediaType: MediaType): boolean {
    if (mediaType === MediaType.AUDIO) {
      return SupportedMediaFormats.isSupportedAudio(fileInfo.fileName);
    }
    if (mediaType === MediaType.VIDEO) {
      return SupportedMediaFormats.isSupportedVideo(fileInfo.fileName);
    }
    return SupportedMediaFormats.isSupportedMedia(fileInfo.fileName);
  }

  isReady(): boolean {
    return this.userFileMgr !== null;
  }

  getUserFileManager(): userFileManager.UserFileManager | null {
    return this.userFileMgr;
  }
}
