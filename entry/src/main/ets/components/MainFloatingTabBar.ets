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


import { MainTabIndex } from '../viewmodel/MainTabViewModel';
import { MainTabBarConstants } from '../constants/MainTabBarConstants';

interface MainTabItem {
  itemIndex: number;
  label: ResourceStr;
  icon: Resource;
  /** true：系统 Symbol；false：本地 SVG/图片资源 */
  useSymbolIcon: boolean;
}

/**
 * 底部 Tab 导航栏：悬浮白色胶囊 + 图标/文字，选中项蓝色
 */
@Component
export struct MainFloatingTabBar {
  @Prop currentTabIndex: number = MainTabIndex.HOME;
  /** 三键导航/手势条避让高度（vp），垫在胶囊下方 */
  @Prop bottomSafeInset: number = 0;
  onTabChange: (index: number) => void = () => {};

  private getTabItems(): MainTabItem[] {
    return [
      {
        itemIndex: MainTabIndex.HOME,
        label: $r('app.string.home'),
        icon: MainTabBarConstants.ICON_HOME,
        useSymbolIcon: false
      },
      {
          itemIndex: MainTabIndex.PLAYLIST,
        label: $r('app.string.my_playlist'),
        icon: MainTabBarConstants.ICON_PLAYLIST,
        useSymbolIcon: true
      }
    ];
  }

  build() {
    Column() {
      Row() {
        ForEach(this.getTabItems(), (item: MainTabItem) => {
          this.TabItem(item)
        }, (item: MainTabItem) => `${item.itemIndex}`)
      }
      .width('100%')
      .height(MainTabBarConstants.BAR_HEIGHT)
      .backgroundColor(MainTabBarConstants.BAR_BG)
      .borderRadius(MainTabBarConstants.BAR_BORDER_RADIUS)
      .shadow({
        radius: 12,
        color: 'rgba(0,0,0,0.08)',
        offsetY: 2
      })
    }
    .width('100%')
    .padding({
      left: MainTabBarConstants.BAR_MARGIN_H,
      right: MainTabBarConstants.BAR_MARGIN_H,
      bottom: MainTabBarConstants.BAR_MARGIN_BOTTOM + this.bottomSafeInset
    })
  }

  @Builder
  TabItem(item: MainTabItem) {
    Column({ space: MainTabBarConstants.TAB_ICON_TEXT_SPACE }) {
      if (item.useSymbolIcon) {
        SymbolGlyph(item.icon)
          .fontSize(MainTabBarConstants.TAB_ICON_SIZE)
          .fontColor([this.isSelected(item.itemIndex) ?
            MainTabBarConstants.TAB_SELECTED_COLOR : MainTabBarConstants.TAB_UNSELECTED_COLOR])
      } else {
        Image(item.icon)
          .width(MainTabBarConstants.TAB_ICON_SIZE)
          .height(MainTabBarConstants.TAB_ICON_SIZE)
          .objectFit(ImageFit.Contain)
          .fillColor(this.isSelected(item.itemIndex) ?
            MainTabBarConstants.TAB_SELECTED_COLOR : MainTabBarConstants.TAB_UNSELECTED_COLOR)
      }

      Text(item.label)
        .fontSize(MainTabBarConstants.TAB_FONT_SIZE)
        .fontWeight(FontWeight.Normal)
        .fontColor(this.isSelected(item.itemIndex) ?
          MainTabBarConstants.TAB_SELECTED_COLOR : MainTabBarConstants.TAB_UNSELECTED_COLOR)
        .textAlign(TextAlign.Center)
        .maxLines(1)
    }
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .height('100%')
    .onClick(() => {
      if (!this.isSelected(item.itemIndex)) {
        this.onTabChange(item.itemIndex);
      }
    })
  }

  private isSelected(itemIndex: number): boolean {
    return this.currentTabIndex === itemIndex;
  }
}
