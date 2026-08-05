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
import { SearchViewModel, SearchMediaType, SearchOptions } from '@ohos/search';
import { FileInfo } from '@ohos/common';
import { SearchIndexCoordinator } from '@ohos/search/src/main/ets/manager/SearchIndexCoordinator';

export default function SearchViewModelIntegrationTest() {
  describe('SearchViewModelIntegration', () => {
    let viewModel: SearchViewModel;
    let coordinator: SearchIndexCoordinator;
    
    beforeAll(() => {
      viewModel = SearchViewModel.getInstance();
      coordinator = SearchIndexCoordinator.getInstance();
    });
    
    beforeEach(() => {
      coordinator.clearIndex();
      viewModel.clearIndex();
    });
    
    afterEach(() => {
      coordinator.clearIndex();
      viewModel.clearIndex();
    });
    
    afterAll(() => {
      coordinator.clearIndex();
      viewModel.clearIndex();
    });
    
    /**
     * 测试索引构建
     */
    it('should_build_index_successfully', 0, () => {
      const mediaList: FileInfo[] = createTestMediaList(100);
      
      // 模拟 MediaAggregateViewModel.getMediaList() 返回数据
      // 注意：实际测试中需要 mock MediaAggregateViewModel
      
      viewModel.buildIndex();
      
      expect(viewModel.isIndexBuilt()).assertTrue();
      
      const stats = coordinator.getIndexStats();
      expect(stats.isBuilt).assertTrue();
      expect(stats.fileCount).assertLarger(0);
    });
    
    /**
     * 测试使用倒排索引搜索
     */
    it('should_search_using_inverted_index', 0, () => {
      const mediaList: FileInfo[] = [
        createFileInfo('测试视频.mp4', 'file://test1'),
        createFileInfo('音乐文件.mp3', 'file://test2'),
        createFileInfo('周杰伦.mp3', 'file://test3')
      ];
      
      coordinator.buildIndexFromCache(mediaList);
      viewModel.buildIndex();
      
      const options: SearchOptions = {
        keyword: '测试',
        mediaType: SearchMediaType.ALL
      };
      
      const result = viewModel.search(options);
      
      expect(result.totalCount).assertLarger(0);
      expect(result.videos.length).assertLarger(0);
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
      viewModel.buildIndex();
      
      const options: SearchOptions = {
        keyword: '音乐',
        mediaType: SearchMediaType.AUDIO
      };
      
      const result = viewModel.search(options);
      
      expect(result.audios.length).assertEqual(1);
      expect(result.videos.length).assertEqual(0);
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
      viewModel.buildIndex();
      
      const options: SearchOptions = {
        keyword: '视频',
        mediaType: SearchMediaType.VIDEO
      };
      
      const result = viewModel.search(options);
      
      expect(result.videos.length).assertEqual(1);
      expect(result.audios.length).assertEqual(0);
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
      viewModel.buildIndex();
      
      // 测试完整拼音
      const options1: SearchOptions = {
        keyword: 'zhoujielun',
        mediaType: SearchMediaType.ALL
      };
      
      const result1 = viewModel.search(options1);
      expect(result1.totalCount).assertLarger(0);
      
      // 测试拼音首字母
      const options2: SearchOptions = {
        keyword: 'zjl',
        mediaType: SearchMediaType.ALL
      };
      
      const result2 = viewModel.search(options2);
      expect(result2.totalCount).assertLarger(0);
    });
    
    /**
     * 测试搜索性能
     */
    it('should_search_with_ok_performance', 0, () => {
      const mediaList: FileInfo[] = createTestMediaList(1000);
      
      coordinator.buildIndexFromCache(mediaList);
      viewModel.buildIndex();
      
      const options: SearchOptions = {
        keyword: '测试',
        mediaType: SearchMediaType.ALL
      };
      
      const startTime = Date.now();
      const result = viewModel.search(options);
      const endTime = Date.now();
      const duration = endTime - startTime;
      
      // O(k)搜索应该在100ms内完成
      expect(duration).assertLess(100);
      expect(result.totalCount).assertLarger(0);
      
      console.log(`搜索耗时: ${duration}ms`);
    });
    
    /**
     * 测试空搜索
     */
    it('should_return_empty_for_empty_query', 0, () => {
      const mediaList: FileInfo[] = createTestMediaList(10);
      
      coordinator.buildIndexFromCache(mediaList);
      viewModel.buildIndex();
      
      const options: SearchOptions = {
        keyword: '',
        mediaType: SearchMediaType.ALL
      };
      
      const result = viewModel.search(options);
      
      expect(result.totalCount).assertEqual(0);
      expect(result.audios.length).assertEqual(0);
      expect(result.videos.length).assertEqual(0);
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
      viewModel.buildIndex();
      
      const options: SearchOptions = {
        keyword: '不存在的关键词',
        mediaType: SearchMediaType.ALL
      };
      
      const result = viewModel.search(options);
      
      expect(result.totalCount).assertEqual(0);
    });
    
    /**
     * 测试清空索引
     */
    it('should_clear_index', 0, () => {
      const mediaList: FileInfo[] = createTestMediaList(10);
      
      coordinator.buildIndexFromCache(mediaList);
      viewModel.buildIndex();
      
      viewModel.clearIndex();
      
      expect(viewModel.isIndexBuilt()).assertFalse();
      
      const stats = coordinator.getIndexStats();
      expect(stats.isBuilt).assertFalse();
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
      viewModel.buildIndex();
      
      // 测试英文关键词
      const options1: SearchOptions = {
        keyword: 'test',
        mediaType: SearchMediaType.ALL
      };
      
      const result1 = viewModel.search(options1);
      expect(result1.totalCount).assertEqual(1);
      
      // 测试中文关键词
      const options2: SearchOptions = {
        keyword: '测试',
        mediaType: SearchMediaType.ALL
      };
      
      const result2 = viewModel.search(options2);
      expect(result2.totalCount).assertEqual(1);
      
      // 测试拼音
      const options3: SearchOptions = {
        keyword: 'ceshi',
        mediaType: SearchMediaType.ALL
      };
      
      const result3 = viewModel.search(options3);
      expect(result3.totalCount).assertEqual(1);
    });
    
    /**
     * 测试性能基准
     */
    it('should_meet_performance_benchmark', 0, () => {
      const mediaList: FileInfo[] = createTestMediaList(5000);
      
      // 测试索引构建性能
      const buildStartTime = Date.now();
      coordinator.buildIndexFromCache(mediaList);
      viewModel.buildIndex();
      const buildEndTime = Date.now();
      const buildDuration = buildEndTime - buildStartTime;
      
      console.log(`索引构建耗时: ${buildDuration}ms`);
      
      // 测试搜索性能（多次搜索）
      const searchQueries = ['测试', 'test', 'zhou', 'zjl', '音乐', '视频'];
      const searchTimes: number[] = [];
      
      for (const query of searchQueries) {
        const options: SearchOptions = {
          keyword: query,
          mediaType: SearchMediaType.ALL
        };
        
        const startTime = Date.now();
        const result = viewModel.search(options);
        const endTime = Date.now();
        const duration = endTime - startTime;
        searchTimes.push(duration);
        
        console.log(`搜索 "${query}" 耗时: ${duration}ms, 结果: ${result.totalCount} 个`);
      }
      
      // 平均搜索时间应该在100ms内
      const avgSearchTime = searchTimes.reduce((a, b) => a + b, 0) / searchTimes.length;
      expect(avgSearchTime).assertLess(100);
      
      console.log(`平均搜索耗时: ${avgSearchTime}ms`);
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
      viewModel.buildIndex();
      
      const options: SearchOptions = {
        keyword: '周杰伦',
        mediaType: SearchMediaType.ALL
      };
      
      const result = viewModel.search(options);
      
      expect(result.totalCount).assertEqual(1);
    });
  });
}

/**
 * 创建测试FileInfo
 */
function createFileInfo(fileName: string, uri: string): FileInfo {
  const fileInfo = new FileInfo(fileName, uri, fileName.endsWith('.mp4') ? 'video/mp4' : 'audio/mp3');
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
    let fileName: string;
    let mimeType: string;
    
    // 创建多样化的文件名（中文、英文、拼音）
    if (i % 3 === 0) {
      fileName = `测试视频${i}.mp4`;
      mimeType = 'video/mp4';
    } else if (i % 3 === 1) {
      fileName = `TestVideo${i}.mp4`;
      mimeType = 'video/mp4';
    } else {
      fileName = `音乐文件${i}.mp3`;
      mimeType = 'audio/mp3';
    }
    
    const fileInfo = new FileInfo(fileName, `file://test${i}`, mimeType);
    
    // 添加艺术家信息（部分文件）
    if (i % 5 === 0) {
      fileInfo.appSourceName = i % 2 === 0 ? '周杰伦' : '林俊杰';
    }
    
    mediaList.push(fileInfo);
  }
  
  return mediaList;
}