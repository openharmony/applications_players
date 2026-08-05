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


import FileInfo from '../model/FileInfo';
import { FileInfo as FileOperateFileInfo } from '../utils/FileOperateInfo';
import { PinyinConverter } from '../utils/PinyinConverter';
import { HiLog } from '../utils/HiLog';

const TAG = 'SearchIndexManager';

/**
 * 索引统计信息接口
 */
export interface IndexStats {
  keywordCount: number;
  pinyinCount: number;
  initialsCount: number;
  fileCount: number;
  isBuilt: boolean;
}

/**
 * 倒排索引搜索管理器
 * 实现O(k)搜索性能（k=关键词长度）
 */
export class SearchIndexManager {
  private static instance: SearchIndexManager;
  
  // 倒排索引：关键词 → 文件URI集合
  private invertedIndex: Map<string, Set<string>> = new Map();
  
  // 拼音索引：拼音 → 文件URI集合
  private pinyinIndex: Map<string, Set<string>> = new Map();
  
  // 拼音首字母索引：首字母 → 文件URI集合
  private pinyinInitialsIndex: Map<string, Set<string>> = new Map();
  
  // 文件URI → FileInfo映射（用于快速获取FileInfo）
  private uriToFileInfo: Map<string, FileOperateFileInfo> = new Map();
  
  // 索引是否已构建
  private indexBuilt: boolean = false;
  
  private constructor() {}
  
  public static getInstance(): SearchIndexManager {
    if (!SearchIndexManager.instance) {
      SearchIndexManager.instance = new SearchIndexManager();
    }
    return SearchIndexManager.instance;
  }
  
  /**
   * 构建倒排索引
   * @param mediaList 媒体文件列表
   */
  public buildIndex(mediaList: FileOperateFileInfo[]): void {
    if (!mediaList || mediaList.length === 0) {
      HiLog.w(TAG, 'Media list is empty, skipping index build');
      return;
    }
    
    HiLog.i(TAG, `Building inverted index, ${mediaList.length} files`);
    
    // 清空现有索引
    this.clearIndex();
    
    const startTime = Date.now();
    
    // 构建索引
    for (const fileInfo of mediaList) {
      if (!fileInfo || !fileInfo.uri) {
        continue;
      }
      
      // 存储URI到FileInfo的映射
      this.uriToFileInfo.set(fileInfo.uri, fileInfo);
      
      // 提取关键词并添加到倒排索引
      this.addToInvertedIndex(fileInfo.fileName, fileInfo.uri);
      
      // 提取艺术家关键词（如果有）
      if (fileInfo.appSourceName) {
        this.addToInvertedIndex(fileInfo.appSourceName, fileInfo.uri);
      }
      
      // 预计算拼音并添加到拼音索引
      this.addToPinyinIndex(fileInfo.fileName, fileInfo.uri);
      
      if (fileInfo.appSourceName) {
        this.addToPinyinIndex(fileInfo.appSourceName, fileInfo.uri);
      }
    }
    
    this.indexBuilt = true;
    
    const endTime = Date.now();
    const duration = endTime - startTime;
    
    HiLog.i(TAG, `Inverted index built in ${duration}ms`);
    HiLog.i(TAG, `Keyword index: ${this.invertedIndex.size} keywords`);
    HiLog.i(TAG, `Pinyin index: ${this.pinyinIndex.size} pinyin entries`);
    HiLog.i(TAG, `Pinyin initials index: ${this.pinyinInitialsIndex.size} initials`);
  }
  
  /**
   * 添加关键词到倒排索引
   * @param text 文本
   * @param uri 文件URI
   */
  private addToInvertedIndex(text: string, uri: string): void {
    if (!text) {
      return;
    }
    
    // 提取关键词（按空格、标点符号分割）
    const keywords = this.extractKeywords(text);
    
    for (const keyword of keywords) {
      const lowerKeyword = keyword.toLowerCase();
      
      if (!this.invertedIndex.has(lowerKeyword)) {
        this.invertedIndex.set(lowerKeyword, new Set());
      }
      
      this.invertedIndex.get(lowerKeyword)!.add(uri);
    }
  }
  
  /**
   * 提取关键词
   * @param text 文本
   * @returns 关键词数组
   */
  private extractKeywords(text: string): string[] {
    if (!text) {
      return [];
    }
    
    // 移除文件扩展名
    const textWithoutSuffix = PinyinConverter.getFileNameWithoutSuffix(text);
    
    // 按空格、标点符号分割
    const keywords = textWithoutSuffix.split(/[\s\-_.,;:!?()（）【】\[\]{}"'""'<>《》·]+/);
    
    // 过滤空字符串和单字符（保留中文单字）
    return keywords.filter(k => {
      if (!k) {
        return false;
      }
      // 保留中文单字，过滤英文单字符
      if (k.length === 1) {
        return PinyinConverter.containsChinese(k);
      }
      return true;
    });
  }
  
  /**
   * 添加拼音到拼音索引
   * @param text 文本
   * @param uri 文件URI
   */
  private addToPinyinIndex(text: string, uri: string): void {
    if (!text) {
      return;
    }
    
    // 移除文件扩展名
    const textWithoutSuffix = PinyinConverter.getFileNameWithoutSuffix(text);
    
    // 计算完整拼音
    const fullPinyin = PinyinConverter.toPinyin(textWithoutSuffix);
    if (fullPinyin) {
      // 添加完整拼音到索引
      if (!this.pinyinIndex.has(fullPinyin)) {
        this.pinyinIndex.set(fullPinyin, new Set());
      }
      this.pinyinIndex.get(fullPinyin)!.add(uri);
      
      // 添加拼音片段（支持部分匹配）
      this.addPinyinSegments(fullPinyin, uri);
    }
    
    // 计算拼音首字母
    const initials = PinyinConverter.toPinyinInitials(textWithoutSuffix);
    if (initials) {
      if (!this.pinyinInitialsIndex.has(initials)) {
        this.pinyinInitialsIndex.set(initials, new Set());
      }
      this.pinyinInitialsIndex.get(initials)!.add(uri);
      
      // 添加首字母片段（支持部分匹配）
      this.addInitialsSegments(initials, uri);
    }
  }
  
  /**
   * 添加拼音片段到索引（支持部分匹配）
   * @param pinyin 完整拼音
   * @param uri 文件URI
   */
  private addPinyinSegments(pinyin: string, uri: string): void {
    if (!pinyin || pinyin.length < 2) {
      return;
    }
    
    // 添加所有可能的拼音片段（长度 >= 2）
    for (let i = 0; i < pinyin.length - 1; i++) {
      for (let len = 2; len <= Math.min(pinyin.length - i, 10); len++) {
        const segment = pinyin.substring(i, i + len);
        
        if (!this.pinyinIndex.has(segment)) {
          this.pinyinIndex.set(segment, new Set());
        }
        
        this.pinyinIndex.get(segment)!.add(uri);
      }
    }
  }
  
  /**
   * 添加首字母片段到索引（支持部分匹配）
   * @param initials 完整首字母
   * @param uri 文件URI
   */
  private addInitialsSegments(initials: string, uri: string): void {
    if (!initials || initials.length < 2) {
      return;
    }
    
    // 添加所有可能的首字母片段（长度 >= 2）
    for (let i = 0; i < initials.length - 1; i++) {
      for (let len = 2; len <= initials.length - i; len++) {
        const segment = initials.substring(i, i + len);
        
        if (!this.pinyinInitialsIndex.has(segment)) {
          this.pinyinInitialsIndex.set(segment, new Set());
        }
        
        this.pinyinInitialsIndex.get(segment)!.add(uri);
      }
    }
  }
  
  /**
   * 搜索文件（O(k)性能）
   * @param query 搜索关键词
   * @returns 匹配的FileInfo数组
   */
  public search(query: string): FileOperateFileInfo[] {
    if (!query || !this.indexBuilt) {
      return [];
    }
    
    const startTime = Date.now();
    
    const lowerQuery = query.toLowerCase().trim();
    
    // 使用Set存储匹配的URI（避免重复）
    const matchedUris = new Set<string>();
    
    // 1. 关键词匹配（O(k)）
    if (this.invertedIndex.has(lowerQuery)) {
      const uris = this.invertedIndex.get(lowerQuery)!;
      for (const uri of uris) {
        matchedUris.add(uri);
      }
    }
    
    // 2. 拼音匹配（O(k)）
    if (this.pinyinIndex.has(lowerQuery)) {
      const uris = this.pinyinIndex.get(lowerQuery)!;
      for (const uri of uris) {
        matchedUris.add(uri);
      }
    }
    
    // 3. 拼音首字母匹配（O(k)）
    if (this.pinyinInitialsIndex.has(lowerQuery)) {
      const uris = this.pinyinInitialsIndex.get(lowerQuery)!;
      for (const uri of uris) {
        matchedUris.add(uri);
      }
    }
    
    // 4. 如果没有精确匹配，尝试部分匹配
    if (matchedUris.size === 0) {
      this.partialMatch(lowerQuery, matchedUris);
    }
    
    // 转换URI到FileInfo
    const results: FileOperateFileInfo[] = [];
    for (const uri of matchedUris) {
      const fileInfo = this.uriToFileInfo.get(uri);
      if (fileInfo) {
        results.push(fileInfo);
      }
    }
    
    const endTime = Date.now();
    const duration = endTime - startTime;
    
    HiLog.i(TAG, `Search completed, query: "${query}", results: ${results.length} files, time: ${duration}ms`);
    
    return results;
  }
  
  /**
   * 部分匹配（当精确匹配失败时）
   * @param query 搜索关键词
   * @param matchedUris 匹配的URI集合
   */
  private partialMatch(query: string, matchedUris: Set<string>): void {
    // 遍历所有关键词，查找包含query的
    this.invertedIndex.forEach((uris: Set<string>, keyword: string) => {
      if (keyword.includes(query)) {
        uris.forEach((uri: string) => {
          matchedUris.add(uri);
        });
      }
    });
    
    // 遍历所有拼音，查找包含query的
    this.pinyinIndex.forEach((uris: Set<string>, pinyin: string) => {
      if (pinyin.includes(query)) {
        uris.forEach((uri: string) => {
          matchedUris.add(uri);
        });
      }
    });
    
    // 遍历所有首字母，查找包含query的
    this.pinyinInitialsIndex.forEach((uris: Set<string>, initials: string) => {
      if (initials.includes(query)) {
        uris.forEach((uri: string) => {
          matchedUris.add(uri);
        });
      }
    });
  }
  
  /**
   * 清空索引
   */
  public clearIndex(): void {
    this.invertedIndex.clear();
    this.pinyinIndex.clear();
    this.pinyinInitialsIndex.clear();
    this.uriToFileInfo.clear();
    this.indexBuilt = false;
  }
  
  /**
   * 添加单个文件到索引
   * @param fileInfo 文件信息
   */
  public addToFileIndex(fileInfo: FileOperateFileInfo): void {
    if (!fileInfo || !fileInfo.uri) {
      return;
    }
    
    // 存储URI到FileInfo的映射
    this.uriToFileInfo.set(fileInfo.uri, fileInfo);
    
    // 提取关键词并添加到倒排索引
    this.addToInvertedIndex(fileInfo.fileName, fileInfo.uri);
    
    // 提取艺术家关键词（如果有）
    if (fileInfo.appSourceName) {
      this.addToInvertedIndex(fileInfo.appSourceName, fileInfo.uri);
    }
    
    // 预计算拼音并添加到拼音索引
    this.addToPinyinIndex(fileInfo.fileName, fileInfo.uri);
    
    if (fileInfo.appSourceName) {
      this.addToPinyinIndex(fileInfo.appSourceName, fileInfo.uri);
    }
  }
  
  /**
   * 从索引中移除文件
   * @param uri 文件URI
   */
  public removeFromIndex(uri: string): void {
    if (!uri) {
      return;
    }
    
    // 从URI映射中移除
    this.uriToFileInfo.delete(uri);
    
    // 从倒排索引中移除
    this.invertedIndex.forEach((uris: Set<string>, keyword: string) => {
      uris.delete(uri);
      if (uris.size === 0) {
        this.invertedIndex.delete(keyword);
      }
    });
    
    // 从拼音索引中移除
    this.pinyinIndex.forEach((uris: Set<string>, pinyin: string) => {
      uris.delete(uri);
      if (uris.size === 0) {
        this.pinyinIndex.delete(pinyin);
      }
    });
    
    // 从首字母索引中移除
    this.pinyinInitialsIndex.forEach((uris: Set<string>, initials: string) => {
      uris.delete(uri);
      if (uris.size === 0) {
        this.pinyinInitialsIndex.delete(initials);
      }
    });
  }
  
  /**
   * 获取索引统计信息
   */
  public getIndexStats(): IndexStats {
    const stats: IndexStats = {
      keywordCount: this.invertedIndex.size,
      pinyinCount: this.pinyinIndex.size,
      initialsCount: this.pinyinInitialsIndex.size,
      fileCount: this.uriToFileInfo.size,
      isBuilt: this.indexBuilt
    };
    return stats;
  }
}
