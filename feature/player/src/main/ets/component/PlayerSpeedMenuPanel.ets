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

import { Constants } from '@ohos/common/src/main/ets/constants/ui/Constants';
import { PlayerUiConstants } from '../constants/PlayerUiConstants';
import { AUDIO_SPEED_OPTIONS, SpeedOptionItem } from './AudioSpeedMenuOverlay';

/**
 * 播放器倍速选择面板：深色毛玻璃风格，与黑色播放页一致
 */
@Component
export struct PlayerSpeedMenuPanel {
  @Prop currentSpeedLabel: string = '1.0X';
  @Prop options: SpeedOptionItem[] = AUDIO_SPEED_OPTIONS;
  onSelect?: (option: SpeedOptionItem) => void;

  private isSelected(option: SpeedOptionItem): boolean {
    return this.currentSpeedLabel === option.label;
  }

  build() {
    Column() {
      Text($r('app.string.speed'))
        .fontSize(PlayerUiConstants.SPEED_MENU_TITLE_FONT_SIZE)
        .fontColor($r('app.color.player_speed_menu_text_secondary'))
        .fontWeight(FontWeight.Medium)
        .width('100%')
        .padding({
          left: PlayerUiConstants.SPEED_MENU_PADDING_H,
          right: PlayerUiConstants.SPEED_MENU_PADDING_H,
          top: PlayerUiConstants.SPEED_MENU_PADDING_TOP,
          bottom: PlayerUiConstants.SPEED_MENU_TITLE_BOTTOM_GAP
        })

      Divider()
        .color($r('app.color.player_speed_menu_divider'))
        .strokeWidth(0.5)
        .margin({
          left: PlayerUiConstants.SPEED_MENU_DIVIDER_MARGIN_H,
          right: PlayerUiConstants.SPEED_MENU_DIVIDER_MARGIN_H
        })

      Column() {
        ForEach(this.options, (option: SpeedOptionItem) => {
          Row() {
            Text(option.label)
              .fontSize(PlayerUiConstants.SPEED_MENU_ITEM_FONT_SIZE)
              .fontColor($r('app.color.player_speed_menu_text'))
              .fontWeight(this.isSelected(option) ? FontWeight.Medium : FontWeight.Regular)
              .layoutWeight(1)
            if (this.isSelected(option)) {
              SymbolGlyph(Constants.APP_BAR_ICON_CHECK_MARK)
                .fontSize(PlayerUiConstants.SPEED_MENU_CHECK_ICON_SIZE)
                .fontColor([$r('app.color.player_speed_menu_text')])
            }
          }
          .width('100%')
          .height(PlayerUiConstants.SPEED_MENU_ITEM_HEIGHT)
          .padding({
            left: PlayerUiConstants.SPEED_MENU_ITEM_PADDING_H,
            right: PlayerUiConstants.SPEED_MENU_ITEM_PADDING_H
          })
          .borderRadius(PlayerUiConstants.SPEED_MENU_ITEM_RADIUS)
          .backgroundColor(this.isSelected(option) ?
            $r('app.color.player_speed_menu_selected_bg') : $r('sys.color.ohos_id_color_background_transparent'))
          .onClick(() => {
            if (this.onSelect) {
              this.onSelect(option);
            }
          })
        }, (option: SpeedOptionItem) => option.label)
      }
      .width('100%')
      .padding({
        left: PlayerUiConstants.SPEED_MENU_LIST_PADDING_H,
        right: PlayerUiConstants.SPEED_MENU_LIST_PADDING_H,
        top: PlayerUiConstants.SPEED_MENU_LIST_PADDING_TOP,
        bottom: PlayerUiConstants.SPEED_MENU_LIST_PADDING_BOTTOM
      })
    }
    .width(PlayerUiConstants.SPEED_MENU_WIDTH)
    .backgroundColor($r('app.color.player_speed_menu_bg'))
    .backgroundBlurStyle(BlurStyle.Thin)
    .borderRadius(PlayerUiConstants.SPEED_MENU_BORDER_RADIUS)
    .borderWidth(1)
    .borderColor($r('app.color.player_speed_menu_border'))
    .shadow({
      radius: PlayerUiConstants.SPEED_MENU_SHADOW_RADIUS,
      color: PlayerUiConstants.SPEED_MENU_SHADOW_COLOR,
      offsetX: 0,
      offsetY: PlayerUiConstants.SPEED_MENU_SHADOW_OFFSET_Y
    })
  }
}
