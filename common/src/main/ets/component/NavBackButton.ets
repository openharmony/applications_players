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

import { Constants } from '../constants/ui/Constants';

/**
 * 系统风格 Nav 返回按钮：chevron_backward + 圆形底，与播放器 TitleBar 一致
 */
@Component
export struct NavBackButton {
  /** 点击返回回调 */
  onBack: () => void = () => {};
  /** 图标颜色，默认系统 TitleBar 图标色 */
  @Prop iconColor: ResourceColor = $r('sys.color.ohos_id_color_titlebar_icon');
  /** 圆形按钮背景，默认系统按钮底色 */
  @Prop buttonBackground: ResourceColor = Constants.TITLE_BAR_ICON_BACKGROUND_COLOR;
  /** 按钮边长（vp） */
  @Prop buttonSize: number = Constants.APP_BAR_BUTTON_WIDTH;

  build() {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph(Constants.APP_BAR_ICON_BACK)
        .fontColor([this.iconColor])
        .fontSize(Constants.APP_BAR_IMAGE_ICON_WIDTH)
        .fontWeight(FontWeight.Medium)
        .focusable(true)
        .draggable(false)
    }
    .responseRegion({ width: this.buttonSize, height: this.buttonSize })
    .backgroundColor(this.buttonBackground)
    .width(this.buttonSize)
    .height(this.buttonSize)
    .borderRadius(Constants.CLICKED_CORNER_RADIUS)
    .onClick(() => {
      this.onBack();
    })
  }
}
