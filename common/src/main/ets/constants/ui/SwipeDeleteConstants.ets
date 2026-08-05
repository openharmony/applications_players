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

/** 滑动删除动效与布局常量（对齐联系人通话记录 AllRecord） */
export class SwipeDeleteConstants {
  static readonly MAX_HEAD_ANGLE: number = 17;
  static readonly MAX_BODY_ANGLE: number = 10;
  static readonly ANGLE_RATIO: number = 12;
  static readonly ACTION_AREA_DISTANCE: number = 56;
  static readonly DELETE_SWIPE_HEAD_WIDTH: number = 64;
  static readonly DELETE_SWIPE_BODY_WIDTH: number = 120;
  static readonly MAX_SCALE_RATIO: number = 1.1;
  static readonly DELETE_ANIMATION_DURATION_MS: number = 400;
  static readonly DELETE_END_MIN_WIDTH: number = 72;
  static readonly DELETE_BUTTON_SIZE: number = 40;
}
