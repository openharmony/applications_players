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
 * 首页媒体多选（长按多选 / 拖动滑选 / 批量删除）相关固定常量。
 * 颜色、尺寸、手势阈值统一在此维护，禁止散落在组件内硬编码。
 */
export class MediaSelectionConstants {
  /** 多选主题色（勾选框选中色 / 选中边框） */
  static readonly SELECTION_PRIMARY_COLOR: Resource = AppThemeConstants.ACCENT;
  /** 勾选框未选中描边色 */
  static readonly CHECKBOX_BORDER_COLOR: Resource = AppThemeConstants.ON_ACCENT_TEXT;
  /** 选中项封面叠加遮罩色 */
  static readonly SELECTED_OVERLAY_COLOR: string = 'rgba(0,122,255,0.18)';
  /** 选中项边框宽度 */
  static readonly SELECTED_BORDER_WIDTH: number = 2;

  /** 宫格勾选框尺寸 */
  static readonly GRID_CHECKBOX_SIZE: number = 22;
  /** 宫格勾选框距封面边缘内边距 */
  static readonly GRID_CHECKBOX_MARGIN: number = 6;
  /** 列表勾选框尺寸 */
  static readonly LIST_CHECKBOX_SIZE: number = 22;
  /** 列表勾选框左侧间距 */
  static readonly LIST_CHECKBOX_MARGIN_LEFT: number = 8;

  /** 长按进入多选的判定时长（ms） */
  static readonly LONG_PRESS_DURATION_MS: number = 400;
  /** 拖动滑选手势的最小触发距离（vp），过小会与点击冲突 */
  static readonly PAN_SELECT_MIN_DISTANCE: number = 8;

  /** 拖动涂选时距上/下边缘多少 vp 触发自动滚动（过大会压缩中部精确选区） */
  static readonly AUTO_SCROLL_EDGE_VP: number = 56;
  /** 自动滚动每帧步进（vp），偏小以提升边缘自动选中的可控性 */
  static readonly AUTO_SCROLL_STEP_VP: number = 10;
  /** 自动滚动定时器间隔（ms） */
  static readonly AUTO_SCROLL_INTERVAL_MS: number = 16;
  /** 宫格同一行 y 坐标误差阈值，用于自动滚动边缘按列命中 */
  static readonly GRID_ROW_EPSILON_VP: number = 1;
}
