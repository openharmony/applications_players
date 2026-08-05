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

import { HiLog } from '@ohos/common/src/main/ets/utils/HiLog';
import FileInfo from '@ohos/common/src/main/ets/model/FileInfo';
import { AudioItem } from '@ohos/common/src/main/ets/model/AudioItem';
import { VideoItem } from '@ohos/common/src/main/ets/model/VideoItem';
import { IMediaListAccess } from '@ohos/common/src/main/ets/bridge/IMediaListAccess';
import { SearchScorer, ScoredFile } from '@ohos/common/src/main/ets/utils/SearchScorer';
import { SearchIndexCoordinator } from '../manager/SearchIndexCoordinator.ets';
import { SearchPreference } from '../utils/SearchPreference';
import { SearchPreferenceConst } from '../constants/SearchPreferenceConst';
import { AppContext } from '@ohos/common/src/main/ets/context/AppContext';

const TAG = 'SearchViewModel';

/** SearchOverlay UI 状态快照，由 ViewModel listener 同步到 View @State */
export interface SearchOverlayUiState {
  searchText: string;
  filteredAudios: AudioItem[];
  filteredVideos: VideoItem[];
  isSearching: boolean;
  searchQueryId: number;
  totalCount: number;
  keywords: string[];
  historyKeywords: string[];
  quickKeywords: string[];
  showIdlePanel: boolean;
  showResultPanel: boolean;
}

export enum SearchMediaType {
  ALL = 'all',
  AUDIO = 'audio',
  VIDEO = 'video'
}

export interface SearchOptions {
  keyword: string;
  mediaType: SearchMediaType;
  debounceMs?: number;
}

export interface SearchResult {
  audios: AudioItem[];
  videos: VideoItem[];
  totalCount: number;
  queryId: number;
  keywords: string[];
}

export class SearchViewModel {
  private static instance: SearchViewModel;
  private mediaAccess: IMediaListAccess | null = null;

  /**
   * 由 entry 层（HomeViewModel）在初始化时注入媒体列表数据访问实例，
   * 消除 feature/search → feature/media 横向依赖。
   */
  public setMediaAccess(access: IMediaListAccess): void {
    this.mediaAccess = access;
  }
  private indexCoordinator: SearchIndexCoordinator = SearchIndexCoordinator.getInstance();
  private currentQueryId: number = 0;
  private debounceTimer: number = 0;
  private searchListeners: ((result: SearchResult) => void)[] = [];
  private indexBuilt: boolean = false;
  private preferenceInitialized: boolean = false;
  private searchPreference: SearchPreference = SearchPreference.getInstance();
  private overlayUiListeners: ((state: SearchOverlayUiState) => void)[] = [];
  private overlaySearchText: string = '';
  private overlayResultVisible: boolean = false;
  private overlayFilteredAudios: AudioItem[] = [];
  private overlayFilteredVideos: VideoItem[] = [];
  private overlayIsSearching: boolean = false;
  private overlaySearchQueryId: number = 0;
  private overlayTotalCount: number = 0;
  private overlayKeywords: string[] = [];
  private overlayHistoryKeywords: string[] = [];
  private overlayQuickKeywords: string[] = [];
  /** 即时搜索防抖定时器（字符级触发，短防抖避免连续键入 thrash） */
  private liveSearchTimer: number = 0;
  private static readonly LIVE_SEARCH_DEBOUNCE_MS: number = 80;

  private constructor() {
  }

  public static getInstance(): SearchViewModel {
    if (!SearchViewModel.instance) {
      SearchViewModel.instance = new SearchViewModel();
    }
    return SearchViewModel.instance;
  }

  public addSearchListener(listener: (result: SearchResult) => void): void {
    this.searchListeners.push(listener);
  }

  public removeSearchListener(listener: (result: SearchResult) => void): void {
    const index: number = this.searchListeners.indexOf(listener);
    if (index !== -1) {
      this.searchListeners.splice(index, 1);
    }
  }

  private sortFilesByNewest(files: FileInfo[]): FileInfo[] {
    return files.slice().sort((left: FileInfo, right: FileInfo): number => {
      const leftTime: number = left.createTime > 0 ? left.createTime : (left.updateTime ?? 0);
      const rightTime: number = right.createTime > 0 ? right.createTime : (right.updateTime ?? 0);
      if (rightTime !== leftTime) {
        return rightTime - leftTime;
      }
      return left.fileName.localeCompare(right.fileName);
    });
  }

  private notifySearchResult(result: SearchResult): void {
    for (const listener of this.searchListeners) {
      try {
        listener(result);
      } catch (error) {
        HiLog.e(TAG, `Search listener execution failed: ${error}`);
      }
    }
  }

  public search(options: SearchOptions): SearchResult {
    const queryId: number = ++this.currentQueryId;
    HiLog.i(TAG, `Starting search: keyword=${options.keyword}, mediaType=${options.mediaType}, queryId=${queryId}`);

    const keyword: string = options.keyword?.trim() || '';
    if (!keyword) {
      return {
        audios: [],
        videos: [],
        totalCount: 0,
        queryId: queryId,
        keywords: []
      };
    }

    const keywords: string[] = SearchScorer.parseKeywords(keyword);
    
    // 尝试使用倒排索引搜索（O(k)性能）
    if (this.indexBuilt) {
      try {
        const startTime = Date.now();
        const indexResults: FileInfo[] = this.indexCoordinator.searchByType(keyword, options.mediaType);
        const endTime = Date.now();
        const duration = endTime - startTime;
        
        HiLog.i(TAG, `Inverted index search completed, duration: ${duration}ms, results: ${indexResults.length} files`);
        
        // 如果索引搜索有结果，直接返回
        if (indexResults.length > 0) {
          const sortedIndexResults: FileInfo[] = this.sortFilesByNewest(indexResults);
          const audios: AudioItem[] = sortedIndexResults
            .filter((f: FileInfo): boolean => f.mimeType?.startsWith('audio') ?? false)
            .map((f: FileInfo): AudioItem => AudioItem.fromEntityFileInfo(f));
          
          const videos: VideoItem[] = sortedIndexResults
            .filter((f: FileInfo): boolean => f.mimeType?.startsWith('video') ?? false)
            .map((f: FileInfo): VideoItem => VideoItem.fromEntityFileInfo(f));
          
          const result: SearchResult = {
            audios: audios,
            videos: videos,
            totalCount: indexResults.length,
            queryId: queryId,
            keywords: keywords
          };
          
          HiLog.i(TAG, `Search completed: audio=${audios.length}, video=${videos.length}, queryId=${queryId}`);
          return result;
        }
      } catch (error) {
        HiLog.e(TAG, `Inverted index search failed, falling back to linear search: ${error}`);
      }
    }
    
    // Fallback: 使用线性搜索（O(n)性能）
    HiLog.i(TAG, 'Using linear search (SearchScorer)');
    
    const allFiles: FileInfo[] = this.mediaAccess!.getMediaList();
    
    let filteredByType: FileInfo[] = allFiles;
    if (options.mediaType === SearchMediaType.AUDIO) {
      filteredByType = allFiles.filter((f: FileInfo): boolean => f.mimeType?.startsWith('audio') ?? false);
    } else if (options.mediaType === SearchMediaType.VIDEO) {
      filteredByType = allFiles.filter((f: FileInfo): boolean => f.mimeType?.startsWith('video') ?? false);
    }

    const scoredFiles: ScoredFile[] = SearchScorer.filterAndSort(filteredByType, keyword);
    const sortedFiles: FileInfo[] = this.sortFilesByNewest(scoredFiles.map((sf: ScoredFile): FileInfo => sf.file));

    const audios: AudioItem[] = sortedFiles
      .filter((file: FileInfo): boolean => file.mimeType?.startsWith('audio') ?? false)
      .map((file: FileInfo): AudioItem => AudioItem.fromEntityFileInfo(file));

    const videos: VideoItem[] = sortedFiles
      .filter((file: FileInfo): boolean => file.mimeType?.startsWith('video') ?? false)
      .map((file: FileInfo): VideoItem => VideoItem.fromEntityFileInfo(file));

    const result: SearchResult = {
      audios: audios,
      videos: videos,
      totalCount: scoredFiles.length,
      queryId: queryId,
      keywords: keywords
    };

    HiLog.i(TAG, `Search completed: audio=${audios.length}, video=${videos.length}, queryId=${queryId}`);
    return result;
  }

  public async searchAsync(options: SearchOptions): Promise<SearchResult> {
    const queryId: number = ++this.currentQueryId;
    HiLog.i(TAG, `Async search started: keyword=${options.keyword}, queryId=${queryId}`);

    const keyword: string = options.keyword?.trim() || '';
    if (!keyword) {
      return {
        audios: [],
        videos: [],
        totalCount: 0,
        queryId: queryId,
        keywords: []
      };
    }

    try {
      const keywords: string[] = SearchScorer.parseKeywords(keyword);
      
      // 尝试使用倒排索引搜索（O(k)性能）
      if (this.indexBuilt) {
        try {
          const startTime = Date.now();
          const indexResults: FileInfo[] = this.indexCoordinator.searchByType(keyword, options.mediaType);
          const endTime = Date.now();
          const duration = endTime - startTime;
          
          HiLog.i(TAG, `Inverted index search completed, duration: ${duration}ms, results: ${indexResults.length} files`);
          
          // 如果索引搜索有结果，直接返回
          if (indexResults.length > 0) {
            if (this.currentQueryId !== queryId) {
              HiLog.i(TAG, `Search result stale, skipping: queryId=${queryId}, currentQueryId=${this.currentQueryId}`);
              return {
                audios: [],
                videos: [],
                totalCount: 0,
                queryId: queryId,
                keywords: keywords
              };
            }
            
            const sortedIndexResults: FileInfo[] = this.sortFilesByNewest(indexResults);
            const audios: AudioItem[] = sortedIndexResults
              .filter((f: FileInfo): boolean => f.mimeType?.startsWith('audio') ?? false)
              .map((f: FileInfo): AudioItem => AudioItem.fromEntityFileInfo(f));
            
            const videos: VideoItem[] = sortedIndexResults
              .filter((f: FileInfo): boolean => f.mimeType?.startsWith('video') ?? false)
              .map((f: FileInfo): VideoItem => VideoItem.fromEntityFileInfo(f));
            
            const result: SearchResult = {
              audios: audios,
              videos: videos,
              totalCount: indexResults.length,
              queryId: queryId,
              keywords: keywords
            };
            
            HiLog.i(TAG, `Async search completed: audio=${audios.length}, video=${videos.length}`);
            this.notifySearchResult(result);
            return result;
          }
        } catch (error) {
          HiLog.e(TAG, `Inverted index search failed, falling back to linear search: ${error}`);
        }
      }
      
      // Fallback: 使用线性搜索（O(n)性能）
      HiLog.i(TAG, 'Using linear search (SearchScorer)');
      
      const allFiles: FileInfo[] = this.mediaAccess!.getMediaList();
      
      let filteredByType: FileInfo[] = allFiles;
      if (options.mediaType === SearchMediaType.AUDIO) {
        filteredByType = allFiles.filter((f: FileInfo): boolean => f.mimeType?.startsWith('audio') ?? false);
      } else if (options.mediaType === SearchMediaType.VIDEO) {
        filteredByType = allFiles.filter((f: FileInfo): boolean => f.mimeType?.startsWith('video') ?? false);
      }

      if (this.currentQueryId !== queryId) {
        HiLog.i(TAG, `Search result stale, skipping: queryId=${queryId}, currentQueryId=${this.currentQueryId}`);
        return {
          audios: [],
          videos: [],
          totalCount: 0,
          queryId: queryId,
          keywords: keywords
        };
      }

      const scoredFiles: ScoredFile[] = SearchScorer.filterAndSort(filteredByType, keyword);
      const sortedFiles: FileInfo[] = this.sortFilesByNewest(scoredFiles.map((sf: ScoredFile): FileInfo => sf.file));

      const audios: AudioItem[] = sortedFiles
        .filter((file: FileInfo): boolean => file.mimeType?.startsWith('audio') ?? false)
        .map((file: FileInfo): AudioItem => AudioItem.fromEntityFileInfo(file));

      const videos: VideoItem[] = sortedFiles
        .filter((file: FileInfo): boolean => file.mimeType?.startsWith('video') ?? false)
        .map((file: FileInfo): VideoItem => VideoItem.fromEntityFileInfo(file));

      const result: SearchResult = {
        audios: audios,
        videos: videos,
        totalCount: scoredFiles.length,
        queryId: queryId,
        keywords: keywords
      };

      HiLog.i(TAG, `Async search completed: audio=${audios.length}, video=${videos.length}`);
      this.notifySearchResult(result);
      return result;
    } catch (error) {
      const errorMsg: string = error instanceof Error ? error.message : String(error);
      HiLog.e(TAG, `Async search failed: ${errorMsg}`);
      return {
        audios: [],
        videos: [],
        totalCount: 0,
        queryId: queryId,
        keywords: []
      };
    }
  }

  public searchWithDebounce(options: SearchOptions, callback: (result: SearchResult) => void): void {
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer);
    }

    const debounceMs: number = options.debounceMs ?? 300;
    this.debounceTimer = setTimeout(() => {
      const result: SearchResult = this.search(options);
      callback(result);
    }, debounceMs);
  }

  public cancelCurrentSearch(): void {
    this.currentQueryId++;
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer);
      this.debounceTimer = 0;
    }
    HiLog.i(TAG, `Cancelled current search: newQueryId=${this.currentQueryId}`);
  }

  public getMediaCount(): number {
    return this.mediaAccess!.getMediaCount();
  }

  public isReady(): boolean {
    return this.mediaAccess!.isReady();
  }

  public clearCache(): void {
    this.cancelCurrentSearch();
  }

  /**
   * 注册 SearchOverlay UI 状态监听
   *
   * @param listener 状态变更回调
   */
  public addOverlayUiListener(listener: (state: SearchOverlayUiState) => void): void {
    this.overlayUiListeners.push(listener);
  }

  /**
   * 移除 SearchOverlay UI 状态监听
   *
   * @param listener 状态变更回调
   */
  public removeOverlayUiListener(listener: (state: SearchOverlayUiState) => void): void {
    const index: number = this.overlayUiListeners.indexOf(listener);
    if (index !== -1) {
      this.overlayUiListeners.splice(index, 1);
    }
  }

  /**
   * SearchOverlay 打开：加载历史/快捷词并推送 UI 快照
   */
  public onOverlayOpened(): void {
    this.ensurePreferenceInitialized();
    this.refreshOverlayIdleData();
    this.notifyOverlayUiState();
    HiLog.i(TAG, `onOverlayOpened history=${this.overlayHistoryKeywords.length} quick=${this.overlayQuickKeywords.length}`);
  }

  /**
   * SearchOverlay 关闭：取消搜索、清理会话状态
   */
  public onOverlayClosed(): void {
    this.closeOverlaySession();
    HiLog.i(TAG, 'onOverlayClosed');
  }

  /**
   * 搜索框文本变更：有内容则即时模糊搜索，清空则回到历史/快捷分区
   *
   * @param text 当前输入
   */
  public updateSearchText(text: string): void {
    // 父组件同步关键词时会回传 onChange，需忽略以免重复触发
    if (text === this.overlaySearchText) {
      return;
    }
    this.overlaySearchText = text;
    const trimmed: string = text.trim();
    this.clearLiveSearchTimer();
    if (trimmed.length === 0) {
      this.cancelCurrentSearch();
      this.clearOverlaySearchResults();
      this.refreshOverlayIdleData();
      this.notifyOverlayUiState();
      return;
    }
    // 先切到结果区，再短防抖执行查询
    this.overlayResultVisible = true;
    this.notifyOverlayUiState();
    this.liveSearchTimer = setTimeout(() => {
      this.liveSearchTimer = 0;
      this.performOverlaySearch(false);
    }, SearchViewModel.LIVE_SEARCH_DEBOUNCE_MS);
  }

  /**
   * 点击历史/快捷词条：填入关键词并在当前页执行最终搜索（写入历史）
   *
   * @param keyword 关键词
   */
  public applyKeywordAndSearch(keyword: string): void {
    const trimmed: string = keyword.trim();
    if (trimmed.length === 0) {
      return;
    }
    HiLog.i(TAG, `applyKeywordAndSearch keyword=${trimmed}`);
    this.clearLiveSearchTimer();
    this.overlaySearchText = trimmed;
    this.notifyOverlayUiState();
    this.performOverlaySearch(true);
  }

  /**
   * 清空搜索历史并刷新空态面板
   */
  public clearOverlaySearchHistory(): void {
    HiLog.i(TAG, 'clearOverlaySearchHistory');
    this.clearSearchHistory();
    this.refreshOverlayIdleData();
    this.notifyOverlayUiState();
  }

  /**
   * 删除单条搜索历史并刷新空态面板
   *
   * @param keyword 待删除关键词
   */
  public removeOverlayHistoryItem(keyword: string): void {
    HiLog.i(TAG, `removeOverlayHistoryItem keyword=${keyword}`);
    this.removeSearchHistoryItem(keyword);
    this.refreshOverlayIdleData();
    this.notifyOverlayUiState();
  }

  /**
   * 快捷搜索恢复默认词条并刷新空态面板
   */
  public resetOverlayQuickSearch(): void {
    HiLog.i(TAG, 'resetOverlayQuickSearch');
    this.resetQuickSearchKeywords();
    this.refreshOverlayIdleData();
    this.notifyOverlayUiState();
  }

  /**
   * 关闭搜索页前重置会话（不控制 showOverlay，由 View @Link 处理）
   */
  public closeOverlaySession(): void {
    this.clearLiveSearchTimer();
    this.cancelCurrentSearch();
    this.overlaySearchText = '';
    this.overlayResultVisible = false;
    this.clearOverlaySearchResults();
    this.notifyOverlayUiState();
  }

  private clearLiveSearchTimer(): void {
    if (this.liveSearchTimer) {
      clearTimeout(this.liveSearchTimer);
      this.liveSearchTimer = 0;
    }
  }

  /** 构建并通知 SearchOverlay UI 状态快照 */
  private notifyOverlayUiState(): void {
    const state: SearchOverlayUiState = this.buildOverlayUiState();
    for (const listener of this.overlayUiListeners) {
      try {
        listener(state);
      } catch (error) {
        HiLog.e(TAG, `overlayUiListener failed: ${error}`);
      }
    }
  }

  /** 组装 SearchOverlay UI 状态快照：有输入则结果区，无输入则历史/快捷区 */
  private buildOverlayUiState(): SearchOverlayUiState {
    const hasInput: boolean = this.overlaySearchText.trim().length > 0;
    const showResultPanel: boolean = hasInput;
    const showIdlePanel: boolean = !hasInput;
    return {
      searchText: this.overlaySearchText,
      filteredAudios: this.overlayFilteredAudios.slice(),
      filteredVideos: this.overlayFilteredVideos.slice(),
      isSearching: this.overlayIsSearching,
      searchQueryId: this.overlaySearchQueryId,
      totalCount: this.overlayTotalCount,
      keywords: this.overlayKeywords.slice(),
      historyKeywords: this.overlayHistoryKeywords.slice(),
      quickKeywords: this.overlayQuickKeywords.slice(),
      showIdlePanel: showIdlePanel,
      showResultPanel: showResultPanel
    };
  }

  /** 从 Preferences 刷新历史/快捷词到 overlay 状态 */
  private refreshOverlayIdleData(): void {
    this.overlayHistoryKeywords = this.getSearchHistory().slice();
    this.overlayQuickKeywords = this.getQuickSearchKeywords().slice();
  }

  /** 清空 overlay 搜索结果区状态 */
  private clearOverlaySearchResults(): void {
    this.overlayFilteredAudios = [];
    this.overlayFilteredVideos = [];
    this.overlayTotalCount = 0;
    this.overlayIsSearching = false;
    this.overlayKeywords = [];
    this.overlaySearchQueryId = 0;
    this.overlayResultVisible = false;
  }

  /**
   * 执行 overlay 搜索：异步模糊匹配并推送结果区
   *
   * @param recordHistory 是否写入搜索历史（历史/快捷点击为 true，键入即时搜索为 false）
   */
  private performOverlaySearch(recordHistory: boolean): void {
    const keyword: string = this.overlaySearchText.trim();
    if (keyword.length === 0) {
      this.clearOverlaySearchResults();
      this.refreshOverlayIdleData();
      this.notifyOverlayUiState();
      return;
    }

    this.overlayResultVisible = true;
    this.overlayIsSearching = true;
    this.notifyOverlayUiState();
    this.cancelCurrentSearch();
    HiLog.i(TAG, `performOverlaySearch keyword=${keyword} recordHistory=${recordHistory}`);

    this.searchAsync({
      keyword: keyword,
      mediaType: SearchMediaType.ALL,
      debounceMs: 0
    }).then((result: SearchResult) => {
      // 输入已清空或关键词已变：丢弃过期结果
      if (this.overlaySearchText.trim() !== keyword) {
        HiLog.i(TAG, `performOverlaySearch stale skip keyword=${keyword}`);
        return;
      }
      this.overlaySearchQueryId = result.queryId;
      this.overlayFilteredAudios = result.audios.slice();
      this.overlayFilteredVideos = result.videos.slice();
      this.overlayTotalCount = result.totalCount;
      this.overlayKeywords = result.keywords.slice();
      this.overlayIsSearching = false;
      this.overlayResultVisible = true;
      if (recordHistory) {
        this.addSearchHistory(keyword);
        this.refreshOverlayIdleData();
      }
      HiLog.i(TAG, `performOverlaySearch done queryId=${result.queryId} total=${result.totalCount}`);
      this.notifyOverlayUiState();
    }).catch((error: Error) => {
      HiLog.e(TAG, `performOverlaySearch failed: ${error.message}`);
      this.overlayIsSearching = false;
      this.notifyOverlayUiState();
    });
  }

  /**
   * 懒加载搜索偏好（历史/快捷词条），依赖 MainAbility 上下文
   */
  public ensurePreferenceInitialized(): void {
    if (this.preferenceInitialized) {
      return;
    }
    const context = AppContext.getInstance().getMainAbilityContext();
    if (!context) {
      HiLog.w(TAG, 'ensurePreferenceInitialized skipped: context is null');
      return;
    }
    this.searchPreference.init(context);
    this.preferenceInitialized = true;
    HiLog.i(TAG, 'search preference initialized');
  }

  /**
   * 获取搜索历史列表
   *
   * @returns 历史关键词（最新在前）
   */
  public getSearchHistory(): string[] {
    this.ensurePreferenceInitialized();
    return this.searchPreference.getHistoryList();
  }

  /**
   * 获取快捷搜索词条
   *
   * @returns 快捷搜索列表
   */
  public getQuickSearchKeywords(): string[] {
    this.ensurePreferenceInitialized();
    return this.searchPreference.getQuickSearchList();
  }

  /**
   * 记录一次成功搜索的关键词（去重、置顶、限长）
   *
   * @param keyword 搜索关键词
   */
  public addSearchHistory(keyword: string): void {
    const trimmed = keyword.trim();
    if (trimmed.length === 0) {
      return;
    }
    this.ensurePreferenceInitialized();
    const history = this.searchPreference.getHistoryList();
    const filtered = history.filter((item: string) => item !== trimmed);
    filtered.unshift(trimmed);
    const limited = filtered.slice(0, SearchPreferenceConst.MAX_HISTORY_COUNT);
    this.searchPreference.setHistoryList(limited);
    HiLog.i(TAG, `addSearchHistory keyword=${trimmed} total=${limited.length}`);
  }

  /**
   * 删除单条搜索历史
   *
   * @param keyword 待删除的关键词
   */
  public removeSearchHistoryItem(keyword: string): void {
    const trimmed = keyword.trim();
    if (trimmed.length === 0) {
      return;
    }
    this.ensurePreferenceInitialized();
    const history = this.searchPreference.getHistoryList();
    const filtered = history.filter((item: string) => item !== trimmed);
    this.searchPreference.setHistoryList(filtered);
    HiLog.i(TAG, `removeSearchHistoryItem keyword=${trimmed} remain=${filtered.length}`);
  }

  /**
   * 清空搜索历史
   */
  public clearSearchHistory(): void {
    this.ensurePreferenceInitialized();
    this.searchPreference.clearHistory();
    HiLog.i(TAG, 'clearSearchHistory');
  }

  /**
   * 快捷搜索恢复默认词条
   */
  public resetQuickSearchKeywords(): void {
    this.ensurePreferenceInitialized();
    this.searchPreference.resetQuickSearchToDefault();
    HiLog.i(TAG, 'resetQuickSearchKeywords');
  }

  /**
   * 构建搜索索引
   * 从数据库缓存构建倒排索引，实现O(k)搜索性能
   */
  public buildIndex(): void {
    const allFiles: FileInfo[] = this.mediaAccess!.getMediaList();
    
    if (!allFiles || allFiles.length === 0) {
      HiLog.w(TAG, 'Media list is empty, skipping index build');
      return;
    }
    
    HiLog.i(TAG, `Building search index, ${allFiles.length} files`);
    
    const startTime = Date.now();
    this.indexCoordinator.buildIndexFromCache(allFiles);
    const endTime = Date.now();
    const duration = endTime - startTime;
    
    this.indexBuilt = true;
    
    HiLog.i(TAG, `Search index build complete, duration: ${duration}ms`);
  }
  
  /**
   * 检查索引是否已构建
   */
  public isIndexBuilt(): boolean {
    return this.indexBuilt;
  }
  
  /**
   * 清空搜索索引
   */
  public clearIndex(): void {
    this.indexCoordinator.clearIndex();
    this.indexBuilt = false;
    HiLog.i(TAG, 'Search index cleared');
  }
}
