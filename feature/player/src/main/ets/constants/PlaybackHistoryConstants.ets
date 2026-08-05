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

/** 历史播放 Tab UI 固定常量（最近点播单曲列表） */
export class PlaybackHistoryConstants {
  static readonly MAX_TRACK_COUNT: number = 50;
  static readonly EMPTY_TEXT_FONT_SIZE: number = 14;
  static readonly EMPTY_TEXT_COLOR: Resource = AppThemeConstants.TEXT_SECONDARY;
  static readonly ICON_DELETE: Resource = $r('sys.symbol.trash');

  /** 兼容旧卡片组件常量（已不再用于历史 Tab） */
  static readonly MAX_PLAYLIST_COUNT: number = 5;
  static readonly CARD_BORDER_RADIUS: number = 16;
  static readonly CARD_BACKGROUND: Resource = AppThemeConstants.CARD_BACKGROUND;
  static readonly CARD_BORDER_COLOR: Resource = AppThemeConstants.BORDER;
  static readonly CARD_BORDER_WIDTH: number = 1;
  static readonly CARD_SHADOW_COLOR: Resource = AppThemeConstants.SHADOW;
  static readonly CARD_SHADOW_RADIUS: number = 12;
  static readonly CARD_SHADOW_OFFSET_Y: number = 2;
  static readonly CARD_HORIZONTAL_MARGIN: number = 20;
  static readonly CARD_INNER_PADDING_H: number = 16;
  static readonly CARD_INNER_PADDING_TOP: number = 14;
  static readonly CARD_INNER_PADDING_BOTTOM: number = 16;
  static readonly CARD_HEADER_BOTTOM_MARGIN: number = 8;
  static readonly CARD_TITLE_FONT_SIZE: number = 16;
  static readonly CARD_TITLE_COLOR: Resource = AppThemeConstants.TEXT_PRIMARY;
  static readonly CARD_DELETE_ICON_SIZE: number = 18;
  static readonly SWIPER_ITEM_SPACE: number = 12;
  static readonly DOT_SIZE: number = 6;
  static readonly DOT_ACTIVE_COLOR: Resource = AppThemeConstants.TEXT_FEATURE;
  static readonly DOT_INACTIVE_COLOR: Resource = AppThemeConstants.TEXT_TERTIARY;
  static readonly DOT_GAP: number = 6;
  static readonly DOT_TOP_MARGIN: number = 12;
  static readonly DOT_BOTTOM_MARGIN: number = 8;
}
