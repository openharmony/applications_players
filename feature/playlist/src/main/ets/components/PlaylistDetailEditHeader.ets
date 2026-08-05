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



import { AppThemeConstants } from '@ohos/common/src/main/ets/constants/ui/AppThemeConstants';
import { PlaylistConstants } from '../constants/PlaylistConstants';

/**
 * 歌单编辑 / 列表多选顶栏：关闭、已选数量、全选、删除
 * 全选：空框主色 / 全选实心强调色；删除：圆底始终浅灰，无选中仅图标灰显并拦截点击
 */
@Component
export struct PlaylistDetailEditHeader {
  @Prop @Watch('syncActionVisualState') selectedCount: number = 0;
  @Prop @Watch('syncActionVisualState') isAllSelected: boolean = false;
  onBack: () => void = () => {};
  onToggleSelectAll: () => void = () => {};
  onDeleteSelected: () => void = () => {};

  @State private selectAllIcon: Resource = $r('sys.symbol.checkmark_square_on_square');
  @State private selectAllColor: Resource = $r('sys.color.ohos_id_color_text_primary');
  @State private deleteEnabled: boolean = false;
  @State private deleteIconColor: Resource = $r('sys.color.ohos_id_color_text_tertiary');

  aboutToAppear(): void {
    this.syncActionVisualState();
  }

  /** 由选中态推导图标/颜色，写入 @State 强制刷新 */
  private syncActionVisualState(): void {
    if (this.isAllSelected) {
      this.selectAllIcon = $r('sys.symbol.checkmark_square_on_square_fill');
      this.selectAllColor = $r('sys.color.font_emphasize');
    } else {
      this.selectAllIcon = $r('sys.symbol.checkmark_square_on_square');
      this.selectAllColor = $r('sys.color.ohos_id_color_text_primary');
    }
    this.deleteEnabled = this.selectedCount > 0;
    this.deleteIconColor = this.deleteEnabled ?
      $r('sys.color.ohos_id_color_text_primary') :
      $r('sys.color.ohos_id_color_text_tertiary');
  }

  build() {
    Row() {
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.xmark'))
          .fontSize(18)
          .fontColor([$r('sys.color.ohos_id_color_text_primary')])
          .fontWeight(FontWeight.Medium)
          .renderingStrategy(SymbolRenderingStrategy.SINGLE)
      }
      .buttonStyle(ButtonStyleMode.NORMAL)
      .width(36)
      .height(36)
      .backgroundColor(AppThemeConstants.HEADER_ICON_BACKGROUND)
      .onClick(() => {
        this.onBack();
      })

      Text(this.selectedCount > 0 ?
        $r('app.string.playlist_selection_count', this.selectedCount) :
        $r('app.string.playlist_selection_none'))
        .fontSize(17)
        .fontWeight(600)
        .fontColor(PlaylistConstants.TEXT_PRIMARY)
        .textAlign(TextAlign.Start)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ left: PlaylistConstants.DETAIL_HEADER_TITLE_GAP })

      Blank()
        .layoutWeight(1)

      Row({ space: PlaylistConstants.DETAIL_HEADER_ACTION_GAP }) {
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph(this.selectAllIcon)
            .fontSize(18)
            .fontColor([this.selectAllColor])
            .fontWeight(FontWeight.Medium)
            .renderingStrategy(SymbolRenderingStrategy.SINGLE)
        }
        .buttonStyle(ButtonStyleMode.NORMAL)
        .width(36)
        .height(36)
        .backgroundColor(AppThemeConstants.HEADER_ICON_BACKGROUND)
        .key(`playlist_select_all_${this.isAllSelected}`)
        .onClick(() => {
          this.onToggleSelectAll();
        })

        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.trash'))
            .fontSize(18)
            .fontColor([this.deleteIconColor])
            .fontWeight(FontWeight.Medium)
            .renderingStrategy(SymbolRenderingStrategy.SINGLE)
        }
        .buttonStyle(ButtonStyleMode.NORMAL)
        .width(36)
        .height(36)
        .backgroundColor(AppThemeConstants.HEADER_ICON_BACKGROUND)
        .key(`playlist_delete_${this.deleteEnabled}`)
        .onClick(() => {
          if (!this.deleteEnabled) {
            return;
          }
          this.onDeleteSelected();
        })
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({
      left: PlaylistConstants.DETAIL_HEADER_HORIZONTAL_PADDING,
      right: PlaylistConstants.DETAIL_HEADER_HORIZONTAL_PADDING,
      top: 8,
      bottom: 10
    })
  }
}
