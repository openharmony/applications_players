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


import photoAccessHelper from '@ohos.file.photoAccessHelper';
import dataSharePredicates from '@ohos.data.dataSharePredicates';
import { HiLog } from '../utils/HiLog';
import { FileInfo } from '../utils/FileOperateInfo';
import type common from '@ohos.app.ability.common';
import { SystemCache } from '../thumbnail/SystemCache';
import { SupportedMediaFormats } from '../constants/media/SupportedMediaFormats';

const TAG = 'MediaLibraryScanner';

export class MediaLibraryScanner {
  private context: common.Context;
  private helper: photoAccessHelper.PhotoAccessHelper | null = null;

  constructor(context: common.Context) {
    this.context = context;
  }

  private initHelper(): void {
    if (!this.helper) {
      this.helper = photoAccessHelper.getPhotoAccessHelper(this.context);
    }
  }

  private resolveCreateTime(asset: photoAccessHelper.PhotoAsset, fallbackTime: number): number {
    try {
      const dateAdded = asset.get('DATE_ADDED') as number;
      if (dateAdded > 0) {
        return dateAdded / 1000;
      }
    } catch (error) {
    }

    try {
      const dateAdded = asset.get('dateAdded') as number;
      if (dateAdded > 0) {
        return dateAdded / 1000;
      }
    } catch (error) {
    }

    return fallbackTime;
  }

async scanVideoFiles(): Promise<FileInfo[]> {
    const videoFiles: FileInfo[] = [];
    
    try {
      this.initHelper();
      
      // 修复：fetchColumns 必须使用 PhotoKeys 定义的 snake_case 列名
      // 之前的 camelCase 列名 ('displayName', 'dateModified') 导致 "invalid parameter"
      // 之前的空 fetchColumns 导致 asset.get() 报 "member not exist"
      // 正确列名参考 photoAccessHelper.PhotoKeys: URI='uri', PHOTO_TYPE='media_type',
      // DISPLAY_NAME='display_name', SIZE='size', DATE_MODIFIED='date_modified',
      // DURATION='duration', WIDTH='width', HEIGHT='height'
      // 注意：uri 和 display_name 是默认列（always fetched），但需显式指定其他列
      const fetchOptions: photoAccessHelper.FetchOptions = {
        fetchColumns: [
          photoAccessHelper.PhotoKeys.PHOTO_TYPE,
          photoAccessHelper.PhotoKeys.SIZE,
          photoAccessHelper.PhotoKeys.DATE_MODIFIED,
          photoAccessHelper.PhotoKeys.DURATION,
          photoAccessHelper.PhotoKeys.WIDTH,
          photoAccessHelper.PhotoKeys.HEIGHT
        ],
        predicates: new dataSharePredicates.DataSharePredicates()
      };
      
      const fetchResult = await this.helper!.getAssets(fetchOptions);
      const count = fetchResult.getCount();
      
      HiLog.i(TAG, 'Media library total assets: ' + count);
      
      const allAssets: photoAccessHelper.PhotoAsset[] = await fetchResult.getAllObjects();
      
      // 过滤：仅包含 photoType 为 VIDEO 的资产（使用 asset.photoType 属性）
      for (const asset of allAssets) {
        // 使用 PhotoAsset 的 photoType 属性（默认列）而非 asset.get('media_type')
        if (asset.photoType !== photoAccessHelper.PhotoType.VIDEO) {
          continue;
        }
        if (!SupportedMediaFormats.isSupportedVideo(asset.displayName)) {
          continue;
        }

        const fileInfo: FileInfo = new FileInfo();

        fileInfo.fileName = asset.displayName;
        fileInfo.uri = asset.uri;
        fileInfo.path = asset.uri;
        fileInfo.size = asset.get(photoAccessHelper.PhotoKeys.SIZE) as number || 0;
        fileInfo.mtime = (asset.get(photoAccessHelper.PhotoKeys.DATE_MODIFIED) as number) / 1000;
        fileInfo.ctime = this.resolveCreateTime(asset, fileInfo.mtime);
        fileInfo.mimeType = 'video/*';
        fileInfo.duration = asset.get(photoAccessHelper.PhotoKeys.DURATION) as number || 0;
        fileInfo.picWidth = asset.get(photoAccessHelper.PhotoKeys.WIDTH) as number || 0;
        fileInfo.picHeight = asset.get(photoAccessHelper.PhotoKeys.HEIGHT) as number || 0;

        fileInfo.timesStampApp = Date.now();
        fileInfo.thumbnailModifiledMs = fileInfo.mtime;

        const systemThumbUri: string = SystemCache.getThumbnailUri(fileInfo);
        if (systemThumbUri) {
          fileInfo.thumbUri = systemThumbUri;
          fileInfo.thumbGenerated = true;
        }

        videoFiles.push(fileInfo);
      }
      
      fetchResult.close();
      HiLog.i(TAG, 'Media library video scan completed: ' + videoFiles.length + ' (total assets: ' + count + ')');
    } catch (error) {
      HiLog.e(TAG, 'Media library video scan failed: ' + error);
    }
    
    return videoFiles;
  }

  async scanImageFiles(): Promise<FileInfo[]> {
    const imageFiles: FileInfo[] = [];
    
    try {
      this.initHelper();
      
      // 修复：与 scanVideoFiles 一致，使用 PhotoKeys snake_case 列名
      const fetchOptions: photoAccessHelper.FetchOptions = {
        fetchColumns: [
          photoAccessHelper.PhotoKeys.PHOTO_TYPE,
          photoAccessHelper.PhotoKeys.SIZE,
          photoAccessHelper.PhotoKeys.DATE_MODIFIED,
          photoAccessHelper.PhotoKeys.WIDTH,
          photoAccessHelper.PhotoKeys.HEIGHT
        ],
        predicates: new dataSharePredicates.DataSharePredicates()
      };
      
      const fetchResult = await this.helper!.getAssets(fetchOptions);
      const count = fetchResult.getCount();
      
      HiLog.i(TAG, 'Media library total assets: ' + count);
      
      const allAssets: photoAccessHelper.PhotoAsset[] = await fetchResult.getAllObjects();
      
      // 过滤：仅包含 photoType 为 IMAGE 的资产
      for (const asset of allAssets) {
        if (asset.photoType !== photoAccessHelper.PhotoType.IMAGE) {
          continue;
        }

        const fileInfo: FileInfo = new FileInfo();

        fileInfo.fileName = asset.displayName;
        fileInfo.uri = asset.uri;
        fileInfo.path = asset.uri;
        fileInfo.size = asset.get(photoAccessHelper.PhotoKeys.SIZE) as number || 0;
        fileInfo.mtime = (asset.get(photoAccessHelper.PhotoKeys.DATE_MODIFIED) as number) / 1000;
        fileInfo.ctime = this.resolveCreateTime(asset, fileInfo.mtime);
        fileInfo.mimeType = 'image/*';
        fileInfo.picWidth = asset.get(photoAccessHelper.PhotoKeys.WIDTH) as number || 0;
        fileInfo.picHeight = asset.get(photoAccessHelper.PhotoKeys.HEIGHT) as number || 0;

        fileInfo.timesStampApp = Date.now();
        fileInfo.thumbnailModifiledMs = fileInfo.mtime;

        const systemThumbUri: string = SystemCache.getThumbnailUri(fileInfo);
        if (systemThumbUri) {
          fileInfo.thumbUri = systemThumbUri;
          fileInfo.thumbGenerated = true;
        }

        imageFiles.push(fileInfo);
      }
      
      fetchResult.close();
      HiLog.i(TAG, 'Media library image scan completed: ' + imageFiles.length + ' (total assets: ' + count + ')');
    } catch (error) {
      HiLog.e(TAG, 'Media library image scan failed: ' + error);
    }
    
    return imageFiles;
  }

  async scanAllMediaFiles(): Promise<FileInfo[]> {
    try {
      HiLog.i(TAG, 'Starting media library video scan');
      const videoFiles = await this.scanVideoFiles();
      HiLog.i(TAG, 'Media library video scan completed: ' + videoFiles.length);
      return videoFiles;
    } catch (error) {
      HiLog.e(TAG, 'Media library video scan failed: ' + error);
      return [];
    }
  }

  isReady(): boolean {
    this.initHelper();
    return this.helper !== null;
  }
}
