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

import { PlaybackHistoryRestoreCallback, PlaybackMediaKind } from '@ohos/common';
import { LoadingStatus } from '@ohos/common/src/main/ets/constants/preview/PreviewConstants';
import FileInfo from '@ohos/common/src/main/ets/model/FileInfo';
import { ToolbarArray } from '@ohos/common/src/main/ets/model/ToolbarItem';
import { AudioItem } from '@ohos/common/src/main/ets/model/AudioItem';
import { syncAppLocalStorageSafeArea } from '@ohos/common/src/main/ets/storage/AppLocalStorage';
import { HiLog } from '@ohos/common/src/main/ets/utils/HiLog';
import WindowUtil from '@ohos/common/src/main/ets/utils/WindowUtil';
import { AudioPage } from '@ohos/player/src/main/ets/pages/AudioPage';
import { AudioPlaybackSession } from '@ohos/player/src/main/ets/session/AudioPlaybackSession';
import window from '@ohos.window';

import { HomeUiState, HomeViewModel } from '../../viewmodel/HomeViewModel';

const TAG = 'AudioPlayerNavPage';

/**
 * 全屏音频播放 NavDestination 页
 */
@Component
export struct AudioPlayerNavPage {
  @State loadingStatus: LoadingStatus = LoadingStatus.LOAD_STATE_LOADING;
  @State currentFileInfo: FileInfo | null = null;
  @State toolBarItems: ToolbarArray = new ToolbarArray();
  @State audioPlayRevision: number = 0;

  private homeViewModel: HomeViewModel = HomeViewModel.getInstance();
  private lastHandledAudioRevision: number = -1;

  aboutToAppear(): void {
    HiLog.i(TAG, 'aboutToAppear');
    this.homeViewModel.addUiStateListener(this.handleUiStateChange);
    syncAppLocalStorageSafeArea();
    this.preparePlayerSystemBars();
    const state: HomeUiState = this.homeViewModel.getUiState();
    this.toolBarItems = this.homeViewModel.getToolBarItems();
    this.audioPlayRevision = state.audioPlayRevision;
    if (state.currentAudio !== undefined) {
      this.mountAudio(state.currentAudio, state.audioPlayRevision);
    }
  }

  aboutToDisappear(): void {
    HiLog.i(TAG, 'aboutToDisappear');
    this.homeViewModel.removeUiStateListener(this.handleUiStateChange);
  }

  private handleUiStateChange = (state: HomeUiState): void => {
    this.toolBarItems = this.homeViewModel.getToolBarItems();
    this.audioPlayRevision = state.audioPlayRevision;
    if (state.currentAudio === undefined) {
      this.currentFileInfo = null;
      return;
    }
    if (state.audioPlayRevision !== this.lastHandledAudioRevision) {
      this.mountAudio(state.currentAudio, state.audioPlayRevision);
    }
  };

  private mountAudio(audioItem: AudioItem, revision: number): void {
    if (revision === this.lastHandledAudioRevision && this.currentFileInfo?.uri === audioItem.uri) {
      return;
    }
    HiLog.i(TAG, `mountAudio fileName=${audioItem.fileName} revision=${revision}`);
    this.lastHandledAudioRevision = revision;
    this.currentFileInfo = FileInfo.fromFileOperateFileInfo(audioItem.fileInfo);
    const controller = AudioPlaybackSession.getInstance().getController();
    if (controller.getActiveUri() === audioItem.uri && controller.hasActivePlayback()) {
      this.loadingStatus = LoadingStatus.LOAD_STATE_SUCCESS;
    } else {
      this.loadingStatus = LoadingStatus.LOAD_STATE_LOADING;
    }
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

  private handleRestoreHistoryPlayback: PlaybackHistoryRestoreCallback = (
    tracks: FileInfo[],
    startUri: string,
    sourceName: string,
    kind: PlaybackMediaKind
  ): void => {
    this.homeViewModel.restoreHistoryPlayback(tracks, startUri, sourceName, kind);
  };

  build() {
    if (this.currentFileInfo !== null) {
      AudioPage({
        loadingStatus: $loadingStatus,
        fileInfo: this.currentFileInfo,
        toolBarItems: this.toolBarItems,
        onRestoreHistoryPlayback: this.handleRestoreHistoryPlayback,
        onAudioQueueEmpty: () => {
          this.homeViewModel.dismissMiniPlayerPermanently();
        },
        onMinimize: () => {
          this.homeViewModel.minimizeAudioPlayer();
        },
        onClose: () => {
          this.homeViewModel.closeFullScreenPlayer();
        }
      })
    }
  }
}
