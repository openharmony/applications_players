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

/** 媒体聚合视图布局固定常量（首页 / 默认样式） */
export class MediaViewLayoutConstants {
  static readonly GRID_BOTTOM_PADDING: number = 56;
  static readonly GRID_CACHED_COUNT: number = 5;
  /** 与首页「更多」菜单分割线一致：1px 发丝线 + 系统 list_separator 色 */
  static readonly LIST_DIVIDER_STROKE_WIDTH: Length = '1px';
  static readonly LIST_DIVIDER_START_MARGIN: number = 16;
  static readonly LIST_DIVIDER_END_MARGIN: number = 16;
  /** 首页列表分割线：从缩略图右侧文字区起画（行左 padding + 缩略图 + 文字左间距） */
  static readonly HOME_LIST_DIVIDER_START_MARGIN: number = 60;

  /** 首页宫格两列 1:1 封面（音频 / 视频统一） */
  static readonly HOME_ROOT_BACKGROUND: Resource = AppThemeConstants.PAGE_BACKGROUND;
  static readonly HOME_GRID_COLUMNS: string = '1fr 1fr';
  static readonly HOME_GRID_ROWS_GAP: number = 12;
  static readonly HOME_GRID_COLUMNS_GAP: number = 12;
  static readonly HOME_GRID_PADDING_LEFT: number = 14;
  static readonly HOME_GRID_PADDING_RIGHT: number = 14;
  static readonly HOME_GRID_PADDING_TOP: number = 4;
  static readonly HOME_LIST_PADDING_LEFT: number = 14;
  static readonly HOME_LIST_PADDING_RIGHT: number = 14;
  /** 首页列表白色圆角卡片（左右边距与分类/底栏/播放栏统一为 16） */
  static readonly HOME_LIST_CARD_MARGIN_H: number = 16;
  static readonly HOME_LIST_CARD_MARGIN_TOP: number = 8;
  static readonly HOME_LIST_CARD_MARGIN_BOTTOM: number = 32;
  static readonly HOME_LIST_CARD_RADIUS: number = 24;
  static readonly HOME_LIST_CARD_BACKGROUND: Resource = $r('sys.color.ohos_id_color_background');
  /** 卡片内列表左右不再额外留白（行内已有 padding） */
  static readonly HOME_LIST_CARD_INNER_PADDING_H: number = 0;
  /** 首页列表底部留白：Tab 栏已在 MainPage 占位，无需再预留 56px */
  static readonly HOME_LIST_BOTTOM_PADDING: number = 0;
  static readonly HOME_USE_EMPTY_STATE: boolean = true;

  /** 默认三列宫格布局 */
  static readonly DEFAULT_GRID_COLUMNS: string = '1fr 1fr 1fr';
  static readonly DEFAULT_GRID_ROWS_GAP: number = 8;
  static readonly DEFAULT_GRID_COLUMNS_GAP: number = 8;
  static readonly DEFAULT_GRID_PADDING_LEFT: number = 8;
  static readonly DEFAULT_GRID_PADDING_RIGHT: number = 8;
  static readonly DEFAULT_GRID_PADDING_TOP: number = 8;
  static readonly DEFAULT_LIST_PADDING_LEFT: number = 0;
  static readonly DEFAULT_LIST_PADDING_RIGHT: number = 0;
  static readonly DEFAULT_USE_EMPTY_STATE: boolean = false;
}
