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


import { SwipeDeleteConstants } from '../constants/ui/SwipeDeleteConstants';
import { HiLog } from './HiLog';

/**
 * 滑动拉到底删除动效（对齐联系人 deleteAction / swipeAction.onAction）
 */
export class SwipeDeleteUtil {
  /**
   * 安全收起 List 已展开的滑动删除区。
   * 组件 aboutToDisappear / 窗口销毁时 Scroller 可能已解绑，直接调用会抛 100004。
   *
   * @param scroller List 滚动控制器
   * @param tag 日志 TAG
   */
  static closeAllSwipeActionsSafe(scroller: ListScroller, tag: string = 'SwipeDeleteUtil'): void {
    try {
      scroller.closeAllSwipeActions();
    } catch (error) {
      const errMsg = error instanceof Error ? error.message : String(error);
      HiLog.w(tag, `closeAllSwipeActions skipped message=${errMsg}`);
    }
  }

  static runDeleteAnimation(onDelete: () => void): void {
    animateTo({
      duration: SwipeDeleteConstants.DELETE_ANIMATION_DURATION_MS,
      curve: Curve.Friction
    }, () => {
      onDelete();
    });
  }

  static runSwipeEndDelete(onDelete: () => void): void {
    animateTo({
      duration: SwipeDeleteConstants.DELETE_ANIMATION_DURATION_MS
    }, () => {
      onDelete();
    });
  }
}
