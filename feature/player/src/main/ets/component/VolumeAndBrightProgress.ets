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

import { Constants } from '@ohos/common/src/main/ets/constants/ui/Constants';
import { AVPlayerController } from '../controller/AVPlayerController';

const GESTURE_PILL_HEIGHT: number = 160;
const GESTURE_PILL_WIDTH: number = 48;

/** 视频区左侧亮度 / 右侧音量手势进度浮层 */
@Component
export struct VolumeAndBrightProgress {
  @Link volume: number;
  @Link volumePercentage: number;
  @Link bright: number;
  @Link showVolumeProgress: boolean;
  @Link showBrightnessProgress: boolean;
  @Prop avPlayerController: AVPlayerController;

  /** 亮度 pill：Builder 内直接读 @Link bright；高度无动画避免每次手势从顶部长出来 */
  @Builder
  BrightnessGesturePill() {
    Column({ space: 12 }) {
      SymbolGlyph(Constants.APP_BAR_ICON_BRIGHTNESS)
        .fontSize($r('app.float.gesture_progress_icon_size'))
        .fontWeight(FontWeight.Medium)
        .fontColor([Color.White])

      Stack({ alignContent: Alignment.Bottom }) {
        Column()
          .width(4)
          .height(GESTURE_PILL_HEIGHT)
          .backgroundColor('rgba(255,255,255,0.25)')
          .borderRadius(2)

        Column()
          .width(4)
          .height(Math.max(4, GESTURE_PILL_HEIGHT * this.bright))
          .backgroundColor(Color.White)
          .borderRadius(2)
          .animation({ duration: 0 })
      }
      .width(4)
      .height(GESTURE_PILL_HEIGHT)
    }
    .width(GESTURE_PILL_WIDTH)
    .padding({ top: 16, bottom: 16, left: 12, right: 12 })
    .backgroundColor($r('app.color.player_gesture_pill_bg'))
    .borderRadius(GESTURE_PILL_WIDTH / 2)
  }

  /** 音量 pill：Builder 内直接读 @Link volumePercentage */
  @Builder
  VolumeGesturePill() {
    Column({ space: 12 }) {
      SymbolGlyph(this.avPlayerController.getVolumeIcon(this.volumePercentage))
        .fontSize($r('app.float.gesture_progress_icon_size'))
        .fontWeight(FontWeight.Medium)
        .fontColor([Color.White])

      Stack({ alignContent: Alignment.Bottom }) {
        Column()
          .width(4)
          .height(GESTURE_PILL_HEIGHT)
          .backgroundColor('rgba(255,255,255,0.25)')
          .borderRadius(2)

        Column()
          .width(4)
          .height(Math.max(4, GESTURE_PILL_HEIGHT * this.volumePercentage))
          .backgroundColor(Color.White)
          .borderRadius(2)
          .animation({ duration: 0 })
      }
      .width(4)
      .height(GESTURE_PILL_HEIGHT)
    }
    .width(GESTURE_PILL_WIDTH)
    .padding({ top: 16, bottom: 16, left: 12, right: 12 })
    .backgroundColor($r('app.color.player_gesture_pill_bg'))
    .borderRadius(GESTURE_PILL_WIDTH / 2)
  }

  build() {
    Stack() {
      Row() {
        this.BrightnessGesturePill()
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Start)
      .padding({ left: 32 })
      .visibility(this.showBrightnessProgress ? Visibility.Visible : Visibility.Hidden)
      .hitTestBehavior(HitTestMode.None)

      Row() {
        this.VolumeGesturePill()
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.End)
      .padding({ right: 32 })
      .visibility(this.showVolumeProgress ? Visibility.Visible : Visibility.Hidden)
      .hitTestBehavior(HitTestMode.None)
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.None)
    .zIndex(10)
  }
}
