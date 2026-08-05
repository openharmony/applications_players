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
import { MediaType } from '../datasource/IMediaDataSource';

const TAG = 'MediaCacheManager';

export interface CacheInfo {
  count: number;
  timestamp: number;
}

export class MediaCacheManager {
  private static instance: MediaCacheManager;
  private memoryCache: Map<MediaType, FileInfo[]> = new Map();
  private cacheTimestamps: Map<MediaType, number> = new Map();
  private readonly CACHE_TTL = 5 * 60 * 1000;

  private constructor() {
  }

  public static getInstance(): MediaCacheManager {
    if (!MediaCacheManager.instance) {
      MediaCacheManager.instance = new MediaCacheManager();
    }
    return MediaCacheManager.instance;
  }

  public hasCache(mediaType: MediaType): boolean {
    if (!this.memoryCache.has(mediaType)) {
      return false;
    }

    const timestamp = this.cacheTimestamps.get(mediaType) || 0;
    const isExpired = Date.now() - timestamp > this.CACHE_TTL;
    
    if (isExpired) {
      HiLog.d(TAG, `Cache expired: ${MediaType[mediaType]}`);
      return false;
    }

    return true;
  }

  public getFromCache(mediaType: MediaType): FileInfo[] {
    const cached = this.memoryCache.get(mediaType);
    if (cached) {
      HiLog.i(TAG, `Loading from cache: ${MediaType[mediaType]}, count: ${cached.length}`);
      return cached.slice();
    }
    return [];
  }

  public updateCache(mediaType: MediaType, items: FileInfo[]): void {
    if (!items || items.length === 0) {
      HiLog.w(TAG, `Cache update failed: ${MediaType[mediaType]}, data is empty`);
      return;
    }

    this.memoryCache.set(mediaType, items.slice());
    this.cacheTimestamps.set(mediaType, Date.now());
    
    HiLog.i(TAG, `Cache updated: ${MediaType[mediaType]}, count: ${items.length}`);
  }

  public addToCache(mediaType: MediaType, items: FileInfo[]): void {
    if (!items || items.length === 0) {
      return;
    }

    const existing = this.memoryCache.get(mediaType) || [];
    const merged = [...existing, ...items];
    
    this.memoryCache.set(mediaType, merged);
    this.cacheTimestamps.set(mediaType, Date.now());
    
    HiLog.i(TAG, `Added to cache: ${MediaType[mediaType]}, added: ${items.length}, total: ${merged.length}`);
  }

  public appendCache(mediaType: MediaType, items: FileInfo[]): void {
    this.addToCache(mediaType, items);
  }

  public clearCache(mediaType?: MediaType): void {
    if (mediaType !== undefined) {
      this.memoryCache.delete(mediaType);
      this.cacheTimestamps.delete(mediaType);
      HiLog.i(TAG, `Cache cleared: ${MediaType[mediaType]}`);
    } else {
      this.memoryCache.clear();
      this.cacheTimestamps.clear();
      HiLog.i(TAG, 'All caches cleared');
    }
  }

  public getCacheSize(): number {
    let totalSize = 0;
    for (const items of this.memoryCache.values()) {
      totalSize += items.length;
    }
    return totalSize;
  }

  public getCacheInfo(): Map<MediaType, CacheInfo> {
    const info = new Map<MediaType, CacheInfo>();
    
    const entries = this.memoryCache.entries();
    let iterator = entries.next();
    while (!iterator.done) {
      const mediaType = iterator.value[0];
      const items = iterator.value[1];
      const timestamp = this.cacheTimestamps.get(mediaType) || 0;
      const cacheInfo: CacheInfo = {
        count: items.length,
        timestamp: timestamp
      };
      info.set(mediaType, cacheInfo);
      iterator = entries.next();
    }
    
    return info;
  }

  public isValidCache(mediaType: MediaType): boolean {
    if (!this.memoryCache.has(mediaType)) {
      return false;
    }

    const items = this.memoryCache.get(mediaType);
    return items !== undefined && items.length > 0;
  }
}