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
import { AudioItem } from '@ohos/common/src/main/ets/model/AudioItem';
import FileInfo from '@ohos/common/src/main/ets/model/FileInfo';
import { Constants, WindowType } from '@ohos/common/src/main/ets/constants/ui/Constants';
import { PlayConstants } from '@ohos/common/src/main/ets/constants/player/PlayConstants';
import { HiLog } from '@ohos/common/src/main/ets/utils/HiLog';
import { PlaybackHistoryRestoreCallback, PlaybackQueueManager } from '@ohos/common';
import { MediaCoverDisplayUtil } from '@ohos/common/src/main/ets/utils/MediaCoverDisplayUtil';
import ToolbarItem from '@ohos/common/src/main/ets/model/ToolbarItem';
import { AudioPlayerController } from '../controller/AudioPlayerController';
import { AudioPlaybackSession } from '../session/AudioPlaybackSession';
import { AudioMiniPlayerConstants } from '../constants/AudioMiniPlayerConstants';
import { PlaybackQueueSheetPanel } from './PlaybackQueueSheetPanel';
import { PlaybackQueueSheetTab, PlaybackQueueSheetConstants } from '../constants/PlaybackQueueSheetConstants';
import { PlayerMediaTitleUtil } from '../utils/PlayerMediaTitleUtil';
import { PlayerUiConstants } from '../constants/PlayerUiConstants';
import { AppThemeConstants } from '@ohos/common/src/main/ets/constants/ui/AppThemeConstants';

const TAG = 'AudioMiniPlayerBar';

/**
 * 底部迷你播放条：封面旋转、环形进度播放钮、播放队列半模态
 */
@Component
export struct AudioMiniPlayerBar {
  @Prop @Watch('onAudioItemChange') audioItem: AudioItem = new AudioItem();
  onExpand?: () => void = undefined;
  onRestoreHistoryPlayback?: PlaybackHistoryRestoreCallback;
  onAudioQueueEmpty?: () => void = undefined;
  onPrepareQueueSheet?: () => void = undefined;

  @State progressVal: number = PlayConstants.PLAY_PROGRESS_PROGRESS_VAL;
  @State currentTime: string = PlayConstants.PLAY_PROGRESS_CURRENT_TIME;
  @State totalTime: string = PlayConstants.PLAY_PROGRESS_TOTAL_TIME;
  @State playState: number = PlayConstants.STATUS_PAUSE;
  @State volumeShow: boolean = false;
  @State playIcon: Resource = Constants.PLAYER_PROGRESS_ICON_PLAY;
  @State coverAngle: number = 0;
  @State coverRevision: number = 0;
  @State storedCoverUri: string = '';
  @State audioImage: image.PixelMap | null = null;
  @State showQueueSheet: boolean = false;
  @State queueSheetTab: number = PlaybackQueueSheetTab.CURRENT;
  @State displayTitle: string = '';
  @State incomingTitle: string = '';
  @State titleOffsetX: number = 0;
  @State titleRowOffsetX: number = 0;
  @State titleSlideWidth: number = AudioMiniPlayerConstants.TITLE_SWIPE_DEFAULT_WIDTH;
  @State titleSwipeDirection: number = 0;
  @State isTitleAnimating: boolean = false;
  @State titleDidPan: boolean = false;
  @State titleRenderRevision: number = 0;
  @State playButton: ToolbarItem = new ToolbarItem('mini_play_button',
    '', Constants.PLAYER_PROGRESS_ICON_PLAY, undefined, true, () => {
    });
  windowType: WindowType = WindowType.MAIN_WINDOW;
  @StorageProp(AppThemeConstants.STORAGE_DARK_MODE) isDarkMode: boolean = false;

  private audioController: AudioPlayerController = AudioPlaybackSession.getInstance().getController();
  private coverRotationTimer: number = -1;
  private coverRotationEpochMs: number = 0;
  private coverRotationBaseAngle: number = 0;
  private readonly onPlaybackStateChanged = (state: number): void => {
    this.playState = state;
    this.updatePlayIcon(state);
    this.syncCoverRotation(state);
  };

  private getString(resource: Resource): string {
    try {
      return getContext(this).resourceManager.getStringSync(resource);
    } catch (error) {
      const errMsg = error instanceof Error ? error.message : String(error);
      HiLog.w(TAG, `getString failed message=${errMsg}`);
      return '';
    }
  }

  private isUnknownArtistText(artist: string): boolean {
    const localizedUnknownArtist = this.getString($r('app.string.player_unknown_artist'));
    return artist.length === 0 || artist === localizedUnknownArtist || artist === '未知艺术家';
  }

  aboutToAppear(): void {
    HiLog.i(TAG, `aboutToAppear title=${this.audioItem.title}`);
    this.coverAngle = this.audioController.getCoverAngle();
    this.applyDisplayTitle(this.getDisplayTitle());
    this.bindPlaybackUi();
    this.playState = this.audioController.getPlayState();
    this.updatePlayIcon(this.playState);
    this.refreshStoredCover();
    this.refreshEmbeddedCover();
    this.syncCoverRotation(this.playState);
  }

  aboutToDisappear(): void {
    HiLog.i(TAG, 'aboutToDisappear');
    this.unbindPlaybackUi();
    this.stopCoverRotation();
    this.audioController.setCoverAngle(this.coverAngle);
  }

  /** 绑定进度条与播放态监听 */
  private bindPlaybackUi(): void {
    this.audioController.initPlayProgress(this);
    this.audioController.addProgressPlayStateListener(this.onPlaybackStateChanged);
    this.audioController.setEmbeddedCoverListener(() => {
      this.refreshEmbeddedCover();
      this.refreshStoredCover();
    });
  }

  /** 解绑监听，避免全屏页挂载后仍向迷你条回调 */
  private unbindPlaybackUi(): void {
    this.audioController.removeProgressPlayStateListener(this.onPlaybackStateChanged);
    this.audioController.detachPlayProgress(this);
    this.audioController.setEmbeddedCoverListener(null);
  }

  /** 清除封面旋转定时器 */
  private clearCoverRotationTimer(): void {
    if (this.coverRotationTimer < 0) {
      return;
    }
    clearInterval(this.coverRotationTimer);
    this.coverRotationTimer = -1;
  }

  /** 按已播放时长计算并冻结当前封面角度 */
  private freezeCoverAngle(): void {
    const duration = AudioMiniPlayerConstants.COVER_ROTATION_DURATION_MS;
    const elapsed = Date.now() - this.coverRotationEpochMs;
    this.coverAngle = this.coverRotationBaseAngle + (elapsed / duration) * 360;
  }

  /** 停止封面旋转，保持当前角度不变 */
  private stopCoverRotation(): void {
    if (this.coverRotationTimer < 0) {
      return;
    }
    this.freezeCoverAngle();
    this.clearCoverRotationTimer();
  }

  /** 根据播放状态切换封面旋转 */
  private syncCoverRotation(state: number): void {
    if (state === PlayConstants.STATUS_START) {
      this.startCoverRotation();
    } else {
      this.stopCoverRotation();
    }
  }

  /** 封面缓慢旋转（播放中），定时器驱动便于暂停时立即冻结角度 */
  private startCoverRotation(): void {
    if (this.coverRotationTimer >= 0) {
      return;
    }
    this.coverRotationBaseAngle = this.coverAngle;
    this.coverRotationEpochMs = Date.now();
    const duration = AudioMiniPlayerConstants.COVER_ROTATION_DURATION_MS;
    const tickMs = AudioMiniPlayerConstants.COVER_ROTATION_TICK_MS;
    this.coverRotationTimer = setInterval(() => {
      if (this.coverRotationTimer < 0) {
        return;
      }
      const elapsed = Date.now() - this.coverRotationEpochMs;
      this.coverAngle = this.coverRotationBaseAngle + (elapsed / duration) * 360;
    }, tickMs);
  }

  /** 同步嵌入式封面 */
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

  /** 切歌时刷新封面；非滑动动画期间同步展示标题 */
  private onAudioItemChange(): void {
    HiLog.i(TAG, `onAudioItemChange title=${this.audioItem.title} animating=${this.isTitleAnimating}`);
    this.stopCoverRotation();
    this.coverAngle = 0;
    this.refreshStoredCover();
    this.coverRevision++;
    if (this.isTitleAnimating) {
      return;
    }
    this.applyDisplayTitle(this.getDisplayTitle());
    this.resetTitleSwipeVisualState();
  }

  /** 写入展示标题并递增 revision，强制 Text 节点重建 */
  private applyDisplayTitle(title: string): void {
    this.displayTitle = title;
    this.titleRenderRevision++;
    HiLog.i(TAG, `applyDisplayTitle title=${title} revision=${this.titleRenderRevision}`);
  }

  /** 重置标题滑动视觉状态（不改动 displayTitle） */
  private resetTitleSwipeVisualState(): void {
    this.titleOffsetX = 0;
    this.titleRowOffsetX = 0;
    this.incomingTitle = '';
    this.titleSwipeDirection = 0;
    this.isTitleAnimating = false;
    this.titleDidPan = false;
  }

  /** 读取持久化封面 URI */
  private refreshStoredCover(): void {
    const fileInfo = this.resolveFileInfo();
    if (!fileInfo?.uri) {
      this.storedCoverUri = '';
      HiLog.i(TAG, `refreshStoredCover: fileInfo.uri is empty, storedCoverUri=''`);
      return;
    }
    const coverUri = MediaCoverDisplayUtil.getAudioCoverUri(fileInfo);
    HiLog.i(TAG, `refreshStoredCover: fileName=${fileInfo.fileName} coverUri=${coverUri} fileInfo.coverUri=${fileInfo.coverUri} fileInfo.thumbUri=${fileInfo.thumbUri}`);
    this.storedCoverUri = coverUri;
  }

  /** 将 AudioItem 转为 FileInfo */
  private resolveFileInfo(): FileInfo {
    if (this.audioItem.fileInfo) {
      return FileInfo.fromFileOperateFileInfo(this.audioItem.fileInfo);
    }
    return new FileInfo(this.audioItem.fileName, this.audioItem.uri, this.audioItem.mimeType);
  }

  /** 更新播放/暂停图标 */
  private updatePlayIcon(state: number): void {
    this.playIcon = state === PlayConstants.STATUS_START ?
      Constants.PLAYER_PROGRESS_ICON_PAUSE : Constants.PLAYER_PROGRESS_ICON_PLAY;
  }

  /** 是否播放完毕（外圈变深色） */
  private isPlaybackCompleted(): boolean {
    return this.playState === PlayConstants.STATUS_COMPLETE;
  }

  /** 展示用标题行：标题 - 艺术家 */
  private getDisplayTitle(): string {
    return this.formatDisplayTitleFromFileName(this.audioItem.fileName, this.audioItem.title,
      this.audioItem.audioInfo?.title, this.audioItem.audioInfo?.artist);
  }

  /**
   * 由文件名/元数据拼展示标题
   *
   * @param fileName 文件名
   * @param fallbackTitle 备用标题
   * @param metaTitle 内嵌标题
   * @param metaArtist 内嵌艺术家
   */
  private formatDisplayTitleFromFileName(fileName: string, fallbackTitle: string = '',
    metaTitle?: string, metaArtist?: string): string {
    const parsed = PlayerMediaTitleUtil.parseFromFileName(fileName);
    const title = metaTitle !== undefined && metaTitle.length > 0 ? metaTitle :
      (fallbackTitle.length > 0 ? fallbackTitle : parsed.title);
    const artist = metaArtist !== undefined && metaArtist.length > 0 &&
      !this.isUnknownArtistText(metaArtist) ? metaArtist : parsed.artist;
    if (artist.length > 0) {
      return `${title} - ${artist}`;
    }
    return title;
  }

  /**
   * 解析 onAreaChange 返回的宽度（可能是 number 或带单位的 string）
   *
   * @param width 区域宽度
   */
  private parseAreaWidth(width: number | string): number {
    if (typeof width === 'number') {
      return width;
    }
    const numeric = parseFloat(width);
    return isNaN(numeric) ? 0 : numeric;
  }

  /** 标题滑动轨道宽度（vp） */
  private getSlideWidth(): number {
    return this.titleSlideWidth > 0 ?
      this.titleSlideWidth : AudioMiniPlayerConstants.TITLE_SWIPE_DEFAULT_WIDTH;
  }

  /**
   * 预览相邻曲目标题（direction: 1 下一曲，-1 上一曲）
   *
   * @param direction 滑动方向
   */
  private resolveAdjacentTitle(direction: number): string {
    const queue = PlaybackQueueManager.getInstance();
    const length = queue.getQueueLength();
    const currentIndex = queue.getCurrentIndex();
    if (length <= 1 || currentIndex < 0) {
      HiLog.w(TAG, `resolveAdjacentTitle empty length=${length} index=${currentIndex}`);
      return '';
    }
    let targetIndex = currentIndex;
    if (direction > 0) {
      targetIndex = (currentIndex + 1) % length;
    } else if (direction < 0) {
      targetIndex = currentIndex <= 0 ? length - 1 : currentIndex - 1;
    }
    const snapshot = queue.getQueueSnapshot();
    if (targetIndex < 0 || targetIndex >= snapshot.length) {
      HiLog.w(TAG, `resolveAdjacentTitle invalid targetIndex=${targetIndex}`);
      return '';
    }
    const entry = snapshot[targetIndex];
    const track = queue.getTrack(entry.uri);
    if (track !== null) {
      return this.formatDisplayTitleFromFileName(track.fileName);
    }
    return this.formatDisplayTitleFromFileName(entry.fileName);
  }

  /** 同步标题 Row 位移（@State 直绑 translate，避免 @Builder 参数不刷新） */
  private syncTitleRowOffset(): void {
    if (this.titleSwipeDirection < 0 && this.incomingTitle.length > 0) {
      this.titleRowOffsetX = -this.getSlideWidth() + this.titleOffsetX;
      return;
    }
    this.titleRowOffsetX = this.titleOffsetX;
  }

  /** 计算标题滑入/回弹动画时长：快滑更短，慢滑与剩余距离成正比 */
  private computeSwipeAnimationDuration(offsetX: number, velocityX: number, committed: boolean): number {
    if (!committed) {
      return AudioMiniPlayerConstants.TITLE_SWIPE_ANIM_CANCEL_MS;
    }
    const absVelocity = Math.abs(velocityX);
    if (absVelocity >= AudioMiniPlayerConstants.TITLE_SWIPE_FAST_VELOCITY) {
      return AudioMiniPlayerConstants.TITLE_SWIPE_ANIM_FAST_MS;
    }
    const slideWidth = this.getSlideWidth();
    const progress = Math.min(1, Math.abs(offsetX) / slideWidth);
    const fastMs = AudioMiniPlayerConstants.TITLE_SWIPE_ANIM_FAST_MS;
    const slowMs = AudioMiniPlayerConstants.TITLE_SWIPE_ANIM_SLOW_MS;
    return Math.round(slowMs - (slowMs - fastMs) * progress);
  }

  /** 标题横向位移动画 */
  private animateTitleOffset(targetOffset: number, currentOffset: number, velocityX: number,
    committed: boolean, onFinish?: () => void): void {
    const duration = this.computeSwipeAnimationDuration(currentOffset, velocityX, committed);
    HiLog.i(TAG, `animateTitleOffset target=${targetOffset} duration=${duration} committed=${committed}`);
    animateTo({
      duration: duration,
      curve: Curve.EaseOut,
      onFinish: () => {
        onFinish?.();
      }
    }, () => {
      this.titleOffsetX = targetOffset;
      this.syncTitleRowOffset();
    });
  }

  /** 标题滑动过程中跟手更新相邻曲目预览 */
  private handleTitlePanUpdate(offsetX: number): void {
    if (this.isTitleAnimating) {
      return;
    }
    this.titleOffsetX = offsetX;
    const previewThreshold = 8;
    if (offsetX <= -previewThreshold) {
      this.titleSwipeDirection = 1;
      this.incomingTitle = this.resolveAdjacentTitle(1);
    } else if (offsetX >= previewThreshold) {
      this.titleSwipeDirection = -1;
      this.incomingTitle = this.resolveAdjacentTitle(-1);
    } else {
      this.titleSwipeDirection = 0;
      this.incomingTitle = '';
    }
    this.syncTitleRowOffset();
    HiLog.i(TAG, `titlePanUpdate offsetX=${offsetX} direction=${this.titleSwipeDirection} rowOffset=${this.titleRowOffsetX}`);
  }

  /**
   * 标题区横滑结束：未达阈值回弹；达阈值则滑出当前标题并滑入目标曲目标题后切歌
   *
   * @param offsetX 手势横向位移（vp）
   * @param velocityX 手势横向速度（px/s）
   */
  private handleTitleSwipeEnd(offsetX: number, velocityX: number): void {
    if (this.isTitleAnimating) {
      return;
    }
    const threshold = AudioMiniPlayerConstants.TITLE_SWIPE_TRACK_MIN_OFFSET;
    const fastVelocity = AudioMiniPlayerConstants.TITLE_SWIPE_FAST_VELOCITY;
    const committedNext = offsetX <= -threshold || velocityX <= -fastVelocity;
    const committedPrev = offsetX >= threshold || velocityX >= fastVelocity;
    if (!committedNext && !committedPrev) {
      HiLog.i(TAG, `titleSwipe cancel offsetX=${offsetX}`);
      this.animateTitleOffset(0, offsetX, velocityX, false, () => {
        this.titleSwipeDirection = 0;
        this.incomingTitle = '';
        this.syncTitleRowOffset();
      });
      return;
    }
    const direction = committedNext ? 1 : -1;
    const adjacentTitle = this.resolveAdjacentTitle(direction);
    if (adjacentTitle.length === 0) {
      HiLog.w(TAG, `titleSwipe no adjacent direction=${direction}`);
      this.animateTitleOffset(0, offsetX, velocityX, false, () => {
        this.titleSwipeDirection = 0;
        this.incomingTitle = '';
        this.syncTitleRowOffset();
      });
      return;
    }
    this.incomingTitle = adjacentTitle;
    this.titleSwipeDirection = direction;
    this.syncTitleRowOffset();
    const slideWidth = this.getSlideWidth();
    const exitOffset = direction > 0 ? -slideWidth : slideWidth;
    this.isTitleAnimating = true;
    HiLog.i(TAG, `titleSwipe commit direction=${direction} offsetX=${offsetX} velocityX=${velocityX}`);
    this.animateTitleOffset(exitOffset, offsetX, velocityX, true, () => {
      const committedTitle = this.incomingTitle;
      // 先提升目标标题再折叠 Row，避免滑入结束后仍显示旧 displayTitle
      if (committedTitle.length > 0) {
        this.applyDisplayTitle(committedTitle);
      }
      this.incomingTitle = '';
      this.titleSwipeDirection = 0;
      this.titleOffsetX = 0;
      this.titleRowOffsetX = 0;
      this.isTitleAnimating = false;
      HiLog.i(TAG, `titleSwipe complete committedTitle=${committedTitle}`);
      if (direction > 0) {
        this.handleSkipNext();
      } else {
        this.handleSkipPrevious();
      }
    });
  }

  /** 点击播放/暂停 */
  private handlePlayPauseClick(): void {
    HiLog.i(TAG, `playPause clicked state=${this.playState}`);
    this.audioController.switchPlayOrPause()
      .then(() => {
        HiLog.i(TAG, `playPause done state=${this.audioController.getPlayState()}`);
      })
      .catch((error: Error) => {
        HiLog.e(TAG, `playPause failed message=${error.message}`);
      });
  }

  /** 点击条体展开全屏播放器 */
  private handleBarExpand(): void {
    HiLog.i(TAG, 'bar expand clicked');
    this.onExpand?.();
  }

  /** 切换上一曲 */
  private handleSkipPrevious(): void {
    HiLog.i(TAG, 'titleSwipe skipPrevious');
    this.audioController.skipToPreviousTrack();
  }

  /** 切换下一曲 */
  private handleSkipNext(): void {
    HiLog.i(TAG, 'titleSwipe skipNext');
    this.audioController.skipToNextTrack();
  }

  /** 关闭播放队列半模态 */
  private closeQueueSheet(): void {
    this.showQueueSheet = false;
  }

  /** 左侧黑胶封面 */
  @Builder
  CoverDisc() {
    Stack({ alignContent: Alignment.Center }) {
      Circle()
        .width(AudioMiniPlayerConstants.COVER_OUTER_SIZE)
        .height(AudioMiniPlayerConstants.COVER_OUTER_SIZE)
        .fill(AudioMiniPlayerConstants.COVER_VINYL_RING_COLOR)

      Stack({ alignContent: Alignment.Center }) {
        if (this.storedCoverUri.length > 0) {
          Image(this.storedCoverUri)
            .key(`mini_cover_uri_${this.audioItem.uri}_${this.coverRevision}`)
            .width(AudioMiniPlayerConstants.COVER_INNER_SIZE)
            .height(AudioMiniPlayerConstants.COVER_INNER_SIZE)
            .borderRadius(AudioMiniPlayerConstants.COVER_INNER_SIZE / 2)
            .objectFit(ImageFit.Cover)
        } else if (this.audioImage !== null) {
          Image(this.audioImage)
            .key(`mini_cover_embed_${this.audioItem.uri}_${this.coverRevision}`)
            .width(AudioMiniPlayerConstants.COVER_INNER_SIZE)
            .height(AudioMiniPlayerConstants.COVER_INNER_SIZE)
            .borderRadius(AudioMiniPlayerConstants.COVER_INNER_SIZE / 2)
            .objectFit(ImageFit.Cover)
        } else {
          Image(MediaCoverDisplayUtil.getAudioPlaceholderIcon())
            .width(16)
            .height(16)
            .objectFit(ImageFit.Contain)
            .opacity(MediaCoverDisplayUtil.PLACEHOLDER_ICON_OPACITY)
        }
      }
      .width(AudioMiniPlayerConstants.COVER_INNER_SIZE)
      .height(AudioMiniPlayerConstants.COVER_INNER_SIZE)
      .clip(true)
      .borderRadius(AudioMiniPlayerConstants.COVER_INNER_SIZE / 2)
    }
    .width(AudioMiniPlayerConstants.COVER_OUTER_SIZE)
    .height(AudioMiniPlayerConstants.COVER_OUTER_SIZE)
    .rotate({ angle: this.coverAngle })
  }

  /** 环形进度 + 播放/暂停 */
  @Builder
  PlayProgressButton() {
    Stack({ alignContent: Alignment.Center }) {
      Progress({
        value: this.isPlaybackCompleted() ? 100 : this.progressVal,
        total: 100,
        type: ProgressType.Ring
      })
        .width(AudioMiniPlayerConstants.PLAY_BUTTON_SIZE)
        .height(AudioMiniPlayerConstants.PLAY_BUTTON_SIZE)
        .style({
          strokeWidth: AudioMiniPlayerConstants.RING_STROKE_WIDTH,
          enableSmoothEffect: false
        })
        .color(this.isPlaybackCompleted() ?
          AudioMiniPlayerConstants.RING_COMPLETED_COLOR :
          AudioMiniPlayerConstants.RING_PROGRESS_COLOR)
        .backgroundColor(this.isPlaybackCompleted() ?
          AudioMiniPlayerConstants.RING_COMPLETED_COLOR :
          AudioMiniPlayerConstants.RING_TRACK_COLOR)

      SymbolGlyph(this.playIcon)
        .fontSize(AudioMiniPlayerConstants.PLAY_ICON_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor([AudioMiniPlayerConstants.CONTROL_ICON_COLOR])
    }
    .width(AudioMiniPlayerConstants.PLAY_BUTTON_SIZE)
    .height(AudioMiniPlayerConstants.PLAY_BUTTON_SIZE)
    .onClick(() => {
      this.handlePlayPauseClick();
    })
  }

  /** 播放队列按钮 */
  @Builder
  QueueButton() {
    Button({ type: ButtonType.Circle }) {
      SymbolGlyph(Constants.APP_BAR_ICON_PLAYLIST)
        .fontSize(AudioMiniPlayerConstants.QUEUE_ICON_SIZE)
        .fontColor([AudioMiniPlayerConstants.CONTROL_ICON_COLOR])
    }
    .width(AudioMiniPlayerConstants.QUEUE_BUTTON_SIZE)
    .height(AudioMiniPlayerConstants.QUEUE_BUTTON_SIZE)
    .backgroundColor($r('sys.color.ohos_id_color_background_transparent'))
    .bindSheet($$this.showQueueSheet, this.QueueSheetPanel(), {
      height: SheetSize.MEDIUM,
      dragBar: true,
      showClose: false,
      backgroundColor: PlaybackQueueSheetConstants.SHEET_ROOT_BACKGROUND,
      maskColor: PlaybackQueueSheetConstants.resolveMaskColor(),
      onDisappear: () => {
        this.closeQueueSheet();
      }
    })
    .onClick(() => {
      HiLog.i(TAG, 'openQueueSheet');
      if (this.onPrepareQueueSheet !== undefined) {
        this.onPrepareQueueSheet();
      }
      this.queueSheetTab = PlaybackQueueSheetTab.CURRENT;
      this.showQueueSheet = true;
    })
  }

  /** 当前曲目标题（直绑 @State，避免 @Builder 字符串参数不刷新） */
  @Builder
  CurrentTitleText() {
    Text(this.displayTitle)
      .key(`mini_title_${this.audioItem.uri}_${this.titleRenderRevision}`)
      .fontSize(AudioMiniPlayerConstants.TITLE_FONT_SIZE)
      .fontColor(AudioMiniPlayerConstants.TITLE_TEXT_COLOR)
      .maxLines(AudioMiniPlayerConstants.TITLE_MAX_LINES)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .width(this.titleSlideWidth)
  }

  /** 滑动预览的相邻曲目标题 */
  @Builder
  IncomingTitleText() {
    Text(this.incomingTitle)
      .key(`mini_incoming_${this.incomingTitle}`)
      .fontSize(AudioMiniPlayerConstants.TITLE_FONT_SIZE)
      .fontColor(AudioMiniPlayerConstants.TITLE_TEXT_COLOR)
      .maxLines(AudioMiniPlayerConstants.TITLE_MAX_LINES)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .width(this.titleSlideWidth)
  }

  /** 封面与播放钮之间的标题区：点击展开，横滑切歌并带滑入动效 */
  @Builder
  TitleSwipeArea() {
    Row() {
      Stack({ alignContent: Alignment.Center }) {
        Row() {
          if (this.titleSwipeDirection < 0 && this.incomingTitle.length > 0) {
            this.IncomingTitleText()
          }
          this.CurrentTitleText()
          if (this.titleSwipeDirection > 0 && this.incomingTitle.length > 0) {
            this.IncomingTitleText()
          }
        }
        .translate({ x: this.titleRowOffsetX })
      }
      .width('100%')
      .height('100%')
      .clip(true)
      .onAreaChange((_oldArea: Area, newArea: Area) => {
        const width = this.parseAreaWidth(newArea.width as number | string);
        if (width > 0 && Math.abs(width - this.titleSlideWidth) > 0.5) {
          this.titleSlideWidth = width;
          HiLog.i(TAG, `titleArea width=${width}`);
        }
      })
    }
    .layoutWeight(1)
    .height('100%')
    .alignItems(VerticalAlign.Center)
    .margin({ left: AudioMiniPlayerConstants.COVER_TITLE_GAP })
    .gesture(
      GestureGroup(GestureMode.Parallel,
        TapGesture({ count: 1 })
          .onAction(() => {
            if (this.isTitleAnimating || this.titleDidPan) {
              this.titleDidPan = false;
              return;
            }
            this.handleBarExpand();
          }),
        PanGesture({
          fingers: 1,
          direction: PanDirection.Horizontal,
          distance: 8
        })
          .onActionStart(() => {
            this.titleDidPan = false;
          })
          .onActionUpdate((event: GestureEvent) => {
            if (Math.abs(event.offsetX) > 4) {
              this.titleDidPan = true;
            }
            this.handleTitlePanUpdate(event.offsetX);
          })
          .onActionEnd((event: GestureEvent) => {
            this.handleTitleSwipeEnd(event.offsetX, event.velocityX);
          })
          .onActionCancel(() => {
            HiLog.w(TAG, 'titlePan cancel');
            this.handleTitleSwipeEnd(0, 0);
          })
      )
    )
  }

  /** 播放队列半模态 */
  @Builder
  QueueSheetPanel() {
    PlaybackQueueSheetPanel({
      activeTab: $queueSheetTab,
      isAudio: true,
      avPlayerController: this.audioController,
      onRestoreHistoryPlayback: this.onRestoreHistoryPlayback,
      onAudioQueueEmpty: this.onAudioQueueEmpty,
      onDismiss: () => {
        this.closeQueueSheet();
      }
    })
  }

  /** 主播放 / 暂停按钮：仅图标，随深浅色切换黑/白 */
  @Builder
  PlayPauseButton() {
    Button({ type: ButtonType.Circle, stateEffect: false }) {
      SymbolGlyph(this.playIcon)
        .fontSize(AudioMiniPlayerConstants.PLAY_ICON_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor([AudioMiniPlayerConstants.CONTROL_ICON_COLOR])
    }
    .backgroundColor($r('sys.color.ohos_id_color_background_transparent'))
    .width(AudioMiniPlayerConstants.TRANSPORT_BUTTON_SIZE)
    .height(AudioMiniPlayerConstants.TRANSPORT_BUTTON_SIZE)
    .key(`play_pause_${this.playState}_${this.isDarkMode}`)
    .onClick(() => {
      this.handlePlayPauseClick();
    })
  }

  /** 切歌按钮：上一首 / 下一首，仅图标无背景 */
  @Builder
  SkipButton(icon: Resource, onClick: () => void) {
    Button({ type: ButtonType.Circle, stateEffect: false }) {
      SymbolGlyph(icon)
        .fontSize(AudioMiniPlayerConstants.TRANSPORT_SKIP_ICON_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor([AudioMiniPlayerConstants.CONTROL_ICON_COLOR])
    }
    .backgroundColor($r('sys.color.ohos_id_color_background_transparent'))
    .width(AudioMiniPlayerConstants.TRANSPORT_BUTTON_SIZE)
    .height(AudioMiniPlayerConstants.TRANSPORT_BUTTON_SIZE)
    .onClick(onClick)
  }

  /** 居中 transport 区：上一首 / 播放 / 下一首 */
  @Builder
  TransportCluster() {
    Row({ space: PlayerUiConstants.TRANSPORT_CLUSTER_GAP }) {
      this.SkipButton(Constants.APP_BAR_ICON_SKIP_PREVIOUS, () => {
        this.handleSkipPrevious()
      })

      this.PlayPauseButton()

      this.SkipButton(Constants.APP_BAR_ICON_SKIP_NEXT, () => {
        this.handleSkipNext()
      })
    }
    .alignItems(VerticalAlign.Center)
  }


  build() {
    Row({ space: AudioMiniPlayerConstants.CONTROL_GAP }) {
      Row() {
        this.CoverDisc()
      }
      .onClick(() => {
        this.handleBarExpand();
      })

      this.TitleSwipeArea()


      this.SkipButton(Constants.APP_BAR_ICON_SKIP_PREVIOUS, () => {
        this.handleSkipPrevious()
      })

      this.PlayProgressButton()

      this.SkipButton(Constants.APP_BAR_ICON_SKIP_NEXT, () => {
        this.handleSkipNext()
      })

      this.QueueButton()
    }
    .width('100%')
    .height(AudioMiniPlayerConstants.BAR_HEIGHT)
    .padding({ left: AudioMiniPlayerConstants.BAR_PADDING_H, right: AudioMiniPlayerConstants.BAR_PADDING_H })
    .backgroundColor(AudioMiniPlayerConstants.BAR_BG)
    .borderRadius(AudioMiniPlayerConstants.BAR_RADIUS)
    .shadow({
      radius: AudioMiniPlayerConstants.BAR_SHADOW_RADIUS,
      color: AudioMiniPlayerConstants.BAR_SHADOW_COLOR,
      offsetX: 0,
      offsetY: AudioMiniPlayerConstants.BAR_SHADOW_OFFSET_Y
    })
  }
}
