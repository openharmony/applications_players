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

/**
 * 应用深浅色主题语义色：引用 common HAR 内 base/dark 同名 token（app.color 在 common 模块编译期绑定）。
 * 各 entry/Feature 若需独立引用，须在各自 resources 下同步同名 theme_* 资源。
 */
export class AppThemeConstants {
  /** AppStorage：当前是否为深色模式 */
  static readonly STORAGE_DARK_MODE: string = 'appDarkMode';
  static readonly PAGE_BACKGROUND: Resource = $r('app.color.theme_page_background');
  static readonly CARD_BACKGROUND: Resource = $r('app.color.theme_card_background');
  static readonly TEXT_PRIMARY: Resource = $r('app.color.theme_text_primary');
  static readonly TEXT_SECONDARY: Resource = $r('app.color.theme_text_secondary');
  static readonly TEXT_TERTIARY: Resource = $r('app.color.theme_text_tertiary');
  static readonly TEXT_FEATURE: Resource = $r('app.color.theme_text_feature');
  static readonly ACCENT: Resource = $r('app.color.theme_accent');
  static readonly BORDER: Resource = $r('app.color.theme_border');
  static readonly DELETE: Resource = $r('app.color.theme_delete');
  static readonly SUCCESS: Resource = $r('app.color.theme_success');
  static readonly CHIP_BACKGROUND: Resource = $r('app.color.theme_chip_background');
  /** 顶栏圆形图标按钮底色（需与页面背景有对比） */
  static readonly HEADER_ICON_BACKGROUND: Resource = $r('app.color.theme_header_icon_background');
  static readonly TAB_BAR_BACKGROUND: Resource = $r('app.color.theme_tab_bar_background');
  static readonly TAB_SELECTED: Resource = $r('app.color.theme_tab_selected');
  static readonly TAB_UNSELECTED: Resource = $r('app.color.theme_tab_unselected');
  static readonly SEGMENT_SELECTED_BG: Resource = $r('app.color.theme_segment_selected_bg');
  static readonly SEGMENT_UNSELECTED_BG: Resource = $r('app.color.theme_segment_unselected_bg');
  static readonly SEGMENT_SELECTED_TEXT: Resource = $r('app.color.theme_segment_selected_text');
  static readonly SEGMENT_UNSELECTED_TEXT: Resource = $r('app.color.theme_segment_unselected_text');
  static readonly THUMB_BACKGROUND: Resource = $r('app.color.theme_thumb_background');
  static readonly AUDIO_THUMB_BACKGROUND: Resource = $r('app.color.theme_audio_thumb_background');
  static readonly MINI_PLAYER_BACKGROUND: Resource = $r('app.color.theme_mini_player_background');
  static readonly RING_PROGRESS: Resource = $r('app.color.theme_ring_progress');
  static readonly RING_TRACK: Resource = $r('app.color.theme_ring_track');
  static readonly RING_COMPLETED: Resource = $r('app.color.theme_ring_completed');
  static readonly VINYL_RING: Resource = $r('app.color.theme_vinyl_ring');
  static readonly SHADOW: Resource = $r('app.color.theme_shadow');
  static readonly QUEUE_SHEET_BACKGROUND: Resource = $r('app.color.theme_queue_sheet_background');
  static readonly DRAG_HIGHLIGHT: Resource = $r('app.color.theme_drag_highlight');
  static readonly ON_ACCENT_TEXT: Resource = $r('app.color.theme_on_accent_text');
  static readonly CURRENT_TRACK: Resource = $r('app.color.theme_current_track');
  static readonly EQUALIZER_BAR: Resource = $r('app.color.theme_equalizer_bar');
  static readonly FORMAT_BADGE_BACKGROUND: Resource = $r('app.color.theme_format_badge_background');
  static readonly PERMISSION_TIP_BACKGROUND: Resource = $r('app.color.theme_permission_tip_background');
  static readonly PERMISSION_GRANT_BACKGROUND: Resource = $r('app.color.theme_permission_grant_background');
  static readonly DIALOG_OVERLAY: Resource = $r('app.color.theme_dialog_overlay');
  static readonly SCRIM_OVERLAY: Resource = $r('app.color.theme_scrim_overlay');
  static readonly STATUS_BAR_BACKGROUND: Resource = $r('app.color.theme_status_bar_background');
  static readonly STATUS_BAR_CONTENT: Resource = $r('app.color.theme_status_bar_content');
  static readonly NAVIGATION_BAR_CONTENT: Resource = $r('app.color.theme_navigation_bar_content');
}
