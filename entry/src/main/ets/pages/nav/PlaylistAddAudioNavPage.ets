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
import { PlaylistTrackDataSource, PlaylistAddAudioView } from '@ohos/playlist';

const TAG = 'PlaylistAddAudioNavPage';

/**
 * 播放列表添加音频 NavDestination 页
 */
@Component
export struct PlaylistAddAudioNavPage {
  @State searchKeyword: string = '';
  @State isEmpty: boolean = true;
  @State alreadyAddedUris: string[] = [];

  private viewModel: PlaylistViewModel = PlaylistViewModel.getInstance();
  private addAudioDataSource: PlaylistTrackDataSource = this.viewModel.getAddAudioDataSource();

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
    this.searchKeyword = state.addAudioSearchKeyword;
    this.isEmpty = state.isAddAudioEmpty;
    this.alreadyAddedUris = state.addAudioInPlaylistUris;
  }

  build() {
    PlaylistAddAudioView({
      searchKeyword: this.searchKeyword,
      isEmpty: this.isEmpty,
      alreadyAddedUris: this.alreadyAddedUris,
      trackDataSource: this.addAudioDataSource,
      onBack: () => {
        this.viewModel.backFromAddAudio();
      },
      onSearchTextChange: (keyword: string) => {
        this.viewModel.updateAddAudioSearchText(keyword);
      },
      onAddTrack: (track: FileInfo) => {
        this.viewModel.addAudioToCurrentPlaylist(track);
      }
    })
      .width('100%')
      .height('100%')
  }
}
