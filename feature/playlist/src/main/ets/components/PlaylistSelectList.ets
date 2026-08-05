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
import { PlaylistDataSource } from '../datasource/PlaylistDataSource';
import { PlaylistItem } from '../model/PlaylistItem';
import { PlaylistConstants } from '../constants/PlaylistConstants';
import { PlaylistCard } from './PlaylistCard';

const TAG = 'PlaylistSelectList';

/**
 * 歌坕列表多选页：点击切杢选中，长按高�?+ 拖拽排庝（无滑动选中〝无左滑删除�?
 */
@Component
export struct PlaylistSelectList {
  dataSource: PlaylistDataSource = new PlaylistDataSource();
  @Prop selectedPlaylistIds: number[] = [];
  onToggleSelect: (playlistId: number) => void = () => {};
  onReorderPlaylist: (from: number, to: number) => void = () => {};

  @State longPressPlaylistId: number = -1;
  private listScroller: ListScroller = new ListScroller();
  private longPressClearTimer: number = -1;

  aboutToDisappear(): void {
    this.clearLongPressEffect();
  }

  private clearLongPressEffect(): void {
    if (this.longPressClearTimer >= 0) {
      clearTimeout(this.longPressClearTimer);
      this.longPressClearTimer = -1;
    }
    this.longPressPlaylistId = -1;
  }

  private scheduleClearLongPressEffect(): void {
    if (this.longPressClearTimer >= 0) {
      clearTimeout(this.longPressClearTimer);
    }
    this.longPressClearTimer = setTimeout(() => {
      this.clearLongPressEffect();
      this.longPressClearTimer = -1;
    }, 0);
  }

  private getListItemBackgroundColor(playlistId: number): ResourceColor {
    return this.longPressPlaylistId === playlistId ?
      PlaylistConstants.DETAIL_TRACK_DRAG_HIGHLIGHT_BACKGROUND : $r('sys.color.ohos_id_color_background_transparent');
  }

  @Builder
  buildSelectListItem(item: PlaylistItem) {
    ListItem() {
      PlaylistCard({
        item: item,
        showCheckbox: true,
        isSelected: this.selectedPlaylistIds.includes(item.id)
      })
    }
    .backgroundColor(this.getListItemBackgroundColor(item.id))
    .onClick(() => {
      this.onToggleSelect(item.id);
    })
    .parallelGesture(
      LongPressGesture({
        repeat: false,
        duration: PlaylistConstants.DETAIL_TRACK_LONG_PRESS_DURATION_MS
      })
        .onAction(() => {
          HiLog.i(TAG, `longPress onAction id=${item.id} name=${item.name}`);
          this.longPressPlaylistId = item.id;
        })
        .onActionEnd(() => {
          HiLog.i(TAG, `longPress onActionEnd id=${item.id}`);
          this.scheduleClearLongPressEffect();
        }),
      GestureMask.Normal
    )
  }

  build() {
    Column() {
      Column() {
        List({ scroller: this.listScroller, space: 0 }) {
          LazyForEach(this.dataSource, (item: PlaylistItem) => {
            this.buildSelectListItem(item);
          }, (item: PlaylistItem) => `pl_select_${item.id}_${item.count}_${item.coverUri}`)
            .onMove((from: number, to: number) => {
              HiLog.i(TAG, `onMove from=${from} to=${to} total=${this.dataSource.totalCount()}`);
              this.onReorderPlaylist(from, to);
              this.scheduleClearLongPressEffect();
            })
        }
        .id('playlist_select_grid')
        .divider({
          strokeWidth: PlaylistConstants.LIST_DIVIDER_STROKE_WIDTH,
          color: PlaylistConstants.LIST_DIVIDER_COLOR,
          startMargin: PlaylistConstants.LIST_DIVIDER_START_MARGIN_WITH_CHECKBOX,
          endMargin: PlaylistConstants.LIST_DIVIDER_END_MARGIN
        })
        .cachedCount(PlaylistConstants.DETAIL_TRACK_LIST_CACHED_COUNT)
        .layoutWeight(1)
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor(PlaylistConstants.LIST_CARD_BACKGROUND)
      .borderRadius(PlaylistConstants.LIST_CARD_RADIUS)
      .clip(true)
    }
    .width('100%')
    .layoutWeight(1)
    .height('100%')
    .padding({
      left: PlaylistConstants.LIST_CARD_MARGIN_H,
      right: PlaylistConstants.LIST_CARD_MARGIN_H,
      top: PlaylistConstants.LIST_CARD_MARGIN_TOP,
      bottom: PlaylistConstants.LIST_CARD_MARGIN_BOTTOM
    })
  }
}
