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


import { SearchIndexManager, IndexStats } from '@ohos/common/src/main/ets/search/SearchIndexManager';
import FileInfo from '@ohos/common/src/main/ets/model/FileInfo';
import { FileInfo as FileOperateFileInfo } from '@ohos/common/src/main/ets/utils/FileOperateInfo';
import { SearchMediaType } from '../viewmodel/SearchViewModel';
import { HiLog } from '@ohos/common/src/main/ets/utils/HiLog';

const TAG = 'SearchIndexCoordinator';

/**
 * 搜索索引协调器
 * 协调 SearchIndexManager 的索引构建与搜索，提供按类型搜索功能
 */
export class SearchIndexCoordinator {
  private static instance: SearchIndexCoordinator;
  private indexManager: SearchIndexManager = SearchIndexManager.getInstance();
  
  private constructor() {}
  
  /**
   * 获取单例实例
   */
  public static getInstance(): SearchIndexCoordinator {
    if (!SearchIndexCoordinator.instance) {
      SearchIndexCoordinator.instance = new SearchIndexCoordinator();
    }
    return SearchIndexCoordinator.instance;
  }
  
  /**
   * 从数据库缓存构建索引
   * @param mediaList 媒体文件列表
   */
  public buildIndexFromCache(mediaList: FileInfo[]): void {
    if (!mediaList || mediaList.length === 0) {
      HiLog.w(TAG, 'Media list is empty, skipping index build');
      return;
    }
    
    HiLog.i(TAG, `Building index from cache, ${mediaList.length} files`);
    
    // 转换 entity/FileInfo 到 FileOperateFileInfo
    const fileOperateList: FileOperateFileInfo[] = mediaList.map((entityInfo: FileInfo): FileOperateFileInfo => {
      return this.convertEntityToFileOperate(entityInfo);
    });
    
    // 使用 SearchIndexManager 构建索引
    this.indexManager.buildIndex(fileOperateList);
    
    HiLog.i(TAG, 'Index build completed');
  }
  
  /**
   * 添加单个文件到索引
   * @param fileInfo 文件信息
   */
  public addToIndex(fileInfo: FileInfo): void {
    if (!fileInfo || !fileInfo.uri) {
      HiLog.w(TAG, 'File info is invalid, skipping add to index');
      return;
    }
    
    HiLog.i(TAG, `Adding file to index: ${fileInfo.fileName}`);
    
    // 转换 entity/FileInfo 到 FileOperateFileInfo
    const fileOperateInfo: FileOperateFileInfo = this.convertEntityToFileOperate(fileInfo);
    
    this.indexManager.addToFileIndex(fileOperateInfo);
  }
  
  /**
   * 从索引中移除文件
   * @param uri 文件URI
   */
  public removeFromIndex(uri: string): void {
    if (!uri) {
      HiLog.w(TAG, 'URI is invalid, skipping removal from index');
      return;
    }
    
    HiLog.i(TAG, `Removing file from index: ${uri}`);
    
    this.indexManager.removeFromIndex(uri);
  }
  
  /**
   * 搜索文件（O(k)性能）
   * @param query 搜索关键词
   * @returns 匹配的FileInfo数组
   */
  public search(query: string): FileInfo[] {
    if (!query) {
      return [];
    }
    
    const startTime = Date.now();
    
    // 使用 SearchIndexManager 进行搜索
    const fileOperateResults: FileOperateFileInfo[] = this.indexManager.search(query);
    
    // 转换 FileOperateFileInfo 到 entity/FileInfo
    const results: FileInfo[] = fileOperateResults.map((fileOperateInfo: FileOperateFileInfo): FileInfo => {
      return FileInfo.fromFileOperateFileInfo(fileOperateInfo);
    });
    
    const endTime = Date.now();
    const duration = endTime - startTime;
    
    HiLog.i(TAG, `Search completed, query: "${query}", results: ${results.length} files, duration: ${duration}ms`);
    
    return results;
  }
  
  /**
   * 按类型搜索文件（O(k)性能）
   * @param query 搜索关键词
   * @param mediaType 媒体类型
   * @returns 匹配的FileInfo数组
   */
  public searchByType(query: string, mediaType: SearchMediaType): FileInfo[] {
    if (!query) {
      return [];
    }
    
    const startTime = Date.now();
    
    // 使用 SearchIndexManager 进行搜索
    const fileOperateResults: FileOperateFileInfo[] = this.indexManager.search(query);
    
    // 转换 FileOperateFileInfo 到 entity/FileInfo
    const allResults: FileInfo[] = fileOperateResults.map((fileOperateInfo: FileOperateFileInfo): FileInfo => {
      return FileInfo.fromFileOperateFileInfo(fileOperateInfo);
    });
    
    // 按类型过滤
    let filteredResults: FileInfo[] = allResults;
    
    if (mediaType === SearchMediaType.AUDIO) {
      filteredResults = allResults.filter((file: FileInfo): boolean => 
        file.mimeType?.startsWith('audio') ?? false
      );
    } else if (mediaType === SearchMediaType.VIDEO) {
      filteredResults = allResults.filter((file: FileInfo): boolean => 
        file.mimeType?.startsWith('video') ?? false
      );
    }
    
    const endTime = Date.now();
    const duration = endTime - startTime;
    
    HiLog.i(TAG, `Search by type completed, query: "${query}", type: ${mediaType}, results: ${filteredResults.length} files, duration: ${duration}ms`);
    
    return filteredResults;
  }
  
  /**
   * 获取索引统计信息
   */
  public getIndexStats(): IndexStats {
    return this.indexManager.getIndexStats();
  }
  
  /**
   * 清空索引
   */
  public clearIndex(): void {
    HiLog.i(TAG, 'Clearing index');
    this.indexManager.clearIndex();
  }
  
  /**
   * 转换 entity/FileInfo 到 FileOperateFileInfo
   * @param entityInfo entity/FileInfo
   * @returns FileOperateFileInfo
   */
  private convertEntityToFileOperate(entityInfo: FileInfo): FileOperateFileInfo {
    const fileOperateInfo = new FileOperateFileInfo();
    fileOperateInfo.fileName = entityInfo.fileName;
    fileOperateInfo.uri = entityInfo.uri;
    fileOperateInfo.mimeType = entityInfo.mimeType;
    fileOperateInfo.size = entityInfo.fileSize;
    fileOperateInfo.mtime = entityInfo.updateTime;
    fileOperateInfo.ctime = entityInfo.createTime;
    fileOperateInfo.duration = entityInfo.duration;
    fileOperateInfo.thumbUri = entityInfo.thumbUri;
    fileOperateInfo.coverUri = entityInfo.coverUri;
    // entity/FileInfo 没有 appSourceName 属性，使用空字符串
    fileOperateInfo.appSourceName = '';
    return fileOperateInfo;
  }
}
