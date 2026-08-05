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

/** 媒体聚合视图 UI 固定常量（颜色、字号、间距等） */
export class MediaViewUiConstants {
  /** 首页宫格封面 1:1（音频 / 视频统一） */
  static readonly HOME_GRID_COVER_ASPECT_RATIO: number = 1;
  static readonly DEFAULT_COVER_ASPECT_RATIO: number = 1;

  static readonly COLOR_VIDEO_THUMB_BG: Resource = AppThemeConstants.THUMB_BACKGROUND;
  static readonly COLOR_AUDIO_THUMB_BG: Resource = AppThemeConstants.AUDIO_THUMB_BACKGROUND;
  static readonly COLOR_FORMAT_BADGE_BG: Resource = AppThemeConstants.FORMAT_BADGE_BACKGROUND;
  static readonly COLOR_FORMAT_BADGE_TEXT: Resource = AppThemeConstants.ON_ACCENT_TEXT;
  static readonly COLOR_FILE_NAME: Resource = AppThemeConstants.TEXT_PRIMARY;
  static readonly COLOR_FILE_META: Resource = AppThemeConstants.TEXT_SECONDARY;
  static readonly COLOR_EMPTY_ICON: Resource = AppThemeConstants.TEXT_TERTIARY;

  static readonly AUDIO_DURATION_BADGE_BG: string = 'rgba(255,255,255,0.35)';
  static readonly VIDEO_DURATION_BADGE_BG: string = 'rgba(0,0,0,0.45)';
  static readonly DEFAULT_DURATION_BADGE_BG: string = 'rgba(0, 0, 0, 0.6)';

  static readonly PERMISSION_TIP_BG: Resource = AppThemeConstants.PERMISSION_TIP_BACKGROUND;
  static readonly PERMISSION_GRANT_BG: Resource = AppThemeConstants.PERMISSION_GRANT_BACKGROUND;
  static readonly PERMISSION_TIP_HEIGHT: number = 48;
  static readonly PERMISSION_GRANT_HEIGHT: number = 32;

  static readonly PLACEHOLDER_ICON_SIZE: number = 32;
  static readonly PLACEHOLDER_ICON_OPACITY: number = 0.4;
  static readonly EMPTY_FOLDER_ICON_SIZE: number = 200;
  static readonly EMPTY_VIEW_HORIZONTAL_PADDING: number = 24;

  static readonly LOADING_PROGRESS_SIZE: number = 40;
  static readonly LOADING_HINT_FONT_SIZE: number = 14;
  static readonly LOADING_HINT_MARGIN_TOP: number = 12;
  static readonly PERMISSION_TEXT_FONT_SIZE: number = 14;
  static readonly PERMISSION_HORIZONTAL_PADDING: number = 16;
  static readonly PERMISSION_GRANT_HORIZONTAL_PADDING: number = 12;

  static readonly FORMAT_BADGE_FONT_BASE: number = 9;
  static readonly HOME_DURATION_FONT_BASE: number = 10;
  static readonly HOME_NAME_FONT_BASE: number = 13;
  static readonly HOME_SIZE_FONT_BASE: number = 11;
  static readonly DEFAULT_DURATION_FONT_BASE: number = 12;
  static readonly DEFAULT_NAME_FONT_BASE: number = 14;
  static readonly HOME_LIST_NAME_FONT_BASE: number = 14;
  static readonly HOME_LIST_META_FONT_BASE: number = 11;
  static readonly HOME_LIST_DURATION_FONT_BASE: number = 12;
  static readonly DEFAULT_LIST_NAME_FONT_BASE: number = 16;
  static readonly DEFAULT_LIST_DURATION_FONT_BASE: number = 14;

  static readonly FORMAT_BADGE_PADDING_H: number = 8;
  static readonly FORMAT_BADGE_PADDING_V: number = 3;
  static readonly FORMAT_BADGE_RADIUS_TOP_LEFT: number = 10;
  static readonly FORMAT_BADGE_RADIUS_BOTTOM_RIGHT: number = 10;
  static readonly DURATION_BADGE_PADDING_H: number = 6;
  static readonly DURATION_BADGE_PADDING_V: number = 2;
  static readonly DURATION_BADGE_RADIUS: number = 4;
  static readonly DURATION_BADGE_MARGIN: number = 8;
  static readonly HOME_COVER_RADIUS: number = 12;
  static readonly HOME_TEXT_BLOCK_SPACE: number = 4;
  static readonly HOME_TEXT_PADDING_TOP: number = 8;
  static readonly HOME_TEXT_PADDING_BOTTOM: number = 4;

  static readonly HOME_LIST_THUMB_SIZE: number = 40;
  static readonly DEFAULT_AUDIO_THUMB_WIDTH: number = 60;
  static readonly DEFAULT_AUDIO_THUMB_HEIGHT: number = 60;
  static readonly DEFAULT_VIDEO_THUMB_WIDTH: number = 120;
  static readonly DEFAULT_VIDEO_THUMB_HEIGHT: number = 68;
  static readonly DEFAULT_LIST_ROW_HEIGHT: number = 88;
  static readonly HOME_LIST_TEXT_MARGIN_LEFT: number = 10;
  static readonly HOME_LIST_META_MARGIN_TOP: number = 3;
  static readonly HOME_LIST_CHEVRON_FONT_SIZE: number = 14;
  /** 时长与箭头间距 */
  static readonly HOME_LIST_CHEVRON_MARGIN_LEFT: number = 8;
  /** 标题区与时长间距 */
  static readonly HOME_LIST_DURATION_MARGIN_LEFT: number = 8;
  /** 列表行左右内边距（右侧略大，箭头离卡片边缘更舒展） */
  static readonly HOME_LIST_ROW_PADDING_LEFT: number = 12;
  static readonly HOME_LIST_ROW_PADDING_RIGHT: number = 16;
  static readonly HOME_LIST_ROW_PADDING_H: number = 12;
  static readonly HOME_LIST_ROW_PADDING_V: number = 10;
  static readonly HOME_LIST_ROW_RADIUS: number = 8;
  static readonly DEFAULT_LIST_PADDING_H: number = 16;
  static readonly DEFAULT_LIST_PADDING_V: number = 12;
  static readonly DEFAULT_LIST_TEXT_MARGIN_LEFT: number = 12;
  static readonly DEFAULT_LIST_DURATION_MARGIN_TOP: number = 4;
  static readonly DEFAULT_LIST_ARROW_SIZE: number = 24;
  static readonly DEFAULT_LIST_ARROW_MARGIN_LEFT: number = 8;
  static readonly DEFAULT_GRID_PADDING: number = 8;
  static readonly DEFAULT_GRID_INNER_RADIUS: number = 8;
  static readonly DEFAULT_GRID_CARD_RADIUS: number = 12;
  static readonly DEFAULT_GRID_NAME_MARGIN_TOP: number = 8;
  static readonly DEFAULT_DURATION_TRANSLATE_X: number = -40;
  static readonly DEFAULT_DURATION_TRANSLATE_Y: number = -16;

  static readonly EMPTY_TITLE_FONT_SIZE: number = 16;
  static readonly EMPTY_HINT_FONT_SIZE: number = 12;
  static readonly EMPTY_HINT_LINE_HEIGHT: number = 18;
  static readonly EMPTY_TITLE_MARGIN_TOP: number = 12;
  static readonly EMPTY_TITLE_MARGIN_BOTTOM: number = 8;

  static readonly DEFAULT_FALLBACK_FORMAT_AUDIO: string = 'MP3';
  static readonly DEFAULT_FALLBACK_FORMAT_VIDEO: string = 'MP4';
}
