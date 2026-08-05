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


import { AppThemeConstants } from './ui/AppThemeConstants';

/**
 * 搜索页 UI 固定常量（对齐搜索设计稿）
 */
export class SearchUiConstants {
  static readonly PAGE_BACKGROUND: Resource = AppThemeConstants.PAGE_BACKGROUND;
  static readonly CARD_BACKGROUND: Resource = AppThemeConstants.CARD_BACKGROUND;
  static readonly CARD_RADIUS: number = 14;
  static readonly CARD_PADDING: number = 16;
  static readonly CARD_MARGIN_H: number = 16;
  static readonly CARD_MARGIN_TOP: number = 12;
  static readonly CARD_TITLE_FONT_SIZE: number = 16;
  static readonly CARD_TITLE_FONT_WEIGHT: number = 600;
  static readonly CHIP_BACKGROUND: Resource = AppThemeConstants.CHIP_BACKGROUND;
  static readonly CHIP_RADIUS: number = 8;
  static readonly CHIP_PADDING_H: number = 12;
  static readonly CHIP_PADDING_V: number = 10;
  static readonly CHIP_FONT_SIZE: number = 14;
  static readonly CHIP_SUBTITLE_FONT_SIZE: number = 12;
  static readonly CHIP_SUBTITLE_COLOR: Resource = AppThemeConstants.TEXT_SECONDARY;
  static readonly CHIP_GAP: number = 8;
  static readonly HISTORY_FONT_SIZE: number = 15;
  /** 历史条目关闭按钮（无气泡背景，仅图标） */
  static readonly HISTORY_CLOSE_SIZE: number = 18;
  static readonly HISTORY_CLOSE_ICON_SIZE: number = 10;
  /** 两列网格：列间距 / 行间距 */
  static readonly HISTORY_ITEM_GAP_H: number = 16;
  static readonly HISTORY_ITEM_GAP_V: number = 12;
  static readonly NAV_BACK_SIZE: number = 36;
  static readonly SEARCH_BAR_HEIGHT: number = 40;
  static readonly SEARCH_BAR_RADIUS: number = 20;
  /** 无描边：灰色底由系统 sub_background 承担层次 */
  static readonly SEARCH_BAR_BORDER_WIDTH: number = 0;
  /** 比 sub_background 更深一级的系统组件背景 */
  static readonly SEARCH_BAR_BACKGROUND: Resource = $r('sys.color.comp_background_tertiary');
  static readonly SEARCH_BAR_BORDER_COLOR: Resource = $r('sys.color.ohos_id_color_list_separator');
  static readonly SEARCH_BAR_PADDING_LEFT: number = 12;
  static readonly SEARCH_BAR_PADDING_RIGHT: number = 4;
  static readonly SEARCH_ICON_SIZE: number = 18;
  static readonly SEARCH_INPUT_FONT_SIZE: number = 15;
  static readonly SEARCH_DIVIDER_WIDTH: number = 1;
  static readonly SEARCH_DIVIDER_HEIGHT: number = 18;
  static readonly SEARCH_DIVIDER_COLOR: Resource = $r('sys.color.ohos_id_color_text_secondary');
  static readonly SEARCH_BUTTON_FONT_SIZE: number = 16;
  static readonly SEARCH_BUTTON_COLOR: Resource = $r('sys.color.ohos_id_color_emphasize');
  static readonly SEARCH_BUTTON_PADDING_H: number = 12;
  static readonly SEARCH_BUTTON_MIN_WIDTH: number = 44;
  static readonly TRASH_ICON_SIZE: number = 20;
  /** 搜索顶栏左右边距（返回按钮左侧外边距 16） */
  static readonly NAV_HORIZONTAL_PADDING: number = 16;
  static readonly NAV_TOP_PADDING: number = 8;
  static readonly TITLE_COLOR: Resource = AppThemeConstants.TEXT_PRIMARY;
  /** 搜索结果卡片 / 列表项（对齐设计稿） */
  static readonly RESULT_CARD_MARGIN_H: number = 16;
  static readonly RESULT_CARD_MARGIN_TOP: number = 4;
  static readonly RESULT_CARD_PADDING_H: number = 16;
  /** 结果卡右侧内边距（大于左侧，给时长/垃圾桶留白） */
  static readonly RESULT_CARD_PADDING_RIGHT: number = 24;
  static readonly RESULT_CARD_PADDING_V: number = 12;
  static readonly RESULT_CARD_RADIUS: number = 16;
  static readonly RESULT_HEADER_FONT_SIZE: number = 16;
  static readonly RESULT_HEADER_FONT_WEIGHT: number = 600;
  static readonly RESULT_HEADER_MARGIN_BOTTOM: number = 4;
  static readonly RESULT_ITEM_ICON_SIZE: number = 40;
  static readonly RESULT_ITEM_ICON_RADIUS: number = 8;
  static readonly RESULT_ITEM_TEXT_MARGIN_LEFT: number = 12;
  /** 分割线左缘 = 图标宽(40) + 文字左间距(12)，与标题/副标题起点对齐 */
  static readonly RESULT_ITEM_DIVIDER_START: number = 52;
  /** 结果卡标题栏右侧操作按钮宽（垃圾桶），时长右缘与其对齐 */
  static readonly RESULT_HEADER_ACTION_SIZE: number = 32;
  static readonly RESULT_ITEM_TITLE_FONT_SIZE: number = 16;
  static readonly RESULT_ITEM_SUBTITLE_FONT_SIZE: number = 12;
  static readonly RESULT_ITEM_SUBTITLE_COLOR: Resource = AppThemeConstants.TEXT_SECONDARY;
  static readonly RESULT_ITEM_DURATION_FONT_SIZE: number = 12;
  static readonly RESULT_ITEM_PADDING_V: number = 10;
  static readonly RESULT_COUNT_FONT_SIZE: number = 14;
  static readonly RESULT_COUNT_COLOR: Resource = AppThemeConstants.TEXT_SECONDARY;
  static readonly RESULT_COUNT_PADDING_H: number = 16;
  static readonly RESULT_COUNT_PADDING_TOP: number = 8;
  static readonly RESULT_COUNT_PADDING_BOTTOM: number = 4;
}
