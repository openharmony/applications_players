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
import FileInfo from '@ohos/common/src/main/ets/model/FileInfo';
import ToolbarItem, { ToolbarArray } from '@ohos/common/src/main/ets/model/ToolbarItem';
import router from '@ohos.router';
import DeviceConfigUtil from '@ohos/common/src/main/ets/utils/DeviceConfigUtil';
import { HiLog } from '@ohos/common';
import { FontScaleUtil } from '@ohos/common/src/main/ets/utils/FontScaleUtil';
import { ToolButton } from './ToolButton';

const TAG = 'TitleBar';

@Component
export struct TitleBar {
  @State page?: Object | undefined = undefined;
  @State cusBackgroundColor: Resource = Constants.COLOR_SUB_BACKGROUND;
  @State windowType: WindowType = WindowType.MAIN_WINDOW;
  @ObjectLink toolBarItems: ToolbarArray;
  @Prop fileInfo: FileInfo;
  @Prop avoidPcDefaultButton: boolean = true;
  @Prop isVideoMode: boolean = false;
  @State isSmallWindow: boolean = true;
  @State isShowMenu: boolean = true;
  @Prop @Watch('watchFileName') fileName: string | Resource = '';
  @StorageProp('fontScale') fontScale: number = FontScaleUtil.DEFAULT_SCALE;
  @State textLength: number = 0;
  @State isShowTitleBar: boolean = false;
  @State isShowTitle: boolean = true;
  @Prop hideFileName: boolean = false;
  @Prop forceDarkStyle: boolean = false;
  /** 为 true 时顶栏背景透明（竖屏浅色视频面板等，避免大通条底色） */
  @Prop transparentTitleBar: boolean = false;
  @Prop showRotateButton: boolean = false;
  public onRotate?: () => void = undefined;
  public onBack?: () => void = undefined;
  private isPCConfig: boolean = DeviceConfigUtil.checkConfigForPC();

  watchFileName() {
    HiLog.i(TAG, 'filename change');
  }

  aboutToAppear() {
    HiLog.i(TAG, 'aboutToAppear');
    this.fileName = this.getDisplayName();
    this.watchFileName();
    this.isShowTitleBar = this.windowType === WindowType.MAIN_WINDOW || !this.isPCConfig;
  }

  handleBack() {
    if (this.onBack) {
      this.onBack();
    } else {
      router.back();
    }
  }

  @Builder
  otherButtonList() {
    Row({ space: Constants.TITLE_BAR_ICON_MARGIN_AROUND }) {
      ForEach(this.toolBarItems, (item: ToolbarItem, index: number) => {
        ToolButton({
          toolbarItem: item,
          showText: false,
          head: AppBarType.TITLE_BAR,
          fontColor: this.getChromeActionIconColor(),
          actionButtonBackground: this.getChromeActionButtonBg()
        })
        .width(Constants.APP_BAR_BUTTON_WIDTH)
        .height(Constants.APP_BAR_BUTTON_WIDTH)
      }, (index: number) => {
        return `${index}`;
      })
    }
    .justifyContent(FlexAlign.End)
    .height(Constants.BAR_HEIGHT)
  }

  build() {
    if (this.isShowTitleBar) {
      Row() {
        if (this.isPCConfig) {
          Row({ space: Constants.TITLE_BAR_MARGIN_12 }) {
            Button({ type: ButtonType.Circle, stateEffect: true }) {
              SymbolGlyph(Constants.APP_BAR_ICON_BACK)
                .fontColor([this.getBackIconColor()])
                .fontSize($r('app.float.app_bar_image_icon_width'))
                .fontWeight(FontWeight.Medium)
                .focusable(true)
                .draggable(false)
            }
            .responseRegion({ width: Constants.APP_BAR_BUTTON_WIDTH, height: Constants.APP_BAR_BUTTON_WIDTH })
            .backgroundColor(this.getBackButtonBgColor())
            .width(Constants.APP_BAR_BUTTON_WIDTH)
            .height(Constants.APP_BAR_BUTTON_WIDTH)
            .borderRadius(Constants.CLICKED_CORNER_RADIUS)
            .onClick(() => {
              this.handleBack();
            })
            .id('title_bar_back_button_id_pc')

            Row() {
              Text(this.getDisplayName())
                .wordBreak(WordBreak.BREAK_ALL)
                .fontSize(FontScaleUtil.scaleFont(18, this.fontScale))
                .fontColor(this.isVideoMode ? Color.White : $r('sys.color.ohos_id_color_titlebar_text'))
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .maxLines(1)
                .id('title_bar_file_name_id_pc')
            }
            .layoutWeight(1)
            .visibility(this.isShowTitle && !this.hideFileName ? Visibility.Visible : Visibility.Hidden)
          }
          .height(Constants.NEW_PC_WINDOW_DECOR_HEIGHT)
          .justifyContent(FlexAlign.Start)
          .padding({ left: Constants.TITLE_BAR_MARGIN_SIDE })

          Row() {
            this.otherButtonList()
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.End)
        } else {
          Row({ space: Constants.TITLE_BAR_ICON_MARGIN_AROUND }) {
            Button({ type: ButtonType.Circle, stateEffect: true }) {
              SymbolGlyph(Constants.APP_BAR_ICON_BACK)
                .fontColor([this.getBackIconColor()])
                .fontSize($r('app.float.app_bar_image_icon_width'))
                .fontWeight(FontWeight.Medium)
                .focusable(true)
                .draggable(false)
                .accessibilityText($r('app.string.return'))
            }
            .responseRegion({ width: Constants.APP_BAR_BUTTON_WIDTH, height: Constants.APP_BAR_BUTTON_WIDTH })
            .backgroundColor(this.getBackButtonBgColor())
            .width(Constants.APP_BAR_BUTTON_WIDTH)
            .height(Constants.APP_BAR_BUTTON_WIDTH)
            .borderRadius(Constants.CLICKED_CORNER_RADIUS)
            .onClick(() => {
              this.handleBack();
            })
            .id('title_bar_back_button_id_phone')

            Row() {
              Text(this.fileName)
                .wordBreak(WordBreak.BREAK_ALL)
                .fontSize(FontScaleUtil.scaleFont(18, this.fontScale))
                .fontColor(this.isVideoMode ? Color.White : $r('sys.color.ohos_id_color_text_primary'))
                .fontWeight(FontWeight.Bold)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .maxLines(1)
                .id('title_bar_file_name_id_phone')
            }
            .layoutWeight(1)
            .visibility(this.isShowTitle && !this.hideFileName ? Visibility.Visible : Visibility.Hidden)

            if (this.showRotateButton) {
              Button({ type: ButtonType.Circle, stateEffect: true }) {
                SymbolGlyph(Constants.APP_BAR_ICON_ROTATE_LANDSCAPE)
                  .fontColor([this.getChromeActionIconColor()])
                  .fontSize($r('app.float.app_bar_image_icon_width'))
                  .fontWeight(FontWeight.Medium)
              }
              .backgroundColor(this.getChromeActionButtonBg())
              .width(Constants.APP_BAR_BUTTON_WIDTH)
              .height(Constants.APP_BAR_BUTTON_WIDTH)
              .borderRadius(Constants.CLICKED_CORNER_RADIUS)
              .onClick(() => {
                HiLog.i(TAG, 'rotateButton clicked');
                if (this.onRotate) {
                  this.onRotate();
                }
              })
              .id('title_bar_rotate_button_id')
            }

            this.otherButtonList()
          }
          .height(Constants.BAR_HEIGHT)
          .padding({ left: Constants.TITLE_BAR_MARGIN_SIDE, right: Constants.TITLE_BAR_MARGIN_SIDE })
        }
      }
      .width(Constants.WEIGHT)
      .backgroundColor(this.getTitleBarBackground())
      .id('title_bar_id')
    }
  }

  private getBackIconColor(): ResourceColor {
    return this.getChromeActionIconColor();
  }

  private getBackButtonBgColor(): ResourceColor {
    return this.getChromeActionButtonBg();
  }

  /** 顶栏操作按钮图标色：视频浮层用白字，浅色面板用系统 TitleBar 色 */
  private getChromeActionIconColor(): ResourceColor {
    if (this.isVideoMode || this.forceDarkStyle) {
      return Color.White;
    }
    return $r('sys.color.ohos_id_color_titlebar_icon');
  }

  /** 顶栏操作按钮底色：视频/音频深色页用深灰圆底，浅色面板用系统圆形按钮底 */
  private getChromeActionButtonBg(): ResourceColor {
    if (this.isVideoMode) {
      return 'rgba(0,0,0,0.45)';
    }
    if (this.forceDarkStyle) {
      return '#3A3A3C';
    }
    return Constants.TITLE_BAR_ICON_BACKGROUND_COLOR;
  }

  private getTitleBarBackground(): ResourceColor {
    if (this.isVideoMode || this.transparentTitleBar) {
      return $r('sys.color.ohos_id_color_background_transparent');
    }
    if (this.forceDarkStyle) {
      return $r('app.color.player_page_bg');
    }
    return Constants.COLOR_SUB_BACKGROUND;
  }

  private getDisplayName(): string | Resource {
    if (!this.fileInfo) {
      HiLog.e(TAG, 'getDisplayName failed, fileInfo is undefined');
      return Constants.UNKNOWN_FILE_NAME;
    }
    return this.fileInfo.fileName ?? Constants.UNKNOWN_FILE_NAME;
  }
}
