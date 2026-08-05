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

import { AppBarType, Constants, WindowType } from '@ohos/common/src/main/ets/constants/ui/Constants';
import ToolbarItem from '@ohos/common/src/main/ets/model/ToolbarItem';
import DeviceConfigUtil from '@ohos/common/src/main/ets/utils/DeviceConfigUtil';
import { HiLog } from '@ohos/common';

const TAG = 'ToolButton';

@Component
export struct ToolButton {
  @State showText: boolean = true;
  @ObjectLink toolbarItem: ToolbarItem;
  public head: AppBarType = AppBarType.TITLE_BAR;
  public fontColor: ResourceColor | undefined = undefined;
  /** TitleBar 圆形操作按钮底色（未设则沿用 toolbarItem.backgroundColor） */
  @Prop actionButtonBackground: ResourceColor | undefined = undefined;
  public windowType: WindowType = WindowType.MAIN_WINDOW;

  aboutToAppear() {
    HiLog.i(TAG, `aboutToAppear`);
  }

  build() {
    Button({
      type: this.checkButtonType() ? ButtonType.Circle : ButtonType.Normal,
      stateEffect: true
    }) {
      Column() {
        SymbolGlyph(this.toolbarItem.icon)
          .fontColor([this.fontColor ? this.fontColor : Constants.COLOR_PRIMARY])
          .fontSize($r('app.float.app_bar_image_icon_width'))
          .fontWeight(FontWeight.Medium)
          .focusable(true)
          .draggable(false)
          .margin(this.head === AppBarType.TITLE_BAR ? Constants.APP_BAR_ICON_MARGIN : {
            top: Constants.TOOL_BAR_ICON_MARGIN_TOP,
            bottom: Constants.TITLE_BAR_ICON_MARGIN_BUTTON
          })

        if (this.showText) {
          Text(this.toolbarItem.title)
            .fontSize($r('sys.float.ohos_id_text_size_caption'))
            .fontColor($r('sys.color.ohos_id_color_toolbar_text'))
            .padding({ left: Constants.TOOL_BAR_TEXT_MARGIN, right: Constants.TOOL_BAR_TEXT_MARGIN })
            .id(`${this.head}_${this.toolbarItem.id}_text_id`)
        }
      }
      .alignItems(HorizontalAlign.Center)
      .justifyContent(FlexAlign.Center)
      .height(Constants.ALL_PERCENT)
    }
    .width(Constants.ALL_PERCENT)
    .height(Constants.ALL_PERCENT)
    .backgroundColor(this.getBackgroundColor())
    .hoverEffect(HoverEffect.None)
    .borderRadius(Constants.CLICKED_CORNER_RADIUS)
    .onClick((event: ClickEvent) => {
      this.toolbarItem.action(event);
    })
    .id(`${this.head}_${this.toolbarItem.id}_button_id`)
  }

  getBackgroundColor(): ResourceColor {
    if (this.head === AppBarType.TOOL_BAR) {
      return Constants.TRANSPARENT_BACKGROUND;
    }
    if (this.actionButtonBackground !== undefined) {
      return this.actionButtonBackground;
    }
    return this.toolbarItem.backgroundColor;
  }

  checkButtonType(): boolean {
    return this.head === AppBarType.TITLE_BAR && (!DeviceConfigUtil.checkConfigForPC());
  }
}
