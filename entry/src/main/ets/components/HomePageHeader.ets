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

/** bindPopup onStateChange 事件 */
interface MoreMenuPopupStateEvent {
  isVisible: boolean;
}

const MORE_MENU_WIDTH: number = 160;
const MORE_MENU_ITEM_HEIGHT: number = 44;
const MORE_MENU_RADIUS: number = 12;

/**
 * 首页顶栏 View：标题 + 搜索 / 导入 / 更多菜单
 */
@Component
export struct HomePageHeader {
  @Prop isGridView: boolean = true;
  /** ViewModel 递增时关闭更多菜单（离开首页上下文、打开其它浮层时） */
  @Prop @Watch('onMenuDismissSignal') menuDismissSignal: number = 0;
  onSearch: () => void = () => {};
  onImport: () => void = () => {};
  onRefresh: () => void = () => {};
  onToggleView: () => void = () => {};
  onOpenSort: () => void = () => {};
  onOpenEdit: () => void = () => {};
  onOpenSettings: () => void = () => {};
  @State private showMoreMenu: boolean = false;

  private onMenuDismissSignal(): void {
    this.showMoreMenu = false;
  }

  build() {
    Row() {
      Text($r('app.string.home'))
        .fontSize(26)
        .fontWeight(600)
        .fontColor(AppThemeConstants.TEXT_PRIMARY)
        .letterSpacing(-0.5)

      Blank()

      Row({ space: 8 }) {
        this.IconButton($r('sys.symbol.magnifyingglass'), () => {
          this.onSearch();
        })

        this.IconButton($r('sys.symbol.plus'), () => {
          this.onImport();
        })

        this.MoreMenuButton()
      }
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 4, bottom: 6 })
  }

  /** 右上角圆形图标 Button（设计稿：浅灰圆底 + 深色线框图标） */
  @Builder
  IconButton(icon: Resource, onClick: () => void) {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph(icon)
        .fontSize(18)
        .fontColor([AppThemeConstants.TEXT_PRIMARY])
        .fontWeight(FontWeight.Medium)
    }
    .buttonStyle(ButtonStyleMode.NORMAL)
    .width(36)
    .height(36)
    .backgroundColor(AppThemeConstants.HEADER_ICON_BACKGROUND)
    .onClick(onClick)
  }

  /**
   * 更多菜单：使用 bindPopup 自定义面板，避免 bindMenu 系统遮罩关闭后残留空白层。
   */
  @Builder
  MoreMenuButton() {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph($r('sys.symbol.dot_grid_2x2'))
        .fontSize(18)
        .fontColor([AppThemeConstants.TEXT_PRIMARY])
        .fontWeight(FontWeight.Medium)
    }
    .buttonStyle(ButtonStyleMode.NORMAL)
    .width(36)
    .height(36)
    .backgroundColor(AppThemeConstants.HEADER_ICON_BACKGROUND)
    .bindPopup(this.showMoreMenu, {
      builder: (): void => {
        this.buildMoreMenuPopup();
      },
      placement: Placement.Bottom,
      popupColor: $r('sys.color.ohos_id_color_background_transparent'),
      enableArrow: false,
      mask: true,
      maskColor: $r('sys.color.ohos_id_color_background_transparent'),
      autoCancel: true,
      onStateChange: (event: MoreMenuPopupStateEvent) => {
        if (!event.isVisible) {
          this.showMoreMenu = false;
        }
      }
    })
    .onClick(() => {
      this.showMoreMenu = !this.showMoreMenu;
    })
  }

  @Builder
  buildMoreMenuPopup() {
    Column({ space: 0 }) {
      this.buildMoreMenuRow($r('app.string.menu_Scan_to_refresh'), () => {
        this.onMoreMenuAction(() => {
          this.onRefresh();
        });
      })
      this.MoreMenuDivider()
      this.buildMoreMenuRow($r('app.string.menu_sort'), () => {
        this.onMoreMenuAction(() => {
          this.onOpenSort();
        });
      })
      this.MoreMenuDivider()
      this.buildMoreMenuRow($r('app.string.menu_edit'), () => {
        this.onMoreMenuAction(() => {
          this.onOpenEdit();
        });
      })
      this.MoreMenuDivider()
      this.buildMoreMenuRow(
        this.isGridView ? $r('app.string.menu_list_view') : $r('app.string.menu_grid_view'),
        () => {
          this.onMoreMenuAction(() => {
            this.onToggleView();
          });
        })
      // 【显示设置】入口已隐藏：保留 SettingsPage / ViewModel / Preferences 等功能代码，不从菜单进入
      /**
       * 保留代码，但功能隐藏
       * this.MoreMenuDivider()
       * this.buildMoreMenuRow($r('app.string.menu_display_settings'), () => {
       * this.onMoreMenuAction(() => {
       * this.onOpenSettings();
       * });
       * })
       * */
    }
    .width(MORE_MENU_WIDTH)
    .backgroundColor(AppThemeConstants.CARD_BACKGROUND)
    .borderRadius(MORE_MENU_RADIUS)
    .clip(true)
    .shadow({
      radius: 16,
      color: 'rgba(0,0,0,0.12)',
      offsetY: 4
    })
  }

  @Builder
  MoreMenuDivider() {
    Divider()
      .color($r('sys.color.ohos_id_color_list_separator'))
      .height('1px')
      .lineCap(LineCapStyle.Square)
      .padding({
        left: $r('sys.float.padding_level6'),
        right: $r('sys.float.padding_level6')
      })
  }

  @Builder
  buildMoreMenuRow(label: ResourceStr, onClick: () => void) {
    Row() {
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Text(label)
          .fontSize(14)
          .fontWeight(500)
          .fontColor(AppThemeConstants.TEXT_PRIMARY)
          .width('100%')
          .textAlign(TextAlign.Start)
          .height(MORE_MENU_ITEM_HEIGHT)
          .padding({ left: 12, right: 12 })
      }
      .layoutWeight(1)
      .height(MORE_MENU_ITEM_HEIGHT)
      .backgroundColor($r('sys.color.ohos_id_color_background_transparent'))
      .borderRadius(MORE_MENU_RADIUS)
      .onClick(onClick)
    }
    .width('100%')
    .height(MORE_MENU_ITEM_HEIGHT)
    .padding({ left: 6, right: 6 })
  }

  private onMoreMenuAction(action: () => void): void {
    this.showMoreMenu = false;
    action();
  }
}
