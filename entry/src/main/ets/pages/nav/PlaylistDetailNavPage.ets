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



import FileInfo from '@ohos/common/src/main/ets/model/FileInfo';
import { HiLog } from '@ohos/common/src/main/ets/utils/HiLog';
import {
  PlaylistViewModel,
  PlaylistUiState
} from '../../viewmodel/PlaylistViewModel';
import { PlaylistTrackDataSource, PlaylistDetailView } from '@ohos/playlist';

const TAG = 'PlaylistDetailNavPage';

/**
 * 播放列表详情 NavDestination 页
 */
@Component
export struct PlaylistDetailNavPage {
  @State detailName: string = '';
  @State detailTrackCount: number = 0;
  @State isDetailEmpty: boolean = true;
  @State showResumeBar: boolean = false;
  @State resumeTrackLabel: string = '';

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
    this.detailName = state.detailName;
    this.detailTrackCount = state.detailTrackCount;
    this.isDetailEmpty = state.isDetailEmpty;
    this.showResumeBar = state.showResumeBar;
    this.resumeTrackLabel = state.resumeTrackLabel;
  }

  build() {
    PlaylistDetailView({
      detailName: this.detailName,
      detailTrackCount: this.detailTrackCount,
      trackDataSource: this.detailTrackDataSource,
      isDetailEmpty: this.isDetailEmpty,
      showResumeBar: this.showResumeBar,
      resumeTrackLabel: this.resumeTrackLabel,
      onBack: () => {
        void this.viewModel.backToList();
      },
      onAddAudio: () => {
        this.viewModel.openAddAudioPage();
      },
      onPlayAll: () => {
        HiLog.i(TAG, 'onPlayAll clicked');
        this.viewModel.playAllDetail();
      },
      onContinueResume: () => {
        HiLog.i(TAG, 'onContinueResume clicked');
        this.viewModel.continueResumePlayback();
      },
      onDismissResume: () => {
        HiLog.i(TAG, 'onDismissResume clicked');
        this.viewModel.dismissResumePlayback();
      },
      onEnterEdit: () => {
        this.viewModel.openEditPage();
      },
      onPlayTrack: (track: FileInfo) => {
        HiLog.i(TAG, `onPlayTrack clicked fileName=${track.fileName}`);
        this.viewModel.playTrack(track);
      },
      onReorderTrack: (from: number, to: number) => {
        HiLog.i(TAG, `onReorderTrack from=${from} to=${to}`);
        this.viewModel.reorderDetailTrack(from, to);
      },
      onRemoveTrack: (uri: string) => {
        HiLog.i(TAG, `onRemoveTrack uri=${uri}`);
        void this.viewModel.removeDetailTrackByUri(uri);
      }
    })
      .width('100%')
      .height('100%')
  }
}
