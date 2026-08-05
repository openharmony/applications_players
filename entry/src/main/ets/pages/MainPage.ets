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

import { DefaultIndexPage } from './default/DefaultIndexPage';
import { PlaylistPage } from './PlaylistPage';
import { MainFloatingTabBar } from '../components/MainFloatingTabBar';
import { MainTabViewModel, MainTabUiState, MainTabIndex } from '../viewmodel/MainTabViewModel';
import { PlaylistViewModel } from '../viewmodel/PlaylistViewModel';
import { MainTabBarConstants } from '../constants/MainTabBarConstants';
import { HomeViewModel, HomeUiState } from '../viewmodel/HomeViewModel';
import { AudioMiniPlayerBar } from '@ohos/player/src/main/ets/component/AudioMiniPlayerBar';
import { AudioPlaybackHost } from '@ohos/player/src/main/ets/component/AudioPlaybackHost';
import { AudioItem } from '@ohos/common/src/main/ets/model/AudioItem';
import FileInfo from '@ohos/common/src/main/ets/model/FileInfo';
import { HiLog, PlaybackHistoryRestoreCallback, PlaybackMediaKind } from '@ohos/common';
import { SafeAreaConstants } from '@ohos/common/src/main/ets/constants/ui/SafeAreaConstants';
import { AppThemeConstants } from '@ohos/common/src/main/ets/constants/ui/AppThemeConstants';
import { NavRouterHelper } from '../utils/NavRouterHelper';
import { AppNavPageMap } from '../navigation/AppNavPageMap';

const TAG = 'MainPage';

/**
 * 主框架 View：底部 Tab 壳层 + NavPathStack 子页导航
 */
@Component
export struct MainPage {
  @Provide('pageStack') pageStack: NavPathStack = new NavPathStack();
  @StorageProp(SafeAreaConstants.STATUS_BAR_HEIGHT_KEY) statusBarHeight: number = 0;
  @StorageProp(SafeAreaConstants.NAVI_INDICATOR_HEIGHT_KEY) naviIndicatorHeight: number = 0;
  @State currentTabIndex: number = MainTabIndex.HOME;
  @State showTabBar: boolean = true;
  @State showPlayer: boolean = false;
  @State showMiniPlayer: boolean = false;
  @State currentAudio: AudioItem | undefined = undefined;
  @State miniPlaybackFileInfo: FileInfo = new FileInfo('', '', '');
  private tabViewModel: MainTabViewModel = MainTabViewModel.getInstance();
  private homeViewModel: HomeViewModel = HomeViewModel.getInstance();

  aboutToAppear(): void {
    HiLog.i(TAG, `aboutToAppear statusBarHeight=${this.statusBarHeight} naviIndicatorHeight=${this.naviIndicatorHeight}`);
    NavRouterHelper.attach(this.pageStack);
    this.tabViewModel.addUiStateListener(this.handleTabUiStateChange);
    this.homeViewModel.addUiStateListener(this.handleHomePlayerStateChange);
    this.currentTabIndex = this.tabViewModel.getCurrentTabIndex();
    this.showTabBar = this.tabViewModel.getUiState().showTabBar;
    this.syncPlayerState(this.homeViewModel.getUiState());
  }

  aboutToDisappear(): void {
    HiLog.i(TAG, 'aboutToDisappear');
    NavRouterHelper.detach();
    this.tabViewModel.removeUiStateListener(this.handleTabUiStateChange);
    this.homeViewModel.removeUiStateListener(this.handleHomePlayerStateChange);
  }

  private handleTabUiStateChange = (state: MainTabUiState): void => {
    this.currentTabIndex = state.currentTabIndex;
    this.showTabBar = state.showTabBar;
  };

  /** HomeViewModel 播放器状态同步到 MainPage（迷你条 / 后台宿主） */
  private handleHomePlayerStateChange = (state: HomeUiState): void => {
    this.showPlayer = state.showPlayer;
    this.showMiniPlayer = state.showMiniPlayer;
    this.currentAudio = state.currentAudio;
    this.syncMiniPlaybackFileInfo(state.currentAudio);
  };

  private syncPlayerState(state: HomeUiState): void {
    this.showPlayer = state.showPlayer;
    this.showMiniPlayer = state.showMiniPlayer;
    this.currentAudio = state.currentAudio;
    this.syncMiniPlaybackFileInfo(state.currentAudio);
  }

  /** 同步迷你条后台宿主的 FileInfo（避免 build 内重复 new） */
  private syncMiniPlaybackFileInfo(audio: AudioItem | undefined): void {
    if (audio === undefined) {
      return;
    }
    this.miniPlaybackFileInfo = FileInfo.fromFileOperateFileInfo(audio.fileInfo);
  }

  /**
   * 历史歌单恢复播放：委托 HomeViewModel 重建队列并打开全屏播放器
   */
  private handleRestoreHistoryPlayback: PlaybackHistoryRestoreCallback = (
    tracks: FileInfo[],
    startUri: string,
    sourceName: string,
    kind: PlaybackMediaKind
  ): void => {
    HiLog.i(TAG, `handleRestoreHistoryPlayback kind=${kind} uri=${startUri}`);
    this.homeViewModel.restoreHistoryPlayback(tracks, startUri, sourceName, kind);
  };

  build() {
    Stack() {
      Navigation(this.pageStack) {
        Column() {
          Tabs({ barPosition: BarPosition.End, index: this.currentTabIndex }) {
            TabContent() {
              DefaultIndexPage()
            }

            TabContent() {
              PlaylistPage()
            }
          }
          .layoutWeight(1)
          .barHeight(0)
          .scrollable(false)
          .onChange((index: number) => {
            this.tabViewModel.setTabIndex(index);
            if (index === MainTabIndex.PLAYLIST) {
              PlaylistViewModel.getInstance().syncDetailResumeUi();
            }
          })

          if (this.showMiniPlayer && this.currentAudio !== undefined) {
            AudioMiniPlayerBar({
              audioItem: this.currentAudio,
              onExpand: () => {
                this.homeViewModel.expandAudioPlayer();
              },
              onRestoreHistoryPlayback: this.handleRestoreHistoryPlayback,
              onAudioQueueEmpty: () => {
                this.homeViewModel.dismissMiniPlayerPermanently();
              },
              onPrepareQueueSheet: () => {
                this.homeViewModel.ensureAudioQueueRestoredForMiniPlayer();
              }
            })
              .margin({
                left: MainTabBarConstants.MINI_PLAYER_MARGIN_H,
                right: MainTabBarConstants.MINI_PLAYER_MARGIN_H,
                bottom: MainTabBarConstants.MINI_PLAYER_MARGIN_BOTTOM
              })
          }

          if (this.showTabBar) {
            MainFloatingTabBar({
              currentTabIndex: this.currentTabIndex,
              bottomSafeInset: this.naviIndicatorHeight,
              onTabChange: (index: number) => {
                this.tabViewModel.setTabIndex(index);
              }
            })
          }
        }
        .padding({
          top: this.statusBarHeight
        })
        .backgroundColor(AppThemeConstants.PAGE_BACKGROUND)
      }
      .hideTitleBar(true)
      .navDestination(AppNavPageMap)
      .mode(NavigationMode.Stack)

      if (this.showMiniPlayer && !this.showPlayer && this.currentAudio !== undefined) {
        AudioPlaybackHost({
          fileInfo: this.miniPlaybackFileInfo
        })
      }
    }
    .width('100%')
    .height('100%')
  }
}
