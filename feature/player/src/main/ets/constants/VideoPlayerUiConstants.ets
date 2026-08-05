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


/** 视频播放页锁屏交互 UI 固定常量 */
export class VideoPlayerUiConstants {
  static readonly LOCK_OVERLAY_Z_INDEX: number = 5;
  static readonly LOCK_SIDE_BUTTON_MARGIN_RIGHT: number = 16;
  /** 横屏锁屏按钮贴左侧边距（设计稿） */
  static readonly LOCK_SIDE_BUTTON_MARGIN_LEFT: number = 16;
  static readonly LOCK_SIDE_BUTTON_SIZE: number = 40;
  static readonly LOCK_SIDE_ICON_SIZE: number = 20;
  static readonly LOCK_SIDE_BUTTON_BG: string = 'rgba(0,0,0,0.55)';
  /** 横屏顶栏信息条背景（半透明黑） */
  static readonly LANDSCAPE_TITLE_BAR_BG: Resource = $r('app.color.video_title_bar_bg_color_transparency');
  /** 锁屏图标自动隐藏时长与视频控制区一致（见 PlayConstants.PLAY_PROGRESS_VIDEO_HIDE_TIME） */
  static readonly UNLOCK_AFFORDANCE_HIDE_MS: number = 4000;
  /** 锁屏按钮横向滑出屏幕的距离（按钮宽 + 右边距 + 缓冲） */
  static readonly LOCK_SIDE_BUTTON_SLIDE_X: number = 72;
  static readonly LOCK_SIDE_SLIDE_DURATION_MS: number = 300;
  static readonly LONG_PRESS_SPEED_LABEL: string = '3.0X';
  static readonly LONG_PRESS_SPEED_PILL_HEIGHT: number = 36;
  static readonly LONG_PRESS_SPEED_PILL_PADDING_H: number = 14;
  static readonly LONG_PRESS_SPEED_PILL_RADIUS: number = 18;
  static readonly LONG_PRESS_SPEED_PILL_BG: string = 'rgba(0,0,0,0.65)';
  static readonly LONG_PRESS_SPEED_ICON_SIZE: number = 18;
  static readonly LONG_PRESS_SPEED_TEXT_SIZE: number = 14;
  static readonly LONG_PRESS_SPEED_TEXT_ICON_GAP: number = 8;
  static readonly LONG_PRESS_SPEED_LANDSCAPE_TOP_MARGIN: number = 48;
  static readonly LONG_PRESS_SPEED_PILL_FALLBACK_TOP: number = 120;
  static readonly LONG_PRESS_SPEED_PILL_Z_INDEX: number = 6;
}
