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

/** 底部迷你播放条 UI 固定常量 */
export class AudioMiniPlayerConstants {
  static readonly BAR_HEIGHT: number = 56;
  static readonly BAR_RADIUS: number = 28;
  static readonly BAR_MARGIN_H: number = 16;
  static readonly BAR_MARGIN_BOTTOM: number = 8;
  static readonly BAR_PADDING_H: number = 12;
  static readonly BAR_BG: Resource = AppThemeConstants.MINI_PLAYER_BACKGROUND;
  static readonly BAR_SHADOW_COLOR: Resource = AppThemeConstants.SHADOW;
  static readonly BAR_SHADOW_RADIUS: number = 12;
  static readonly BAR_SHADOW_OFFSET_Y: number = 4;

  static readonly COVER_OUTER_SIZE: number = 44;
  static readonly COVER_INNER_SIZE: number = 28;
  static readonly COVER_VINYL_RING_COLOR: Resource = AppThemeConstants.VINYL_RING;
  static readonly COVER_VINYL_RING_WIDTH: number = 8;
  static readonly COVER_ROTATION_DURATION_MS: number = 20000;
  static readonly COVER_ROTATION_TICK_MS: number = 50;

  static readonly TITLE_FONT_SIZE: number = 14;
  static readonly TITLE_TEXT_COLOR: Resource = AppThemeConstants.TEXT_PRIMARY;
  static readonly TITLE_MAX_LINES: number = 1;

  static readonly PLAY_BUTTON_SIZE: number = 36;
  static readonly PLAY_ICON_SIZE: number = 18;
  /** 迷你条 transport：仅图标、无圆形底 */
  static readonly TRANSPORT_BUTTON_SIZE: number = 36;
  static readonly TRANSPORT_SKIP_ICON_SIZE: number = 20;
  static readonly CONTROL_ICON_COLOR: Resource = AppThemeConstants.TEXT_PRIMARY;
  static readonly RING_STROKE_WIDTH: number = 2.5;
  static readonly RING_PROGRESS_COLOR: Resource = AppThemeConstants.RING_PROGRESS;
  static readonly RING_TRACK_COLOR: Resource = AppThemeConstants.RING_TRACK;
  static readonly RING_COMPLETED_COLOR: Resource = AppThemeConstants.RING_COMPLETED;

  static readonly QUEUE_BUTTON_SIZE: number = 32;
  static readonly QUEUE_ICON_SIZE: number = 18;
  static readonly CONTROL_GAP: number = 10;
  static readonly COVER_TITLE_GAP: number = 10;
  /** 标题区横向滑动切歌：超过该位移（vp）才触发上一曲/下一曲 */
  static readonly TITLE_SWIPE_TRACK_MIN_OFFSET: number = 48;
  /** 标题区快速滑动速度阈值（px/s），超过则视为快滑 */
  static readonly TITLE_SWIPE_FAST_VELOCITY: number = 600;
  /** 标题滑入/滑出：快滑动画时长（毫秒） */
  static readonly TITLE_SWIPE_ANIM_FAST_MS: number = 120;
  /** 标题滑入/滑出：慢滑动画时长（毫秒） */
  static readonly TITLE_SWIPE_ANIM_SLOW_MS: number = 280;
  /** 标题滑动未达阈值回弹时长（毫秒） */
  static readonly TITLE_SWIPE_ANIM_CANCEL_MS: number = 200;
  /** 标题区默认宽度（vp），onAreaChange 未测量前的回退值 */
  static readonly TITLE_SWIPE_DEFAULT_WIDTH: number = 160;
}
