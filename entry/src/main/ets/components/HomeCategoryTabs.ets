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
import { AppThemeConstants } from '@ohos/common/src/main/ets/constants/ui/AppThemeConstants';
import { HomeViewConstants } from '../constants/HomeViewConstants';

const TAG = 'HomeCategoryTabs';

/** 与播放栏、底栏、列表卡片左侧对齐（设计稿 16） */
const CATEGORY_ROW_PADDING_H: number = 16;

interface CategoryTabItem {
  filterKey: string;
  label: ResourceStr;
  icon: Resource;
}

/**
 * 首页分类 Tab View：全部 / 音频 / 视频 分段选择
 */
@Component
export struct HomeCategoryTabs {
  @Prop currentFilter: string = HomeViewConstants.FILTER_ALL;
  onFilterSelected: (filterKey: string) => void = () => {};

  private getCategoryTabItems(): CategoryTabItem[] {
    return [
      {
        filterKey: HomeViewConstants.FILTER_ALL,
        label: $r('app.string.filter_all'),
        icon: $r('sys.symbol.square_fill_grid_2x2')
      },
      {
        filterKey: HomeViewConstants.FILTER_MUSIC,
        label: $r('app.string.audio'),
        icon: $r('sys.symbol.music_fill')
      },
      {
        filterKey: HomeViewConstants.FILTER_VIDEO,
        label: $r('app.string.video'),
        icon: $r('sys.symbol.movie_fill')
      }
    ];
  }

  build() {
    Row({ space: 8 }) {
      ForEach(this.getCategoryTabItems(), (item: CategoryTabItem) => {
        this.CategoryPill(item)
      }, (item: CategoryTabItem) => item.filterKey)
    }
    .width('60%')
    .alignSelf(ItemAlign.Start)
    .padding({ left: CATEGORY_ROW_PADDING_H, right: CATEGORY_ROW_PADDING_H, top: 2, bottom: 10 })
  }

  @Builder
  CategoryPill(item: CategoryTabItem) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row({ space: 4 }) {
        SymbolGlyph(item.icon)
          .fontSize(16)
          .fontColor([this.currentFilter === item.filterKey ?
            AppThemeConstants.SEGMENT_SELECTED_TEXT : AppThemeConstants.SEGMENT_UNSELECTED_TEXT])
        Text(item.label)
          .fontSize(16)
          .fontWeight(this.currentFilter === item.filterKey ? 600 : 500)
          .fontColor(this.currentFilter === item.filterKey ?
            AppThemeConstants.SEGMENT_SELECTED_TEXT : AppThemeConstants.SEGMENT_UNSELECTED_TEXT)
      }
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
    }
    .layoutWeight(1)
    .height(34)
    .borderRadius(17)
    .backgroundColor(this.currentFilter === item.filterKey ?
      AppThemeConstants.SEGMENT_SELECTED_BG : $r('sys.color.ohos_id_color_background'))
    .onClick(() => {
      HiLog.i(TAG, `Pipeline[filter/1] Tab click filter=${item.filterKey}`);
      this.onFilterSelected(item.filterKey);
    })
  }
}
