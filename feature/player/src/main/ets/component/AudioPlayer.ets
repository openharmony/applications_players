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

import image from '@ohos.multimedia.image';
import { AudioPlayerController } from '../controller/AudioPlayerController';
import { Constants, LoadingStatus, WindowType } from '@ohos/common/src/main/ets/constants/ui/Constants';
import DeviceConfigUtil from '@ohos/common/src/main/ets/utils/DeviceConfigUtil';
import { HiLog } from '@ohos/common';
import FileInfo from '@ohos/common/src/main/ets/model/FileInfo';
import { MediaCoverDisplayUtil } from '@ohos/common/src/main/ets/utils/MediaCoverDisplayUtil';
import hiTraceMeter from '@ohos.hiTraceMeter';
import { TaskId } from '@ohos/common/src/main/ets/constants/system/EventName';
import { PlayConstants } from '@ohos/common/src/main/ets/constants/player/PlayConstants';
import { PlaybackResumeContext } from '@ohos/common/src/main/ets/player/PlaybackResumeContext';
import { PlayerUiConstants } from '../constants/PlayerUiConstants';
import { PlayingEqualizerBars } from './PlayingEqualizerBars';
import { PlayingEqualizerConstants } from '../constants/PlayingEqualizerConstants';

const TAG = 'AudioPlayer';

@Component
export struct AudioPlayer {
  @Prop @Watch('onFileInfoChange') fileInfo: FileInfo = new FileInfo('', '', '');
  /** 后台宿主模式：仅绑定封面页，不触发 firstPlay */
  @Prop hostOnlyMode: boolean = false;
  @State audioImage: image.PixelMap | null = null;
  @State storedCoverUri: string = '';
  @State coverRevision: number = 0;
  @State windowType: WindowType = WindowType.MAIN_WINDOW;
  /** 封面下方频谱动画帧，仅驱动 UI 竖条 */
  @State equalizerAnimTick: number = 0;
  @Link audioController: AudioPlayerController;
  @Link @Watch('onPlayStateForEqualizer') playState: number;
  @Link loadingStatus: LoadingStatus;
  private isPCConfig: boolean = DeviceConfigUtil.checkConfigForPC();
  private equalizerTimer: number = -1;
  /** 当前封面绑定的曲目 URI，用于区分切歌与元数据补丁 */
  private coverTrackUri: string = '';

  /** 播放态变化时启停封面下方频谱动画 */
  private onPlayStateForEqualizer(): void {
    this.syncEqualizerTimer();
  }

  private syncEqualizerTimer(): void {
    const playing = this.playState === PlayConstants.STATUS_START;
    if (playing) {
      if (this.equalizerTimer >= 0) {
        return;
      }
      this.equalizerTimer = setInterval(() => {
        this.equalizerAnimTick++;
      }, PlayingEqualizerConstants.BAR_ANIM_FRAME_MS);
      return;
    }
    if (this.equalizerTimer >= 0) {
      clearInterval(this.equalizerTimer);
      this.equalizerTimer = -1;
    }
  }

  aboutToAppear() {
    HiLog.i(TAG, 'aboutToAppear');
    hiTraceMeter.startAsyncTrace(hiTraceMeter.HiTraceOutputLevel.INFO,
      'AUDIO_LOAD_PLAYER', TaskId.LOAD_PLAYER, 'PREVIEW_AUDIO_FILE');

    this.audioController.initAudioPlayerPage(this);
    this.audioController.setEmbeddedCoverListener(() => {
      this.refreshStoredCover();
      this.refreshEmbeddedCover();
    });
    this.playState = this.audioController.getPlayState();
    this.coverTrackUri = this.fileInfo.uri ?? '';
    this.refreshStoredCover();
    this.syncEqualizerTimer();

    if (this.fileInfo.uri === undefined || this.fileInfo.uri.length === 0) {
      HiLog.e(TAG, 'file info is undefined');
      hiTraceMeter.finishAsyncTrace(hiTraceMeter.HiTraceOutputLevel.INFO, 'AUDIO_LOAD_PLAYER',
        TaskId.LOAD_PLAYER);
      return;
    }
    if (this.hostOnlyMode) {
      HiLog.i(TAG, 'hostOnlyMode bind page skip firstPlay');
      this.playState = this.audioController.getPlayState();
      this.audioController.setFileInfo(this.fileInfo, true);
      const activeUri = this.audioController.getActiveUri();
      if (!(activeUri === this.fileInfo.uri && this.audioController.hasActivePlayback())) {
        HiLog.i(TAG, 'hostOnlyMode cold restore firstPlay');
        this.audioController.firstPlay(this.fileInfo.uri);
      }
      hiTraceMeter.finishAsyncTrace(hiTraceMeter.HiTraceOutputLevel.INFO, 'AUDIO_LOAD_PLAYER',
        TaskId.LOAD_PLAYER);
      return;
    }
    const activeUri = this.audioController.getActiveUri();
    if (activeUri === this.fileInfo.uri && this.audioController.hasActivePlayback()) {
      HiLog.i(TAG, `skip firstPlay same active uri`);
      this.playState = this.audioController.getPlayState();
      this.audioController.setFileInfo(this.fileInfo, true);
      if (PlaybackResumeContext.consumeForceAutoPlay() &&
        this.playState !== PlayConstants.STATUS_START) {
        HiLog.i(TAG, 'external open resume play on active uri');
        void this.audioController.play();
        this.playState = PlayConstants.STATUS_START;
      }
    } else if (activeUri.length > 0 && activeUri !== this.fileInfo.uri &&
      this.audioController.hasActivePlayback()) {
      HiLog.i(TAG, `switchToTrack from expanded ui uri change`);
      void this.audioController.switchToTrack(this.fileInfo);
    } else {
      PlaybackResumeContext.consumeForceAutoPlay();
      this.audioController.setFileInfo(this.fileInfo, true);
      this.audioController.firstPlay(this.fileInfo.uri);
    }

    hiTraceMeter.finishAsyncTrace(hiTraceMeter.HiTraceOutputLevel.INFO, 'AUDIO_LOAD_PLAYER',
      TaskId.LOAD_PLAYER);
  }

  aboutToUpdate(): void {
    this.refreshEmbeddedCover();
    this.refreshStoredCover();
  }

  /**
   * 将 Controller 异步提取的封面同步到 @State，触发 Image 刷新
   */
  private refreshEmbeddedCover(): void {
    const embedded = this.audioController.getCoverPixelMap();
    if (embedded !== null && embedded !== this.audioImage) {
      this.audioImage?.release();
      this.audioImage = embedded;
      this.coverRevision++;
      return;
    }
    if (embedded === null && this.audioImage !== null) {
      this.audioImage.release();
      this.audioImage = null;
      this.coverRevision++;
    }
  }

  onFileInfoChange(): void {
    const uri = this.fileInfo?.uri ?? '';
    const trackChanged = uri.length > 0 && uri !== this.coverTrackUri;
    if (trackChanged) {
      this.coverTrackUri = uri;
      this.coverRevision++;
    }
    const prevStored = this.storedCoverUri;
    this.refreshStoredCover();
    if (!trackChanged && this.storedCoverUri.length > 0 && this.storedCoverUri !== prevStored) {
      this.coverRevision++;
    }
    // 元数据补丁（如播放后补齐 duration）会克隆 FileInfo，不应清空已提取的内嵌封面
    this.refreshEmbeddedCover();
  }

  aboutToDisappear() {
    if (this.equalizerTimer >= 0) {
      clearInterval(this.equalizerTimer);
      this.equalizerTimer = -1;
    }
    this.audioImage?.release();
    this.audioImage = null;
    HiLog.i(TAG, 'aboutToDisappear');
  }

  private refreshStoredCover(): void {
    if (!this.fileInfo?.uri) {
      this.storedCoverUri = '';
      return;
    }
    this.storedCoverUri = MediaCoverDisplayUtil.getAudioCoverUri(this.fileInfo);
  }

  @Builder
  CoverForeground() {
    if (this.storedCoverUri.length > 0) {
      Image(this.storedCoverUri)
        .key(`audio_cover_uri_${this.fileInfo.uri}_${this.coverRevision}`)
        .width(Constants.ALL_PERCENT)
        .height(Constants.ALL_PERCENT)
        .objectFit(ImageFit.Contain)
        .focusable(this.isPCConfig && this.windowType === WindowType.UI_EXTENSION_WINDOW ? false : true)
        .draggable(false)
        .id('audio_player_cover_uri_id')
    } else if (this.audioImage !== null) {
      Image(this.audioImage)
        .key(`audio_cover_embed_${this.fileInfo.uri}_${this.coverRevision}`)
        .width(Constants.ALL_PERCENT)
        .height(Constants.ALL_PERCENT)
        .objectFit(ImageFit.Contain)
        .focusable(this.isPCConfig && this.windowType === WindowType.UI_EXTENSION_WINDOW ? false : true)
        .draggable(false)
        .id('audio_player_image_id')
    } else {
      Image(MediaCoverDisplayUtil.getAudioPlaceholderIcon())
        .width(MediaCoverDisplayUtil.PLAYER_PLACEHOLDER_ICON_SIZE)
        .height(MediaCoverDisplayUtil.PLAYER_PLACEHOLDER_ICON_SIZE)
        .objectFit(ImageFit.Contain)
        .opacity(MediaCoverDisplayUtil.PLACEHOLDER_ICON_OPACITY)
        .id('audio_player_placeholder_icon_id')
    }
  }

  build() {
    // 封面按剩余高度等比缩放（不可 height=100% 再叠 aspectRatio），为起伏特效保留固定行，避免叠到标题
    Column({ space: PlayerUiConstants.COVER_EQUALIZER_GAP }) {
      Stack({ alignContent: Alignment.Center }) {
        Column()
          .width(Constants.ALL_PERCENT)
          .height(Constants.ALL_PERCENT)
          .backgroundColor(MediaCoverDisplayUtil.AUDIO_PLACEHOLDER_BG)

        this.CoverForeground()
      }
      .aspectRatio(1)
      .constraintSize({ maxWidth: Constants.ALL_PERCENT, maxHeight: Constants.ALL_PERCENT })
      .layoutWeight(1)
      .borderRadius(PlayerUiConstants.COVER_BORDER_RADIUS)
      .shadow({
        radius: PlayerUiConstants.COVER_SHADOW_RADIUS,
        color: PlayerUiConstants.COVER_SHADOW_COLOR,
        offsetX: 0,
        offsetY: PlayerUiConstants.COVER_SHADOW_OFFSET_Y
      })
      .clip(true)

      PlayingEqualizerBars({
        alwaysVisible: true,
        isPlaying: this.playState === PlayConstants.STATUS_START,
        animTick: this.equalizerAnimTick,
        barCount: 5,
        barColor: Color.White
      })
        .flexShrink(0)
        .margin({ bottom: PlayerUiConstants.EQUALIZER_BOTTOM_GAP })
    }
    .width(Constants.ALL_PERCENT)
    .height(Constants.ALL_PERCENT)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .clip(true)
  }
}
