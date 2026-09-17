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


/** 播放器底部控制区 UI 固定常量 */
export class PlayerUiConstants {
  /** 竖屏音频面板相对屏幕总宽度的内缩（vp），封面与下方播放区共用 */
  static readonly AUDIO_PANEL_SCREEN_INSET: number = 5;
  /** 竖屏音频面板宽度：屏宽减去 AUDIO_PANEL_SCREEN_INSET */
  static readonly AUDIO_PANEL_WIDTH: string = 'calc(100% - 2vp)';
  /** 音频面板内左右内边距（与封面边缘对齐，面板已限宽故为 0） */
  static readonly AUDIO_CONTENT_PADDING_H: number = 0;
  /** 视频/通用底部控制区左右内边距（收紧以适配最大显示尺寸） */
  static readonly CONTENT_PADDING_H: number = 12;
  static readonly FILE_INFO_BOTTOM_GAP: number = 10;
  static readonly PROGRESS_TIME_GAP: number = 1;
  static readonly CONTROL_ROW_TOP_MARGIN: number = 8;
  static readonly PANEL_BOTTOM_PADDING: number = 18;

  static readonly SIDE_SLOT_WIDTH: number = 64;
  /** 右侧槽宽：音频为倍速+播放列表；视频横屏为音量+倍速 */
  static readonly RIGHT_SIDE_SLOT_WIDTH: number = 108;
  static readonly RIGHT_CONTROL_GAP: number = 4;
  static readonly TRANSPORT_CLUSTER_GAP: number = 8;
  /** 视频播控簇间距：窄屏下避免 ±15 与上一曲/下一曲重叠 */
  static readonly VIDEO_TRANSPORT_CLUSTER_GAP: number = 4;

  /** 播控尺寸按最大显示+字号场景收紧，保证一行七键不互相挤压 */
  static readonly PLAY_BUTTON_SIZE: number = 48;
  static readonly PLAY_ICON_SIZE: number = 22;
  static readonly SKIP_BUTTON_SIZE: number = 36;
  static readonly SKIP_ICON_SIZE: number = 18;
  static readonly SEEK_BUTTON_SIZE: number = 32;
  static readonly SEEK_ICON_SIZE: number = 18;
  static readonly ACCESSORY_BUTTON_SIZE: number = 32;
  static readonly ACCESSORY_ICON_SIZE: number = 18;

  static readonly SPEED_CHIP_HEIGHT: number = 28;
  static readonly SPEED_CHIP_WIDTH: number = 44;
  static readonly SPEED_CHIP_RADIUS: number = 14;
  static readonly SPEED_CHIP_PADDING_H: number = 6;
  static readonly SPEED_FONT_SIZE: number = 11;
  static readonly SPEED_MENU_WIDTH: number = 168;
  static readonly SPEED_MENU_ITEM_FONT_SIZE: number = 16;
  static readonly SPEED_MENU_ITEM_HEIGHT: number = 44;
  static readonly SPEED_MENU_ITEM_RADIUS: number = 10;
  static readonly SPEED_MENU_ITEM_PADDING_H: number = 12;
  static readonly SPEED_MENU_BORDER_RADIUS: number = 16;
  static readonly SPEED_MENU_TITLE_FONT_SIZE: number = 13;
  static readonly SPEED_MENU_PADDING_H: number = 16;
  static readonly SPEED_MENU_PADDING_TOP: number = 14;
  static readonly SPEED_MENU_TITLE_BOTTOM_GAP: number = 8;
  static readonly SPEED_MENU_DIVIDER_MARGIN_H: number = 12;
  static readonly SPEED_MENU_LIST_PADDING_H: number = 8;
  static readonly SPEED_MENU_LIST_PADDING_TOP: number = 6;
  static readonly SPEED_MENU_LIST_PADDING_BOTTOM: number = 10;
  static readonly SPEED_MENU_CHECK_ICON_SIZE: number = 18;
  static readonly SPEED_MENU_SHADOW_RADIUS: number = 24;
  static readonly SPEED_MENU_SHADOW_OFFSET_Y: number = 8;
  static readonly SPEED_MENU_MASK_COLOR: string = 'rgba(0,0,0,0.45)';
  static readonly SPEED_MENU_SHADOW_COLOR: string = '#80000000';
  static readonly SPEED_MENU_OVERLAY_MARGIN_TOP: number = 120;
  static readonly SPEED_MENU_OVERLAY_MARGIN_RIGHT: number = 20;

  /** 播放页标题/元信息：配合 chromeSize(vp)，不再用过大 fp 撑破底栏 */
  static readonly TITLE_FONT_SIZE: number = 18;
  static readonly META_FONT_SIZE: number = 12;
  static readonly TIME_FONT_SIZE: number = 11;

  static readonly ICON_BUTTON_BG: string = 'rgba(255,255,255,0.12)';
  static readonly SPEED_CHIP_BG: string = 'rgba(255,255,255,0.14)';
  static readonly SPEED_CHIP_BORDER: string = 'rgba(255,255,255,0.20)';
  static readonly PLAY_BUTTON_SHADOW_COLOR: string = '#4D000000';
  static readonly PLAY_BUTTON_SHADOW_RADIUS: number = 16;
  static readonly PLAY_BUTTON_SHADOW_OFFSET_Y: number = 6;

  /** 竖屏音频封面：占音频面板 100%（面板为屏宽减 AUDIO_PANEL_SCREEN_INSET） */
  static readonly COVER_WIDTH_PERCENT: string = '100%';
  static readonly COVER_BORDER_RADIUS: number = 20;
  static readonly COVER_SHADOW_COLOR: string = '#33000000';
  static readonly COVER_SHADOW_RADIUS: number = 24;
  static readonly COVER_SHADOW_OFFSET_Y: number = 8;
  static readonly COVER_AREA_PADDING_TOP: number = 12;
  static readonly COVER_AREA_PADDING_BOTTOM: number = 4;
  /** 封面与起伏特效间距：须保留，避免特效叠到下方标题 */
  static readonly COVER_EQUALIZER_GAP: number = 10;
  /** 起伏特效底部预留，与 PlayerProgress 标题区隔离 */
  static readonly EQUALIZER_BOTTOM_GAP: number = 6;

  /** 播放模式切换 Toast 展示时长（毫秒） */
  static readonly LOOP_MODE_TOAST_DURATION_MS: number = 2000;
  /** 亮度/音量手势条高度（vp），手指滑动该距离对应满量程 */
  static readonly GESTURE_PILL_HEIGHT: number = 160;
  static readonly GESTURE_PILL_WIDTH: number = 48;
}
