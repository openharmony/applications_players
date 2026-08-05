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


import { LoadingStatus } from '@ohos/common/src/main/ets/constants/ui/Constants';
import { PlayConstants } from '@ohos/common/src/main/ets/constants/player/PlayConstants';
import FileInfo from '@ohos/common/src/main/ets/model/FileInfo';
import { HiLog } from '@ohos/common/src/main/ets/utils/HiLog';
import { AudioPlayerController } from '../controller/AudioPlayerController';
import { AudioPlayer } from './AudioPlayer';
import { AudioPlaybackSession } from '../session/AudioPlaybackSession';

const TAG = 'AudioPlaybackHost';

/**
 * 后台音频播放宿主：迷你条模式下保持 AudioPlayer 挂载，避免 AVPlayer 被释放
 */
@Component
export struct AudioPlaybackHost {
  @Prop @Watch('onFileInfoChange') fileInfo: FileInfo = new FileInfo('', '', '');
  @State audioController: AudioPlayerController = AudioPlaybackSession.getInstance().getController();
  @State playState: number = PlayConstants.STATUS_PAUSE;
  @State loadingStatus: LoadingStatus = LoadingStatus.LOAD_STATE_LOADING;

  aboutToAppear(): void {
    HiLog.i(TAG, `aboutToAppear uri=${this.fileInfo.uri}`);
    this.playState = this.audioController.getPlayState();
  }

  /** 切歌时同步 fileInfo */
  private onFileInfoChange(): void {
    if (this.fileInfo.uri.length === 0) {
      return;
    }
    HiLog.i(TAG, `onFileInfoChange uri=${this.fileInfo.uri}`);
    if (this.audioController.getActiveUri() !== this.fileInfo.uri) {
      this.loadingStatus = LoadingStatus.LOAD_STATE_LOADING;
      this.audioController.switchToTrack(this.fileInfo);
    }
  }

  build() {
    // 不可见挂载：仅维持播放与封面提取，不占布局空间
    AudioPlayer({
      fileInfo: this.fileInfo,
      hostOnlyMode: true,
      audioController: $audioController,
      playState: $playState,
      loadingStatus: $loadingStatus,
    })
      .width(0)
      .height(0)
      .opacity(0)
  }
}
