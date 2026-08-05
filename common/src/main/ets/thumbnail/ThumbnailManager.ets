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
import { HiLog } from '../utils/HiLog';
import { MediaPlaybackFileOpener } from '../utils/MediaPlaybackFileOpener';
import { ThumbnailConfig } from './ThumbnailConfig';
import { MemoryCache } from './MemoryCache';
import { DiskCache } from './DiskCache';
import { SystemCache } from './SystemCache';
import { ImageProcessor } from './ImageProcessor';
import type common from '@ohos.app.ability.common';
import media from '@ohos.multimedia.media';
import image from '@ohos.multimedia.image';
import fs from '@ohos.file.fs';
import storageStatistics from '@ohos.file.storageStatistics';

const TAG = 'ThumbnailManager';

/** 批量生成封面的结果对象 */
export interface GenerateBatchResult {
  /** uri → 封面 URI 映射 */
  results: Map<string, string>;
  /** 封面提取失败的文件列表 */
  failedItems: FileInfo[];
}

/** 已打开的媒体文件句柄，供 AV 框架 fdSrc 使用 */
class MediaFileReadHandle {
  fd: number;
  size: number;

  constructor(fd: number, size: number) {
    this.fd = fd;
    this.size = size;
  }
}

export class ThumbnailManager {
  private static instance: ThumbnailManager | null = null;
  private context: common.Context;
  private memoryCache: MemoryCache;
  private diskCache: DiskCache;
  private lastCleanTime: number = 0;

  private constructor(context: common.Context) {
    this.context = context;
    this.memoryCache = new MemoryCache(50);
    this.diskCache = new DiskCache(context);
  }

  public static getInstance(context?: common.Context): ThumbnailManager {
    if (!ThumbnailManager.instance) {
      if (!context) {
        throw new Error('ThumbnailManager 需要上下文参数进行初始化');
      }
      ThumbnailManager.instance = new ThumbnailManager(context);
    }
    return ThumbnailManager.instance;
  }

  public static reset(): void {
    if (ThumbnailManager.instance) {
      ThumbnailManager.instance.memoryCache.clear();
      ThumbnailManager.instance = null;
    }
  }

  /**
   * Release all cached resources
   * Called when Ability is destroyed to prevent memory leaks
   */
  public releaseAll(): void {
    HiLog.i(TAG, 'Releasing all cache resources');
    this.memoryCache.clear();
  }

  /** 读取已存储封面 URI（音频 coverUri，视频 thumbUri） */
  public static getStoredUri(fileInfo: FileInfo): string {
    if (fileInfo.mimeType.startsWith('audio/')) {
      return fileInfo.coverUri || '';
    }
    return fileInfo.thumbUri || '';
  }

  /** 是否仍缺少封面，需要后台生成 */
  public static needsGeneration(fileInfo: FileInfo): boolean {
    return ThumbnailManager.getStoredUri(fileInfo).length === 0;
  }

  public async generateThumbnail(fileInfo: FileInfo): Promise<string> {
    if (!fileInfo || !fileInfo.uri) {
      HiLog.e(TAG, 'FileInfo or URI is empty');
      return '';
    }

    const existingUri = ThumbnailManager.getStoredUri(fileInfo);
    if (fileInfo.thumbGenerated && existingUri.length > 0) {
      return existingUri;
    }

    try {
      this.checkMemoryCacheSize();

      if (SystemCache.isMediaLibraryFile(fileInfo.uri)) {
        const systemUri = SystemCache.getThumbnailUri(fileInfo);
        if (systemUri) {
          return this.applyThumbnailUri(fileInfo, systemUri);
        }
      }

      const cacheKey = this.getCacheKey(fileInfo);

      const memoryCached = this.memoryCache.get(cacheKey);
      if (memoryCached) {
        HiLog.i(TAG, `Memory cache hit: ${fileInfo.fileName}`);
        const cachedUri = this.resolveCachedThumbnailUri(fileInfo, cacheKey);
        if (cachedUri.length > 0) {
          return cachedUri;
        }
      }

      const diskCached = await this.diskCache.get(cacheKey);
      if (diskCached) {
        HiLog.i(TAG, `Disk cache hit: ${fileInfo.fileName}`);
        const thumbnailUri = `${ThumbnailConfig.THUMBNAIL_CACHE_PATH_PREFIX}${diskCached}`;
        return this.applyThumbnailUri(fileInfo, thumbnailUri);
      }

      return await this.generateCustomThumbnail(fileInfo, cacheKey);
    } catch (error) {
      HiLog.e(TAG, `Thumbnail generation failed: ${fileInfo.fileName}, error: ${error}`);
      return '';
    }
  }

  /**
   * 批量生成封面（并发数见 ThumbnailConfig.MAX_CONCURRENT_TASKS）
   *
   * @param fileInfos 待处理文件列表
   * @returns 包含成功映射和失败列表的结果对象
   */
  public async generateBatch(fileInfos: FileInfo[]): Promise<GenerateBatchResult> {
    const results = new Map<string, string>();
    const failedItems: FileInfo[] = [];
    const batchSize = ThumbnailConfig.MAX_CONCURRENT_TASKS;

    for (let i = 0; i < fileInfos.length; i += batchSize) {
      const batch = fileInfos.slice(i, i + batchSize);
      const promises = batch.map(async (fileInfo) => {
        const thumbUri = await this.generateThumbnail(fileInfo);
        results.set(fileInfo.uri, thumbUri);
        // 封面提取失败的文件收集到失败列表
        if (!thumbUri || thumbUri.length === 0) {
          failedItems.push(fileInfo);
        }
      });

      await Promise.all(promises);
    }

    return { results, failedItems };
  }

  public async cleanCache(force: boolean = false): Promise<void> {
    const now = Date.now();
    const timeSinceLastClean = now - this.lastCleanTime;

    if (!force && timeSinceLastClean < ThumbnailConfig.CLEAN_INTERVAL) {
      HiLog.i(TAG, 'Time since last clean insufficient, skipping');
      return;
    }

    try {
      // Log current memory cache size before cleaning
      HiLog.i(TAG, `Memory cache size before cleaning: ${Math.round(this.memoryCache.getCurrentSize() / 1024 / 1024)}MB`);

      const needDeepClean = await this.checkStorageSpace();

      if (needDeepClean) {
        HiLog.i(TAG, 'Performing deep clean');
        await this.deepClean();
      } else {
        HiLog.i(TAG, 'Performing regular clean');
        await this.diskCache.clear();
        this.memoryCache.clear();
      }

      // Log memory cache size after cleaning
      HiLog.i(TAG, `Memory cache size after cleaning: ${Math.round(this.memoryCache.getCurrentSize() / 1024 / 1024)}MB`);

      this.lastCleanTime = now;
      HiLog.i(TAG, 'Cache cleaning complete');
    } catch (error) {
      HiLog.e(TAG, `Cache clean failed: ${error}`);
    }
  }

  public async deepClean(): Promise<void> {
    try {
      const keepDays = 30;
      await this.diskCache.clear(keepDays);
      this.memoryCache.clear();
      HiLog.i(TAG, `Deep clean complete, keeping last ${keepDays} days of cache`);
    } catch (error) {
      HiLog.e(TAG, `Deep clean failed: ${error}`);
    }
  }

  public async cleanUsbCache(usbDeviceUidList: string[]): Promise<void> {
    try {
      const now = Date.now();
      const timeSinceLastClean = now - this.lastCleanTime;

      if (timeSinceLastClean < ThumbnailConfig.USB_CLEAN_INTERVAL) {
        HiLog.i(TAG, 'Time since last USB clean insufficient, skipping');
        return;
      }

      for (const uid of usbDeviceUidList) {
        const usbCache = new DiskCache(this.context, uid);
        await usbCache.clear();
      }

      this.lastCleanTime = now;
      HiLog.i(TAG, 'USB Cache cleaning complete');
    } catch (error) {
      HiLog.e(TAG, `USB cache clean failed: ${error}`);
    }
  }

  public async checkStorageSpace(): Promise<boolean> {
    try {
      const freeSize = await storageStatistics.getFreeSize();
      const needDeepClean = freeSize < ThumbnailConfig.DEEP_CLEAN_THRESHOLD;

      if (needDeepClean) {
        HiLog.w(TAG, `Storage space low: ${Math.round(freeSize / 1024 / 1024)}MB, deep clean needed`);
      }

      return needDeepClean;
    } catch (error) {
      HiLog.e(TAG, `Storage space check failed: ${error}`);
      return false;
    }
  }

  public async getCacheSize(): Promise<number> {
    try {
      return await this.diskCache.getSize();
    } catch (error) {
      HiLog.e(TAG, `Failed to get cache size: ${error}`);
      return 0;
    }
  }

  /**
   * Get memory cache size in bytes
   */
  public getMemoryCacheSize(): number {
    return this.memoryCache.getCurrentSize();
  }

  /**
   * Get memory cache max size in bytes
   */
  public getMemoryCacheMaxSize(): number {
    return this.memoryCache.getMaxCacheSize();
  }

  /**
   * Get memory cache instance for testing purposes
   */
  public getMemoryCache(): MemoryCache {
    return this.memoryCache;
  }

  /**
   * Check memory cache size and log if approaching limit
   */
  public checkMemoryCacheSize(): void {
    const currentSize = this.memoryCache.getCurrentSize();
    const maxSize = this.memoryCache.getMaxCacheSize();
    const usagePercent = (currentSize / maxSize) * 100;

    if (usagePercent > 80) {
      HiLog.w(TAG, `Memory cache usage high: ${Math.round(usagePercent)}% (${Math.round(currentSize / 1024 / 1024)}MB / ${Math.round(maxSize / 1024 / 1024)}MB)`);
    } else {
      HiLog.i(TAG, `Memory cache usage: ${Math.round(usagePercent)}% (${Math.round(currentSize / 1024 / 1024)}MB / ${Math.round(maxSize / 1024 / 1024)}MB)`);
    }
  }

  // 获取封面
  private async generateCustomThumbnail(fileInfo: FileInfo, cacheKey: string): Promise<string> {
    try {
      HiLog.w(TAG, `Extracting thumbnail: ${fileInfo.fileName}`);
      let pixelMap: image.PixelMap | undefined = undefined;

      if (fileInfo.mimeType.startsWith('audio/')) {
        pixelMap = await this.extractAudioCover(fileInfo);
      } else if (fileInfo.mimeType.startsWith('video/')) {
        pixelMap = await this.extractVideoThumbnail(fileInfo);
      } else {
        HiLog.w(TAG, `Unsupported media type: ${fileInfo.mimeType}`);
        return '';
      }

      if (!pixelMap) {
        HiLog.w(TAG, `Failed to extract thumbnail: ${fileInfo.fileName}`);
        return '';
      }

      HiLog.w(TAG, `Thumbnail extracted: ${fileInfo.fileName}`);

      let processedPixelMap: image.PixelMap = pixelMap;

      if (fileInfo.mimeType.startsWith('video/')) {
        processedPixelMap = await ImageProcessor.cropToRatio(pixelMap, ThumbnailConfig.VIDEO_COVER_RATIO, 'center');
        processedPixelMap = await ImageProcessor.resizeWithAspectRatio(processedPixelMap, ThumbnailConfig.VIDEO_THUMB_HEIGHT);
      } else {
        processedPixelMap = await ImageProcessor.limitAspectRatio(pixelMap, ThumbnailConfig.MAX_IMAGE_ASPECT_RATIO);
        processedPixelMap = await ImageProcessor.resizeWithAspectRatio(processedPixelMap, ThumbnailConfig.THUMBNAIL_SIZE);
      }

      const cachePath = this.diskCache.getCachePath(cacheKey);
      const saved = await ImageProcessor.saveAsJpg(processedPixelMap, cachePath, ThumbnailConfig.IMAGE_QUALITY);

      if (saved) {
        await this.memoryCache.set(cacheKey, processedPixelMap);
        const thumbnailUri = `${ThumbnailConfig.THUMBNAIL_CACHE_PATH_PREFIX}${cachePath}`;
        this.applyThumbnailUri(fileInfo, thumbnailUri);

        await pixelMap.release();
        if (processedPixelMap !== pixelMap) {
          await processedPixelMap.release();
        }

        return ThumbnailManager.getStoredUri(fileInfo);
      }

      await pixelMap.release();
      if (processedPixelMap !== pixelMap) {
        await processedPixelMap.release();
      }
      return '';
    } catch (error) {
      HiLog.e(TAG, `Custom thumbnail generation failed: ${fileInfo.fileName}, error: ${error}`);
      return '';
    }
  }

  /**
   * 依次尝试 uri / path 打开媒体文件供 fdSrc 读取（AVImageGenerator 仅支持 fdSrc）
   *
   * @param fileInfo 媒体文件
   * @returns 文件描述符与大小，均失败时返回 undefined
   */
  private openMediaFileReadOnly(fileInfo: FileInfo): MediaFileReadHandle | undefined {
    const targets: string[] = [];
    if (fileInfo.uri.length > 0) {
      targets.push(fileInfo.uri);
    }
    if (fileInfo.path && fileInfo.path.length > 0 && fileInfo.path !== fileInfo.uri) {
      targets.push(fileInfo.path);
    }

    for (const target of targets) {
      try {
        const file = fs.openSync(target, fs.OpenMode.READ_ONLY);
        const stat = fs.statSync(file.fd);
        return new MediaFileReadHandle(file.fd, stat.size);
      } catch (error) {
        HiLog.w(TAG, `Failed to open media file target=${target} fileName=${fileInfo.fileName}`);
      }
    }
    return undefined;
  }

  private async extractAudioCover(fileInfo: FileInfo): Promise<image.PixelMap | undefined> {
    let avMetadataExtractor: media.AVMetadataExtractor | undefined = undefined;
    let opened = await MediaPlaybackFileOpener.openReadOnly(fileInfo.uri, fileInfo.fileName);

    try {
      avMetadataExtractor = await media.createAVMetadataExtractor();

      if (opened) {
        avMetadataExtractor.fdSrc = {
          fd: opened.fd,
          offset: 0,
          length: opened.size
        };
      } else {
        HiLog.w(TAG, `Audio cover fd open failed, falling back to setUrlSource: ${fileInfo.fileName}`);
        avMetadataExtractor.setUrlSource(fileInfo.uri);
      }

      const pixelMap = await avMetadataExtractor.fetchAlbumCover();

      if (pixelMap) {
        HiLog.i(TAG, `Audio cover extracted: ${fileInfo.fileName}`);
      }

      return pixelMap;
    } catch (error) {
      HiLog.e(TAG, `Audio cover extraction failed: ${fileInfo.fileName}, error=${error}`);
      return undefined;
    } finally {
      if (avMetadataExtractor) {
        await avMetadataExtractor.release();
      }
      if (opened) {
        await opened.release();
      }
    }
  }

  private async extractVideoThumbnail(fileInfo: FileInfo): Promise<image.PixelMap | undefined> {
    let avImageGenerator: media.AVImageGenerator | undefined = undefined;
    const opened = await MediaPlaybackFileOpener.openReadOnly(fileInfo.uri, fileInfo.fileName);

    try {
      avImageGenerator = await media.createAVImageGenerator();

      if (!opened) {
        HiLog.e(TAG, `Video thumbnail cannot open file (AVImageGenerator only supports fdSrc): ${fileInfo.fileName}`);
        return undefined;
      }
      avImageGenerator.fdSrc = {
        fd: opened.fd,
        offset: 0,
        length: opened.size
      };

      const options = media.AVImageQueryOptions.AV_IMAGE_QUERY_NEXT_SYNC;
      const param: media.PixelMapParams = {
        width: ThumbnailConfig.VIDEO_THUMB_WIDTH,
        height: ThumbnailConfig.VIDEO_THUMB_HEIGHT
      };

      // 优先取第0秒关键帧；失败后回退到第1秒重试，应对部分容器第0帧非关键帧/解码超时
      let pixelMap: image.PixelMap | undefined = undefined;
      try {
        pixelMap = await avImageGenerator.fetchFrameByTime(0, options, param);
      } catch (e) {
        HiLog.w(TAG, `fetchFrameByTime(0s) failed, retry 1s: ${fileInfo.fileName}`);
      }
      if (!pixelMap) {
        try {
          pixelMap = await avImageGenerator.fetchFrameByTime(1000000, options, param);
        } catch (e) {
          HiLog.w(TAG, `fetchFrameByTime(1s) failed: ${fileInfo.fileName}`);
        }
      }

      if (pixelMap) {
        HiLog.i(TAG, `Video thumbnail extracted: ${fileInfo.fileName}`);
      }

      return pixelMap;
    } catch (error) {
      HiLog.e(TAG, `Video thumbnail extraction failed: ${fileInfo.fileName}, error=${error}`);
      return undefined;
    } finally {
      if (avImageGenerator) {
        await avImageGenerator.release();
      }
      if (opened) {
        await opened.release();
      }
    }
  }

  /**
   * 内存/磁盘缓存命中时，将缓存路径写回 FileInfo 并返回可用 URI
   *
   * @param fileInfo 媒体文件
   * @param cacheKey 缓存键
   * @returns 缩略图 URI，无法解析时返回空串
   */
  private resolveCachedThumbnailUri(fileInfo: FileInfo, cacheKey: string): string {
    const existingUri = ThumbnailManager.getStoredUri(fileInfo);
    if (existingUri.length > 0) {
      return existingUri;
    }
    const cachePath = this.diskCache.getCachePath(cacheKey);
    const thumbnailUri = `${ThumbnailConfig.THUMBNAIL_CACHE_PATH_PREFIX}${cachePath}`;
    return this.applyThumbnailUri(fileInfo, thumbnailUri);
  }

  /** 按媒体类型写入 coverUri / thumbUri 并标记已生成 */
  private applyThumbnailUri(fileInfo: FileInfo, uri: string): string {
    if (fileInfo.mimeType.startsWith('audio/')) {
      fileInfo.coverUri = uri;
    } else {
      fileInfo.thumbUri = uri;
    }
    fileInfo.thumbGenerated = true;
    return uri;
  }

  private getCacheKey(fileInfo: FileInfo): string {
    let key = fileInfo.fileName || '';
    
    if (fileInfo.size > 0) {
      key += `_${fileInfo.size}`;
    }
    if (fileInfo.mtime > 0) {
      key += `_${fileInfo.mtime}`;
    }
    if (fileInfo.mimeType.startsWith('video/')) {
      key += ThumbnailConfig.VIDEO_THUMB_CACHE_SUFFIX;
    }
    
    key = key
      .replace(/^file:\/\//, '')
      .replace(/^media:\/\//, '')
      .replace(/[\/\\:*\?"<>|%#&]/g, '_')
      .replace(/_+/g, '_')
      .substring(0, 100);
    
    return key;
  }
}
