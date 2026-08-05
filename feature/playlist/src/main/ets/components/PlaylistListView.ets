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
import { PlaylistItem } from '../model/PlaylistItem';
import { PlaylistListHeader } from './PlaylistListHeader';
import { PlaylistEmptyState } from './PlaylistEmptyState';
import { PlaylistView } from './PlaylistView';
import { PlaylistConstants } from '../constants/PlaylistConstants';

/**
 * 播放列表 Tab 首页：顶�?+ 空�?/ 宫格
 */
@Component
export struct PlaylistListView {
  @Prop isEmpty: boolean = true;
  dataSource: PlaylistDataSource = new PlaylistDataSource();
  onCreateClick: () => void = () => {};
  onOpenDetail: (item: PlaylistItem) => void = () => {};
  onPlay: (item: PlaylistItem) => void = () => {};
  onRename: (item: PlaylistItem) => void = () => {};
  onDelete: (item: PlaylistItem) => void = () => {};
  onSwipeDeletePlaylist: (item: PlaylistItem) => void = () => {};
  onReorderPlaylist: (from: number, to: number) => void = () => {};
  onEnterSelectMode: (item: PlaylistItem) => void = () => {};

  build() {
    Column() {
      PlaylistListHeader({
        onCreateClick: this.onCreateClick
      })

      if (this.isEmpty) {
        PlaylistEmptyState({
          title: $r('app.string.playlist_empty_title'),
          hint: $r('app.string.playlist_empty_hint')
        })
      } else {
        PlaylistView({
          dataSource: this.dataSource,
          onOpenDetail: this.onOpenDetail,
          onPlay: this.onPlay,
          onRename: this.onRename,
          onDelete: this.onDelete,
          onSwipeDeletePlaylist: this.onSwipeDeletePlaylist,
          onReorderPlaylist: this.onReorderPlaylist,
          onEnterSelectMode: this.onEnterSelectMode
        })
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(PlaylistConstants.PAGE_BACKGROUND)
  }
}
