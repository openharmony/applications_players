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



import { PlaylistTrackDataSource } from '../datasource/PlaylistTrackDataSource';
import { PlaylistDetailEditHeader } from './PlaylistDetailEditHeader';
import { PlaylistEmptyState } from './PlaylistEmptyState';
import { PlaylistEditTrackList } from './PlaylistEditTrackList';
import { PlaylistSelectionDeleteBar } from './PlaylistSelectionDeleteBar';
import { PlaylistConstants } from '../constants/PlaylistConstants';

/**
 * æ’­æ”¾åˆ—è¡¨ç¼–è¾‘å­�é¡µé�¢ï¼šå¤šé€‰é¡¶æ ?+ æ›²ç›®åˆ—è¡¨ + åº•éƒ¨åˆ é™¤æ�¡ï¼ˆä¸Žè¯¦æƒ…é¡µè§£è€¦ï¼‰
 */
@Component
export struct PlaylistDetailEditView {
  @Prop isDetailEmpty: boolean = true;
  @Prop selectedUris: string[] = [];
  trackDataSource: PlaylistTrackDataSource = new PlaylistTrackDataSource();
  onBack: () => void = () => {};
  onToggleSelectAll: () => void = () => {};
  onToggleSelect: (uri: string) => void = () => {};
  onReorderTrack: (from: number, to: number) => void = () => {};
  onDeleteSelected: () => void = () => {};

  build() {
    Column() {
      PlaylistDetailEditHeader({
        selectedCount: this.selectedUris.length,
        isAllSelected: this.trackDataSource.totalCount() > 0 &&
          this.selectedUris.length === this.trackDataSource.totalCount(),
        onBack: this.onBack,
        onToggleSelectAll: this.onToggleSelectAll,
        onDeleteSelected: this.onDeleteSelected
      })

      if (this.isDetailEmpty) {
        PlaylistEmptyState({
          title: $r('app.string.playlist_detail_empty_title'),
          hint: $r('app.string.playlist_detail_empty_hint')
        })
      } else {
        PlaylistEditTrackList({
          trackDataSource: this.trackDataSource,
          selectedUris: this.selectedUris,
          onToggleSelect: this.onToggleSelect,
          onReorderTrack: this.onReorderTrack
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(PlaylistConstants.DETAIL_CONTENT_BACKGROUND)
  }
}
