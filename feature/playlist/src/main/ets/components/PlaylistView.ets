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
import { AppThemeConstants } from '@ohos/common/src/main/ets/constants/ui/AppThemeConstants';
import { PlaylistDataSource } from '../datasource/PlaylistDataSource';
import { PlaylistItem } from '../model/PlaylistItem';
import { PlaylistConstants, PopupStateEvent } from '../constants/PlaylistConstants';
import { PlaylistCard } from './PlaylistCard';

const TAG = 'PlaylistView';

/**
 * ????????????????? / ??????????
 */
@Component
export struct PlaylistView {
  dataSource: PlaylistDataSource = new PlaylistDataSource();
  @State popupVisible: boolean = false;
  @State popupTargetId: number = -1;
  private popupTargetItem: PlaylistItem = { id: -1, name: '', count: 0, coverUri: '' };
  onOpenDetail: (item: PlaylistItem) => void = () => {};
  onPlay: (item: PlaylistItem) => void = () => {};
  onRename: (item: PlaylistItem) => void = () => {};
  onDelete: (item: PlaylistItem) => void = () => {};
  onSwipeDeletePlaylist: (item: PlaylistItem) => void = () => {};
  onReorderPlaylist: (from: number, to: number) => void = () => {};
  onEnterSelectMode: (item: PlaylistItem) => void = () => {};

  aboutToDisappear(): void {
    this.closePopup('aboutToDisappear');
  }

  /**
   * ??????
   *
   * @param phase ????
   */
  private closePopup(phase: string): void {
    if (!this.popupVisible) {
      return;
    }
    HiLog.i(TAG, `closePopup phase=${phase} id=${this.popupTargetId}`);
    this.popupVisible = false;
    this.popupTargetId = -1;
  }

  /**
   * ??????
   *
   * @param item ????
   */
  private openPopup(item: PlaylistItem): void {
    HiLog.i(TAG, `openPopup id=${item.id}`);
    this.popupTargetItem = item;
    this.popupTargetId = item.id;
    this.popupVisible = true;
  }

  /** ?????????? popupTargetItem? */
  @Builder
  PlaylistMenuPopup() {
    Column({ space: 0 }) {
      this.PlaylistMenuRow($r('app.string.playlist_menu_play'), () => {
        this.closePopup('menuPlay');
        this.onPlay(this.popupTargetItem);
      })
      this.PlaylistMenuDivider()
      this.PlaylistMenuRow($r('app.string.playlist_menu_rename'), () => {
        this.closePopup('menuRename');
        this.onRename(this.popupTargetItem);
      })
      this.PlaylistMenuDivider()
      this.PlaylistMenuRow($r('app.string.delete'), () => {
        this.closePopup('menuDelete');
        this.onDelete(this.popupTargetItem);
      })
      this.PlaylistMenuDivider()
      this.PlaylistMenuRow($r('app.string.playlist_menu_select'), () => {
        this.closePopup('menuSelect');
        this.onEnterSelectMode(this.popupTargetItem);
      })
    }
    .width(PlaylistConstants.PLAYLIST_MENU_WIDTH)
    .backgroundColor(AppThemeConstants.CARD_BACKGROUND)
    .borderRadius(PlaylistConstants.PLAYLIST_MENU_RADIUS)
    .clip(true)
    .shadow({
      radius: 16,
      color: 'rgba(0,0,0,0.12)',
      offsetY: 4
    })
  }

  @Builder
  PlaylistMenuRow(label: ResourceStr, onClick: () => void) {
    Row() {
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Text(label)
          .fontSize(14)
          .fontWeight(500)
          .fontColor(AppThemeConstants.TEXT_PRIMARY)
          .width('100%')
          .textAlign(TextAlign.Start)
          .padding({ left: 12, right: 12 })
          .height(PlaylistConstants.PLAYLIST_MENU_ITEM_HEIGHT)
      }
      .layoutWeight(1)
      .height(PlaylistConstants.PLAYLIST_MENU_ITEM_HEIGHT)
      .backgroundColor($r('sys.color.ohos_id_color_background_transparent'))
      .borderRadius(PlaylistConstants.PLAYLIST_MENU_RADIUS)
      .onClick(onClick)
    }
    .width('100%')
    .height(PlaylistConstants.PLAYLIST_MENU_ITEM_HEIGHT)
    .padding({ left: PlaylistConstants.PLAYLIST_MENU_PRESS_INSET, right: PlaylistConstants.PLAYLIST_MENU_PRESS_INSET })
  }

  @Builder
  PlaylistMenuDivider() {
    Divider()
      .color(PlaylistConstants.LIST_DIVIDER_COLOR)
      .height(PlaylistConstants.LIST_DIVIDER_STROKE_WIDTH)
      .lineCap(LineCapStyle.Square)
      .padding({
        left: $r('sys.float.padding_level6'),
        right: $r('sys.float.padding_level6')
      })
  }

  build() {
    Grid() {
      LazyForEach(this.dataSource, (item: PlaylistItem) => {
        GridItem() {
          PlaylistCard({
            item: item,
            onMoreClick: () => {
              this.openPopup(item);
            }
          })
        }
        .bindPopup(this.popupVisible && this.popupTargetId === item.id, {
          builder: (): void => {
            this.PlaylistMenuPopup();
          },
          placement: Placement.BottomRight,
          popupColor: $r('sys.color.ohos_id_color_background_transparent'),
          enableArrow: false,
          maskColor: $r('sys.color.ohos_id_color_background_transparent'),
          autoCancel: true,
          onStateChange: (event: PopupStateEvent) => {
            if (!event.isVisible) {
              HiLog.i(TAG, `popupDisappear id=${this.popupTargetId}`);
              this.popupVisible = false;
              this.popupTargetId = -1;
            }
          }
        })
        .parallelGesture(
          GestureGroup(GestureMode.Parallel,
            LongPressGesture({
              repeat: false,
              duration: PlaylistConstants.DETAIL_TRACK_LONG_PRESS_DURATION_MS
            })
              .onAction(() => {
                HiLog.i(TAG, `longPress openMenu id=${item.id}`);
                this.openPopup(item);
              }),
            PanGesture({
              fingers: 1,
              distance: PlaylistConstants.GRID_MENU_DRAG_CLOSE_PAN_DISTANCE
            })
              .onActionStart(() => {
                if (!this.popupVisible) {
                  return;
                }
                HiLog.i(TAG, `panStart closeMenu id=${this.popupTargetId}`);
                this.closePopup('panStart');
              })
          ),
          GestureMask.Normal
        )
        .onClick(() => {
          HiLog.i(TAG, `gridItemClick id=${item.id}`);
          this.closePopup('gridItemClick');
          this.onOpenDetail(item);
        })
      }, (item: PlaylistItem) => `pl_${item.id}_${item.name}_${item.count}_${item.coverUri}`)
    }
    .id('playlist_grid')
    .columnsTemplate('1fr 1fr')
    .columnsGap(PlaylistConstants.GRID_COLUMNS_GAP)
    .rowsGap(PlaylistConstants.GRID_ROWS_GAP)
    .cachedCount(PlaylistConstants.GRID_CACHED_COUNT)
    .layoutWeight(1)
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .padding({
      left: PlaylistConstants.GRID_HORIZONTAL_PADDING,
      right: PlaylistConstants.GRID_HORIZONTAL_PADDING,
      top: PlaylistConstants.GRID_TOP_PADDING,
      bottom: PlaylistConstants.GRID_BOTTOM_PADDING
    })
  }
}
