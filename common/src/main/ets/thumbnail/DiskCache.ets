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


import image from '@ohos.multimedia.image';
import fs from '@ohos.file.fs';
import { HiLog } from '../utils/HiLog';
import { ThumbnailConfig } from './ThumbnailConfig';
import type common from '@ohos.app.ability.common';

const TAG = 'DiskCache';

export class DiskCache {
  private cacheDir: string;
  private context: common.Context;

  constructor(context: common.Context, storageDeviceUID: string = ThumbnailConfig.DEFAULT_STORAGE_DEVICE_UID) {
    this.context = context;
    this.cacheDir = `${context.filesDir}/${ThumbnailConfig.THUMBNAIL_CACHE_FOLDER_NAME}/${storageDeviceUID}/`;
    this.ensureCacheDir();
  }

  public getCachePath(key: string): string {
    return this.getFilePath(key);
  }

  public async get(key: string): Promise<string | undefined> {
    const filePath = this.getFilePath(key);
    try {
      if (fs.accessSync(filePath)) {
        return filePath;
      }
    } catch (error) {
      HiLog.d(TAG, `Cache file not found: ${filePath}`);
    }
    return undefined;
  }

  public async set(key: string, pixelMap: image.PixelMap): Promise<string> {
    const filePath = this.getFilePath(key);
    let imagePacker: image.ImagePacker | null = null;
    try {
      imagePacker = image.createImagePacker();
      const packOpts: image.PackingOption = {
        format: ThumbnailConfig.IMAGE_FORMAT,
        quality: ThumbnailConfig.IMAGE_QUALITY
      };

      // Use packing method to get ArrayBuffer, then write to file
      const packedData: ArrayBuffer = await imagePacker.packing(pixelMap, packOpts);

      // Write ArrayBuffer to file synchronously
      const file = fs.openSync(filePath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY);
      fs.writeSync(file.fd, packedData);
      fs.closeSync(file.fd);

      HiLog.d(TAG, `Thumbnail cached: ${filePath}`);
      return filePath;
    } catch (error) {
      HiLog.e(TAG, `Thumbnail cache failed: ${filePath}, error: ${error}`);
      try {
        if (fs.accessSync(filePath)) {
          fs.unlinkSync(filePath);
        }
      } catch (unlinkError) {
        HiLog.e(TAG, `Failed to delete failed file: ${filePath}, error: ${unlinkError}`);
      }
      return '';
    } finally {
      if (imagePacker) {
        await imagePacker.release();
      }
    }
  }

  public async has(key: string): Promise<boolean> {
    const filePath = this.getFilePath(key);
    try {
      return fs.accessSync(filePath);
    } catch (error) {
      return false;
    }
  }

  public async clear(keepRecentDays?: number): Promise<void> {
    try {
      if (!fs.accessSync(this.cacheDir)) {
        return;
      }

      if (keepRecentDays) {
        await this.cleanByAge(keepRecentDays);
      } else {
        fs.rmdirSync(this.cacheDir);
        this.ensureCacheDir();
      }
    } catch (error) {
      HiLog.e(TAG, `Failed to clean cache directory: ${this.cacheDir}, error: ${error}`);
    }
  }

  public async getSize(): Promise<number> {
    try {
      if (!fs.accessSync(this.cacheDir)) {
        return 0;
      }

      let totalSize = 0;
      const files = fs.listFileSync(this.cacheDir);

      for (const file of files) {
        const filePath = `${this.cacheDir}${file}`;
        const stat = fs.statSync(filePath);
        if (!stat.isDirectory()) {
          totalSize += stat.size;
        }
      }

      return totalSize;
    } catch (error) {
      HiLog.e(TAG, `Failed to get cache size: ${this.cacheDir}, error: ${error}`);
      return 0;
    }
  }

  public async cleanByAge(maxAgeDays: number): Promise<void> {
    try {
      if (!fs.accessSync(this.cacheDir)) {
        return;
      }

      const now = Date.now();
      const maxAgeMs = maxAgeDays * 24 * 60 * 60 * 1000;
      const files = fs.listFileSync(this.cacheDir);

      for (const file of files) {
        const filePath = `${this.cacheDir}${file}`;
        const stat = fs.statSync(filePath);

        if (stat.isDirectory()) {
          continue;
        }

        const fileAge = now - stat.mtime;
        if (fileAge > maxAgeMs) {
          try {
            fs.unlinkSync(filePath);
            HiLog.d(TAG, `Deleted expired cache file: ${filePath}`);
          } catch (error) {
            HiLog.e(TAG, `Failed to delete expired file: ${filePath}, error: ${error}`);
          }
        }
      }
    } catch (error) {
      HiLog.e(TAG, `Failed to clean cache by age: ${this.cacheDir}, error: ${error}`);
    }
  }

  private getFilePath(key: string): string {
    let cleanedKey = key
      .replace(/^file:\/\//, '')
      .replace(/^media:\/\//, '')
      .replace(/[\/\\:*\?"<>|%#&]/g, '_')
      .replace(/_+/g, '_')
      .substring(0, 100);
    
    return `${this.cacheDir}${cleanedKey}${ThumbnailConfig.THUMBNAIL_FILE_SUFFIX}`;
  }

  private ensureCacheDir(): void {
    try {
      if (!fs.accessSync(this.cacheDir)) {
        fs.mkdirSync(this.cacheDir, true);
        HiLog.d(TAG, `Created cache directory: ${this.cacheDir}`);
      }
    } catch (error) {
      HiLog.e(TAG, `Failed to create cache directory: ${this.cacheDir}, error: ${error}`);
    }
  }
}
