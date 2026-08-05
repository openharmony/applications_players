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
import { PlaylistTrackDataSource } from '../datasource/PlaylistTrackDataSource';
import { PlaylistConstants } from '../constants/PlaylistConstants';
import { PlaylistEditTrackRow } from './PlaylistEditTrackRow';

const TAG = 'PlaylistEditTrackList';

/**
 * 播放列表编辑页曲目列表：扝平样弝对齝详情行，长按高亮 + 拖拽排庝
 */
@Component
export struct PlaylistEditTrackList {
  trackDataSource: PlaylistTrackDataSource = new PlaylistTrackDataSource();
  @Prop selectedUris: string[] = [];
  onToggleSelect: (uri: string) => void = () => {};
  onReorderTrack: (from: number, to: number) => void = () => {};

  @State longPressUri: string = '';
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
    if (this.longPressUri.length > 0) {
      HiLog.i(TAG, `clearLongPressEffect uri=${this.longPressUri}`);
    }
    this.longPressUri = '';
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

  /** 长按高亮背景�?*/
  private getListItemBackgroundColor(uri: string): ResourceColor {
    return this.longPressUri === uri ?
      PlaylistConstants.DETAIL_TRACK_DRAG_HIGHLIGHT_BACKGROUND : $r('sys.color.ohos_id_color_background_transparent');
  }

  @Builder
  buildEditTrackListItem(track: FileInfo) {
    ListItem() {
      PlaylistEditTrackRow({
        track: track,
        isSelected: this.selectedUris.includes(track.uri)
      })
    }
    .backgroundColor(this.getListItemBackgroundColor(track.uri))
    .onClick(() => {
      this.onToggleSelect(track.uri);
    })
    .parallelGesture(
      LongPressGesture({
        repeat: false,
        duration: PlaylistConstants.DETAIL_TRACK_LONG_PRESS_DURATION_MS
      })
        .onAction(() => {
          HiLog.i(TAG, `longPress onAction fileName=${track.fileName} uri=${track.uri}`);
          this.longPressUri = track.uri;
        })
        .onActionEnd(() => {
          HiLog.i(TAG, `longPress onActionEnd fileName=${track.fileName} uri=${track.uri}`);
          this.scheduleClearLongPressEffect();
        }),
      GestureMask.Normal
    )
  }

  build() {
    Column() {
      Column() {
        List({ scroller: this.listScroller }) {
          LazyForEach(this.trackDataSource, (track: FileInfo) => {
            this.buildEditTrackListItem(track);
          }, (track: FileInfo) => track.uri)
            .onMove((from: number, to: number) => {
              const total = this.trackDataSource.totalCount();
              HiLog.i(TAG, `onMove from=${from} to=${to} total=${total} longPressUri=${this.longPressUri}`);
              this.onReorderTrack(from, to);
              this.scheduleClearLongPressEffect();
            })
        }
        .divider({
          strokeWidth: PlaylistConstants.LIST_DIVIDER_STROKE_WIDTH,
          color: PlaylistConstants.LIST_DIVIDER_COLOR,
          startMargin: PlaylistConstants.LIST_DIVIDER_START_MARGIN_WITH_CHECKBOX,
          endMargin: PlaylistConstants.LIST_DIVIDER_END_MARGIN
        })
        .cachedCount(PlaylistConstants.DETAIL_TRACK_LIST_CACHED_COUNT)
        .layoutWeight(1)
        .width('100%')
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
    .padding({
      left: PlaylistConstants.LIST_CARD_MARGIN_H,
      right: PlaylistConstants.LIST_CARD_MARGIN_H,
      top: PlaylistConstants.LIST_CARD_MARGIN_TOP,
      bottom: PlaylistConstants.LIST_CARD_MARGIN_BOTTOM
    })
  }
}
