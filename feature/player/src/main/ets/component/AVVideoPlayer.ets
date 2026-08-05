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
import { VideoOperate } from '@ohos/common/src/main/ets/constants/system/EventName';
import { PlayConstants } from '@ohos/common/src/main/ets/constants/player/PlayConstants';
import { HiLog } from '@ohos/common';
import { VideoPlayerController } from '../controller/VideoPlayerController';

const TAG: string = 'AVVideoPlayer';
/** 底边叠层遮绿高度：不改 XComponent 布局尺寸，避免画面被挤扁/拉伸 */
const EDGE_GREEN_MASK_BOTTOM_VP: number = 8;

/**
 * 不改 contain 布局比例；绿边仅用底部叠层遮盖。
 */
@Component
export struct AVVideoPlayer {
  @Link surfaceId: string;
  @Prop isFileManagerUIExtension: boolean = false;
  @Prop @Watch('onFullScreenChange') isFullScreen: boolean;
  @Prop @Watch('onBreakHwcChange') breakHwcCompose: boolean = false;
  @Prop cropBottomGreenEdge: boolean = false;
  @Prop concealSurface: boolean = false;
  private playVideoModel: VideoPlayerController | null = null;
  private xComponentController: XComponentController = new XComponentController();
  onXComponentControllerReady?: (controller: XComponentController) => void = undefined;

  onFullScreenChange(): void {
    if (this.playVideoModel) {
      this.playVideoModel.reportBehaviorEvent(this.isFullScreen ? VideoOperate.ENTER_FULL_SCREEN :
      VideoOperate.EXIT_FULL_SCREEN);
    }
  }

  onBreakHwcChange(): void {
    HiLog.i(TAG, `breakHwcCompose=${this.breakHwcCompose}`);
  }

  aboutToAppear() {
    if (this.playVideoModel === null) {
      HiLog.e(TAG, 'PlayVideoModel is null');
      return;
    }
    this.playVideoModel.initPlayerThis(this);
  }

  build() {
    Stack() {
      XComponent({
        id: PlayConstants.VIDEO_PLAY_PLAYER_ID,
        type: PlayConstants.VIDEO_PLAY_PLAYER_TYPE,
        libraryname: PlayConstants.VIDEO_PLAY_PLAYER_LIBRARY_NAME,
        controller: this.xComponentController
      })
        .borderWidth(0)
        .borderColor(Color.Black)
        .borderRadius(0)
        .onLoad(() => {
          HiLog.i(TAG, `onLoad breakHwc=${this.breakHwcCompose} cropGreen=${this.cropBottomGreenEdge} layoutFix=v6`);
          this.xComponentController.setXComponentSurfaceSize({
            surfaceWidth: PlayConstants.VIDEO_PLAY_PLAYER_SURFACE_WIDTH,
            surfaceHeight: PlayConstants.VIDEO_PLAY_PLAYER_SURFACE_HEIGHT
          });
          this.surfaceId = this.xComponentController.getXComponentSurfaceId();
          HiLog.i(TAG, `Surface ID obtained: %{private}s`, this.surfaceId);
          if (this.onXComponentControllerReady) {
            this.onXComponentControllerReady(this.xComponentController);
          }
          if (this.surfaceId && this.surfaceId.length > 0) {
            this.playVideoModel !== null && this.playVideoModel.videoSurfaceID(this.surfaceId);
            this.playVideoModel !== null && this.playVideoModel.applyAspectMatchedSurfaceSize();
          } else {
            HiLog.e(TAG, 'Surface ID is empty, videoSurfaceID will not be called');
          }
        })
        .id('video_play_xcomponent')
        .width(Constants.ALL_PERCENT)
        .height(Constants.ALL_PERCENT)
        .clip(true)
      Text()
        .focusable(true)
        .tabIndex(-1)

      // 叠层遮绿：不改变视频布局宽高比
      if (this.cropBottomGreenEdge) {
        Row()
          .width(Constants.ALL_PERCENT)
          .height(EDGE_GREEN_MASK_BOTTOM_VP)
          .backgroundColor(Color.Black)
          .hitTestBehavior(HitTestMode.None)
          .position({ x: 0, y: '100%' })
          .translate({ y: -EDGE_GREEN_MASK_BOTTOM_VP })
          .zIndex(2)
      }
    }
    .width(Constants.ALL_PERCENT)
    .height(Constants.ALL_PERCENT)
    // conceal 时才垫黑底；常态透明，避免 PiP 迁窗后四周黑遮罩
    .backgroundColor(this.concealSurface ? Color.Black : Color.Transparent)
    .clip(true)
    .renderGroup(this.breakHwcCompose || this.cropBottomGreenEdge)
  }
}
