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



import { PlaylistDataSource } from '../datasource/PlaylistDataSource';
import { PlaylistDetailEditHeader } from './PlaylistDetailEditHeader';
import { PlaylistEmptyState } from './PlaylistEmptyState';
import { PlaylistSelectList } from './PlaylistSelectList';
import { PlaylistConstants } from '../constants/PlaylistConstants';

/**
 * æ­Œå�•åˆ—è¡¨å¤šé€‰å­�é¡µé�¢ï¼šå¤�ç”¨ç¼–è¾‘é¡µé¡¶æ �æ ·å¼�ï¼Œç‚¹å‡»é€‰ä¸­ / å…¨é€?/ é•¿æŒ‰æ‹–æ‹½æŽ’åº�
 */
@Component
export struct PlaylistListSelectView {
  @Prop isEmpty: boolean = true;
  @Prop selectedPlaylistIds: number[] = [];
  dataSource: PlaylistDataSource = new PlaylistDataSource();
  onBack: () => void = () => {};
  onToggleSelectAll: () => void = () => {};
  onToggleSelect: (playlistId: number) => void = () => {};
  onReorderPlaylist: (from: number, to: number) => void = () => {};
  onDeleteSelected: () => void = () => {};

  build() {
    Column() {
      PlaylistDetailEditHeader({
        selectedCount: this.selectedPlaylistIds.length,
        isAllSelected: this.dataSource.totalCount() > 0 &&
          this.selectedPlaylistIds.length === this.dataSource.totalCount(),
        onBack: this.onBack,
        onToggleSelectAll: this.onToggleSelectAll,
        onDeleteSelected: this.onDeleteSelected
      })

      if (this.isEmpty) {
        PlaylistEmptyState({
          title: $r('app.string.playlist_empty_title'),
          hint: $r('app.string.playlist_empty_hint')
        })
      } else {
        PlaylistSelectList({
          dataSource: this.dataSource,
          selectedPlaylistIds: this.selectedPlaylistIds,
          onToggleSelect: this.onToggleSelect,
          onReorderPlaylist: this.onReorderPlaylist
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(PlaylistConstants.PAGE_BACKGROUND)
  }
}
