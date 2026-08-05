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
import { SwipeDeleteEndAction } from '@ohos/common/src/main/ets/component/SwipeDeleteEndAction';
import { SwipeDeleteUtil } from '@ohos/common/src/main/ets/utils/SwipeDeleteUtil';
import { HiLog } from '@ohos/common/src/main/ets/utils/HiLog';
import { PlaylistTrackDataSource } from '../datasource/PlaylistTrackDataSource';
import { PlaylistConstants } from '../constants/PlaylistConstants';
import { PlaylistDetailTrackRow } from './PlaylistDetailTrackRow';

const TAG = 'PlaylistDetailTrackList';

/**
 * 播放列表详情页曲目列表：LazyForEach 直挂 ListItem；滑动删除按 track.uri 定佝（勿�?index 闭包�?
 */
@Component
export struct PlaylistDetailTrackList {
  trackDataSource: PlaylistTrackDataSource = new PlaylistTrackDataSource();
  onPlayTrack: (track: FileInfo) => void = () => {};
  onReorderTrack: (from: number, to: number) => void = () => {};
  onRemoveTrack: (uri: string) => void = () => {};

  @State longPressUri: string = '';
  private listScroller: ListScroller = new ListScroller();
  private longPressClearTimer: number = -1;

  aboutToDisappear(): void {
    this.clearLongPressEffect();
    this.closeAllSwipeActions();
  }

  /** 收起已展开的滑动删除区�?*/
  private closeAllSwipeActions(): void {
    SwipeDeleteUtil.closeAllSwipeActionsSafe(this.listScroller, TAG);
  }

  /** ListItem 背景色：仅被长按项高�?*/
  private getListItemBackgroundColor(uri: string): ResourceColor {
    return this.longPressUri === uri ? PlaylistConstants.DETAIL_TRACK_DRAG_HIGHLIGHT_BACKGROUND : $r('sys.color.ohos_id_color_background_transparent');
  }

  /** 清除长按高亮与待执行定时�?*/
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

  /** 延迟清除长按思：排在 onMove 之坎，靿兝抢在蝽点回调剝刷新导致拖拽回弹 */
  private scheduleClearLongPressEffect(): void {
    if (this.longPressClearTimer >= 0) {
      clearTimeout(this.longPressClearTimer);
    }
    this.longPressClearTimer = setTimeout(() => {
      this.clearLongPressEffect();
      this.longPressClearTimer = -1;
    }, 0);
  }

  /** 点击垃圾桶删�?*/
  private runSwipeDelete(uri: string): void {
    this.closeAllSwipeActions();
    SwipeDeleteUtil.runDeleteAnimation(() => {
      this.onRemoveTrack(uri);
    });
  }

  /** swipeAction.onAction：拉到底删除 */
  private runSwipeEndDelete(uri: string): void {
    this.closeAllSwipeActions();
    SwipeDeleteUtil.runSwipeEndDelete(() => {
      this.onRemoveTrack(uri);
    });
  }

  @Builder
  buildSwipeDeleteEnd(uri: string) {
    SwipeDeleteEndAction({
      onDelete: () => {
        this.runSwipeDelete(uri);
      }
    })
  }

  build() {
    Column() {
      Column() {
        List({ scroller: this.listScroller }) {
          LazyForEach(this.trackDataSource, (track: FileInfo) => {
            ListItem() {
              PlaylistDetailTrackRow({ track: track })
            }
            .backgroundColor(this.getListItemBackgroundColor(track.uri))
            .onClick(() => {
              HiLog.i(TAG, `playTrack clicked uri=${track.uri} fileName=${track.fileName}`);
              this.onPlayTrack(track);
            })
            .parallelGesture(
              LongPressGesture({
                repeat: false,
                duration: PlaylistConstants.DETAIL_TRACK_LONG_PRESS_DURATION_MS
              })
                .onAction(() => {
                  HiLog.i(TAG, `handleLongPressStart uri=${track.uri} fileName=${track.fileName}`);
                  this.longPressUri = track.uri;
                })
                .onActionEnd(() => {
                  HiLog.i(TAG, `longPress onActionEnd uri=${track.uri} fileName=${track.fileName}`);
                  this.scheduleClearLongPressEffect();
                }),
              GestureMask.Normal
            )
            .swipeAction({
              end: {
                builder: () => {
                  this.buildSwipeDeleteEnd(track.uri);
                },
                onAction: () => {
                  this.runSwipeEndDelete(track.uri);
                }
              }
            })
          }, (track: FileInfo) => track.uri)
            .onMove((from: number, to: number) => {
              HiLog.i(TAG, `onMove from=${from} to=${to} total=${this.trackDataSource.totalCount()} longPressUri=${this.longPressUri}`);
              this.closeAllSwipeActions();
              this.onReorderTrack(from, to);
              this.scheduleClearLongPressEffect();
            })
        }
        .onItemDragStart(() => {
          this.closeAllSwipeActions();
        })
        .divider({
          strokeWidth: PlaylistConstants.LIST_DIVIDER_STROKE_WIDTH,
          color: PlaylistConstants.LIST_DIVIDER_COLOR,
          startMargin: PlaylistConstants.LIST_DIVIDER_START_MARGIN,
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
