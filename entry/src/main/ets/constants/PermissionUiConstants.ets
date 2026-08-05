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

/** 权限弹窗 UI 固定常量 */
export class PermissionUiConstants {
  public static readonly DIALOG_WIDTH: string = '85%';
  public static readonly DIALOG_PADDING: number = 24;
  public static readonly DIALOG_BORDER_RADIUS: number = 16;
  public static readonly DIALOG_CONTENT_SPACE: number = 16;
  public static readonly FEATURE_ITEM_SPACE: number = 10;
  public static readonly TITLE_FONT_SIZE: number = 20;
  public static readonly DESC_FONT_SIZE: number = 14;
  public static readonly FEATURE_FONT_SIZE: number = 14;
  public static readonly PRIMARY_BUTTON_HEIGHT: number = 44;
  public static readonly SECONDARY_BUTTON_HEIGHT: number = 40;
  public static readonly TITLE_COLOR: Resource = AppThemeConstants.TEXT_PRIMARY;
  public static readonly DESC_COLOR: Resource = AppThemeConstants.TEXT_SECONDARY;
  public static readonly FEATURE_COLOR: Resource = AppThemeConstants.TEXT_FEATURE;
  public static readonly PRIMARY_BUTTON_COLOR: Resource = AppThemeConstants.ACCENT;
  public static readonly SECONDARY_TEXT_COLOR: Resource = AppThemeConstants.TEXT_SECONDARY;
  public static readonly DIALOG_BACKGROUND: Resource = AppThemeConstants.CARD_BACKGROUND;
}
