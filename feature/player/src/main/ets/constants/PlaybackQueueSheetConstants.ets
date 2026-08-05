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
import { AppThemeModeHelper } from '@ohos/common/src/main/ets/utils/AppThemeModeHelper';

/** 播放队列半模态 Tab 标识 */
export class PlaybackQueueSheetTab {
  static readonly CURRENT: number = 0;
  static readonly HISTORY: number = 1;
}

/** 播放队列半模态 UI 固定常量 */
export class PlaybackQueueSheetConstants {
  /** 半模态根背景（页面灰底） */
  static readonly SHEET_ROOT_BACKGROUND: Resource = AppThemeConstants.PAGE_BACKGROUND;
  /** bindSheet 半透明黑蒙层 */
  static readonly SHEET_MASK_COLOR: string = '#4D000000';
  static readonly SHEET_MASK_COLOR_DARK: string = '#66000000';

  /** 统一左右留白 16 */
  static readonly SHEET_HEADER_PADDING_H: number = 16;
  /** 顶栏上外边距略加大，避免贴顶 */
  static readonly SHEET_HEADER_PADDING_TOP: number = 16;
  static readonly SHEET_HEADER_PADDING_BOTTOM: number = 8;

  /** 顶栏关闭按钮 */
  static readonly CLOSE_BUTTON_SIZE: number = 32;
  static readonly CLOSE_BUTTON_BG: Resource = AppThemeConstants.HEADER_ICON_BACKGROUND;
  static readonly CLOSE_ICON_SIZE: number = 16;

  /** 胶囊分段 Tab：大胶囊底色 tertiary，选中项叠白色圆角块 */
  static readonly SEGMENT_MARGIN_H: number = 16;
  static readonly SEGMENT_PADDING: number = 3;
  static readonly SEGMENT_HEIGHT: number = 36;
  static readonly SEGMENT_RADIUS: number = 18;
  static readonly SEGMENT_BG: Resource = $r('sys.color.comp_background_tertiary');
  static readonly SEGMENT_ACTIVE_BG: Resource = AppThemeConstants.CARD_BACKGROUND;
  static readonly SEGMENT_FONT_SIZE: number = 14;
  static readonly SEGMENT_BOTTOM_MARGIN: number = 8;

  /** 内容区统一左右外边距（操作条 / 列表共用，避免视觉错位） */
  static readonly CONTENT_OUTER_MARGIN_H: number = 16;
  /** 当前播放 / 历史操作条 */
  static readonly ACTION_BAR_MARGIN_H: number = PlaybackQueueSheetConstants.CONTENT_OUTER_MARGIN_H;
  static readonly ACTION_BAR_HEIGHT: number = 40;
  static readonly ACTION_BAR_BOTTOM_MARGIN: number = 4;
  static readonly ACTION_BAR_ICON_SIZE: number = 18;
  static readonly ACTION_BAR_FONT_SIZE: number = 14;
  static readonly ACTION_BAR_GAP: number = 6;

  static readonly SHEET_TAB_GAP: number = 24;
  static readonly SHEET_TAB_FONT_SIZE: number = 14;
  static readonly SHEET_TAB_COUNT_FONT_SIZE: number = 14;
  static readonly SHEET_HEADER_ACTION_GAP: number = 12;
  static readonly SHEET_HEADER_ACTION_ICON_SIZE: number = 20;
  static readonly SHEET_TAB_COUNT_OFFSET_TOP: number = 0;

  static readonly TAB_ACTIVE_TEXT: Resource = AppThemeConstants.TEXT_PRIMARY;
  static readonly TAB_INACTIVE_TEXT: Resource = AppThemeConstants.TEXT_PRIMARY;
  static readonly TAB_COUNT_TEXT: Resource = AppThemeConstants.TEXT_PRIMARY;

  static readonly SOURCE_FONT_SIZE: number = 16;
  static readonly SOURCE_TEXT_COLOR: Resource = AppThemeConstants.TEXT_PRIMARY;
  static readonly SOURCE_BOTTOM_MARGIN: number = 0;

  static readonly LIST_INITIAL_SCROLL_DELAY_MS: number = 50;
  static readonly LIST_PREFETCH_COUNT: number = 8;
  static readonly LIST_ITEM_SPACE: number = 0;
  static readonly PLAY_STATE_POLL_MS: number = 200;

  /** 列表内容左右外边距（与操作条 CONTENT_OUTER_MARGIN_H 统一） */
  static readonly LIST_CONTENT_MARGIN_H: number = PlaybackQueueSheetConstants.CONTENT_OUTER_MARGIN_H;
  /** @deprecated 与 LIST_CONTENT_MARGIN_H 同值，保留兼容 */
  static readonly HISTORY_LIST_PADDING_H: number = PlaybackQueueSheetConstants.CONTENT_OUTER_MARGIN_H;

  static readonly ROW_LEFT_SLOT_WIDTH: number = 14;
  /** 行内容上下内边距（上下对称） */
  static readonly ROW_VERTICAL_PADDING: number = 10;
  /** 列表已有外边距时，高亮行不再额外左右外扩 */
  static readonly ROW_MARGIN_H: number = 0;
  /** 行左右内边距：0，避免与列表外边距叠加导致与操作条不对齐 */
  static readonly ROW_CONTENT_PADDING_H: number = 0;
  static readonly ROW_HIGHLIGHT_RADIUS: number = 12;
  static readonly ROW_DIVIDER_INDENT: number = 16;
  /** 与首页「更多」菜单一致：发丝线 + list_separator */
  static readonly ROW_DIVIDER_COLOR: Resource = $r('sys.color.ohos_id_color_list_separator');
  static readonly ROW_DIVIDER_STROKE: Length = '1px';
  static readonly ROW_DIVIDER_PADDING: number = 0;
  static readonly ROW_ITEM_CURRENT_BACKGROUND: Resource = AppThemeConstants.CARD_BACKGROUND;
  static readonly ROW_ITEM_DRAG_BACKGROUND: Resource = AppThemeConstants.DRAG_HIGHLIGHT;
  static readonly ROW_DRAG_LONG_PRESS_DURATION_MS: number = 400;
  static readonly ROW_TITLE_FONT_SIZE: number = 15;
  static readonly ROW_SUBTITLE_FONT_SIZE: number = 12;
  static readonly ROW_ACTION_GAP: number = 4;
  static readonly ROW_ACTION_ICON_SIZE: number = 14;
  static readonly ROW_ACTION_HIT_SIZE: number = 28;
  static readonly ROW_TITLE_COLOR: Resource = AppThemeConstants.TEXT_PRIMARY;
  static readonly ROW_SUBTITLE_COLOR: Resource = AppThemeConstants.TEXT_SECONDARY;
  static readonly ROW_CURRENT_TEXT_COLOR: Resource = AppThemeConstants.TEXT_PRIMARY;
  static readonly ROW_SEPARATOR_COLOR: Resource = AppThemeConstants.TEXT_SECONDARY;
  static readonly ROW_ACTION_COLOR: Resource = AppThemeConstants.TEXT_TERTIARY;
  static readonly ROW_CURRENT_ACTION_COLOR: Resource = AppThemeConstants.TEXT_TERTIARY;
  static readonly ROW_TEXT_GAP: number = 8;
  static readonly ROW_CHECKBOX_SIZE: number = 22;
  static readonly ROW_SELECTED_OVERLAY: string = 'rgba(0,122,255,0.12)';
  static readonly SELECTION_DELETE_BAR_HEIGHT: number = 48;
  static readonly SELECTION_DELETE_RADIUS: number = 12;

  /** 兼容旧引用 */
  static readonly ROW_HORIZONTAL_PADDING: number = 0;
  static readonly ROW_DRAG_BLEED_PADDING_H: number = 16;

  static readonly EMPTY_TEXT_COLOR: Resource = AppThemeConstants.TEXT_SECONDARY;
  static readonly EMPTY_TEXT_FONT_SIZE: number = 14;

  static readonly ICON_REVERSE_QUEUE: Resource = $r('sys.symbol.list_bullet');
  static readonly ICON_CLEAR_QUEUE: Resource = $r('sys.symbol.trash');
  static readonly ICON_REMOVE: Resource = $r('sys.symbol.xmark');
  static readonly ICON_DRAG_HANDLE: Resource = $r('sys.symbol.line_3_horizontal');
  static readonly ICON_CLOSE: Resource = $r('sys.symbol.xmark');

  static resolveMaskColor(): string {
    if (AppThemeModeHelper.isDarkMode()) {
      return PlaybackQueueSheetConstants.SHEET_MASK_COLOR_DARK;
    }
    return PlaybackQueueSheetConstants.SHEET_MASK_COLOR;
  }
}
