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
import { SearchIndexCoordinator } from '@ohos/search/src/main/ets/manager/SearchIndexCoordinator';
import { FileInfo } from '@ohos/common';
import { SearchMediaType } from '@ohos/search';

export default function SearchIndexCoordinatorTest() {
  describe('SearchIndexCoordinator', () => {
    let coordinator: SearchIndexCoordinator;
    
    beforeAll(() => {
      coordinator = SearchIndexCoordinator.getInstance();
    });
    
    beforeEach(() => {
      coordinator.clearIndex();
    });
    
    afterEach(() => {
      coordinator.clearIndex();
    });
    
    afterAll(() => {
      coordinator.clearIndex();
    });
    
    /**
     * 测试单例模式
     */
    it('should_return_same_instance', 0, () => {
      const instance1 = SearchIndexCoordinator.getInstance();
      const instance2 = SearchIndexCoordinator.getInstance();
      
      expect(instance1).assertEqual(instance2);
    });
    
    /**
     * 测试从缓存构建索引
     */
    it('should_build_index_from_cache', 0, () => {
      const mediaList: FileInfo[] = createTestMediaList(100);
      
      coordinator.buildIndexFromCache(mediaList);
      
      const stats = coordinator.getIndexStats();
      
      expect(stats.isBuilt).assertTrue();
      expect(stats.fileCount).assertEqual(100);
      expect(stats.keywordCount).assertLarger(0);
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
      
      coordinator.buildIndexFromCache(mediaList);
      
      const results = coordinator.search('测试');
      
      expect(results.length).assertEqual(1);
      expect(results[0].fileName).assertEqual('测试视频.mp4');
    });
    
    /**
     * 测试按类型搜索 - 音频
     */
    it('should_search_audio_by_type', 0, () => {
      const mediaList: FileInfo[] = [
        createFileInfo('测试视频.mp4', 'file://test1'),
        createFileInfo('音乐文件.mp3', 'file://test2'),
        createFileInfo('歌曲.mp3', 'file://test3')
      ];
      
      coordinator.buildIndexFromCache(mediaList);
      
      const results = coordinator.searchByType('音乐', SearchMediaType.AUDIO);
      
      expect(results.length).assertEqual(1);
      expect(results[0].fileName).assertEqual('音乐文件.mp3');
      expect(results[0].mimeType).assertContain('audio');
    });
    
    /**
     * 测试按类型搜索 - 视频
     */
    it('should_search_video_by_type', 0, () => {
      const mediaList: FileInfo[] = [
        createFileInfo('测试视频.mp4', 'file://test1'),
        createFileInfo('电影.mp4', 'file://test2'),
        createFileInfo('音乐文件.mp3', 'file://test3')
      ];
      
      coordinator.buildIndexFromCache(mediaList);
      
      const results = coordinator.searchByType('视频', SearchMediaType.VIDEO);
      
      expect(results.length).assertEqual(1);
      expect(results[0].fileName).assertEqual('测试视频.mp4');
      expect(results[0].mimeType).assertContain('video');
    });
    
    /**
     * 测试按类型搜索 - 全部
     */
    it('should_search_all_types', 0, () => {
      const mediaList: FileInfo[] = [
        createFileInfo('测试视频.mp4', 'file://test1'),
        createFileInfo('测试音乐.mp3', 'file://test2')
      ];
      
      coordinator.buildIndexFromCache(mediaList);
      
      const results = coordinator.searchByType('测试', SearchMediaType.ALL);
      
      expect(results.length).assertEqual(2);
    });
    
    /**
     * 测试拼音搜索
     */
    it('should_search_by_pinyin', 0, () => {
      const mediaList: FileInfo[] = [
        createFileInfo('周杰伦.mp3', 'file://test1'),
        createFileInfo('青花瓷.mp3', 'file://test2')
      ];
      
      coordinator.buildIndexFromCache(mediaList);
      
      // 测试完整拼音
      const results1 = coordinator.search('zhoujielun');
      expect(results1.length).assertLarger(0);
      
      // 测试拼音首字母
      const results2 = coordinator.search('zjl');
      expect(results2.length).assertLarger(0);
    });
    
    /**
     * 测试增量添加文件
     */
    it('should_add_file_to_index', 0, () => {
      const mediaList: FileInfo[] = createTestMediaList(10);
      
      coordinator.buildIndexFromCache(mediaList);
      
      const newFile = createFileInfo('新文件.mp4', 'file://new');
      coordinator.addToIndex(newFile);
      
      const results = coordinator.search('新文件');
      
      expect(results.length).assertEqual(1);
      expect(results[0].fileName).assertEqual('新文件.mp4');
    });
    
    /**
     * 测试增量移除文件
     */
    it('should_remove_file_from_index', 0, () => {
      const mediaList: FileInfo[] = [
        createFileInfo('文件1.mp4', 'file://test1'),
        createFileInfo('文件2.mp4', 'file://test2')
      ];
      
      coordinator.buildIndexFromCache(mediaList);
      
      coordinator.removeFromIndex('file://test1');
      
      const results = coordinator.search('文件1');
      
      expect(results.length).assertEqual(0);
      
      const results2 = coordinator.search('文件2');
      expect(results2.length).assertEqual(1);
    });
    
    /**
     * 测试O(k)性能
     */
    it('should_search_with_ok_performance', 0, () => {
      // 创建1000个测试文件
      const mediaList: FileInfo[] = createTestMediaList(1000);
      
      coordinator.buildIndexFromCache(mediaList);
      
      // 测试搜索性能
      const startTime = Date.now();
      const results = coordinator.search('测试');
      const endTime = Date.now();
      const duration = endTime - startTime;
      
      // O(k)搜索应该在100ms内完成
      expect(duration).assertLess(100);
      expect(results.length).assertLarger(0);
      
      console.log(`搜索耗时: ${duration}ms`);
    });
    
    /**
     * 测试按类型搜索性能
     */
    it('should_search_by_type_with_ok_performance', 0, () => {
      // 创建1000个测试文件
      const mediaList: FileInfo[] = createTestMediaList(1000);
      
      coordinator.buildIndexFromCache(mediaList);
      
      // 测试按类型搜索性能
      const startTime = Date.now();
      const results = coordinator.searchByType('测试', SearchMediaType.VIDEO);
      const endTime = Date.now();
      const duration = endTime - startTime;
      
      // O(k)搜索应该在100ms内完成
      expect(duration).assertLess(100);
      
      console.log(`按类型搜索耗时: ${duration}ms`);
    });
    
    /**
     * 测试空搜索
     */
    it('should_return_empty_for_empty_query', 0, () => {
      const mediaList: FileInfo[] = createTestMediaList(10);
      
      coordinator.buildIndexFromCache(mediaList);
      
      const results = coordinator.search('');
      
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
      
      coordinator.buildIndexFromCache(mediaList);
      
      const results = coordinator.search('不存在的关键词');
      
      expect(results.length).assertEqual(0);
    });
    
    /**
     * 测试索引统计
     */
    it('should_get_index_stats', 0, () => {
      const mediaList: FileInfo[] = createTestMediaList(50);
      
      coordinator.buildIndexFromCache(mediaList);
      
      const stats = coordinator.getIndexStats();
      
      expect(stats.fileCount).assertEqual(50);
      expect(stats.keywordCount).assertLarger(0);
      expect(stats.pinyinCount).assertLarger(0);
      expect(stats.initialsCount).assertLarger(0);
      expect(stats.isBuilt).assertTrue();
    });
    
    /**
     * 测试清空索引
     */
    it('should_clear_index', 0, () => {
      const mediaList: FileInfo[] = createTestMediaList(10);
      
      coordinator.buildIndexFromCache(mediaList);
      
      coordinator.clearIndex();
      
      const stats = coordinator.getIndexStats();
      
      expect(stats.isBuilt).assertFalse();
      expect(stats.fileCount).assertEqual(0);
    });
    
    /**
     * 测试性能基准
     */
    it('should_meet_performance_benchmark', 0, () => {
      // 创建5000个测试文件（模拟真实场景）
      const mediaList: FileInfo[] = createTestMediaList(5000);
      
      // 测试索引构建性能
      const buildStartTime = Date.now();
      coordinator.buildIndexFromCache(mediaList);
      const buildEndTime = Date.now();
      const buildDuration = buildEndTime - buildStartTime;
      
      console.log(`索引构建耗时: ${buildDuration}ms`);
      
      // 测试搜索性能（多次搜索）
      const searchQueries = ['测试', 'test', 'zhou', 'zjl', '音乐', '视频'];
      const searchTimes: number[] = [];
      
      for (const query of searchQueries) {
        const startTime = Date.now();
        const results = coordinator.search(query);
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
    
    /**
     * 测试中英文混合搜索
     */
    it('should_support_mixed_chinese_english_search', 0, () => {
      const mediaList: FileInfo[] = [
        createFileInfo('Test测试.mp4', 'file://test1'),
        createFileInfo('Music音乐.mp3', 'file://test2')
      ];
      
      coordinator.buildIndexFromCache(mediaList);
      
      // 测试英文关键词
      const results1 = coordinator.search('test');
      expect(results1.length).assertEqual(1);
      
      // 测试中文关键词
      const results2 = coordinator.search('测试');
      expect(results2.length).assertEqual(1);
      
      // 测试拼音
      const results3 = coordinator.search('ceshi');
      expect(results3.length).assertEqual(1);
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
      
      coordinator.buildIndexFromCache(mediaList);
      
      const results = coordinator.search('周杰伦');
      
      expect(results.length).assertEqual(1);
      expect(results[0].appSourceName).assertEqual('周杰伦');
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