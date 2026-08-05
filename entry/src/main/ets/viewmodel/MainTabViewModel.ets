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

const TAG = 'MainTabViewModel';

/** 底部 Tab 索引 */
export enum MainTabIndex {
  HOME = 0,
  PLAYLIST = 1
}

/**
 * 主框架 Tab UI 状态快照
 */
export interface MainTabUiState {
  currentTabIndex: number;
  /** 是否展示底部双 Tab 导航（仅各 Tab 一层页面为 true） */
  showTabBar: boolean;
}

/**
 * 主框架底部 Tab ViewModel：管理 Tab 切换状态
 */
export class MainTabViewModel {
  private static instance: MainTabViewModel;
  private uiStateListeners: ((state: MainTabUiState) => void)[] = [];
  private currentTabIndex: number = MainTabIndex.HOME;
  /** 首页是否处于一层（无搜索/设置等全屏子页） */
  private homeAtRoot: boolean = true;
  /** 播放列表是否处于宫格列表层 */
  private playlistAtRoot: boolean = true;
  /** 迷你播放条展示时，歌单子页（如详情）仍显示底部 Tab */
  private miniPlayerTabBarBoost: boolean = false;

  private constructor() {
  }

  /**
   * 获取 MainTabViewModel 单例
   *
   * @returns MainTabViewModel 实例
   */
  public static getInstance(): MainTabViewModel {
    if (!MainTabViewModel.instance) {
      MainTabViewModel.instance = new MainTabViewModel();
    }
    return MainTabViewModel.instance;
  }

  public getUiState(): MainTabUiState {
    return this.buildUiState();
  }

  public getCurrentTabIndex(): number {
    return this.currentTabIndex;
  }

  /**
   * 注册 Tab UI 状态监听器
   *
   * @param listener 状态快照回调
   */
  public addUiStateListener(listener: (state: MainTabUiState) => void): void {
    this.uiStateListeners.push(listener);
  }

  /**
   * 移除 Tab UI 状态监听器
   *
   * @param listener 待移除的回调
   */
  public removeUiStateListener(listener: (state: MainTabUiState) => void): void {
    const index = this.uiStateListeners.indexOf(listener);
    if (index !== -1) {
      this.uiStateListeners.splice(index, 1);
    }
  }

  /**
   * 切换底部 Tab
   *
   * @param index Tab 索引
   */
  public setTabIndex(index: number): void {
    if (index < MainTabIndex.HOME || index > MainTabIndex.PLAYLIST) {
      HiLog.w(TAG, `Invalid tab index: ${index}`);
      return;
    }
    if (this.currentTabIndex === index) {
      return;
    }
    this.currentTabIndex = index;
    HiLog.i(TAG, `Tab changed to: ${index} showTabBar=${this.computeShowTabBar()}`);
    this.notifyUiState();
  }

  /**
   * 同步首页是否处于一层页面（搜索/设置等子页打开时为 false）
   *
   * @param atRoot 是否一层
   */
  public setHomeAtRoot(atRoot: boolean): void {
    if (this.homeAtRoot === atRoot) {
      return;
    }
    this.homeAtRoot = atRoot;
    HiLog.i(TAG, `setHomeAtRoot atRoot=${atRoot} showTabBar=${this.computeShowTabBar()}`);
    this.notifyUiState();
  }

  /**
   * 同步播放列表是否处于宫格列表层（详情/编辑/添加音频时为 false）
   *
   * @param atRoot 是否一层
   */
  public setPlaylistAtRoot(atRoot: boolean): void {
    if (this.playlistAtRoot === atRoot) {
      return;
    }
    this.playlistAtRoot = atRoot;
    HiLog.i(TAG, `setPlaylistAtRoot atRoot=${atRoot} showTabBar=${this.computeShowTabBar()}`);
    this.notifyUiState();
  }

  /**
   * 迷你播放条可见且非全屏播放器时，歌单子页仍展示底部 Tab（如详情页播放全部后收起）
   *
   * @param enabled 是否启用
   */
  public setMiniPlayerTabBarBoost(enabled: boolean): void {
    if (this.miniPlayerTabBarBoost === enabled) {
      return;
    }
    this.miniPlayerTabBarBoost = enabled;
    HiLog.i(TAG, `setMiniPlayerTabBarBoost enabled=${enabled} showTabBar=${this.computeShowTabBar()}`);
    this.notifyUiState();
  }

  private computeShowTabBar(): boolean {
    if (this.currentTabIndex === MainTabIndex.HOME) {
      return this.homeAtRoot;
    }
    if (this.playlistAtRoot) {
      return true;
    }
    return this.miniPlayerTabBarBoost;
  }

  private buildUiState(): MainTabUiState {
    return {
      currentTabIndex: this.currentTabIndex,
      showTabBar: this.computeShowTabBar()
    };
  }

  private notifyUiState(): void {
    const state = this.buildUiState();
    for (const listener of this.uiStateListeners) {
      try {
        listener(state);
      } catch (error) {
        HiLog.e(TAG, `UiState listener failed: ${error}`);
      }
    }
  }
}
