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
import { FontScaleUtil } from '@ohos/common/src/main/ets/utils/FontScaleUtil';
import { PlaylistItem } from '../model/PlaylistItem';
import { PlaylistConstants } from '../constants/PlaylistConstants';

const TAG = 'PlaylistCard';

/**
 * 播放列表项：扁平行样式，左侧封面右侧名称+曲目数
 */
@Component
export struct PlaylistCard {
  @Prop @Watch('onItemChanged') item: PlaylistItem = { id: -1, name: '', count: 0, coverUri: '' };
  @Prop showCheckbox: boolean = false;
  @Prop isSelected: boolean = false;
  onMoreClick: () => void = () => {};
  @State displayCoverUri: string = '';
  @State displayCount: number = 0;
  @State displayName: string = '';
  /** 无封面占位 music 图标边长（vp），随封面尺寸与系统字号更新 */
  @State placeholderIconSizeVp: number = PlaylistConstants.GRID_CARD_COVER_ICON_SIZE;
  @StorageProp(FontScaleUtil.SYSTEM_FONT_SIZE_SCALE_KEY) @Watch('onSystemFontScaleChanged')
  systemFontSizeScale: number = FontScaleUtil.DEFAULT_SCALE;
  private coverSideVp: number = 0;

  aboutToAppear(): void {
    this.syncDisplayFromItem();
    this.refreshPlaceholderIconSize();
  }

  onItemChanged(): void {
    this.syncDisplayFromItem();
  }

  private onSystemFontScaleChanged(): void {
    this.refreshPlaceholderIconSize();
  }

  /** 占位图标：封面比例定基准，再乘系统字号，夹在合理区间内 */
  private refreshPlaceholderIconSize(): void {
    const side = this.coverSideVp > 0 ? this.coverSideVp : PlaylistConstants.GRID_CARD_COVER_ICON_SIZE /
      PlaylistConstants.GRID_CARD_COVER_ICON_RATIO;
    const fontScale = Math.max(FontScaleUtil.DEFAULT_SCALE, this.systemFontSizeScale);
    const byCover = side * PlaylistConstants.GRID_CARD_COVER_ICON_RATIO * fontScale;
    const maxSize = side * PlaylistConstants.GRID_CARD_COVER_ICON_MAX_RATIO;
    const next = Math.round(Math.min(maxSize, Math.max(PlaylistConstants.GRID_CARD_COVER_ICON_MIN, byCover)));
    if (next !== this.placeholderIconSizeVp) {
      this.placeholderIconSizeVp = next;
    }
  }

  /** 从 item 同步封面、名称与曲目数展示字段 */
  private syncDisplayFromItem(): void {
    this.displayName = this.item.name;
    this.displayCoverUri = this.item.coverUri;
    this.displayCount = this.item.count;
    if (this.displayCoverUri.length === 0) {
      HiLog.i(TAG, `syncDisplayFromItem placeholder id=${this.item.id} name=${this.item.name}`);
    }
  }

  /** 无封面占位：浅灰蓝底 + 居中系统 music 图标（随显示/字体缩放） */
  @Builder
  GridCoverPlaceholder() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(PlaylistConstants.GRID_CARD_COVER_PLACEHOLDER_BACKGROUND)

      SymbolGlyph($r('sys.symbol.music'))
        .fontSize(`${this.placeholderIconSizeVp}vp`)
        .fontColor([PlaylistConstants.GRID_CARD_COVER_PLACEHOLDER_ICON_COLOR])
        .fontWeight(FontWeight.Medium)
        .renderingStrategy(SymbolRenderingStrategy.SINGLE)
    }
    .width('100%')
    .height('100%')
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      const side = Number(newValue.width);
      if (!(side > 0) || Math.abs(side - this.coverSideVp) < 0.5) {
        return;
      }
      this.coverSideVp = side;
      this.refreshPlaceholderIconSize();
    })
  }

  @Builder
  ListCoverPlaceholder() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width(PlaylistConstants.THUMB_SIZE)
        .height(PlaylistConstants.THUMB_SIZE)
        .borderRadius(PlaylistConstants.LIST_CARD_COVER_PLACEHOLDER_RADIUS)
        .backgroundColor(PlaylistConstants.LIST_CARD_COVER_PLACEHOLDER_BACKGROUND)

      SymbolGlyph($r('sys.symbol.music_note_list'))
        .fontSize(PlaylistConstants.LIST_CARD_COVER_PLACEHOLDER_ICON_SIZE)
        .fontColor([PlaylistConstants.LIST_CARD_COVER_PLACEHOLDER_ICON_COLOR])
    }
    .width(PlaylistConstants.THUMB_SIZE)
    .height(PlaylistConstants.THUMB_SIZE)
  }

  @Builder
  GridCardBody() {
    Column() {
      Stack({ alignContent: Alignment.TopEnd }) {
        if (this.displayCoverUri.length > 0) {
          Image(this.displayCoverUri)
            .key(`playlist_cover_${this.item.id}_${this.displayCoverUri}`)
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Cover)
            .backgroundColor(PlaylistConstants.GRID_CARD_COVER_PLACEHOLDER_BACKGROUND)
        } else {
          this.GridCoverPlaceholder()
        }

        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.dot_grid_1x2'))
            .fontSize(PlaylistConstants.GRID_CARD_MORE_ICON_SIZE)
            .fontColor([PlaylistConstants.GRID_CARD_MORE_ICON_COLOR])
            .renderingStrategy(SymbolRenderingStrategy.SINGLE)
        }
        .width(PlaylistConstants.GRID_CARD_MORE_HIT_SIZE)
        .height(PlaylistConstants.GRID_CARD_MORE_HIT_SIZE)
        .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
        .margin({
          top: PlaylistConstants.GRID_CARD_MORE_MARGIN,
          right: PlaylistConstants.GRID_CARD_MORE_MARGIN
        })
        .onClick(() => {
          HiLog.i(TAG, `moreClick id=${this.item.id}`);
          this.onMoreClick();
        })
      }
      .width('100%')
      .aspectRatio(1)
      .clip(true)

      Column() {
        Text(this.displayName)
          .fontSize(PlaylistConstants.GRID_CARD_NAME_FONT_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(PlaylistConstants.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        Text($r('app.string.playlist_track_count', this.displayCount))
          .fontSize(PlaylistConstants.GRID_CARD_COUNT_FONT_SIZE)
          .fontColor(PlaylistConstants.TEXT_SECONDARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .margin({ top: PlaylistConstants.GRID_CARD_TEXT_GAP })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({
        left: PlaylistConstants.GRID_CARD_TEXT_PADDING_HORIZONTAL,
        right: PlaylistConstants.GRID_CARD_TEXT_PADDING_HORIZONTAL,
        top: PlaylistConstants.GRID_CARD_TEXT_PADDING_VERTICAL,
        bottom: PlaylistConstants.GRID_CARD_TEXT_PADDING_VERTICAL
      })
      .backgroundColor(PlaylistConstants.CARD_BACKGROUND)
    }
    .width('100%')
    .borderRadius(PlaylistConstants.GRID_CARD_BORDER_RADIUS)
    .clip(true)
    .backgroundColor(PlaylistConstants.CARD_BACKGROUND)
  }

  @Builder
  ListRowBody() {
    Row() {
      if (this.showCheckbox) {
        Checkbox({ name: `playlist_${this.item.id}` })
          .select(this.isSelected)
          .selectedColor(PlaylistConstants.PRIMARY_COLOR)
          .hitTestBehavior(HitTestMode.None)
          .width(24)
          .height(24)
          .margin({ right: 10 })
      }

      if (this.displayCoverUri.length > 0) {
        Image(this.displayCoverUri)
          .key(`playlist_cover_${this.item.id}_${this.displayCoverUri}`)
          .width(PlaylistConstants.THUMB_SIZE)
          .height(PlaylistConstants.THUMB_SIZE)
          .borderRadius(6)
          .objectFit(ImageFit.Cover)
          .backgroundColor(PlaylistConstants.DETAIL_TRACK_THUMB_PLACEHOLDER_BACKGROUND)
      } else {
        this.ListCoverPlaceholder()
      }

      Column() {
        Text(this.displayName)
          .fontSize(15)
          .fontWeight(500)
          .fontColor(PlaylistConstants.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text($r('app.string.playlist_track_count', this.displayCount))
          .fontSize(12)
          .fontColor(PlaylistConstants.TEXT_SECONDARY)
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 12 })

      SymbolGlyph($r('sys.symbol.line_3_horizontal'))
        .fontSize(20)
        .fontColor([PlaylistConstants.TEXT_PRIMARY])
        .margin({ left: 8 })
    }
    .width('100%')
    .padding({
      left: PlaylistConstants.DETAIL_HEADER_HORIZONTAL_PADDING,
      right: PlaylistConstants.DETAIL_HEADER_HORIZONTAL_PADDING,
      top: PlaylistConstants.DETAIL_FLAT_TRACK_ROW_PADDING_V,
      bottom: PlaylistConstants.DETAIL_FLAT_TRACK_ROW_PADDING_V
    })
  }

  build() {
    if (this.showCheckbox) {
      this.ListRowBody()
    } else {
      this.GridCardBody()
    }
  }
}
