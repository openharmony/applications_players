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

/**
 * 底部 Tab 导航栏 UI 固定常量（设计稿：悬浮白色胶囊）
 * CONTENT_MARGIN_H=16：播放栏 / 底栏 /「全部」胶囊 / 列表卡片左侧统一对齐
 */
export class MainTabBarConstants {
  public static readonly CONTENT_MARGIN_H: number = 16;
  public static readonly BAR_HEIGHT: number = 56;
  public static readonly BAR_MARGIN_H: number = 16;
  public static readonly BAR_MARGIN_BOTTOM: number = 8;
  public static readonly BAR_BORDER_RADIUS: number = 30;
  public static readonly BAR_BG: Resource = $r('sys.color.ohos_id_color_background');
  public static readonly BAR_TOP_BORDER_COLOR: Resource = AppThemeConstants.BORDER;

  public static readonly TAB_FONT_SIZE: number = 16;
  public static readonly TAB_ICON_SIZE: number = 24;
  public static readonly TAB_ICON_TEXT_SPACE: number = 2;
  /** 选中：蓝色；未选中：黑色 */
  public static readonly TAB_SELECTED_COLOR: Resource = $r('sys.color.interactive_active');
  public static readonly TAB_UNSELECTED_COLOR: Resource = $r('sys.color.icon_primary');

  public static readonly ICON_HOME: Resource = $r('app.media.ic_home_filled');
  public static readonly ICON_PLAYLIST: Resource = $r('sys.symbol.list_bullet_square_fill');

  public static readonly MINI_PLAYER_MARGIN_H: number = 16;
  public static readonly MINI_PLAYER_MARGIN_BOTTOM: number = 6;
}
