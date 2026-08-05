/*
 * Copyright (c) 2025. All rights reserved.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { SearchIndexManager } from '../../../../../../common/src/main/ets/search/SearchIndexManager.ets';
import { FileInfo } from '@ohos/common';

export default function SearchIndexManagerTest() {
  describe('SearchIndexManager', () => {
    let searchManager: SearchIndexManager;
    
    beforeAll(() => {
      searchManager = SearchIndexManager.getInstance();
    });
    
    beforeEach(() => {
      searchManager.clearIndex();
    });
    
    afterEach(() => {
      searchManager.clearIndex();
    });
    
    afterAll(() => {
      searchManager.clearIndex();
    });
    
    /**
     * 测试索引构建
     */
    it('should_build_index_successfully', 0, () => {
      const mediaList: FileInfo[] = createTestMediaList(100);
      
      searchManager.buildIndex(mediaList);
      
      const stats = searchManager.getIndexStats();
      
      expect(stats.isBuilt).assertTrue();
      expect(stats.fileCount).assertEqual(100);
      expect(stats.keywordCount).assertLarger(0);
      expect(stats.pinyinCount).assertLarger(0);
    });
    
    /**
     * 测试关键词搜索
     */
    it('should_search_by_keyword', 0, () => {
      const mediaList: FileInfo[] = [
        createFileInfo('测试视频.mp4', 'file://test1'),
        createFileInfo('音乐文件.mp3', 'file://test2'),
        createFileInfo('图片.jpg', 'file://test3')
      ];
      
      searchManager.buildIndex(mediaList);
      
      const results = searchManager.search('测试');
      
      expect(results.length).assertEqual(1);
      expect(results[0].fileName).assertEqual('测试视频.mp4');
    });
    
    /**
     * 测试拼音搜索
     */
    it('should_search_by_pinyin', 0, () => {
      const mediaList: FileInfo[] = [
        createFileInfo('周杰伦.mp3', 'file://test1'),
        createFileInfo('青花瓷.mp3', 'file://test2'),
        createFileInfo('七里香.mp3', 'file://test3')
      ];
      
      searchManager.buildIndex(mediaList);
      
      // 测试完整拼音
      const results1 = searchManager.search('zhoujielun');
      expect(results1.length).assertLarger(0);
      
      // 测试拼音首字母
      const results2 = searchManager.search('zjl');
      expect(results2.length).assertLarger(0);
      
      // 测试部分拼音
      const results3 = searchManager.search('qinghua');
      expect(results3.length).assertLarger(0);
    });
    
    /**
     * 测试艺术家搜索
     */
    it('should_search_by_artist', 0, () => {
      const mediaList: FileInfo[] = [
        createFileInfoWithArtist('歌曲1.mp3', 'file://test1', '周杰伦'),
        createFileInfoWithArtist('歌曲2.mp3', 'file://test2', '林俊杰'),
        createFileInfoWithArtist('歌曲3.mp3', 'file://test3', '邓紫棋')
      ];
      
      searchManager.buildIndex(mediaList);
      
      const results = searchManager.search('周杰伦');
      
      expect(results.length).assertEqual(1);
      expect(results[0].appSourceName).assertEqual('周杰伦');
    });
    
    /**
     * 测试O(k)性能
     */
    it('should_search_with_ok_performance', 0, () => {
      // 创建1000个测试文件
      const mediaList: FileInfo[] = createTestMediaList(1000);
      
      searchManager.buildIndex(mediaList);
      
      // 测试搜索性能
      const startTime = Date.now();
      const results = searchManager.search('测试');
      const endTime = Date.now();
      const duration = endTime - startTime;
      
      // O(k)搜索应该在100ms内完成
      expect(duration).assertLess(100);
      expect(results.length).assertLarger(0);
      
      console.log(`搜索耗时: ${duration}ms`);
    });
    
    /**
     * 测试空搜索
     */
    it('should_return_empty_for_empty_query', 0, () => {
      const mediaList: FileInfo[] = createTestMediaList(10);
      
      searchManager.buildIndex(mediaList);
      
      const results = searchManager.search('');
      
      expect(results.length).assertEqual(0);
    });
    
    /**
     * 测试无匹配结果
     */
    it('should_return_empty_for_no_match', 0, () => {
      const mediaList: FileInfo[] = [
        createFileInfo('视频1.mp4', 'file://test1'),
        createFileInfo('视频2.mp4', 'file://test2')
      ];
      
      searchManager.buildIndex(mediaList);
      
      const results = searchManager.search('不存在的关键词');
      
      expect(results.length).assertEqual(0);
    });
    
    /**
     * 测试添加单个文件
     */
    it('should_add_single_file_to_index', 0, () => {
      const mediaList: FileInfo[] = createTestMediaList(10);
      
      searchManager.buildIndex(mediaList);
      
      const newFile = createFileInfo('新文件.mp4', 'file://new');
      searchManager.addToFileIndex(newFile);
      
      const results = searchManager.search('新文件');
      
      expect(results.length).assertEqual(1);
      expect(results[0].fileName).assertEqual('新文件.mp4');
    });
    
    /**
     * 测试移除文件
     */
    it('should_remove_file_from_index', 0, () => {
      const mediaList: FileInfo[] = [
        createFileInfo('文件1.mp4', 'file://test1'),
        createFileInfo('文件2.mp4', 'file://test2')
      ];
      
      searchManager.buildIndex(mediaList);
      
      searchManager.removeFromIndex('file://test1');
      
      const results = searchManager.search('文件1');
      
      expect(results.length).assertEqual(0);
      
      const results2 = searchManager.search('文件2');
      expect(results2.length).assertEqual(1);
    });
    
    /**
     * 测试索引统计
     */
    it('should_get_index_stats', 0, () => {
      const mediaList: FileInfo[] = createTestMediaList(50);
      
      searchManager.buildIndex(mediaList);
      
      const stats = searchManager.getIndexStats();
      
      expect(stats.fileCount).assertEqual(50);
      expect(stats.keywordCount).assertLarger(0);
      expect(stats.pinyinCount).assertLarger(0);
      expect(stats.initialsCount).assertLarger(0);
      expect(stats.isBuilt).assertTrue();
    });
    
    /**
     * 测试部分匹配
     */
    it('should_support_partial_match', 0, () => {
      const mediaList: FileInfo[] = [
        createFileInfo('测试视频文件.mp4', 'file://test1'),
        createFileInfo('音乐测试.mp3', 'file://test2')
      ];
      
      searchManager.buildIndex(mediaList);
      
      // 测试部分关键词匹配
      const results = searchManager.search('测试');
      
      expect(results.length).assertEqual(2);
    });
    
    /**
     * 测试拼音片段匹配
     */
    it('should_support_pinyin_segment_match', 0, () => {
      const mediaList: FileInfo[] = [
        createFileInfo('周杰伦.mp3', 'file://test1')
      ];
      
      searchManager.buildIndex(mediaList);
      
      // 测试拼音片段匹配
      const results1 = searchManager.search('zhou');
      expect(results1.length).assertLarger(0);
      
      const results2 = searchManager.search('jie');
      expect(results2.length).assertLarger(0);
      
      const results3 = searchManager.search('lun');
      expect(results3.length).assertLarger(0);
    });
    
    /**
     * 测试首字母片段匹配
     */
    it('should_support_initials_segment_match', 0, () => {
      const mediaList: FileInfo[] = [
        createFileInfo('周杰伦.mp3', 'file://test1')
      ];
      
      searchManager.buildIndex(mediaList);
      
      // 测试首字母片段匹配
      const results1 = searchManager.search('zj');
      expect(results1.length).assertLarger(0);
      
      const results2 = searchManager.search('jl');
      expect(results2.length).assertLarger(0);
    });
    
    /**
     * 测试中英文混合搜索
     */
    it('should_support_mixed_chinese_english_search', 0, () => {
      const mediaList: FileInfo[] = [
        createFileInfo('Test测试.mp4', 'file://test1'),
        createFileInfo('Music音乐.mp3', 'file://test2')
      ];
      
      searchManager.buildIndex(mediaList);
      
      // 测试英文关键词
      const results1 = searchManager.search('test');
      expect(results1.length).assertEqual(1);
      
      // 测试中文关键词
      const results2 = searchManager.search('测试');
      expect(results2.length).assertEqual(1);
      
      // 测试拼音
      const results3 = searchManager.search('ceshi');
      expect(results3.length).assertEqual(1);
    });
    
    /**
     * 测试性能基准
     */
    it('should_meet_performance_benchmark', 0, () => {
      // 创建5000个测试文件（模拟真实场景）
      const mediaList: FileInfo[] = createTestMediaList(5000);
      
      // 测试索引构建性能
      const buildStartTime = Date.now();
      searchManager.buildIndex(mediaList);
      const buildEndTime = Date.now();
      const buildDuration = buildEndTime - buildStartTime;
      
      console.log(`索引构建耗时: ${buildDuration}ms`);
      
      // 测试搜索性能（多次搜索）
      const searchQueries = ['测试', 'test', 'zhou', 'zjl', '音乐', '视频'];
      const searchTimes: number[] = [];
      
      for (const query of searchQueries) {
        const startTime = Date.now();
        const results = searchManager.search(query);
        const endTime = Date.now();
        const duration = endTime - startTime;
        searchTimes.push(duration);
        
        console.log(`搜索 "${query}" 耗时: ${duration}ms, 结果: ${results.length} 个`);
      }
      
      // 平均搜索时间应该在100ms内
      const avgSearchTime = searchTimes.reduce((a, b) => a + b, 0) / searchTimes.length;
      expect(avgSearchTime).assertLess(100);
      
      console.log(`平均搜索耗时: ${avgSearchTime}ms`);
    });
  });
}

/**
 * 创建测试FileInfo
 */
function createFileInfo(fileName: string, uri: string): FileInfo {
  const fileInfo = new FileInfo();
  fileInfo.fileName = fileName;
  fileInfo.uri = uri;
  fileInfo.mimeType = fileName.endsWith('.mp4') ? 'video/mp4' : 
                       fileName.endsWith('.mp3') ? 'audio/mp3' : 'image/jpeg';
  return fileInfo;
}

/**
 * 创建带艺术家的FileInfo
 */
function createFileInfoWithArtist(fileName: string, uri: string, artist: string): FileInfo {
  const fileInfo = createFileInfo(fileName, uri);
  fileInfo.appSourceName = artist;
  return fileInfo;
}

/**
 * 创建测试媒体列表
 */
function createTestMediaList(count: number): FileInfo[] {
  const mediaList: FileInfo[] = [];
  
  for (let i = 0; i < count; i++) {
    const fileInfo = new FileInfo();
    
    // 创建多样化的文件名（中文、英文、拼音）
    if (i % 3 === 0) {
      fileInfo.fileName = `测试视频${i}.mp4`;
    } else if (i % 3 === 1) {
      fileInfo.fileName = `TestVideo${i}.mp4`;
    } else {
      fileInfo.fileName = `音乐文件${i}.mp3`;
    }
    
    fileInfo.uri = `file://test${i}`;
    fileInfo.mimeType = fileInfo.fileName.endsWith('.mp4') ? 'video/mp4' : 'audio/mp3';
    
    // 添加艺术家信息（部分文件）
    if (i % 5 === 0) {
      fileInfo.appSourceName = i % 2 === 0 ? '周杰伦' : '林俊杰';
    }
    
    mediaList.push(fileInfo);
  }
  
  return mediaList;
}