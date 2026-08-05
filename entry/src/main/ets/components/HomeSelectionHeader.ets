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



import { NavBackButton } from '@ohos/common';
import { AppThemeConstants } from '@ohos/common/src/main/ets/constants/ui/AppThemeConstants';
import { HomeSelectionConstants } from '../constants/HomeSelectionConstants';

/**
 * 首页媒体编辑顶栏：返回 + 已选 N 项 + 全选/删除
 * 全选：空框主色 / 全选实心强调色；删除：圆底始终浅灰，无选中仅图标灰显并拦截点击
 */
@Component
export struct HomeSelectionHeader {
  @Prop @Watch('syncActionVisualState') selectedCount: number = 0;
  @Prop @Watch('syncActionVisualState') isAllSelected: boolean = false;
  onBack: () => void = () => {};
  onToggleSelectAll: () => void = () => {};
  onDelete: () => void = () => {};

  @State private selectAllIcon: Resource = $r('sys.symbol.checkmark_square_on_square');
  @State private selectAllColor: Resource = $r('sys.color.ohos_id_color_text_primary');
  @State private deleteEnabled: boolean = false;
  @State private deleteIconColor: Resource = $r('sys.color.ohos_id_color_text_tertiary');

  aboutToAppear(): void {
    this.syncActionVisualState();
  }

  /** 由选中态推导图标/颜色，写入 @State 强制刷新（避免 @Builder 参数不更新） */
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
      Row({ space: HomeSelectionConstants.HEADER_TITLE_GAP }) {
        NavBackButton({
          onBack: () => {
            this.onBack();
          }
        })

        Text($r('app.string.media_selected_count', this.selectedCount))
          .fontSize(HomeSelectionConstants.HEADER_TITLE_FONT_SIZE)
          .fontWeight(600)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(VerticalAlign.Center)

      Row({ space: HomeSelectionConstants.HEADER_ACTION_GAP }) {
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph(this.selectAllIcon)
            .fontSize(HomeSelectionConstants.HEADER_ICON_SIZE)
            .fontColor([this.selectAllColor])
            .fontWeight(FontWeight.Medium)
            .renderingStrategy(SymbolRenderingStrategy.SINGLE)
        }
        .buttonStyle(ButtonStyleMode.NORMAL)
        .width(HomeSelectionConstants.HEADER_ICON_BUTTON_SIZE)
        .height(HomeSelectionConstants.HEADER_ICON_BUTTON_SIZE)
        .backgroundColor(AppThemeConstants.HEADER_ICON_BACKGROUND)
        .key(`home_select_all_${this.isAllSelected}`)
        .onClick(() => {
          this.onToggleSelectAll();
        })

        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.trash'))
            .fontSize(HomeSelectionConstants.HEADER_ICON_SIZE)
            .fontColor([this.deleteIconColor])
            .fontWeight(FontWeight.Medium)
            .renderingStrategy(SymbolRenderingStrategy.SINGLE)
        }
        .buttonStyle(ButtonStyleMode.NORMAL)
        .width(HomeSelectionConstants.HEADER_ICON_BUTTON_SIZE)
        .height(HomeSelectionConstants.HEADER_ICON_BUTTON_SIZE)
        .backgroundColor(AppThemeConstants.HEADER_ICON_BACKGROUND)
        .key(`home_delete_${this.deleteEnabled}`)
        .onClick(() => {
          if (!this.deleteEnabled) {
            return;
          }
          this.onDelete();
        })
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({
      left: HomeSelectionConstants.HEADER_PADDING_H,
      right: HomeSelectionConstants.HEADER_PADDING_H,
      top: HomeSelectionConstants.HEADER_PADDING_V,
      bottom: HomeSelectionConstants.HEADER_PADDING_V
    })
  }
}
