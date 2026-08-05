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
 * 首页多选顶栏与删除确认弹窗的固定 UI 常量。
 */
export class HomeSelectionConstants {
  /** 编辑顶栏左右边距（返回按钮左侧外边距 16） */
  public static readonly HEADER_PADDING_H: number = 16;
  public static readonly HEADER_PADDING_V: number = 8;
  /** 返回与标题间距 */
  public static readonly HEADER_TITLE_GAP: number = 15;
  /** 全选 / 删除图标按钮间距（与首页搜索/导入一致） */
  public static readonly HEADER_ACTION_GAP: number = 8;
  public static readonly HEADER_ACTION_FONT_SIZE: number = 16;
  public static readonly HEADER_TITLE_FONT_SIZE: number = 17;
  /** 圆形图标按钮：对齐首页搜索按钮 */
  public static readonly HEADER_ICON_BUTTON_SIZE: number = 36;
  public static readonly HEADER_ICON_SIZE: number = 18;
  public static readonly HEADER_ACTION_COLOR: Resource = AppThemeConstants.ACCENT;
  /** 鸿蒙系统主文字色（系统黑，随深浅色模式变化） */
  public static readonly HEADER_TITLE_COLOR: Resource = $r('sys.color.ohos_id_color_text_primary');
  public static readonly HEADER_ICON_COLOR: Resource = $r('sys.color.ohos_id_color_text_primary');
  public static readonly HEADER_DELETE_COLOR: Resource = AppThemeConstants.DELETE;
  public static readonly HEADER_DELETE_DISABLED_COLOR: Resource = AppThemeConstants.TEXT_TERTIARY;

  public static readonly DIALOG_WIDTH: string = '80%';
  public static readonly DIALOG_RADIUS: number = 14;
  public static readonly DIALOG_TITLE_FONT_SIZE: number = 17;
  public static readonly DIALOG_MESSAGE_FONT_SIZE: number = 14;
  public static readonly DIALOG_BUTTON_FONT_SIZE: number = 16;
  public static readonly DIALOG_TITLE_COLOR: Resource = AppThemeConstants.TEXT_PRIMARY;
  public static readonly DIALOG_MESSAGE_COLOR: Resource = AppThemeConstants.TEXT_SECONDARY;
  public static readonly DIALOG_CANCEL_COLOR: Resource = AppThemeConstants.TEXT_PRIMARY;
  public static readonly DIALOG_CONFIRM_COLOR: Resource = AppThemeConstants.DELETE;
  public static readonly DIALOG_DIVIDER_COLOR: Resource = AppThemeConstants.BORDER;
  public static readonly DIALOG_MASK_COLOR: Resource = AppThemeConstants.SCRIM_OVERLAY;
  public static readonly DIALOG_BG_COLOR: Resource = AppThemeConstants.CARD_BACKGROUND;
}
