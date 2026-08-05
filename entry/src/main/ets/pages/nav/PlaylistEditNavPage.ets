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
import {
  PlaylistViewModel,
  PlaylistUiState
} from '../../viewmodel/PlaylistViewModel';
import { PlaylistTrackDataSource, PlaylistDetailEditView } from '@ohos/playlist';

const TAG = 'PlaylistEditNavPage';

/**
 * 播放列表编辑 NavDestination 页
 */
@Component
export struct PlaylistEditNavPage {
  @State isDetailEmpty: boolean = true;
  @State selectedUris: string[] = [];

  private viewModel: PlaylistViewModel = PlaylistViewModel.getInstance();
  private detailTrackDataSource: PlaylistTrackDataSource = this.viewModel.getDetailTrackDataSource();

  aboutToAppear(): void {
    HiLog.i(TAG, 'aboutToAppear');
    this.viewModel.addUiStateListener(this.handleUiStateChange);
    this.syncFromViewModel(this.viewModel.getUiState());
  }

  aboutToDisappear(): void {
    HiLog.i(TAG, 'aboutToDisappear');
    this.viewModel.removeUiStateListener(this.handleUiStateChange);
  }

  private handleUiStateChange = (state: PlaylistUiState): void => {
    this.syncFromViewModel(state);
  };

  private syncFromViewModel(state: PlaylistUiState): void {
    this.isDetailEmpty = state.isDetailEmpty;
    this.selectedUris = state.selectedUris;
  }

  build() {
    PlaylistDetailEditView({
      isDetailEmpty: this.isDetailEmpty,
      selectedUris: this.selectedUris,
      trackDataSource: this.detailTrackDataSource,
      onBack: () => {
        this.viewModel.backFromEdit();
      },
      onToggleSelectAll: () => {
        this.viewModel.toggleSelectAllTracks();
      },
      onToggleSelect: (uri: string) => {
        this.viewModel.toggleTrackSelection(uri);
      },
      onReorderTrack: (from: number, to: number) => {
        HiLog.i(TAG, `onReorderTrack edit from=${from} to=${to}`);
        this.viewModel.reorderDetailTrack(from, to);
      },
      onDeleteSelected: () => {
        this.viewModel.openDeleteTracksConfirm();
      }
    })
      .width('100%')
      .height('100%')
  }
}
