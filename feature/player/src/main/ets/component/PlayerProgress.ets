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

import { promptAction } from '@kit.ArkUI';

import { PlaybackHistoryRestoreCallback } from '@ohos/common';
import { Constants, WindowType } from '@ohos/common/src/main/ets/constants/ui/Constants';
import { AudioLoopMode, LoopState, PlayConstants } from '@ohos/common/src/main/ets/constants/player/PlayConstants';
import FileInfo from '@ohos/common/src/main/ets/model/FileInfo';
import ToolbarItem from '@ohos/common/src/main/ets/model/ToolbarItem';
import DeviceConfigUtil from '@ohos/common/src/main/ets/utils/DeviceConfigUtil';
import { HiLog } from '@ohos/common/src/main/ets/utils/HiLog';
import { MediaFormatUtil } from '@ohos/common/src/main/ets/utils/MediaFormatUtil';

import { PlayerUiConstants } from '../constants/PlayerUiConstants';
import { PlaybackQueueSheetConstants, PlaybackQueueSheetTab } from '../constants/PlaybackQueueSheetConstants';
import { AVPlayerController } from '../controller/AVPlayerController';
import { PlayerMediaTitleUtil } from '../utils/PlayerMediaTitleUtil';
import { AUDIO_SPEED_OPTIONS, SpeedOptionItem } from './AudioSpeedMenuOverlay';
import { PlaybackQueueSheetPanel } from './PlaybackQueueSheetPanel';
import { PlayerSpeedMenuPanel } from './PlayerSpeedMenuPanel';

const TAG = 'PlayerProgress';

/** bindPopup onStateChange 事件 */
interface SpeedMenuPopupStateEvent {
  isVisible: boolean;
}

@Component
export struct PlayerProgress {
  @State currentTime: string = PlayConstants.PLAY_PROGRESS_CURRENT_TIME;
  @State totalTime: string = PlayConstants.PLAY_PROGRESS_TOTAL_TIME;
  @State progressVal: number = PlayConstants.PLAY_PROGRESS_PROGRESS_VAL;
  @State volumeShow: boolean = false;
  @State isSilent: boolean = false;
  @Prop type: string = '';
  @State loopButton: ToolbarItem = new ToolbarItem('loop',
    $r('app.string.single_loop'), Constants.APP_BAR_ICON_LOOP, undefined, true, () => {
    });
  @Require @Prop isAudio: boolean = false;
  onRestoreHistoryPlayback?: PlaybackHistoryRestoreCallback;
  onAudioQueueEmpty?: () => void;
  @Prop isPortraitVideoPanel: boolean = false;
  @Prop isVideoFullscreen: boolean = false;
  @Prop videoFrameRate: number = 0;
  @Link avPlayerController: AVPlayerController;
  @Link @Watch('onPlayStateChanged') playState: number;
  @Prop @Watch('volumeChangeCallback') volumePercentage: number;
  @Prop fileInfo: FileInfo;
  @Prop windowType: WindowType;
  @Prop toolbarHeight: number = 0;
  @Link @Watch('progressHideWatchCallback') isHideProgressAndTitle: boolean;
  @Link showSpeedMenu: boolean;
  @Link speedLabel: string;
  @State showPlaylistSheet: boolean = false;
  @State playlistSheetTab: number = PlaybackQueueSheetTab.CURRENT;
  @State playIcon: Resource = Constants.PLAYER_PROGRESS_ICON_PLAY;
  @State isMuted: boolean = false;
  @State volumeButtonIcon: Resource = Constants.APP_BAR_ICON_VOLUME;
  @State audioLoopMode: AudioLoopMode = AudioLoopMode.LIST;
  @State loopModeIcon: Resource = Constants.APP_BAR_ICON_REPEAT_LIST;
  @State playButton: ToolbarItem = new ToolbarItem('play_button',
    '', Constants.PLAYER_PROGRESS_ICON_PLAY, undefined, true, async (event?: ClickEvent) => {
      try {
        await this.avPlayerController.switchPlayOrPause();
        this.onPlayStateChanged();
      } catch (err) {
        HiLog.e(TAG, `playButton action error,${err?.message}`);
      }
    });

  private isPCConfig: boolean = DeviceConfigUtil.checkConfigForPC();
  private isPhoneConfig: boolean = DeviceConfigUtil.checkConfigForPhone();
  private volumeBeforeMute: number = PlayConstants.PLAY_PAGE_DEFAULT_VOLUME;
  private readonly onProgressPlayStateChanged = (state: number): void => {
    this.playState = state;
    this.updatePlayIcon(state);
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

  volumeChangeCallback() {
    if (this.type === 'video') {
      if (this.volumePercentage > 0 && this.isMuted) {
        this.isMuted = false;
      }
      this.syncVolumeButtonIcon();
      return;
    }
    if (this.volumePercentage > 0 && this.isMuted) {
      this.isMuted = false;
    }
    this.syncVolumeButtonIcon();
  }

  onPcFullScreen() {
  }

  progressHideWatchCallback() {
  }

  onPlayStateChanged(): void {
    this.updatePlayIcon(this.playState);
  }

  private updatePlayIcon(state: number): void {
    this.playIcon = state === PlayConstants.STATUS_START ?
      Constants.PLAYER_PROGRESS_ICON_PAUSE : Constants.PLAYER_PROGRESS_ICON_PLAY;
    HiLog.i(TAG, `updatePlayIcon state:${state}`);
  }

  private getVolumeButtonIcon(): Resource {
    if (this.isMuted) {
      return Constants.APP_BAR_ICON_SILENT;
    }
    return this.avPlayerController.getVolumeIcon(this.volumePercentage);
  }

  /** 将静音态同步到 @State 图标，确保 SymbolGlyph 随 isMuted 刷新 */
  private syncVolumeButtonIcon(): void {
    this.volumeButtonIcon = this.getVolumeButtonIcon();
  }

  switchLoopState(state: string) {
    switch (state) {
      case LoopState.CLOSE_LOOP_BUTTON:
        this.avPlayerController?.setLoop(true);
        break;
      case LoopState.SINGLE_LOOP_BUTTON:
        this.avPlayerController?.setLoop(false);
        break;
    }
  }

  aboutToAppear() {
    if (this.avPlayerController !== null) {
      this.avPlayerController.initPlayProgress(this);
      this.avPlayerController.addProgressPlayStateListener(this.onProgressPlayStateChanged);
      this.playState = this.avPlayerController.getPlayState();
    }
    this.refreshSpeedLabel();
    this.onPlayStateChanged();
    if (this.isAudio) {
      this.audioLoopMode = this.avPlayerController.getAudioLoopMode();
      this.updateLoopModeIcon();
    }
    this.syncVolumeButtonIcon();
  }

  aboutToDisappear() {
    if (this.avPlayerController !== null) {
      this.avPlayerController.detachPlayProgress(this);
      this.avPlayerController.removeProgressPlayStateListener(this.onProgressPlayStateChanged);
    }
  }

  private getSpeedOptions(): SpeedOptionItem[] {
    return AUDIO_SPEED_OPTIONS;
  }

  private closeSpeedMenu(): void {
    this.showSpeedMenu = false;
  }

  /** 关闭播放队列半模态 */
  private closePlaylistSheet(): void {
    this.showPlaylistSheet = false;
  }

  private refreshSpeedLabel(): void {
    const rate = this.avPlayerController.getSpeed();
    const options = this.getSpeedOptions();
    for (let i = 0; i < options.length; i++) {
      if (Math.abs(options[i].speed - rate) < 0.01) {
        this.speedLabel = options[i].label;
        return;
      }
    }
    this.speedLabel = `${rate.toFixed(1)}X`;
  }

  private getLoopModeIcon(mode: AudioLoopMode = this.audioLoopMode): Resource {
    switch (mode) {
      case AudioLoopMode.LIST:
        return Constants.APP_BAR_ICON_REPEAT_LIST;
      case AudioLoopMode.SINGLE:
        return Constants.APP_BAR_ICON_REPEAT_ONE;
      case AudioLoopMode.RANDOM:
        return Constants.APP_BAR_ICON_SHUFFLE;
      default:
        return Constants.APP_BAR_ICON_REPEAT_OFF;
    }
  }

  /** 同步 @State 循环模式图标，确保点击后 SymbolGlyph 立即刷新 */
  private updateLoopModeIcon(): void {
    this.loopModeIcon = this.getLoopModeIcon(this.audioLoopMode);
  }

  /**
   * 获取播放模式 Toast 文案
   *
   * @param mode 当前播放模式
   * @returns 模式名称资源
   */
  private getLoopModeToastMessage(mode: AudioLoopMode): Resource {
    switch (mode) {
      case AudioLoopMode.SINGLE:
        return $r('app.string.player_mode_single_loop');
      case AudioLoopMode.RANDOM:
        return $r('app.string.player_mode_shuffle');
      case AudioLoopMode.LIST:
        return $r('app.string.player_mode_list_loop');
      default:
        return $r('app.string.player_mode_list_loop');
    }
  }

  /** 切换播放模式后弹出当前模式提示 */
  private showLoopModeToast(mode: AudioLoopMode): void {
    try {
      promptAction.showToast({
        message: this.getLoopModeToastMessage(mode),
        duration: PlayerUiConstants.LOOP_MODE_TOAST_DURATION_MS
      });
    } catch (error) {
      const errMsg = error instanceof Error ? error.message : String(error);
      HiLog.w(TAG, `showLoopModeToast failed message=${errMsg}`);
    }
  }

  private cycleLoopMode(): void {
    HiLog.i(TAG, `loopModeButton clicked current=${this.audioLoopMode}`);
    this.audioLoopMode = this.avPlayerController.cycleAudioLoopMode();
    this.updateLoopModeIcon();
    HiLog.i(TAG, `loopModeButton switched mode=${this.audioLoopMode}`);
    this.showLoopModeToast(this.audioLoopMode);
  }

  /** 进度已播放段颜色：音频白色，视频蓝色 */
  private getAccentColor(): ResourceColor {
    if (this.isAudio) {
      return $r('app.color.player_progress_selected');
    }
    return $r('app.color.player_accent_blue');
  }

  /** 滑块圆点颜色：音频白色，视频白色（与蓝进度对比） */
  private getBlockColor(): ResourceColor {
    return $r('app.color.player_progress_selected');
  }

  private getTitleTextColor(): ResourceColor {
    return $r('app.color.player_title_text');
  }

  /** 辅助按钮底色：设计稿为透明，仅中心播放键使用白底圆 */
  private getPlayStyleButtonBackground(): ResourceColor {
    return $r('app.color.player_icon_button_bg');
  }

  private getPlayStyleButtonIconColor(): ResourceColor {
    return $r('app.color.player_control_icon');
  }

  private getSpeedChipBackground(): ResourceColor {
    return $r('app.color.player_speed_chip_bg');
  }

  /** 音频面板已限宽 90%，内边距为 0；视频仍用 CONTENT_PADDING_H */
  private getContentPaddingH(): number {
    return this.isAudio ? PlayerUiConstants.AUDIO_CONTENT_PADDING_H : PlayerUiConstants.CONTENT_PADDING_H;
  }

  /** 音频标题：去掉扩展名，优先解析「歌名 - 歌手」中的歌名 */
  private getAudioDisplayTitle(): string {
    const parsed = PlayerMediaTitleUtil.parseFromFileName(this.fileInfo?.fileName ?? '');
    if (parsed.title.length > 0) {
      return parsed.title;
    }
    return this.fileInfo?.fileName ?? '';
  }

  /**
   * 按文件大小与时长估算码率（bps），供音频元信息展示。
   *
   * @returns 估算码率，无法估算时为 0
   */
  private estimateAudioBitrateBps(): number {
    const fileSize = this.fileInfo?.fileSize ?? 0;
    const durationMs = this.fileInfo?.duration ?? 0;
    if (fileSize <= 0 || durationMs <= 0) {
      return 0;
    }
    return Math.round(fileSize * 8000 / durationMs);
  }

  private getProgressTimeTextColor(): ResourceColor {
    if (this.type === 'video' && this.isVideoFullscreen) {
      return $r('app.color.player_progress_time_text');
    }
    return $r('app.color.player_text_secondary');
  }

  private getTimeTextColor(): ResourceColor {
    return $r('app.color.player_text_secondary');
  }

  private getTrackColor(): ResourceColor {
    return $r('app.color.player_progress_track');
  }

  private onSpeedSelected(option: SpeedOptionItem): void {
    this.avPlayerController.setSpeed(option.speed);
    this.speedLabel = option.label;
    this.closeSpeedMenu();
  }

  private buildVideoMetaText(): string {
    const fileSize = this.fileInfo?.fileSize ?? 0;
    const sizeText = MediaFormatUtil.formatFileSizeDecimal(fileSize);
    const height = this.fileInfo?.picHeight ?? 0;
    let resolution = '';
    if (height >= 1080) {
      resolution = '1080P';
    } else if (height >= 720) {
      resolution = '720P';
    } else if (height > 0) {
      resolution = `${this.fileInfo?.picWidth ?? 0}x${height}`;
    }
    const parts: string[] = [this.getString($r('app.string.player_media_type_video')), sizeText];
    if (resolution.length > 0) {
      parts.push(resolution);
    }
    if (this.videoFrameRate > 0) {
      parts.push(`${Math.round(this.videoFrameRate)}fps`);
    }
    return parts.join(' · ');
  }

  private buildAudioMetaText(): string {
    const fileSize = this.fileInfo?.fileSize ?? 0;
    const sizeText = MediaFormatUtil.formatFileSizeDecimal(fileSize);
    const bitrateText = MediaFormatUtil.formatBitrate(this.estimateAudioBitrateBps());
    return `${this.getString($r('app.string.player_media_type_audio'))} · ${sizeText} · ${bitrateText}`;
  }

  /**
   * Apply video mute volume to the same target used by video gestures, then refresh page state.
   *
   * @param volume target volume in 0..1
   */
  private applyVideoMuteVolume(volume: number): void {
    const safeVolume = Math.max(PlayConstants.MIN_VALUE, Math.min(PlayConstants.MAX_VALUE, volume));
    this.avPlayerController.updatePageVolume(safeVolume, safeVolume / PlayConstants.MAX_AUDIO_LEVEL);
    this.avPlayerController.setVolume(safeVolume);
    if (!this.isPCConfig) {
      this.avPlayerController.setSystemVolume(safeVolume);
    }
    HiLog.i(TAG, `applyVideoMuteVolume volume:${safeVolume} isPC:${this.isPCConfig}`);
  }

  private toggleMute(): void {
    if (this.isMuted) {
      this.isMuted = false;
      const restoreVolume = this.volumeBeforeMute > 0 ?
        this.volumeBeforeMute : PlayConstants.PLAY_PAGE_DEFAULT_VOLUME;
      if (this.isAudio) {
        this.avPlayerController.setVolume(restoreVolume);
      } else {
        this.applyVideoMuteVolume(restoreVolume);
      }
      HiLog.i(TAG, `unmute, restore avPlayer volume: ${restoreVolume}`);
    } else {
      this.volumeBeforeMute = this.isAudio ? this.avPlayerController.getPlayerVolume() : this.volumePercentage;
      if (this.volumeBeforeMute <= 0) {
        this.volumeBeforeMute = PlayConstants.PLAY_PAGE_DEFAULT_VOLUME;
      }
      this.isMuted = true;
      if (this.isAudio) {
        this.avPlayerController.setVolume(0);
      } else {
        this.applyVideoMuteVolume(PlayConstants.PLAY_PAGE_SILENT);
      }
      HiLog.i(TAG, `mute, saved avPlayer volume: ${this.volumeBeforeMute}`);
    }
    this.syncVolumeButtonIcon();
  }

  private async handlePlayPauseClick(): Promise<void> {
    try {
      await this.avPlayerController.switchPlayOrPause();
      this.updatePlayIcon(this.avPlayerController.getPlayState());
    } catch (err) {
      HiLog.e(TAG, `handlePlayPauseClick error,${err?.message}`);
    }
  }

  @Builder
  AudioFileInfoSection() {
    Column({ space: 4 }) {
      Text(this.getAudioDisplayTitle())
        .fontSize(PlayerUiConstants.TITLE_FONT_SIZE)
        .fontColor(this.getTitleTextColor())
        .fontWeight(FontWeight.Bold)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(this.buildAudioMetaText())
        .fontSize(PlayerUiConstants.META_FONT_SIZE)
        .fontColor(this.getTimeTextColor())
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding({
      left: this.getContentPaddingH(),
      right: this.getContentPaddingH(),
      top: 0,
      bottom: PlayerUiConstants.FILE_INFO_BOTTOM_GAP,
    })
  }

  @Builder
  VideoFileInfoSection() {
    Column({ space: 4 }) {
      Text(this.fileInfo?.fileName ?? '')
        .fontSize(PlayerUiConstants.TITLE_FONT_SIZE)
        .fontColor(this.getTitleTextColor())
        .fontWeight(FontWeight.Medium)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(this.buildVideoMetaText())
        .fontSize(PlayerUiConstants.META_FONT_SIZE)
        .fontColor(this.getTimeTextColor())
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding({
      left: this.getContentPaddingH(),
      right: this.getContentPaddingH(),
      top: 8,
      bottom: PlayerUiConstants.FILE_INFO_BOTTOM_GAP,
    })
  }

  /** 进度条 + 时间：横屏视频为「时间 | 滑条 | 总时长」横向布局，其余纵向 */
  @Builder
  ProgressSliderRow() {
    if (this.isVideoFullscreen) {
      this.LandscapeVideoProgressSection()
    } else {
      this.MediaProgressSection()
    }
  }

  @Builder
  ProgressSliderControl() {
    Slider({
      value: $$this.progressVal,
      min: 0,
      max: 100,
      step: PlayConstants.PLAY_PROGRESS_STEP,
      style: SliderStyle.OutSet
    })
      .blockColor(this.getBlockColor())
      .trackColor(this.getTrackColor())
      .selectedColor(this.getAccentColor())
      .layoutWeight(1)
      .showSteps(false)
      .onChange((value: number, mode: SliderChangeMode) => {
        this.avPlayerController.seekTime(value, mode, this.isAudio);
        if (mode !== SliderChangeMode.Click) {
          this.avPlayerController.setIsMovingProgressSlider(mode !== SliderChangeMode.End);
        }
      })
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          this.avPlayerController.setIsMovingProgressSlider(true);
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.avPlayerController.setIsMovingProgressSlider(false);
        }
      })
  }

  /** 横屏视频进度：当前时间 — 滑条 — 总时长（同一行） */
  @Builder
  LandscapeVideoProgressSection() {
    Row({ space: 10 }) {
      Text(this.currentTime)
        .fontSize(PlayerUiConstants.TIME_FONT_SIZE)
        .fontColor(this.getProgressTimeTextColor())

      this.ProgressSliderControl()

      Text(this.totalTime)
        .fontSize(PlayerUiConstants.TIME_FONT_SIZE)
        .fontColor(this.getProgressTimeTextColor())
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ left: this.getContentPaddingH(), right: this.getContentPaddingH() })
  }

  @Builder
  MediaProgressSection() {
    Column({ space: PlayerUiConstants.PROGRESS_TIME_GAP }) {
      Slider({
        value: $$this.progressVal,
        min: 0,
        max: 100,
        step: PlayConstants.PLAY_PROGRESS_STEP,
        style: SliderStyle.OutSet
      })
        .blockColor(this.getBlockColor())
        .trackColor(this.getTrackColor())
        .selectedColor(this.getAccentColor())
        .width('100%')
        .showSteps(false)
        .onChange((value: number, mode: SliderChangeMode) => {
          this.avPlayerController.seekTime(value, mode, this.isAudio);
          if (mode !== SliderChangeMode.Click) {
            this.avPlayerController.setIsMovingProgressSlider(mode !== SliderChangeMode.End);
          }
        })
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down) {
            this.avPlayerController.setIsMovingProgressSlider(true);
          } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
            this.avPlayerController.setIsMovingProgressSlider(false);
          }
        })

      Row() {
        Text(this.currentTime)
          .fontSize(PlayerUiConstants.TIME_FONT_SIZE)
          .fontColor(this.getProgressTimeTextColor())

        Blank()

        Text(this.totalTime)
          .fontSize(PlayerUiConstants.TIME_FONT_SIZE)
          .fontColor(this.getProgressTimeTextColor())
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: this.getContentPaddingH(), right: this.getContentPaddingH() })
  }

  /** 主播放 / 暂停：音频与竖屏视频为白底圆钮；横屏视频为白色图标（无白底圆） */
  @Builder
  PlayPauseButton() {
    if (this.isVideoFullscreen) {
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph(this.playIcon)
          .fontSize(PlayerUiConstants.PLAY_ICON_SIZE + 4)
          .fontWeight(FontWeight.Medium)
          .fontColor([$r('app.color.player_control_icon')])
      }
      .backgroundColor($r('sys.color.ohos_id_color_background_transparent'))
      .width(PlayerUiConstants.PLAY_BUTTON_SIZE)
      .height(PlayerUiConstants.PLAY_BUTTON_SIZE)
      .key(`play_pause_fs_${this.playState}`)
      .onClick(() => {
        this.handlePlayPauseClick();
      })
    } else {
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph(this.playIcon)
          .fontSize(PlayerUiConstants.PLAY_ICON_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor([$r('app.color.player_play_button_icon')])
      }
      .backgroundColor($r('app.color.player_play_button_bg'))
      .width(PlayerUiConstants.PLAY_BUTTON_SIZE)
      .height(PlayerUiConstants.PLAY_BUTTON_SIZE)
      .key(`play_pause_${this.playState}`)
      .shadow({
        radius: PlayerUiConstants.PLAY_BUTTON_SHADOW_RADIUS,
        color: PlayerUiConstants.PLAY_BUTTON_SHADOW_COLOR,
        offsetX: 0,
        offsetY: PlayerUiConstants.PLAY_BUTTON_SHADOW_OFFSET_Y
      })
      .onClick(() => {
        this.handlePlayPauseClick();
      })
    }
  }

  /** 音频播放模式按钮：单曲循环 / 随机 / 列表循环 */
  @Builder
  LoopModeButton() {
    Button() {
      SymbolGlyph(this.loopModeIcon)
        .fontSize(PlayerUiConstants.ACCESSORY_ICON_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor([this.getPlayStyleButtonIconColor()])
    }
    .type(ButtonType.Circle)
    .backgroundColor(this.getPlayStyleButtonBackground())
    .width(PlayerUiConstants.ACCESSORY_BUTTON_SIZE)
    .height(PlayerUiConstants.ACCESSORY_BUTTON_SIZE)
    .key(`loop_mode_${this.audioLoopMode}`)
    .onClick(() => {
      HiLog.i(TAG, 'loopModeButton clicked');
      this.cycleLoopMode();
    })
  }

  /** 左侧辅助按钮：循环 / 音量 */
  @Builder
  AccessoryButton(icon: Resource, onClick: () => void) {
    Button() {
      SymbolGlyph(icon)
        .fontSize(PlayerUiConstants.ACCESSORY_ICON_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor([this.getPlayStyleButtonIconColor()])
    }
    .type(ButtonType.Circle)
    .backgroundColor(this.getPlayStyleButtonBackground())
    .width(PlayerUiConstants.ACCESSORY_BUTTON_SIZE)
    .height(PlayerUiConstants.ACCESSORY_BUTTON_SIZE)
    .onClick(onClick)
  }

  /** 切歌按钮：上一首 / 下一首 */
  @Builder
  SkipButton(icon: Resource, onClick: () => void) {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph(icon)
        .fontSize(PlayerUiConstants.SKIP_ICON_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor([this.getPlayStyleButtonIconColor()])
    }
    .type(ButtonType.Circle)
    .backgroundColor(this.getPlayStyleButtonBackground())
    .width(PlayerUiConstants.SKIP_BUTTON_SIZE)
    .height(PlayerUiConstants.SKIP_BUTTON_SIZE)
    .onClick(onClick)
  }

  /** 视频右侧控制区：横屏为音量+倍速，竖屏仅倍速；不参与压缩 */
  @Builder
  VideoRightControlCluster() {
    Row({ space: PlayerUiConstants.RIGHT_CONTROL_GAP }) {
      if (this.isVideoFullscreen) {
        this.VolumeMuteButton()
      }
      this.SpeedButton()
    }
    .alignItems(VerticalAlign.Center)
    .flexShrink(0)
  }

  @Builder
  VolumeMuteButton() {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph(this.volumeButtonIcon)
        .fontSize(PlayerUiConstants.ACCESSORY_ICON_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor([this.getPlayStyleButtonIconColor()])
    }
    .type(ButtonType.Circle)
    .backgroundColor(this.getPlayStyleButtonBackground())
    .width(PlayerUiConstants.ACCESSORY_BUTTON_SIZE)
    .height(PlayerUiConstants.ACCESSORY_BUTTON_SIZE)
    .key(`volume_mute_${this.isMuted}`)
    .onClick(() => {
      HiLog.i(TAG, 'volumeMuteButton clicked');
      this.toggleMute();
    })
  }

  /** 倍速弹层内容（bindPopup 自定义面板，深色毛玻璃） */
  @Builder
  SpeedMenuPopup() {
    PlayerSpeedMenuPanel({
      currentSpeedLabel: this.speedLabel,
      options: this.getSpeedOptions(),
      onSelect: (option: SpeedOptionItem) => {
        this.onSpeedSelected(option);
      }
    })
  }

  /** 倍速按钮文案：音频显示当前倍率，视频显示「倍速」 */
  private getSpeedButtonLabel(): ResourceStr {
    if (this.isAudio) {
      return this.speedLabel;
    }
    return $r('app.string.speed');
  }

  /** 倍速文字按钮（无胶囊底色，贴合设计稿） */
  @Builder
  SpeedButton() {
    Button({ type: ButtonType.Normal }) {
      Text(this.getSpeedButtonLabel())
        .fontSize(this.isAudio ? 16 : PlayerUiConstants.SPEED_FONT_SIZE + 2)
        .fontColor(this.getPlayStyleButtonIconColor())
        .fontWeight(FontWeight.Medium)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .textAlign(TextAlign.Center)
    }
    .backgroundColor(this.getSpeedChipBackground())
    .constraintSize({ minWidth: PlayerUiConstants.SPEED_CHIP_WIDTH })
    .height(PlayerUiConstants.SPEED_CHIP_HEIGHT)
    .padding({ left: PlayerUiConstants.SPEED_CHIP_PADDING_H, right: PlayerUiConstants.SPEED_CHIP_PADDING_H })
    .borderRadius(PlayerUiConstants.SPEED_CHIP_RADIUS)
    .bindPopup($$this.showSpeedMenu, {
      builder: (): void => {
        this.SpeedMenuPopup();
      },
      placement: Placement.Top,
      popupColor: $r('sys.color.ohos_id_color_background_transparent'),
      enableArrow: false,
      mask: true,
      maskColor: PlayerUiConstants.SPEED_MENU_MASK_COLOR,
      onStateChange: (event: SpeedMenuPopupStateEvent) => {
        if (!event.isVisible) {
          this.closeSpeedMenu();
        }
      }
    })
    .onClick(() => {
      this.showSpeedMenu = true;
    })
  }

  /** 播放列表按钮：点击拉起半模态 */
  @Builder
  PlaylistButton() {
    Button() {
      SymbolGlyph(Constants.APP_BAR_ICON_PLAYLIST)
        .fontSize(PlayerUiConstants.ACCESSORY_ICON_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor([this.getPlayStyleButtonIconColor()])
    }
    .type(ButtonType.Normal)
    .backgroundColor(this.getPlayStyleButtonBackground())
    .width(PlayerUiConstants.ACCESSORY_BUTTON_SIZE)
    .height(PlayerUiConstants.ACCESSORY_BUTTON_SIZE)
    .borderRadius(PlayerUiConstants.ACCESSORY_BUTTON_SIZE / 2)
    .bindSheet($$this.showPlaylistSheet, this.PlaylistSheetPanel(), {
      height: SheetSize.MEDIUM,
      dragBar: true,
      showClose: false,
      backgroundColor: PlaybackQueueSheetConstants.SHEET_ROOT_BACKGROUND,
      maskColor: PlaybackQueueSheetConstants.resolveMaskColor(),
      onDisappear: () => {
        this.closePlaylistSheet();
      }
    })
    .onClick(() => {
      HiLog.i(TAG, 'openPlaylistSheet');
      this.playlistSheetTab = PlaybackQueueSheetTab.CURRENT;
      this.showPlaylistSheet = true;
    })
  }

  /** 播放队列半模态面板 */
  @Builder
  PlaylistSheetPanel() {
    PlaybackQueueSheetPanel({
      activeTab: $playlistSheetTab,
      isAudio: this.isAudio,
      avPlayerController: this.avPlayerController,
      onRestoreHistoryPlayback: this.onRestoreHistoryPlayback,
      onAudioQueueEmpty: this.onAudioQueueEmpty,
      onDismiss: () => {
        this.closePlaylistSheet();
      }
    })
  }

  /** 右侧：倍速 + 播放列表 */
  @Builder
  RightControlCluster() {
    Row({ space: PlayerUiConstants.RIGHT_CONTROL_GAP }) {
      this.SpeedButton()
      this.PlaylistButton()
    }
    .alignItems(VerticalAlign.Center)
  }

  /** 视频 ±15 秒按钮 */
  @Builder
  SeekButton(icon: Resource, onClick: () => void) {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph(icon)
        .fontSize(PlayerUiConstants.SEEK_ICON_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor([this.getPlayStyleButtonIconColor()])
    }
    .type(ButtonType.Circle)
    .backgroundColor(this.getPlayStyleButtonBackground())
    .width(PlayerUiConstants.SEEK_BUTTON_SIZE)
    .height(PlayerUiConstants.SEEK_BUTTON_SIZE)
    .onClick(onClick)
  }

  /** 核心播控：上一首 / 播放 / 下一首（竖屏绝对居中） */
  @Builder
  CoreTransportCluster() {
    Row({ space: PlayerUiConstants.VIDEO_TRANSPORT_CLUSTER_GAP }) {
      this.SkipButton(Constants.APP_BAR_ICON_SKIP_PREVIOUS, () => {
        this.avPlayerController.skipToPreviousTrack();
      })

      this.PlayPauseButton()

      this.SkipButton(Constants.APP_BAR_ICON_SKIP_NEXT, () => {
        this.avPlayerController.skipToNextTrack();
      })
    }
    .alignItems(VerticalAlign.Center)
    .flexShrink(0)
  }

  /** 完整 transport：音频为上一首/播放/下一首；视频额外含 ±15 秒；不参与压缩以免重叠 */
  @Builder
  TransportCluster() {
    Row({
      space: this.isAudio ? PlayerUiConstants.TRANSPORT_CLUSTER_GAP : PlayerUiConstants.VIDEO_TRANSPORT_CLUSTER_GAP
    }) {
      if (!this.isAudio) {
        this.SeekButton(Constants.APP_BAR_ICON_GO_BACKWARD_15, () => {
          this.avPlayerController.skipBackward15Seconds();
        })
      }

      this.SkipButton(Constants.APP_BAR_ICON_SKIP_PREVIOUS, () => {
        this.avPlayerController.skipToPreviousTrack();
      })

      this.PlayPauseButton()

      this.SkipButton(Constants.APP_BAR_ICON_SKIP_NEXT, () => {
        this.avPlayerController.skipToNextTrack();
      })

      if (!this.isAudio) {
        this.SeekButton(Constants.APP_BAR_ICON_GO_FORWARD_15, () => {
          this.avPlayerController.skipForward15Seconds();
        })
      }
    }
    .alignItems(VerticalAlign.Center)
    .flexShrink(0)
  }

  @Builder
  AudioControlRow() {
    Stack({ alignContent: Alignment.Center }) {
      Row() {
        this.LoopModeButton()
        Blank()
        this.RightControlCluster()
      }
      .width('100%')
      .padding({ left: this.getContentPaddingH(), right: this.getContentPaddingH() })
      .alignItems(VerticalAlign.Center)

      this.TransportCluster()
    }
    .width('100%')
    .height(PlayerUiConstants.PLAY_BUTTON_SIZE)
    .margin({ top: PlayerUiConstants.CONTROL_ROW_TOP_MARGIN })
  }

  /**
   * 竖屏：上一首/播放/下一首居中入流；左音量/-15 与右 +15/倍速等宽镜像（Start/End + 同间距）。
   * 横屏：完整播控簇 + Blank + 音量/倍速，flexShrink(0) 防压缩重叠。
   */
  @Builder
  VideoControlRow() {
    if (this.isVideoFullscreen) {
      Row() {
        this.TransportCluster()

        Blank()
          .layoutWeight(1)

        this.VideoRightControlCluster()
      }
      .width('100%')
      .padding({ left: this.getContentPaddingH(), right: this.getContentPaddingH() })
      .alignItems(VerticalAlign.Center)
      .margin({ top: PlayerUiConstants.CONTROL_ROW_TOP_MARGIN })
    } else {
      // 竖屏：两侧 layoutWeight 等宽，左贴左、右贴右，中间播控自然居中，左右镜像对齐
      Row() {
        Row({ space: PlayerUiConstants.VIDEO_TRANSPORT_CLUSTER_GAP }) {
          this.VolumeMuteButton()
          this.SeekButton(Constants.APP_BAR_ICON_GO_BACKWARD_15, () => {
            this.avPlayerController.skipBackward15Seconds();
          })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Start)
        .alignItems(VerticalAlign.Center)
        .padding({ right: PlayerUiConstants.VIDEO_TRANSPORT_CLUSTER_GAP })

        this.CoreTransportCluster()

        Row({ space: PlayerUiConstants.VIDEO_TRANSPORT_CLUSTER_GAP }) {
          this.SeekButton(Constants.APP_BAR_ICON_GO_FORWARD_15, () => {
            this.avPlayerController.skipForward15Seconds();
          })
          this.SpeedButton()
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.End)
        .alignItems(VerticalAlign.Center)
        .padding({ left: PlayerUiConstants.VIDEO_TRANSPORT_CLUSTER_GAP })
      }
      .width('100%')
      .height(PlayerUiConstants.PLAY_BUTTON_SIZE)
      .padding({ left: this.getContentPaddingH(), right: this.getContentPaddingH() })
      .alignItems(VerticalAlign.Center)
      .margin({ top: PlayerUiConstants.CONTROL_ROW_TOP_MARGIN })
    }
  }

  build() {
    Column() {
      if (this.isAudio) {
        this.AudioFileInfoSection()
      } else if (this.isPortraitVideoPanel) {
        this.VideoFileInfoSection()
      }

      this.ProgressSliderRow()

      if (this.isAudio) {
        this.AudioControlRow()
      } else {
        this.VideoControlRow()
      }
    }
    .width('100%')
    .padding({ bottom: PlayerUiConstants.PANEL_BOTTOM_PADDING })
  }
}
