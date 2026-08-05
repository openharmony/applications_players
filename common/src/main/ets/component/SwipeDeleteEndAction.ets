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

/**
 * ListItem.swipeAction end 区域（对齐联系人 AllRecord.itemEnd）
 */
@Component
export struct SwipeDeleteEndAction {
  onDelete: () => void = () => {};
  @State headAngle: number = 0;
  @State bodyAngle: number = 0;
  @State swipeScale: number = 1;
  private dustbinAnimationEnabled: boolean = true;

  build() {
    Row() {
      Flex({ direction: FlexDirection.Column, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center }) {
        Image($r('app.media.ic_delete_head'))
          .height(5)
          .width(20)
          .rotate({
            x: 0,
            y: 0,
            z: 1,
            centerX: '100%',
            centerY: '100%',
            angle: this.headAngle
          })
        Image($r('app.media.ic_delete_body'))
          .height(16)
          .width(16)
          .rotate({
            x: 0,
            y: 0,
            z: 1,
            centerX: '100%',
            centerY: 0,
            angle: this.bodyAngle
          })
      }
      .width(SwipeDeleteConstants.DELETE_BUTTON_SIZE)
      .height(SwipeDeleteConstants.DELETE_BUTTON_SIZE)
      .borderRadius(20)
      .scale({ x: this.swipeScale, y: this.swipeScale })
      .backgroundColor($r('sys.color.ohos_id_color_warning'))
      .onClick(() => {
        this.onDelete();
      })
    }
    .draggable(false)
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      if (this.dustbinAnimationEnabled) {
        const wid: Length = newValue.width;
        const widthNum = typeof wid === 'number' ? wid : 0;
        this.headAngle = Math.min(SwipeDeleteConstants.MAX_HEAD_ANGLE,
          Math.max((widthNum - SwipeDeleteConstants.DELETE_SWIPE_HEAD_WIDTH) /
            SwipeDeleteConstants.ACTION_AREA_DISTANCE * SwipeDeleteConstants.ANGLE_RATIO, 0.0));
        let body = Math.min(SwipeDeleteConstants.MAX_BODY_ANGLE,
          Math.max((widthNum - SwipeDeleteConstants.DELETE_SWIPE_BODY_WIDTH) /
            SwipeDeleteConstants.ACTION_AREA_DISTANCE * 24.35, 0.0));
        this.bodyAngle = (-1) * body;
        this.swipeScale = Math.min(SwipeDeleteConstants.MAX_SCALE_RATIO,
          (widthNum - SwipeDeleteConstants.DELETE_SWIPE_HEAD_WIDTH) /
            SwipeDeleteConstants.ACTION_AREA_DISTANCE * 0.05 + 1.0);
      }
    })
    .height('100%')
    .margin({ left: 6 })
    .justifyContent(FlexAlign.Center)
    .borderRadius(8)
    .constraintSize({ minWidth: SwipeDeleteConstants.DELETE_END_MIN_WIDTH })
  }
}
