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


import { AVPlayerController } from '../controller/AVPlayerController';
import { IPlaybackControlHandler } from './PlaybackControlCenterBridge';

/**
 * 将 AVPlayerController 适配为播控反向控制委托（ArkTS 禁止匿名对象实现接口）
 */
export class AvPlayerPlaybackControlHandler implements IPlaybackControlHandler {
  private readonly owner: AVPlayerController;

  /**
   * @param owner 播放器控制器
   */
  constructor(owner: AVPlayerController) {
    this.owner = owner;
  }

  onControlPlay(): void {
    void this.owner.play();
  }

  onControlPause(): void {
    this.owner.pause();
  }

  onControlStop(): void {
    this.owner.pause();
  }

  onControlSeek(time: number): void {
    this.owner.dispatchControlCenterSeek(time);
  }

  onControlPlayNext(): void {
    this.owner.skipToNextTrack();
  }

  onControlPlayPrevious(): void {
    this.owner.skipToPreviousTrack();
  }
}
