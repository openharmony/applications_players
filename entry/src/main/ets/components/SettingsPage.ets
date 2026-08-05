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
import { AppThemeConstants } from '@ohos/common/src/main/ets/constants/ui/AppThemeConstants';
import { NavBackButton } from '@ohos/common';
import { SettingsViewModel } from '../viewmodel/SettingsViewModel';

const TAG = 'SettingsPage';

/** 界面缩放卡片相对屏幕左右外边距 */
const SETTINGS_CARD_MARGIN_H: number = 16;
/** 界面缩放卡片上下外边距 */
const SETTINGS_CARD_MARGIN_V: number = 16;
/** 卡片内边距；进度条与标题文字共用，保证左对齐 */
const SETTINGS_CARD_PADDING: number = 16;
/** 滑轨厚度（InSet 胶囊样式，与滑块约 5:3） */
const SLIDER_TRACK_THICKNESS: number = 16;
/** 滑块直径 */
const SLIDER_BLOCK_SIZE: number = 10;
/** 进度条与百分比间距（靠近） */
const SLIDER_LABEL_SPACE: number = 4;
/** 标题与返回按钮间距 */
const NAV_TITLE_GAP: number = 12;

/**
 * 显示设置全屏页 View（NavDestination 内容区）
 */
@Component
export struct SettingsPage {
  onClose: () => void = () => {};
  @StorageLink('fontScale') fontScale: number = FontScaleUtil.DEFAULT_SCALE;

  private viewModel: SettingsViewModel = SettingsViewModel.getInstance();

  build() {
    Column() {
      this.NavBar()

      // 用父级左右 padding 保证卡片两侧外边距均为 16（避免 width 100% + margin 失效）
      Column() {
        Column() {
          Text($r('app.string.settings_section_font_scale'))
            .fontSize(FontScaleUtil.scaleFont(14, this.fontScale))
            .fontWeight(600)
            .fontColor(AppThemeConstants.TEXT_PRIMARY)
            .width('100%')
            .margin({ bottom: 12 })

          Row({ space: SLIDER_LABEL_SPACE }) {
            Slider({
              value: this.fontScale,
              min: FontScaleUtil.MIN_SCALE,
              max: FontScaleUtil.MAX_SCALE,
              step: FontScaleUtil.STEP,
              style: SliderStyle.InSet
            })
              .layoutWeight(1)
              .height(SLIDER_TRACK_THICKNESS)
              .trackThickness(SLIDER_TRACK_THICKNESS)
              .trackBorderRadius(SLIDER_TRACK_THICKNESS / 2)
              .selectedBorderRadius(SLIDER_TRACK_THICKNESS / 2)
              .blockSize({ width: SLIDER_BLOCK_SIZE, height: SLIDER_BLOCK_SIZE })
              .blockColor(Color.White)
              .blockBorderColor(AppThemeConstants.ACCENT)
              .blockBorderWidth(1)
              .trackColor(AppThemeConstants.BORDER)
              .selectedColor(AppThemeConstants.ACCENT)
              .showSteps(false)
              .onChange((value: number, mode: SliderChangeMode) => {
                if (mode === SliderChangeMode.Begin || mode === SliderChangeMode.Moving ||
                  mode === SliderChangeMode.Click || mode === SliderChangeMode.End) {
                  this.fontScale = this.viewModel.setFontScale(value);
                }
              })

            Text(this.viewModel.getFontScaleLabel(this.fontScale))
              .fontSize(FontScaleUtil.scaleFont(14, this.fontScale))
              .fontWeight(500)
              .fontColor(AppThemeConstants.TEXT_SECONDARY)
              .textAlign(TextAlign.Start)
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          .clip(true)

          Text($r('app.string.settings_font_scale_hint'))
            .fontSize(FontScaleUtil.scaleFont(12, this.fontScale))
            .fontColor(AppThemeConstants.TEXT_SECONDARY)
            .lineHeight(FontScaleUtil.scaleFont(18, this.fontScale))
            .width('100%')
            .margin({ top: 10 })
        }
        .width('100%')
        .padding(SETTINGS_CARD_PADDING)
        .backgroundColor(AppThemeConstants.CARD_BACKGROUND)
        .borderRadius(12)
        .clip(true)
      }
      .width('100%')
      .padding({
        left: SETTINGS_CARD_MARGIN_H,
        right: SETTINGS_CARD_MARGIN_H,
        top: SETTINGS_CARD_MARGIN_V,
        bottom: SETTINGS_CARD_MARGIN_V
      })

      Blank()
        .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppThemeConstants.PAGE_BACKGROUND)
  }

  /** 顶部导航栏：标题靠近返回按钮，字号不随 fontScale 变化 */
  @Builder
  NavBar() {
    Row({ space: NAV_TITLE_GAP }) {
      NavBackButton({
        onBack: () => {
          HiLog.i(TAG, 'Back button clicked');
          this.onClose();
        }
      })

      Text($r('app.string.settings_page_title'))
        .fontSize(20)
        .fontWeight(600)
        .fontColor(AppThemeConstants.TEXT_PRIMARY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 4, bottom: 8 })
    .alignItems(VerticalAlign.Center)
  }
}
