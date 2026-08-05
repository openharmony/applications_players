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



import { BusinessError } from '@kit.BasicServicesKit';

import { LoadingStatus } from '@ohos/common/src/main/ets/constants/preview/PreviewConstants';
import FileInfo from '@ohos/common/src/main/ets/model/FileInfo';
import { ToolbarArray } from '@ohos/common/src/main/ets/model/ToolbarItem';
import { VideoItem } from '@ohos/common/src/main/ets/model/VideoItem';
import { syncAppLocalStorageSafeArea } from '@ohos/common/src/main/ets/storage/AppLocalStorage';
import { HiLog } from '@ohos/common/src/main/ets/utils/HiLog';
import WindowUtil from '@ohos/common/src/main/ets/utils/WindowUtil';
import { VideoPlayPage } from '@ohos/player/src/main/ets/pages/VideoPlayPage';
import window from '@ohos.window';

import { HomeUiState, HomeViewModel } from '../../viewmodel/HomeViewModel';

const TAG = 'VideoPlayerNavPage';

/**
 * 全屏视频播放 NavDestination 页
 */
@Component
export struct VideoPlayerNavPage {
  @State loadingStatus: LoadingStatus = LoadingStatus.LOAD_STATE_LOADING;
  @State currentFileInfo: FileInfo | null = null;
  @State toolBarItems: ToolbarArray = new ToolbarArray();

  private homeViewModel: HomeViewModel = HomeViewModel.getInstance();
  private isSyncingFromViewModel: boolean = false;

  aboutToAppear(): void {
    HiLog.i(TAG, 'aboutToAppear');
    this.homeViewModel.addUiStateListener(this.handleUiStateChange);
    syncAppLocalStorageSafeArea();
    this.preparePlayerSystemBars();
    this.mountFromViewModel(this.homeViewModel.getUiState());
  }

  aboutToDisappear(): void {
    HiLog.i(TAG, 'aboutToDisappear');
    this.homeViewModel.removeUiStateListener(this.handleUiStateChange);
  }

  private handleUiStateChange = (state: HomeUiState): void => {
    this.isSyncingFromViewModel = true;
    this.toolBarItems = this.homeViewModel.getToolBarItems();
    if (state.currentVideo !== undefined) {
      this.mountVideo(state.currentVideo);
    }
    this.isSyncingFromViewModel = false;
  };

  private mountFromViewModel(state: HomeUiState): void {
    this.toolBarItems = this.homeViewModel.getToolBarItems();
    if (state.currentVideo !== undefined) {
      this.mountVideo(state.currentVideo);
    }
  }

  private mountVideo(videoItem: VideoItem): void {
    if (this.currentFileInfo?.uri === videoItem.uri) {
      return;
    }
    HiLog.i(TAG, `mountVideo fileName=${videoItem.fileName}`);
    this.currentFileInfo = FileInfo.fromFileOperateFileInfo(videoItem.fileInfo);
    this.loadingStatus = LoadingStatus.LOAD_STATE_LOADING;
  }

  private preparePlayerSystemBars(): void {
    try {
      window.getLastWindow(getContext(this), (err: BusinessError, win: window.Window) => {
        if (err.code) {
          HiLog.e(TAG, `preparePlayerSystemBars failed message=${err.message}`);
          return;
        }
        WindowUtil.refreshAppSafeArea(win);
        WindowUtil.applyPlayerDarkSystemBars(win);
      });
    } catch (exception) {
      HiLog.e(TAG, `preparePlayerSystemBars exception=${String(exception)}`);
    }
  }

  build() {
    if (this.currentFileInfo !== null) {
      VideoPlayPage({
        loadingStatus: $loadingStatus,
        fileInfo: this.currentFileInfo,
        toolBarItems: this.toolBarItems,
        onClose: () => {
          this.homeViewModel.closeFullScreenPlayer();
        }
      })
    }
  }
}
