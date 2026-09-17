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
import { FontScaleUtil } from '@ohos/common/src/main/ets/utils/FontScaleUtil';
import { HomeViewConstants } from '../constants/HomeViewConstants';

const TAG = 'HomeCategoryTabs';

/** 与播放栏、底栏、列表卡片左侧对齐（设计稿 16） */
const CATEGORY_ROW_PADDING_H: number = 16;
/** 设计稿：常规字号下胶囊组占总宽比例 */
const CATEGORY_ROW_WIDTH_NORMAL: string = '60%';
/** 系统字号特别大时横向铺满，避免三项挤叠 */
const CATEGORY_ROW_WIDTH_EXPANDED: string = '100%';
/** 分类胶囊高度（vp）；内部字号用 chromeSize，避免字体放大撑破固定高度 */
const CATEGORY_PILL_HEIGHT: number = 34;
const CATEGORY_PILL_ICON_SIZE: number = 16;
const CATEGORY_PILL_FONT_SIZE: number = 16;

interface CategoryTabItem {
  filterKey: string;
  label: ResourceStr;
  icon: Resource;
}

/**
 * 首页分类 Tab View：全部 / 音频 / 视频 分段选择
 * 常规字号保持设计稿约 60% 宽；系统字号 ≥ 1.2 时横向铺满。
 */
@Component
export struct HomeCategoryTabs {
  @Prop currentFilter: string = HomeViewConstants.FILTER_ALL;
  @StorageProp(FontScaleUtil.SYSTEM_FONT_SIZE_SCALE_KEY)
  systemFontSizeScale: number = FontScaleUtil.DEFAULT_SCALE;
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

  private getCategoryRowWidth(): string {
    if (FontScaleUtil.needsExpandedHorizontalLayout(this.systemFontSizeScale)) {
      return CATEGORY_ROW_WIDTH_EXPANDED;
    }
    return CATEGORY_ROW_WIDTH_NORMAL;
  }

  build() {
    Row({ space: 8 }) {
      ForEach(this.getCategoryTabItems(), (item: CategoryTabItem) => {
        this.CategoryPill(item)
      }, (item: CategoryTabItem) => item.filterKey)
    }
    .width(this.getCategoryRowWidth())
    .alignSelf(ItemAlign.Start)
    .padding({ left: CATEGORY_ROW_PADDING_H, right: CATEGORY_ROW_PADDING_H, top: 2, bottom: 10 })
  }

  @Builder
  CategoryPill(item: CategoryTabItem) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row({ space: 4 }) {
        SymbolGlyph(item.icon)
          .fontSize(FontScaleUtil.chromeSize(CATEGORY_PILL_ICON_SIZE))
          .fontColor([this.currentFilter === item.filterKey ?
            AppThemeConstants.SEGMENT_SELECTED_TEXT : AppThemeConstants.SEGMENT_UNSELECTED_TEXT])
        Text(item.label)
          .fontSize(FontScaleUtil.chromeSize(CATEGORY_PILL_FONT_SIZE))
          .fontWeight(this.currentFilter === item.filterKey ? FontWeight.Medium : FontWeight.Regular)
          .fontColor(this.currentFilter === item.filterKey ?
            AppThemeConstants.SEGMENT_SELECTED_TEXT : AppThemeConstants.SEGMENT_UNSELECTED_TEXT)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .width('100%')
    }
    .layoutWeight(1)
    .height(CATEGORY_PILL_HEIGHT)
    .borderRadius(CATEGORY_PILL_HEIGHT / 2)
    .backgroundColor(this.currentFilter === item.filterKey ?
      AppThemeConstants.SEGMENT_SELECTED_BG : $r('sys.color.ohos_id_color_background'))
    .onClick(() => {
      HiLog.i(TAG, `Pipeline[filter/1] Tab click filter=${item.filterKey}`);
      this.onFilterSelected(item.filterKey);
    })
  }
}
