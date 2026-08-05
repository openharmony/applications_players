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

import { image } from '@kit.ImageKit';
import { promptAction, window } from '@kit.ArkUI';

import { HiLog } from '@ohos/common';
import common from '@ohos.app.ability.common';
import wantAgent, { WantAgent } from '@ohos.app.ability.wantAgent';
import { BusinessError } from '@ohos.base';
import { Constants, LoadingStatus, SPEED_MAP, ShortKey, ViewFileType, WindowType } from '@ohos/common/src/main/ets/constants/ui/Constants';
import { OperationPath } from '@ohos/common/src/main/ets/constants/system/EventName';
import { AudioLoopMode, AVPLAYER_LOADING_STATE, AVPLAYER_PREPARED_STATE, PlayConstants } from '@ohos/common/src/main/ets/constants/player/PlayConstants';
import { LocalStorageParam } from '@ohos/common/src/main/ets/constants/storage/StorageParam';
import FileInfo from '@ohos/common/src/main/ets/model/FileInfo';
import ToolbarItem from '@ohos/common/src/main/ets/model/ToolbarItem';
import VideoInformation from '@ohos/common/src/main/ets/model/VideoInformation';
import { AvPlayerToPlayingEvent } from '@ohos/common/src/main/ets/player/Events';
import { PlaybackMediaKind, PlaybackQueueManager, SkipPreviousResult } from '@ohos/common/src/main/ets/player/PlaybackQueueManager';
import { PlaybackResumeContext } from '@ohos/common/src/main/ets/player/PlaybackResumeContext';
import { PlaylistPlaybackResumeManager } from '@ohos/common/src/main/ets/persistence/preferences/PlaylistPlaybackResumeManager';
import { appLocalStorage } from '@ohos/common/src/main/ets/storage/AppLocalStorage';
import DateFormatUtil from '@ohos/common/src/main/ets/utils/DateFormatUtil';
import DeviceConfigUtil from '@ohos/common/src/main/ets/utils/DeviceConfigUtil';
import WindowUtil from '@ohos/common/src/main/ets/utils/WindowUtil';
import fs from '@ohos.file.fs';
import audio from '@ohos.multimedia.audio';
import AVSessionManager from '@ohos.multimedia.avsession';
import media from '@ohos.multimedia.media';
import backgroundTaskManager from '@ohos.resourceschedule.backgroundTaskManager';

import { PlayerMediaTitleUtil } from '../utils/PlayerMediaTitleUtil';
import { AvPlayerPlaybackControlHandler } from '../session/AvPlayerPlaybackControlHandler';
import { CallInterruptState } from '../session/CallInterruptState';
import { PlaybackControlCenterBridge, PlaybackControlLaunchOptions } from '../session/PlaybackControlCenterBridge';

let TAG = 'AVPlayerController'

export class AVPlayerController {
  playState: number = PlayConstants.STATUS_PAUSE;
  progressPlayState: number = PlayConstants.STATUS_PAUSE;
  public isProgressFocus: boolean = false;
  public isProgressVisible: boolean = true;
  protected avPlayer: media.AVPlayer | null = null;
  protected playProgress: Record<string, Object> | null = null;
  protected playPage: Record<string, Object> | null = null;
  protected url: string | null = null;
  protected fdSrc: number | null = null;
  protected volume: number = PlayConstants.PLAY_PAGE_DEFAULT_VOLUME;
  protected speed: number = PlayConstants.PLAY_PAGE_PLAY_SPEED;
  protected isLoop: boolean = false;
  protected audioLoopMode: AudioLoopMode = AudioLoopMode.LIST;
  protected isMovingVolumeSlider: boolean = false;
  protected isMovingProgressSlider: boolean = false;
  protected isLeftOrRightKeyDown: boolean = false;
  private isAudioPage: boolean = false;
  private saveFileInfo: FileInfo = new FileInfo('', '', '', 0, 0, 0, 0, 0);
  private isTabletConfig: boolean = DeviceConfigUtil.checkConfigForTablet();
  private isPcConfig: boolean = DeviceConfigUtil.checkConfigForPC();
  private sliderPlayEvent: number | null = null;
  private nowSeconds: number | null = null;
  private readonly audioControlBridge: PlaybackControlCenterBridge =
    new PlaybackControlCenterBridge(PlaybackMediaKind.AUDIO);
  private readonly videoControlBridge: PlaybackControlCenterBridge =
    new PlaybackControlCenterBridge(PlaybackMediaKind.VIDEO);
  private controlHandler: AvPlayerPlaybackControlHandler | undefined = undefined;
  private controlBridgesBound: boolean = false;
  protected currentTime: number = 0;
  protected localStorage: LocalStorage = appLocalStorage;
  private isActiveWindow: boolean = true;
  private isShownWindow: boolean = true;
  private isPcFullScreen: boolean = false;
  private isEnterVideoFullScene: boolean = false;
  private isSeekDone: boolean = true;
  /** 拖动进度条前是否在播，用于 seek 结束后恢复播放 */
  private wasPlayingBeforeSeek: boolean = false;
  /** 来电等系统中断前是否在播，用于挂断后自动恢复 */
  private interruptedWhilePlaying: boolean = false;
  /** 挂断后待执行的恢复（延迟/后台 defer，避免电话音频会话未释放时抢焦点失败） */
  private pendingInterruptResume: boolean = false;
  private interruptResumeTimerId: number = -1;
  private interruptResumeRetryCount: number = 0;
  /** 通话/焦点异常后 AudioRenderer 可能卡在 Illegal state，需重建而非对 paused 再 play */
  protected rendererNeedsRebuild: boolean = false;
  private playProgressWatchTimerId: number = -1;
  private playProgressWatchBaselineMs: number = 0;
  private static readonly INTERRUPT_RESUME_DELAY_MS: number = 1000;
  private static readonly INTERRUPT_RESUME_MAX_RETRY: number = 2;
  private static readonly PLAY_PROGRESS_WATCH_MS: number = 700;
  private lastProgressUpdateTime = 0;
  private lastUIExtensionStopTime = 0;
  /** 歌单续播落盘节流（毫秒） */
  private lastPlaylistResumeSaveAt: number = 0;
  private videoInformation: VideoInformation = new VideoInformation();
  private audioManager: audio.AudioManager | undefined = undefined;
  /** 切歌代际：快速连点时丢弃过期的 prepare/firstPlay */
  protected trackSwitchGeneration: number = 0;
  private audioVolumeManager: audio.AudioVolumeManager | undefined = undefined;
  /** 系统媒体最大音量（从 AudioVolumeGroupManager.getMaxVolume 获取），用于归一化 */
  private systemMaxVolume: number = 15;
  private showVolumeTimerId: number = 0;
  private below48Hz: boolean = false;
  public didAvPlayerCreate: boolean = false;
  /** release 与 createAVPlayer 并发时的代际，避免过期实例回写 */
  private avPlayerGeneration: number = 0;
  private avPlayerEnsurePromise: Promise<boolean> | null = null;
  private continuousTaskRunning: boolean = false;
  private isSetSystemVolume: boolean = false;
  private pagePlayStateUpdater?: (state: number) => void;
  private progressPlayStateListeners: ((state: number) => void)[] = [];
  private volumePanelUpdater?: (show: boolean) => void;
  protected volumePanelVisible: boolean = false;
  private pageVolumeUpdater?: (volume: number, volumePercentage: number) => void;
  private brightnessPanelUpdater?: (show: boolean) => void;
  protected brightnessPanelVisible: boolean = false;
  private pageBrightnessUpdater?: (bright: number) => void;
  /** 最近一次同步到页面的亮度，手势起点以此为准（避免 playPage.bright 与 @State 不同步） */
  protected lastPageBrightness: number = PlayConstants.PLAY_PAGE_DEFAULT_BRIGHTNESS;
  /** 最近一次同步到页面的音量百分比 */
  protected lastPageVolumePercentage: number = PlayConstants.PLAY_PAGE_DEFAULT_VOLUME;
  public operatePath: OperationPath = OperationPath.RIGHT_CLICK_MENU;
  public operationSource: number = SourceTool.MOUSE;

  constructor() {
    this.init();
  }

  private getString(resource: Resource): string {
    const context: Context = getContext(this);
    if (!context) {
      return '';
    }
    try {
      return context.resourceManager.getStringSync(resource);
    } catch (err) {
      const error = err as BusinessError;
      HiLog.w(TAG, `getString failed code=${error.code} message=${error.message}`);
      return '';
    }
  }

  isDialog(): boolean {
    if (!this.playPage) {
      return false;
    }
    return this.playPage.windowType === WindowType.DIALOG_WINDOW;
  }

  releaseResource(): void {
    if (this.fdSrc) {
      HiLog.i(TAG, 'Close fdSrc to release resource');
      this.windowCallBackOff();
      try {
        fs.closeSync(this.fdSrc);
        this.fdSrc = null;
        HiLog.i(TAG, 'success to close fd.');
      } catch (e) {
        HiLog.e(TAG, `failed to close fd, cause: ${JSON.stringify(e)}`);
      }
    }
    this.url = null;
  }

  setIsMovingVolumeSlider(flag: boolean): void {
    this.isMovingVolumeSlider = flag;
  }

  getIsMovingVolumeSlider(): boolean {
    return this.isMovingVolumeSlider;
  }

  setIsMovingProgressSlider(flag: boolean): void {
    this.isMovingProgressSlider = flag;
  }

  getIsMovingProgressSlider(): boolean {
    return this.isMovingProgressSlider;
  }

  setIsLeftOrRightKeyDown(flag: boolean): void {
    this.isLeftOrRightKeyDown = flag;
  }

  initPlayProgress(playProgress: Object): void {
    this.playProgress = playProgress as Record<string, Object>;
    this.syncBoundPlayProgress();
  }

  /**
   * 进度 UI 卸载时解绑，避免控制器继续写入已销毁组件
   *
   * @param playProgress 曾绑定的进度组件实例
   */
  detachPlayProgress(playProgress: Object): void {
    if (this.playProgress !== playProgress) {
      return;
    }
    HiLog.i(TAG, 'detachPlayProgress');
    this.playProgress = null;
  }

  /**
   * 新进度 UI 绑定时，将当前播放位置同步到进度条，避免从迷你条进入全屏页显示 00:00
   */
  private syncBoundPlayProgress(): void {
    if (this.playProgress === null) {
      return;
    }
    const avTime = this.avPlayer?.currentTime ?? 0;
    const syncTime = avTime > 0 ? avTime :
      (this.currentTime > 0 ? this.currentTime : this.lastProgressUpdateTime);
    if (syncTime <= 0) {
      return;
    }
    HiLog.i(TAG, `syncBoundPlayProgress time=${syncTime}`);
    this.initProgress(syncTime, true);
  }

  initPlayPage(playPage: Object): void {
    if (playPage === null) {
      return;
    }
    this.playPage = playPage as Record<string, Object>;
  }

  setPagePlayStateUpdater(updater: (state: number) => void): void {
    this.pagePlayStateUpdater = updater;
  }

  /**
   * 注册播放态监听（全屏进度条、迷你条封面等）
   *
   * @param listener 播放态变更回调
   */
  addProgressPlayStateListener(listener: (state: number) => void): void {
    if (this.progressPlayStateListeners.indexOf(listener) >= 0) {
      return;
    }
    this.progressPlayStateListeners.push(listener);
  }

  /**
   * 移除播放态监听
   *
   * @param listener 曾注册的回调
   */
  removeProgressPlayStateListener(listener: (state: number) => void): void {
    const index = this.progressPlayStateListeners.indexOf(listener);
    if (index >= 0) {
      this.progressPlayStateListeners.splice(index, 1);
    }
  }

  /** 通知所有进度相关 UI 播放态变更 */
  private notifyProgressPlayState(state: number): void {
    for (let i = 0; i < this.progressPlayStateListeners.length; i++) {
      this.progressPlayStateListeners[i](state);
    }
  }

  setVolumePanelUpdater(updater: (show: boolean) => void): void {
    this.volumePanelUpdater = updater;
  }

  setPageVolumeUpdater(updater: (volume: number, volumePercentage: number) => void): void {
    this.pageVolumeUpdater = updater;
  }

  /**
   * 注册亮度条显隐回调，由 Page 写入 @State 以驱动 ArkUI 刷新。
   *
   * @param updater 显隐回调
   */
  setBrightnessPanelUpdater(updater: (show: boolean) => void): void {
    this.brightnessPanelUpdater = updater;
  }

  /**
   * 注册亮度值回调，由 Page 写入 @State 以驱动手势亮度条刷新。
   *
   * @param updater 亮度回调
   */
  setPageBrightnessUpdater(updater: (bright: number) => void): void {
    this.pageBrightnessUpdater = updater;
  }

  updatePageVolume(volume: number, volumePercentage: number): void {
    this.lastPageVolumePercentage = volumePercentage;
    this.pageVolumeUpdater?.(volume, volumePercentage);
    if (this.playPage !== null) {
      this.playPage.volume = volume;
      this.playPage.volumePercentage = volumePercentage;
    }
  }

  /**
   * 同步页面亮度 @State 与 playPage 快照。
   *
   * @param bright 0~1 亮度
   */
  updatePageBrightness(bright: number): void {
    this.lastPageBrightness = bright;
    this.pageBrightnessUpdater?.(bright);
    if (this.playPage !== null) {
      this.playPage.bright = bright;
    }
  }

  toggleVolumePanel(): void {
    this.volumePanelVisible = !this.volumePanelVisible;
    if (this.volumePanelUpdater) {
      this.volumePanelUpdater(this.volumePanelVisible);
      return;
    }
    if (this.playPage !== null) {
      this.playPage.showVolumeProgress = this.volumePanelVisible;
    }
  }

  setVolumePanelVisible(show: boolean): void {
    this.volumePanelVisible = show;
    if (this.volumePanelUpdater) {
      this.volumePanelUpdater(show);
      return;
    }
    if (this.playPage !== null) {
      this.playPage.showVolumeProgress = show;
    }
  }

  /**
   * 显示或隐藏亮度手势条浮层。
   *
   * @param show 是否显示
   */
  setBrightnessPanelVisible(show: boolean): void {
    this.brightnessPanelVisible = show;
    if (this.brightnessPanelUpdater) {
      this.brightnessPanelUpdater(show);
      return;
    }
    if (this.playPage !== null) {
      this.playPage.showBrightnessProgress = show;
    }
  }

  setVolumeShow(volumeShow: boolean): void {
    if (this.playProgress === null) {
      return;
    }
    this.playProgress.volumeShow = volumeShow;
  }

  setAvPlayer(player: media.AVPlayer): void {
    this.avPlayer = player;
  }

  init(): void {
    HiLog.i(TAG, `Init`);
    void this.ensureAvPlayer();
  }

  /**
   * 确保 AVPlayer 存在：构造时首次创建，release 后惰性重建；并发调用合并为同一 Promise。
   */
  protected ensureAvPlayer(): Promise<boolean> {
    if (this.avPlayer !== null) {
      return Promise.resolve(true);
    }
    if (this.avPlayerEnsurePromise !== null) {
      return this.avPlayerEnsurePromise;
    }
    const generation = this.avPlayerGeneration;
    HiLog.i(TAG, `ensureAvPlayer create generation=${generation}`);
    this.avPlayerEnsurePromise = media.createAVPlayer().then((player) => {
      this.avPlayerEnsurePromise = null;
      this.didAvPlayerCreate = true;
      if (generation !== this.avPlayerGeneration) {
        HiLog.i(TAG, `ensureAvPlayer stale generation=${generation}, release orphan player`);
        if (player !== null) {
          void player.release();
        }
        return false;
      }
      if (player !== null) {
        HiLog.i(TAG, `success to createAVPlayer`);
        this.avPlayer = player;
        this.bindState();
        this.applyPendingAvPlayerSource();
        return true;
      }
      HiLog.e(TAG, `failed to createAVPlayer`);
      return false;
    }).catch((error: BusinessError) => {
      this.avPlayerEnsurePromise = null;
      this.didAvPlayerCreate = true;
      HiLog.e(TAG, `ensureAvPlayer failed message=${error.message}`);
      if (this.playPage !== null) {
        this.playPage.loadingStatus = LoadingStatus.LOAD_STATE_FAILED;
      }
      return false;
    });
    return this.avPlayerEnsurePromise;
  }

  /** AVPlayer 创建完成后应用已缓存的 fd 源（仅支持 fd://，不支持 file://media content URI） */
  protected applyPendingAvPlayerSource(): void {
    if (this.avPlayer === null || this.fdSrc === null) {
      return;
    }
    if (!this.isAvPlayerIdle()) {
      HiLog.e(TAG, `applyPendingAvPlayerSource skipped: state=${this.avPlayer.state} not idle`);
      return;
    }
    this.avPlayer.url = `fd://${this.fdSrc}`;
    HiLog.i(TAG, `applyPendingAvPlayerSource fd=${this.fdSrc}`);
  }

  /**
   * 销毁并惰性重建 AVPlayer（释放失败或非 idle 无法 reset 时自愈）。
   * 子类可重写以在重建后重绑 surface 等资源。
   */
  protected async recreateAvPlayer(): Promise<boolean> {
    HiLog.i(TAG, 'recreateAvPlayer');
    this.avPlayerGeneration++;
    this.unregisterListeners();
    if (this.avPlayer !== null) {
      try {
        await this.avPlayer.release();
      } catch (err) {
        const error = err as BusinessError;
        HiLog.e(TAG, `recreateAvPlayer release failed message=${error.message}`);
      }
      this.avPlayer = null;
    }
    return await this.ensureAvPlayer();
  }

  /** 当前 AVPlayer 是否为 idle（重建后需重新读 state，避免类型收窄） */
  protected isAvPlayerIdle(): boolean {
    return this.avPlayer !== null && this.avPlayer.state === 'idle';
  }

  /**
   * 保证 AVPlayer 处于 idle，方可 setFdSrc / set url。
   * stop+reset 失败或仍非 idle 时重建实例，避免 5400102 卡死。
   */
  protected async ensureIdleForSetSource(): Promise<boolean> {
    const ready = await this.ensureAvPlayer();
    if (!ready || this.avPlayer === null) {
      return false;
    }
    if (this.isAvPlayerIdle()) {
      return true;
    }
    const state = this.avPlayer.state;
    if (state === 'released' || state === 'error') {
      HiLog.w(TAG, `ensureIdleForSetSource recreate from state=${state}`);
      const recreated = await this.recreateAvPlayer();
      return recreated && this.isAvPlayerIdle();
    }
    try {
      if (state === 'playing' || state === 'paused' || state === 'completed' ||
        state === 'prepared' || state === 'stopped') {
        await this.avPlayer.stop();
      }
      if (this.avPlayer !== null && !this.isAvPlayerIdle() && this.avPlayer.state !== 'released') {
        await this.avPlayer.reset();
      }
    } catch (err) {
      const error = err as BusinessError;
      HiLog.e(TAG, `ensureIdleForSetSource stop/reset failed: ${error.message}`);
      const recreated = await this.recreateAvPlayer();
      return recreated && this.isAvPlayerIdle();
    }
    if (this.isAvPlayerIdle()) {
      return true;
    }
    const stuckState = this.avPlayer !== null ? this.avPlayer.state : 'null';
    HiLog.w(TAG, `ensureIdleForSetSource still state=${stuckState}, recreate`);
    const recreated = await this.recreateAvPlayer();
    return recreated && this.isAvPlayerIdle();
  }

  /**
   * 播放出错后重置 AVPlayer 与 fd，保留 playPage 供用户重试或关闭
   */
  protected async recoverAvPlayerAfterError(): Promise<void> {
    this.releaseResource();
    if (this.avPlayer === null) {
      return;
    }
    try {
      const state = this.avPlayer.state;
      if (state !== 'idle' && state !== 'released') {
        await this.avPlayer.reset();
      }
    } catch (err) {
      const error = err as BusinessError;
      HiLog.e(TAG, `recoverAvPlayerAfterError failed message=${error.message}`);
      await this.recreateAvPlayer();
    }
    this.syncPlayState(PlayConstants.STATUS_PAUSE);
  }

  setUrl(url: string): void {
    HiLog.i(TAG, `setUrl`);
    this.url = url;
  }

  setFdSrc(fdSrc: number): void {
    HiLog.i(TAG, `setFdSrc: ${String(fdSrc)}`);
    this.fdSrc = fdSrc;
    this.applyPendingAvPlayerSource();
  }

  setLoop(isLoop: boolean): void {
    HiLog.i(TAG, `setLoop: ${isLoop}`);
    if (this.avPlayer !== null) {
      this.isLoop = isLoop;
      this.avPlayer.loop = this.isLoop;
    }
  }

  setAudioLoopMode(mode: AudioLoopMode): void {
    this.audioLoopMode = mode;
    this.setLoop(mode === AudioLoopMode.SINGLE);
    HiLog.i(TAG, `setAudioLoopMode: ${mode}`);
  }

  getAudioLoopMode(): AudioLoopMode {
    return this.audioLoopMode;
  }

  cycleAudioLoopMode(): AudioLoopMode {
    const modes: AudioLoopMode[] = [AudioLoopMode.SINGLE, AudioLoopMode.RANDOM, AudioLoopMode.LIST];
    let currentIndex = -1;
    for (let i = 0; i < modes.length; i++) {
      if (modes[i] === this.audioLoopMode) {
        currentIndex = i;
        break;
      }
    }
    const nextIndex = (currentIndex + 1) % modes.length;
    this.setAudioLoopMode(modes[nextIndex]);
    return this.audioLoopMode;
  }

  setVolume(volume: number): void {
    if (!AVPLAYER_PREPARED_STATE.has(this.avPlayer?.state as string)) {
      HiLog.e(TAG, `setVolume, state is not prepared`);
      return;
    }
    HiLog.i(TAG, `setVolume: ${volume}`);
    this.volume = volume;
    this.avPlayer !== null && this.avPlayer.setVolume(this.volume);
  }

  /**
   * 将 PlaybackSpeed 枚举码或实际倍速解析为 setPlaybackRate 所需倍速。
   *
   * @param speed 枚举码（如 SPEED_FORWARD_3_00_X=7）实际倍速（3）
   * @returns setPlaybackRate 可用倍速
   */
  private resolvePlaybackRate(speed: number): number {
    return SPEED_MAP.get(speed) ?? speed;
  }

  setSpeed(speed: number): void {
    const playbackRate = this.resolvePlaybackRate(speed);
    HiLog.i(TAG, `setSpeed: ${speed} playbackRate=${playbackRate}`);
    this.speed = speed;
    if (this.avPlayer !== null && AVPLAYER_PREPARED_STATE.has(this.avPlayer.state as string)) {
      this.avPlayer.setPlaybackRate(playbackRate);
    } else {
      HiLog.w(TAG, `setSpeed skipped state=${this.avPlayer?.state} playbackRate=${playbackRate}`);
    }
    this.setPlayingTime(this.avPlayer?.currentTime ?? 0);
    this.setPlayingSpeed(playbackRate);
  }

  setProgressVisible(visible: boolean) {
    this.isProgressVisible = visible;
    if (this.currentTime < this.lastProgressUpdateTime ||
      this.currentTime > this.lastProgressUpdateTime + PlayConstants.TIME_UPDATE_MAX_INTERVAL) {
      HiLog.w(TAG, `time update back, lastTime:${this.lastProgressUpdateTime} time:${this.currentTime}`);
      return;
    }
    if (visible && this.playProgress) {
      this.initProgress(this.currentTime, true);
    }
  }

  getPlayState(): number {
    return this.playState;
  }

  /**
   * AVPlayer 是否处于 playing（比 playState 更可靠，用于队列竖条动画）
   *
   * @returns 是否正在播放
   */
  isMediaPlaying(): boolean {
    return this.avPlayer?.state === 'playing';
  }

  getPlayerVolume(): number {
    return this.volume;
  }

  getSpeed(): number {
    return this.speed;
  }

  isActive() {
    return this.isActiveWindow || this.isShownWindow;
  }

  /**
   * 是否允许视频在应用退后台时继续播放；默认禁止，画中画场景由子类开启。
   *
   * @returns 是否豁免后台暂停策略
   */
  protected allowVideoPlayOnBackground(): boolean {
    return false;
  }

  seekBack(needPlay: boolean) {
    HiLog.i(TAG, `seek back time:${this.lastUIExtensionStopTime} state:${this.avPlayer?.state}`);
    this.lastProgressUpdateTime = this.lastUIExtensionStopTime;
    this.avPlayer?.seek(this.lastUIExtensionStopTime, Constants.SEEK_CLOSEST);
    this.initProgress(this.lastUIExtensionStopTime, true);
    if (needPlay) {
      this.play();
    }
  }

  async play() {
    HiLog.i(TAG, `play, state:${this.avPlayer?.state} uniqueId:${this.playPage?.uniqueId} ` +
      `rebuild=${this.rendererNeedsRebuild}`);
    let isAppInBackground: boolean = this.localStorage?.get<boolean>(LocalStorageParam.APP_IN_BACKGROUND) ?? false;
    if (!this.isPcConfig && isAppInBackground && !this.isAudioPage && !this.allowVideoPlayOnBackground()) {
      HiLog.i(TAG, `appInBackground, no need play`);
      this.changePlayHoverTips();
      return;
    }
    if (CallInterruptState.isCallActive()) {
      HiLog.w(TAG, 'play deferred: phone call still active');
      this.pendingInterruptResume = true;
      this.changePlayHoverTips();
      return;
    }
    if (this.avPlayer === null) {
      const ready = await this.ensureAvPlayer();
      if (!ready || this.avPlayer === null) {
        HiLog.w(TAG, 'play aborted: avPlayer unavailable');
        this.changePlayHoverTips();
        return;
      }
      this.applyPendingAvPlayerSource();
    }
    if (this.avPlayer !== null && this.needsSourceRebindForPlay()) {
      HiLog.w(TAG, `play recovery: state=${this.avPlayer.state} fd=${this.fdSrc} rebuild=${this.rendererNeedsRebuild}`);
      const rebound = await this.rebindMediaSourceForRecovery(this.getPlaybackPositionMs());
      if (rebound) {
        // 重绑后走 initialized → prepared → play，避免对 error/idle/坏 renderer 裸 play
        this.armPlayProgressWatch();
        return;
      }
      HiLog.e(TAG, 'play recovery rebind failed');
      this.changePlayHoverTips();
      return;
    }
    if (this.avPlayer !== null && AVPLAYER_PREPARED_STATE.has(this.avPlayer.state)) {
      try {
        await this.avPlayer.play();
        this.armPlayProgressWatch();
      } catch (err) {
        HiLog.e(TAG, `avPlayer.play failed, err.code = ${err.code}, err.message = ${err.message}`);
        this.rendererNeedsRebuild = true;
        const rebound = await this.rebindMediaSourceForRecovery(this.getPlaybackPositionMs());
        if (rebound) {
          this.armPlayProgressWatch();
          return;
        }
      }
    } else if (this.avPlayer !== null) {
      this.prepare();
    } else {
      HiLog.w(TAG, 'play aborted: avPlayer is null after ensure');
      this.changePlayHoverTips();
      return;
    }
    this.syncPlayState(PlayConstants.STATUS_START);
    this.updatePlayButtonAccessibility(true);
  }

  /** error/无源/通话后 renderer 可疑时不可直接 play，需重绑媒体源 */
  private needsSourceRebindForPlay(): boolean {
    if (this.rendererNeedsRebuild) {
      return true;
    }
    if (this.avPlayer === null) {
      return false;
    }
    const state = this.avPlayer.state;
    if (state === 'error' || state === 'released') {
      return true;
    }
    if ((state === 'idle' || state === 'stopped') && this.fdSrc === null) {
      return true;
    }
    return false;
  }

  /** play 后若进度不前进，判定 AudioRenderer 已坏，强制重建 */
  private armPlayProgressWatch(): void {
    this.cancelPlayProgressWatch();
    this.playProgressWatchBaselineMs = this.getPlaybackPositionMs();
    this.playProgressWatchTimerId = setTimeout(() => {
      this.playProgressWatchTimerId = -1;
      this.onPlayProgressWatchFired();
    }, AVPlayerController.PLAY_PROGRESS_WATCH_MS);
  }

  private cancelPlayProgressWatch(): void {
    if (this.playProgressWatchTimerId >= 0) {
      clearTimeout(this.playProgressWatchTimerId);
      this.playProgressWatchTimerId = -1;
    }
  }

  private onPlayProgressWatchFired(): void {
    if (CallInterruptState.isCallActive()) {
      HiLog.i(TAG, 'playProgressWatch skip: call active');
      return;
    }
    if (this.playState !== PlayConstants.STATUS_START && this.avPlayer?.state !== 'playing') {
      return;
    }
    const nowMs = this.getPlaybackPositionMs();
    if (nowMs > this.playProgressWatchBaselineMs + 80 && this.avPlayer?.state === 'playing') {
      this.rendererNeedsRebuild = false;
      this.interruptResumeRetryCount = 0;
      return;
    }
    HiLog.w(TAG, `playProgressWatch stalled baseline=${this.playProgressWatchBaselineMs} now=${nowMs}, rebuild`);
    this.rendererNeedsRebuild = true;
    if (this.interruptResumeRetryCount >= AVPlayerController.INTERRUPT_RESUME_MAX_RETRY) {
      HiLog.e(TAG, 'playProgressWatch recovery exhausted');
      this.pendingInterruptResume = false;
      this.syncPlayState(PlayConstants.STATUS_PAUSE);
      this.changePlayHoverTips();
      return;
    }
    this.interruptResumeRetryCount++;
    this.pendingInterruptResume = true;
    void this.rebindMediaSourceForRecovery(this.getPlaybackPositionMs()).then((ok: boolean) => {
      if (!ok) {
        HiLog.e(TAG, 'playProgressWatch rebind failed');
        this.pendingInterruptResume = false;
        this.changePlayHoverTips();
        return;
      }
      this.armPlayProgressWatch();
    });
  }

  /**
   * 通话/焦点异常后重开媒体源。基类在 fd 仍有效时 reset+重绑；子类可重开文件。
   *
   * @param resumePositionMs 恢复播放位置
   * @returns 是否已启动重绑流程
   */
  protected async rebindMediaSourceForRecovery(resumePositionMs: number): Promise<boolean> {
    const forceRecreate = this.rendererNeedsRebuild;
    HiLog.i(TAG, `rebindMediaSourceForRecovery ms=${resumePositionMs} fd=${this.fdSrc} forceRecreate=${forceRecreate}`);
    if (resumePositionMs > 0) {
      PlaybackResumeContext.setPendingStartMs(resumePositionMs);
    }
    this.rendererNeedsRebuild = false;
    if (this.fdSrc === null) {
      return false;
    }
    let idle = false;
    if (forceRecreate) {
      idle = await this.recreateAvPlayer() && this.isAvPlayerIdle();
    } else {
      idle = await this.ensureIdleForSetSource();
    }
    if (!idle || this.avPlayer === null) {
      this.rendererNeedsRebuild = true;
      return false;
    }
    this.applyPendingAvPlayerSource();
    return this.fdSrc !== null;
  }

  private updatePlayButtonAccessibility(isPlaying: boolean): void {
    if (!this.playProgress || !this.playProgress.playButton) {
      return;
    }
    const context: Context = getContext(this);
    if (!context) {
      HiLog.w(TAG, 'context is undefined');
    }
    (this.playProgress.playButton as ToolbarItem).icon = isPlaying ?
      Constants.PLAYER_PROGRESS_ICON_PAUSE : Constants.PLAYER_PROGRESS_ICON_PLAY;
    (this.playProgress.playButton as ToolbarItem).title = context?.resourceManager.getStringSync(
      isPlaying ? $r('app.string.pause') : $r('app.string.play'));
    if (this.playProgress.windowType === WindowType.MAIN_WINDOW) {
      (this.playProgress.playButton as ToolbarItem).title += '(' + ShortKey.SPACE + ')';
    }
  }

  private changePlayHoverTips() {
    this.updatePlayButtonAccessibility(false);
  }

  pause(): void {
    HiLog.i(TAG, `pause`);
    this.cancelPendingInterruptResume();
    this.cancelPlayProgressWatch();
    this.savePlaylistResumeIfNeeded(true);
    this.avPlayer !== null && this.avPlayer.pause();
    this.syncPlayState(PlayConstants.STATUS_PAUSE);
    this.updatePlayButtonAccessibility(false);
  }

  /**
   * 来电等外部中断开始：暂停并记录状态（供通话状态监听兜底调用）。
   */
  public handlePhoneCallBegin(): void {
    HiLog.i(TAG, `handlePhoneCallBegin pending=${this.pendingInterruptResume} ` +
      `interrupted=${this.interruptedWhilePlaying}`);
    // 取消 audioInterrupt 过早 RESUME 排的恢复，等真正挂断再播
    this.cancelInterruptResumeTimer();
    this.cancelPlayProgressWatch();
    this.rendererNeedsRebuild = true;
    if (this.isActivelyPlaying()) {
      this.pauseForAudioInterrupt();
      return;
    }
    if (this.interruptedWhilePlaying || this.pendingInterruptResume ||
      this.playState === PlayConstants.STATUS_START) {
      this.interruptedWhilePlaying = true;
      this.pendingInterruptResume = false;
      this.interruptResumeRetryCount = 0;
      this.syncPlayState(PlayConstants.STATUS_PAUSE);
      this.updatePlayButtonAccessibility(false);
    }
  }

  /**
   * 来电结束：按场景自动恢复播放。
   */
  public handlePhoneCallEnd(): void {
    const isAppInBackground: boolean = this.localStorage?.get<boolean>(LocalStorageParam.APP_IN_BACKGROUND) ?? false;
    this.resumeAfterAudioInterrupt(isAppInBackground);
  }

  /**
   * 应用回到前台时补刷挂断后待恢复的播放（视频后台 defer 场景）。
   * 通话中断恢复必须走 CallGuard 延迟，禁止在此立即 play（易 Cannot find session）。
   */
  public flushPendingInterruptResume(): void {
    if (!this.pendingInterruptResume && !this.interruptedWhilePlaying) {
      return;
    }
    if (this.interruptedWhilePlaying || this.rendererNeedsRebuild) {
      HiLog.i(TAG, 'flushPendingInterruptResume skip: wait call/telephony delayed resume');
      return;
    }
    HiLog.i(TAG, 'flushPendingInterruptResume');
    this.scheduleInterruptResume(0);
  }

  /** 子类可扩展：中断暂停时（如来电）暂停画中画等 */
  protected notifyInterruptPaused(): void {
  }

  /** 子类可扩展：中断恢复后还原画中画等 */
  protected notifyInterruptResumed(): void {
  }

  private isActivelyPlaying(): boolean {
    return this.playState === PlayConstants.STATUS_START || this.avPlayer?.state === 'playing';
  }

  private applyShareInterruptMode(): void {
    if (this.avPlayer === null) {
      return;
    }
    const state = this.avPlayer.state;
    if (state !== 'prepared' && state !== 'playing' && state !== 'paused' && state !== 'completed') {
      HiLog.w(TAG, `applyShareInterruptMode skipped unsupported state=${state}`);
      return;
    }
    if (!this.isPcConfig || this.playPage?.isPADModeInTable) {
      this.avPlayer.audioInterruptMode = audio.InterruptMode.SHARE_MODE;
      HiLog.i(TAG, 'applyShareInterruptMode SHARE_MODE');
    }
  }

  private pauseForAudioInterrupt(): void {
    if (!this.isActivelyPlaying()) {
      return;
    }
    HiLog.i(TAG, 'pauseForAudioInterrupt');
    this.cancelInterruptResumeTimer();
    this.cancelPlayProgressWatch();
    this.interruptedWhilePlaying = true;
    this.pendingInterruptResume = false;
    this.interruptResumeRetryCount = 0;
    // 通话会改路由并可能打坏 AudioRenderer，恢复时强制重建
    this.rendererNeedsRebuild = true;
    this.notifyInterruptPaused();
    if (this.avPlayer !== null && this.avPlayer.state === 'playing') {
      this.avPlayer.pause();
      this.syncPlayState(PlayConstants.STATUS_PAUSE);
      this.updatePlayButtonAccessibility(false);
    } else {
      this.syncPlayState(PlayConstants.STATUS_PAUSE);
      this.updatePlayButtonAccessibility(false);
    }
  }

  private resumeAfterAudioInterrupt(isAppInBackground: boolean): void {
    if (!this.interruptedWhilePlaying && !this.pendingInterruptResume) {
      return;
    }
    HiLog.i(TAG, `resumeAfterAudioInterrupt isAppInBackground=${isAppInBackground} ` +
      `avState=${this.avPlayer?.state} callActive=${CallInterruptState.isCallActive()}`);
    this.interruptedWhilePlaying = false;
    this.pendingInterruptResume = true;
    this.notifyInterruptResumed();
    this.localStorage?.setOrCreate<boolean>('swiperVideo', undefined);

    // 通话未真正结束时（含 audioInterrupt 误报 RESUME），只挂起待恢复
    if (CallInterruptState.isCallActive()) {
      HiLog.i(TAG, 'resumeAfterAudioInterrupt deferred: call still active');
      return;
    }

    // 视频在后台禁止恢复，等回前台再 flush
    if (!this.isAudioPage && isAppInBackground && !this.allowVideoPlayOnBackground()) {
      HiLog.i(TAG, 'resumeAfterAudioInterrupt deferred until foreground');
      return;
    }
    // telephony 与 audioInterrupt 双通道：已在排队则不重置延迟
    if (this.interruptResumeTimerId >= 0) {
      HiLog.i(TAG, 'resumeAfterAudioInterrupt already scheduled');
      return;
    }
    this.scheduleInterruptResume(AVPlayerController.INTERRUPT_RESUME_DELAY_MS);
  }

  private cancelPendingInterruptResume(): void {
    this.cancelInterruptResumeTimer();
    this.cancelPlayProgressWatch();
    this.pendingInterruptResume = false;
    this.interruptedWhilePlaying = false;
    this.interruptResumeRetryCount = 0;
  }

  private cancelInterruptResumeTimer(): void {
    if (this.interruptResumeTimerId >= 0) {
      clearTimeout(this.interruptResumeTimerId);
      this.interruptResumeTimerId = -1;
    }
  }

  private scheduleInterruptResume(delayMs: number): void {
    this.cancelInterruptResumeTimer();
    this.pendingInterruptResume = true;
    this.interruptResumeTimerId = setTimeout(() => {
      this.interruptResumeTimerId = -1;
      void this.executeInterruptResume();
    }, delayMs);
  }

  private async executeInterruptResume(): Promise<void> {
    if (!this.pendingInterruptResume) {
      return;
    }
    if (CallInterruptState.isCallActive()) {
      HiLog.i(TAG, 'executeInterruptResume deferred: call still active');
      return;
    }
    const isAppInBackground: boolean =
      this.localStorage?.get<boolean>(LocalStorageParam.APP_IN_BACKGROUND) ?? false;
    if (!this.isAudioPage && isAppInBackground && !this.allowVideoPlayOnBackground()) {
      HiLog.i(TAG, 'executeInterruptResume still background, keep pending');
      return;
    }
    // 通话恢复一律重建 AVPlayer：paused 复用会踩 Cannot find session / Illegal state
    this.rendererNeedsRebuild = true;
    HiLog.i(TAG, `executeInterruptResume avState=${this.avPlayer?.state} fd=${this.fdSrc} ` +
      `retry=${this.interruptResumeRetryCount} rebuild=${this.rendererNeedsRebuild}`);

    const rebound = await this.rebindMediaSourceForRecovery(this.getPlaybackPositionMs());
    if (!rebound) {
      HiLog.e(TAG, 'executeInterruptResume rebind failed');
      this.pendingInterruptResume = false;
      this.changePlayHoverTips();
      return;
    }
    this.armPlayProgressWatch();
  }

  /**
   * 处理系统音频中断（如来电）：暂停播放并在挂断后按场景自动恢复。
   */
  private handleAudioInterrupt(info: audio.InterruptEvent): void {
    const isAppInBackground: boolean = this.localStorage?.get<boolean>(LocalStorageParam.APP_IN_BACKGROUND) ?? false;
    HiLog.i(TAG, `audioInterrupt force=${info.forceType} hint=${info.hintType} event=${info.eventType} ` +
      `isAudioPage=${this.isAudioPage} isAppInBackground=${isAppInBackground} avState=${this.avPlayer?.state} ` +
      `callActive=${CallInterruptState.isCallActive()}`);

    if (info.forceType === audio.InterruptForceType.INTERRUPT_FORCE) {
      switch (info.hintType) {
        case audio.InterruptHint.INTERRUPT_HINT_PAUSE:
        case audio.InterruptHint.INTERRUPT_HINT_STOP:
          this.pauseForAudioInterrupt();
          break;
        default:
          break;
      }
      return;
    }

    if (info.forceType === audio.InterruptForceType.INTERRUPT_SHARE &&
      info.hintType === audio.InterruptHint.INTERRUPT_HINT_RESUME) {
      this.resumeAfterAudioInterrupt(isAppInBackground);
      return;
    }

    if (info.hintType === audio.InterruptHint.INTERRUPT_HINT_PAUSE ||
      info.hintType === audio.InterruptHint.INTERRUPT_HINT_STOP) {
      this.pauseForAudioInterrupt();
      return;
    }
    if (info.hintType === audio.InterruptHint.INTERRUPT_HINT_RESUME) {
      this.resumeAfterAudioInterrupt(isAppInBackground);
    }
  }

  prepare() {
    HiLog.i(TAG, `prepare`);
    this.avPlayer !== null && this.avPlayer.prepare();
  }

  stop(): void {
    HiLog.i(TAG, `stop, currentTime:${this.currentTime}`);
    this.lastUIExtensionStopTime = this.currentTime;
    this.savePlaylistResumeIfNeeded(true);
    this.avPlayer !== null && this.avPlayer.stop();
    this.playState = PlayConstants.STATUS_STOP;
  }

  private unregisterListeners() {
    this.avPlayer?.off('stateChange');
    this.avPlayer?.off('timeUpdate');
    this.avPlayer?.off('volumeChange');
    this.avPlayer?.off('error');
    this.avPlayer?.off('seekDone');
    this.avPlayer?.off('audioInterrupt');
    this.avPlayer?.off('audioOutputDeviceChangeWithInfo');
    this.audioControlBridge.unregisterCallbacks();
    this.videoControlBridge.unregisterCallbacks();
  }

  async release() {
    HiLog.i(TAG, `release`);
    this.avPlayerGeneration++;
    this.cancelPendingInterruptResume();
    this.cancelPlayProgressWatch();
    this.rendererNeedsRebuild = false;
    this.continuousTaskRunning = false;
    this.unregisterListeners();
    this.avPlayer !== null && await this.avPlayer.release();
    this.avPlayer = null;
    this.releaseResource();
    this.syncPlayState(PlayConstants.STATUS_PAUSE);
    this.playPage = null;
    this.playProgress = null;
    this.pagePlayStateUpdater = undefined;
    this.progressPlayStateListeners = [];
    this.volumePanelUpdater = undefined;
    this.pageVolumeUpdater = undefined;
    if (this.sliderPlayEvent !== null) {
      clearTimeout(this.sliderPlayEvent);
      this.sliderPlayEvent = null;
    }
  }

  async reset(): Promise<void> {
    HiLog.i(TAG, `reset`);
    this.releaseResource();
    this.avPlayer !== null && this.avPlayer.reset();
    this.lastProgressUpdateTime = 0;
    if (this.playProgress) {
      this.playProgress.progressVal = 0;
      this.playProgress.currentTime = '00:00';
    }
  }

  /** 开始一次切歌，返回代际 token 供后续校验 */
  protected beginTrackSwitch(): number {
    this.trackSwitchGeneration++;
    return this.trackSwitchGeneration;
  }

  /** 判断切歌 token 是否仍为最新（未被更新的切歌请求取代） */
  protected isTrackSwitchCurrent(generation: number): boolean {
    return generation === this.trackSwitchGeneration;
  }

  /** 切歌前重置播放器状态，保留 AVPlayer 实例与监听；失败则重建以保证 idle */
  async prepareForTrackSwitch(): Promise<void> {
    HiLog.i(TAG, 'prepareForTrackSwitch');
    this.releaseResource();
    const idle = await this.ensureIdleForSetSource();
    if (!idle) {
      HiLog.e(TAG, 'prepareForTrackSwitch failed to reach idle');
    }
    this.currentTime = 0;
    this.lastProgressUpdateTime = 0;
    if (this.playProgress !== null) {
      this.playProgress.progressVal = 0;
      this.playProgress.currentTime = '00:00';
    }
    if (this.playPage !== null) {
      this.playPage.loadingStatus = LoadingStatus.LOAD_STATE_LOADING;
    }
  }

  private handleStateChange() {
    if (this.avPlayer === null) {
      return;
    }
    this.avPlayer.on('stateChange', async (state) => {
      switch (state) {
        case 'idle':
          this.toIdle()
          break;
        case 'initialized':
          this.toInitialized();
          break;
        case 'prepared':
          await this.toPrepared();
          break;
        case 'playing':
          this.toPlaying();
          break;
        case 'paused':
          this.toPaused();
          break;
        case 'stopped':
          this.toStopped();
          break;
        case 'completed':
          this.toCompleted();
          break;
        case 'released':
          this.toReleased();
          break;
        default:
          this.toUnknown();
          break;
      }
    });
  }

  bindState(): void {
    HiLog.i(TAG, `bindState`);
    if (this.avPlayer === null) {
      return;
    }
    this.handleStateChange();
    this.avPlayer.on('timeUpdate', (time: number) => {
      this.timeUpdate(time);
    });
    this.avPlayer.on('volumeChange', (volume: number) => {
      HiLog.d(TAG, `volumeChange to ${volume}`);
    });
    this.avPlayer.on('error', (err: BusinessError) => {
      const fromInterruptResume = this.pendingInterruptResume;
      HiLog.e(TAG, `avPlayer error message: ${err.message}, code: ${err.code} ` +
        `fromInterruptResume=${fromInterruptResume} retry=${this.interruptResumeRetryCount}`);
      this.error();
      if (!fromInterruptResume) {
        promptAction.showToast({ message: $r('app.string.file_parse_failure_tips') });
      }
      void this.recoverAvPlayerAfterError().then(() => {
        if (!fromInterruptResume && !this.pendingInterruptResume) {
          return;
        }
        if (this.interruptResumeRetryCount >= AVPlayerController.INTERRUPT_RESUME_MAX_RETRY) {
          HiLog.e(TAG, 'interrupt resume recovery exhausted');
          this.pendingInterruptResume = false;
          this.interruptResumeRetryCount = 0;
          promptAction.showToast({ message: $r('app.string.file_parse_failure_tips') });
          return;
        }
        this.interruptResumeRetryCount++;
        this.pendingInterruptResume = true;
        this.scheduleInterruptResume(AVPlayerController.INTERRUPT_RESUME_DELAY_MS);
      });
    });

    this.avPlayer.on('seekDone', (seekDoneTime: number) => {
      this.currentTime = seekDoneTime;
      this.isSeekDone = true;
      HiLog.i(TAG, `onSeekDone,isSeekDone: ${this.isSeekDone},seekDoneTime: ${seekDoneTime}`);
    })

    this.avPlayer.on('audioInterrupt', (info: audio.InterruptEvent) => {
      this.handleAudioInterrupt(info);
    });
    this.avPlayer.on('audioOutputDeviceChangeWithInfo', (data: audio.AudioStreamDeviceChangeInfo) => {
      HiLog.i(TAG, `AudioStreamDeviceChangeInfo: ${JSON.stringify(data)}`);
      if (data.changeReason === audio.AudioStreamDeviceChangeReason.REASON_OLD_DEVICE_UNAVAILABLE) {
        HiLog.i(TAG, `AudioStreamDeviceChange old device is unavailable`);
        this.pause();
      }
    });
  }

  toIdle(): void {
    HiLog.i(TAG, `toIdle`);
  }

  toInitialized(): void {
    HiLog.i(TAG, `toInitialized! isAudioPage: ${this.isAudioPage}`);
    if (this.avPlayer === null) {
      HiLog.e(TAG, `toInitialized, avPlayer is null`);
      return;
    }
    audio.AudioPrivacyType.PRIVACY_TYPE_PUBLIC;

    this.avPlayer.audioRendererInfo = {
      usage: this.isAudioPage ? audio.StreamUsage.STREAM_USAGE_MUSIC : audio.StreamUsage.STREAM_USAGE_MOVIE,
      rendererFlags: 0
    }
    this.avPlayer.prepare();
  }

  async toPrepared() {
    if (this.avPlayer === null || this.avPlayer.state !== 'prepared') {
      HiLog.w(TAG, `toPrepared, this.aveplayer.state:${this.avPlayer?.state}`);
      return;
    }

    this.applyShareInterruptMode();
    this.avPlayer.setVolume(this.volume);
    this.avPlayer.setPlaybackRate(this.resolvePlaybackRate(this.speed));
    this.avPlayer.loop = this.isLoop;
    let totalSeconds = Math.floor(this.avPlayer.duration / Constants.A_THOUSAND);


    if (this.playProgress) {
      this.playProgress.totalTime = DateFormatUtil.secondToTime(totalSeconds);
      HiLog.i(TAG, `toPrepared: totalTime: ${this.playProgress.totalTime}`);
    }
    const pendingResumeMs = PlaybackResumeContext.consumePendingStartMs();
    const startPaused = PlaybackResumeContext.consumePendingStartPaused();
    if (pendingResumeMs > 0) {
      HiLog.i(TAG, `toPrepared resumeSeek ms=${pendingResumeMs}`);
      this.initProgress(pendingResumeMs, true);
      this.avPlayer.seek(pendingResumeMs, Constants.SEEK_CLOSEST);
    }
    this.getRefreshRate();

    if (this.checkSwiperAudio()) {
      return;
    }

    if (this.isPcConfig && this.playPage?.windowType === WindowType.UI_EXTENSION_WINDOW) {
      HiLog.i(TAG, `Audio and video do not play automatically in PC embedded scenarios.`);
      return
    }
    if (startPaused && this.isAudioPage) {
      HiLog.i(TAG, 'toPrepared cold restore paused');
      this.syncPlayState(PlayConstants.STATUS_PAUSE);
      this.updatePlayButtonAccessibility(false);
      return;
    }
    await this.play();

    let windowClass: window.Window | undefined = this.localStorage?.get<window.Window>('windowClass');
    let regWindowEvent: boolean = !!windowClass && (this.isPcConfig || this.isTabletConfig);
    if (regWindowEvent) {
      windowClass?.on('windowEvent', this.windowEventChangeCallback);
    }
    if (windowClass) {
      this.volumeAndBrightInit(windowClass);
    }
  }


  private checkSwiperAudio(): boolean {
    let viewFileType: ViewFileType = this.playPage?.viewFileType as ViewFileType;
    let onSwiperAudio: boolean = this.localStorage?.get<boolean>('swiperAudio') ?? true;
    let isAppInBackground: boolean = this.localStorage?.get<boolean>(LocalStorageParam.APP_IN_BACKGROUND) ?? true;
    HiLog.i(TAG, `onSwiperChange:${onSwiperAudio} viewFileType:${viewFileType} isAppInBackground=${isAppInBackground}
      this.isAudioPage:${this.isAudioPage}`);
    if (viewFileType === ViewFileType.MULTIPLE && this.isAudioPage && !onSwiperAudio && !isAppInBackground &&
      !this.isPcConfig) {
      HiLog.i(TAG, `onSwiperChange audio, no need play`);
      return true;
    }
    return false;
  }

  private checkSwiperVideo() {
    let viewFileType: ViewFileType = this.playPage?.viewFileType as ViewFileType;
    let onSwiperVideo: boolean = this.localStorage?.get<boolean>('swiperVideo') ?? true;
    let isAppInBackground: boolean = this.localStorage?.get<boolean>(LocalStorageParam.APP_IN_BACKGROUND) ?? true;
    HiLog.i(TAG, `onSwiperChange toPlaying:${onSwiperVideo} viewFileType:${viewFileType}`);

    if (viewFileType === ViewFileType.MULTIPLE && !this.isAudioPage && !onSwiperVideo && !isAppInBackground &&
      !this.isPcConfig) {
      HiLog.i(TAG, `onSwiperChange video, no need play`);
      this.pause();
      return;
    }
  }


  async getRefreshRate(): Promise<number> {
    if (!this.isPcConfig && !this.isTabletConfig) {
      return 0;
    }
    let originFrameRate: number | undefined = 0;
    await this.avPlayer?.getTrackDescription().then((arrList: media.MediaDescription[]): void => {
      if (!arrList || arrList.length === 0) {
        HiLog.e(TAG, 'getRefreshRate failed, MediaDescription is null or empty.');
        return;
      }
      for (let i = 0; i < arrList.length; i++) {
        let desc: media.MediaDescription = arrList[i];
        if (desc[media.MediaDescriptionKey.MD_KEY_TRACK_TYPE] === media.MediaType.MEDIA_TYPE_VID) {
          originFrameRate = desc[media.MediaDescriptionKey.MD_KEY_FRAME_RATE] as number;
          HiLog.i(TAG, `current refresh rate : ${originFrameRate}`);
          this.videoInformation = this.localStorage?.get<VideoInformation>(LocalStorageParam.VIDEO_INFORMATION) ??
            new VideoInformation();
          this.videoInformation.width = this.avPlayer?.width as number;
          this.videoInformation.height = this.avPlayer?.height as number;
          this.videoInformation.originFrameRate = originFrameRate;
          this.videoInformation.duration = this.playProgress?.totalTime as string;
          this.localStorage?.setOrCreate<VideoInformation>(LocalStorageParam.VIDEO_INFORMATION, this.videoInformation);
          HiLog.i(TAG, `getRefreshRate, videoInformation: ${JSON.stringify(this.videoInformation)}`)
          if (originFrameRate > 0 && originFrameRate < PlayConstants.ORIGIN_FRAME_RATE) {
            let windowClass: window.Window | undefined = this.localStorage?.get<window.Window>('windowClass');
            if (!windowClass) {
              return;
            }
            this.below48Hz = true;
            this.windowCallBackRegister(windowClass);
          }
        }
      }
    });
    HiLog.i(TAG, `getRefreshRate, originFrameRate: ${originFrameRate}`)
    return originFrameRate;
  }

  isPrepared() {
    if (!this.avPlayer) {
      return undefined;
    }
    return AVPLAYER_PREPARED_STATE.has(this.avPlayer.state);
  }

  isLoading() {
    if (!this.avPlayer) {
      return undefined;
    }
    return AVPLAYER_LOADING_STATE.has(this.avPlayer.state);
  }

  public windowCallBackOff() {
    HiLog.i(TAG, `windowCallBackOff`);
    let windowClass = this.localStorage?.get<window.Window>('windowClass');
    if (windowClass && (this.isPcConfig && !this.playPage?.isPADModeInTable)) {
      try {
        windowClass.off('windowStatusChange', this.windowStatusChangeCallback);
        windowClass.off('windowEvent', this.windowEventChangeCallback);
        let audioRoutingManager: audio.AudioRoutingManager | undefined = this.audioManager?.getRoutingManager();
        audioRoutingManager?.off('preferOutputDeviceChangeForRendererInfo');
      } catch (error) {
        HiLog.e(TAG, `Failed to unregister window callback: ${error}`);
      }
    }
  }


  public windowStatusChangeCallback = (type: window.WindowStatusType) => {
    if (!this.isPcConfig || this.playPage?.isPADModeInTable) {
      return;
    }
    this.isPcFullScreen = type === window.WindowStatusType.FULL_SCREEN;
    this.localStorage?.setOrCreate<boolean>('isPcFullScreen', this.isPcFullScreen);
    HiLog.i(TAG, `windowSizeChangeCallback, isPcFullScreen: ${this.isPcFullScreen}`);
  }


  public setVideoFullScene(isProgressHide: boolean) {
    if (!this.isTabletConfig) {
      return;
    }
    HiLog.i(TAG,
      `setVideoFullScene, isEnterVideoFullScene: ${this.isEnterVideoFullScene}. isProgressHide: ${isProgressHide}`)
  }


  public windowEventChangeCallback = (type: window.WindowEventType) => {
    HiLog.i(TAG,
      `getRefreshRate, windowEventChangeCallback, isPcConfig: ${this.isPcConfig}, isTabletConfig: ${this.isTabletConfig}`)
    if (!this.isPcConfig && !this.isTabletConfig) {
      return;
    }
    this.isActiveWindow = type === window.WindowEventType.WINDOW_ACTIVE;
    this.isShownWindow = type === window.WindowEventType.WINDOW_SHOWN;
    this.localStorage?.setOrCreate<boolean>('isActiveWindow', this.isActiveWindow);
    HiLog.i(TAG, `windowEventChangeCallback, isActiveWindow: ${this.isActiveWindow} below48Hz:${this.below48Hz}`);
    if (!this.below48Hz) {
      return;
    }
  }


  public windowCallBackRegister(windowClass: window.Window) {
    if (windowClass && this.isPcConfig) {
      windowClass.on('windowStatusChange', this.windowStatusChangeCallback);
    }
  }

  toPlaying(): void {
    HiLog.i(TAG, `toPlaying isAudioPage:${this.isAudioPage}`);
    this.interruptedWhilePlaying = false;
    this.pendingInterruptResume = false;
    this.cancelInterruptResumeTimer();
    getContext(this).eventHub.emit(AvPlayerToPlayingEvent.event);
    this.checkSwiperVideo();
    this.localStorage?.setOrCreate<boolean>('swiperAudio', false);
    this.localStorage?.setOrCreate<boolean>('swiperVideo', false);
    this.syncPlayState(PlayConstants.STATUS_START);
    this.savePlaylistResumeIfNeeded(true);
    // 不在此处清 rendererNeedsRebuild / retry：等 timeUpdate 前进再确认真正出声
    this.armPlayProgressWatch();
  }

  toPaused(): void {
    HiLog.i(TAG, `toPaused`);
    // 拖动进度条触发的 pause 不改变 UI 播放态，seek 结束后由 play() 恢复
    if (this.wasPlayingBeforeSeek || this.isMovingProgressSlider) {
      return;
    }
    if (this.playProgress !== null && this.playProgress.playState !== PlayConstants.STATUS_COMPLETE) {
      this.syncPlayState(PlayConstants.STATUS_PAUSE);
    }
    this.changeIcon();
  }

  private syncPlayState(state: number): void {
    this.playState = state;
    this.progressPlayState = state;
    HiLog.i(TAG, `syncPlayState state:${state}`);
    this.pagePlayStateUpdater?.(state);
    this.notifyProgressPlayState(state);
  }

  changeIcon() {
    let fileInfo = this.playPage?.fileInfo as FileInfo;
    let isAppInBackground: boolean = this.localStorage?.get<boolean>(LocalStorageParam.APP_IN_BACKGROUND) ?? true;
  }

  toStopped() {
    if (this.playProgress !== null && this.playProgress.playState !== PlayConstants.STATUS_COMPLETE) {
      this.syncPlayState(PlayConstants.STATUS_STOP);
    }
  }

  toCompleted(): void {
    HiLog.i(TAG, `toCompleted`);
    this.avPlayer !== null && this.avPlayer.seek(0);
    this.currentTime = 0;
    if (this.playProgress !== null) {
      this.playProgress.progressVal = 0;
      this.playProgress.currentTime = '00:00';
      this.lastProgressUpdateTime = 0;
    }
    this.changePlayHoverTips();
    this.syncPlayState(PlayConstants.STATUS_COMPLETE);
  }

  toReleased(): void {
    HiLog.i(TAG, `toReleased`);
  }

  toUnknown(): void {
    HiLog.i(TAG, `toUnknown`);
  }

  timeUpdate(time: number): void {
    HiLog.d(TAG, `timeUpdate:${time} last:${this.lastProgressUpdateTime}`);
    if (time < this.lastProgressUpdateTime ||
      time > this.lastProgressUpdateTime + PlayConstants.TIME_UPDATE_MAX_INTERVAL) {
      HiLog.w(TAG, `time update back, lastProgressUpdateTime:${this.lastProgressUpdateTime} time:${time}`);
      if (this.isSeekDone) {
        this.lastProgressUpdateTime = time;
        HiLog.i(TAG, `lastProgressUpdateTime is update`);
      }
      return;
    }
    // 仅在真正 playing 且进度前进时清除重建标记；暂停后迟到的 timeUpdate 不得清掉
    if (this.playState === PlayConstants.STATUS_START && this.avPlayer?.state === 'playing' &&
      time > this.lastProgressUpdateTime) {
      this.rendererNeedsRebuild = false;
      this.interruptResumeRetryCount = 0;
      this.cancelPlayProgressWatch();
    }
    this.currentTime = time;
    if (this.playProgress) {
      this.initProgress(time);
    }
    this.savePlaylistResumeIfNeeded(false);
  }

  /**
   * 获取当前播放进度（毫秒）
   *
   * @returns 播放位置
   */
  public getPlaybackPositionMs(): number {
    if (this.avPlayer !== null && this.avPlayer.currentTime > 0) {
      return this.avPlayer.currentTime;
    }
    return this.currentTime > 0 ? this.currentTime : 0;
  }

  /**
   * 立即将歌单续播进度写入 Preferences（退后台/杀进程前调用）
   */
  public persistPlaylistResumeSnapshot(): void {
    this.savePlaylistResumeIfNeeded(true);
  }

  /**
   * 歌单音频播放时持久化续播进度
   *
   * @param force 是否跳过节流立即落盘
   */
  private savePlaylistResumeIfNeeded(force: boolean): void {
    if (!this.isAudioPage) {
      return;
    }
    const playlistId = PlaybackQueueManager.getInstance().getSourcePlaylistId();
    if (playlistId < 0) {
      return;
    }
    const now = Date.now();
    if (!force && now - this.lastPlaylistResumeSaveAt < 3000) {
      return;
    }
    this.lastPlaylistResumeSaveAt = now;
    const uri = PlaybackQueueManager.getInstance().getCurrentUri();
    if (uri.length === 0) {
      return;
    }
    const positionMs = this.getPlaybackPositionMs();
    const snapshot = PlaybackQueueManager.getInstance().getQueueSnapshot();
    const uris: string[] = [];
    for (let i = 0; i < snapshot.length; i++) {
      uris.push(snapshot[i].uri);
    }
    const signature = PlaylistPlaybackResumeManager.buildTrackOrderSignature(uris);
    const track = PlaybackQueueManager.getInstance().getTrack(uri);
    const fileName = track !== null ? track.fileName : this.saveFileInfo.fileName;
    PlaylistPlaybackResumeManager.getInstance()
      .saveResume(playlistId, uri, fileName, positionMs, signature);
  }

  error(): void {
    HiLog.e(TAG, `default error`);
  }

  async switchPlayOrPause() {
    HiLog.i(TAG, `switchPlayOrPause-playState:${this.playState}`);
    if (this.playState === PlayConstants.STATUS_START) {
      this.pause();
    } else if (this.playState === PlayConstants.STATUS_PAUSE || this.playState === PlayConstants.STATUS_COMPLETE ||
      this.playState === PlayConstants.STATUS_STOP) {
      this.localStorage?.setOrCreate<boolean>('swiperVideo', undefined);
      await this.play();
    }
  }


  startContinuousTask(fileInfo: FileInfo) {
    const wantAgentInfo = PlaybackControlCenterBridge.buildWantAgentInfoForFile(fileInfo);
    HiLog.i(TAG, `want is wantAgentInfo %{private}s`, JSON.stringify(wantAgentInfo));

    try {
      wantAgent.getWantAgent(wantAgentInfo).then((wantAgentObj: WantAgent) => {
        backgroundTaskManager.startBackgroundRunning(getContext(this) as common.UIAbilityContext,
          backgroundTaskManager.BackgroundMode.AUDIO_PLAYBACK, wantAgentObj).then(() => {
          this.continuousTaskRunning = true;
          HiLog.i(TAG, `Succeeded in operationing startBackgroundRunning.`);
        }).catch((err: BusinessError) => {
          this.continuousTaskRunning = false;
          HiLog.e(TAG,
            `Failed to operation startBackgroundRunning. Code is ${err.code}, message is ${err.message}`);
        });
      });
    } catch (err) {
      HiLog.e(TAG, `startBackgroundRunning error. Code is ${err.code}, message is ${err.message}`);
    }
  }


  stopContinuousTask() {
    if (!this.continuousTaskRunning) {
      return;
    }
    try {
      backgroundTaskManager.stopBackgroundRunning(getContext(this) as common.UIAbilityContext).then(() => {
        this.continuousTaskRunning = false;
        HiLog.i(TAG, `Succeeded in operationing stopBackgroundRunning.`);
      }).catch((err: BusinessError) => {
        this.continuousTaskRunning = false;
        HiLog.e(TAG, `Failed to operation stopBackgroundRunning. Code is ${err.code}, message is ${err.message}`);
      });
    } catch (err) {
      this.continuousTaskRunning = false;
      HiLog.e(TAG, `stopBackgroundRunning error. Code is ${err.code}, message is ${err.message}`);
    }
  }

  setFileInfo(fileInfo: FileInfo, isAudioPage: boolean) {
    this.saveFileInfo = fileInfo;
    this.isAudioPage = isAudioPage;
  }

  /**
   * 当前媒体类型对应的播控桥（音频/视频实例解耦）
   *
   * @returns 播控桥实例
   */
  private getActiveControlBridge(): PlaybackControlCenterBridge {
    return this.isAudioPage ? this.audioControlBridge : this.videoControlBridge;
  }

  /**
   * 绑定 UI 上下文与播控反向控制委托（音频/视频桥各绑定一次）
   */
  private ensureControlBridgeBound(): void {
    if (this.controlBridgesBound) {
      return;
    }
    const context = getContext(this) as common.UIAbilityContext;
    if (this.controlHandler === undefined) {
      this.controlHandler = new AvPlayerPlaybackControlHandler(this);
    }
    this.audioControlBridge.bind(this.controlHandler, context);
    this.videoControlBridge.bind(this.controlHandler, context);
    this.controlBridgesBound = true;
  }

  /**
   * 同步播控中心为播放态（音频/视频共用）。
   * 必须先 await 会话创建，再写 PLAY + 进度；否则 setPlaybackState 会在 avSession 未就绪时丢包，
   * 随后仅带 position 的 updatePosition 还会把状态清成 INITIAL，引发播控中心误发 pause。
   *
   * @param refreshMetadata 是否在播放时刷新元数据（视频建议 true）
   */
  protected applyControlCenterPlayingState(refreshMetadata: boolean = false): void {
    this.startContinuousTask(this.saveFileInfo);
    void this.syncControlCenterPlayingState(refreshMetadata);
  }

  private async syncControlCenterPlayingState(refreshMetadata: boolean): Promise<void> {
    await this.setSessionInfo(AVSessionManager.PlaybackState.PLAYBACK_STATE_PLAY);
    this.setPlaybackState(AVSessionManager.PlaybackState.PLAYBACK_STATE_PLAY);
    this.setPlayingTime(this.avPlayer?.currentTime ?? 0);
    if (refreshMetadata) {
      await this.updateAvSessionMetadata();
      // 元数据刷新后再次确认 PLAY，避免系统侧状态抖动
      this.setPlaybackState(AVSessionManager.PlaybackState.PLAYBACK_STATE_PLAY);
    }
  }

  /**
   * 同步播控中心为暂停态（音频/视频共用）
   */
  protected applyControlCenterPausedState(): void {
    this.setPlayingTime(this.avPlayer?.currentTime ?? 0);
    this.setPlaybackState(AVSessionManager.PlaybackState.PLAYBACK_STATE_PAUSE);
    this.stopContinuousTask();
  }

  /**
   * 播控中心 seek 入口（供 Handler 适配类调用）
   *
   * @param time 目标位置（毫秒）
   */
  dispatchControlCenterSeek(time: number): void {
    this.performControlCenterSeek(time);
  }

  /**
   * 播控中心拖动进度：BUFFERING → seek → 恢复 PLAY
   *
   * @param time 目标位置（毫秒）
   */
  private performControlCenterSeek(time: number): void {
    if (!this.avPlayer?.duration) {
      return;
    }
    const bridge = this.getActiveControlBridge();
    bridge.reportSeekBuffering();
    this.lastProgressUpdateTime = time;
    if (this.isAudioPage) {
      this.avPlayer.seek(time);
    } else {
      this.avPlayer.seek(time, Constants.SEEK_CLOSEST);
    }
    bridge.completeSeek(time);
  }

  /**
   * 释放当前媒体类型播控会话
   */
  protected async clearAvSession(): Promise<void> {
    await this.getActiveControlBridge().release();
  }

  /**
   * 创建/激活播控会话并同步状态（委托 {@link PlaybackControlCenterBridge}）
   *
   * @param state 播放状态
   */
  async setSessionInfo(state: AVSessionManager.PlaybackState) {
    this.ensureControlBridgeBound();
    let launchOptions: PlaybackControlLaunchOptions | undefined = undefined;
    if (this.isTabletConfig || this.isPcConfig) {
      launchOptions = { fileInfo: this.saveFileInfo };
    }
    await this.getActiveControlBridge().ensureActive(state, this.buildAvMetadata(), launchOptions);
    this.getActiveControlBridge().updatePosition(this.currentTime);
  }

  /**
   * 子类可提供嵌入式封面（音频内嵌图）
   *
   * @returns 封面 PixelMap，无则 null
   */
  protected getSessionCoverPixelMap(): image.PixelMap | null {
    return null;
  }

  /**
   * 子类可覆盖默认播控封面（视频使用视频图标）
   *
   * @returns 默认封面资源
   */
  protected getDefaultSessionCoverResource(): Resource {
    return $r('app.media.ic_audio');
  }

  /**
   * 构建当前曲目的 AVSession 元数据（assetId 使用 uri，便于后台切歌后播控中心刷新）
   */
  protected buildAvMetadata(): AVSessionManager.AVMetadata {
    const titleInfo = PlayerMediaTitleUtil.parseFromFileName(this.saveFileInfo.fileName);
    const metadata: AVSessionManager.AVMetadata = {
      assetId: this.saveFileInfo.uri.length > 0 ? this.saveFileInfo.uri : this.saveFileInfo.fileName,
      title: titleInfo.title.length > 0 ? titleInfo.title : this.saveFileInfo.fileName,
      artist: titleInfo.artist.length > 0 ? titleInfo.artist : this.getString($r('app.string.player_unknown_artist')),
      duration: this.avPlayer?.duration,
    };
    const embeddedCover = this.getSessionCoverPixelMap();
    if (embeddedCover !== null) {
      metadata.mediaImage = embeddedCover;
      return metadata;
    }
    try {
      const resourceMgr = getContext(this)?.resourceManager;
      if (resourceMgr !== undefined) {
        metadata.mediaImage =
          resourceMgr.getDrawableDescriptor(this.getDefaultSessionCoverResource()).getPixelMap();
      }
    } catch (err) {
      const error = err as BusinessError;
      HiLog.w(TAG, `buildAvMetadata default cover failed message=${error.message}`);
    }
    return metadata;
  }

  /**
   * 更新播控中心元数据（切歌后须主动调用，后台场景依赖唯一 assetId）
   */
  async updateAvSessionMetadata(): Promise<void> {
    this.ensureControlBridgeBound();
    await this.getActiveControlBridge().publishMetadata(this.buildAvMetadata());
  }

  setPlayingTime(time: number) {
    this.getActiveControlBridge().updatePosition(time);
  }

  setPlayingSpeed(speed: number) {
    this.getActiveControlBridge().updateSpeed(speed);
  }

  setPlaybackState(state: AVSessionManager.PlaybackState) {
    this.getActiveControlBridge().updatePlaybackState(state);
  }

  seek(time: number) {
    HiLog.i(TAG, `seek time:${time}`);
    this.lastProgressUpdateTime = time;
    if (this.isAudioPage) {
      this.avPlayer?.seek(time);
    } else {
      this.avPlayer?.seek(time, Constants.SEEK_CLOSEST);
    }
    this.initProgress(time, true);
  }

  skipForward30Seconds() {
    HiLog.i(TAG, `skipForward30Seconds currentTime:${this.currentTime} duration:${this.avPlayer?.duration}`);
    this.seek(Math.min(this.currentTime + PlayConstants.SECONDS_30, this.avPlayer?.duration ?? 0));
  }

  skipBackward10Seconds() {
    HiLog.i(TAG, `skipBackward10Seconds currentTime:${this.currentTime}`);
    this.seek(Math.max(0, this.currentTime - PlayConstants.SECONDS_10));
  }

  skipForward15Seconds() {
    HiLog.i(TAG, `skipForward15Seconds currentTime:${this.currentTime}`);
    this.seek(Math.min(this.currentTime + PlayConstants.SECONDS_15, this.avPlayer?.duration ?? 0));
  }

  skipBackward15Seconds() {
    HiLog.i(TAG, `skipBackward15Seconds currentTime:${this.currentTime}`);
    this.seek(Math.max(0, this.currentTime - PlayConstants.SECONDS_15));
  }

  skipToPreviousTrack(): void {
    HiLog.i(TAG, `skipToPreviousTrack currentTime:${this.currentTime}`);
    const result = PlaybackQueueManager.getInstance().skipToPrevious();
    if (result === SkipPreviousResult.RESTART_CURRENT) {
      this.seek(0);
    }
  }

  skipToNextTrack(): void {
    HiLog.i(TAG, `skipToNextTrack currentTime:${this.currentTime}`);
    if (PlaybackQueueManager.getInstance().skipToNext()) {
      return;
    }
    HiLog.i(TAG, 'skipToNextTrack: no next track in queue');
  }

  getVolumeIcon(volumePercentage: number) {
    let volumeIcon: Resource = Constants.APP_BAR_ICON_VOLUME;
    let volume: number = volumePercentage * PlayConstants.MAX_AUDIO_LEVEL;
    switch (true) {
      case volume > PlayConstants.VOLUME_MEDIUM:
        volumeIcon = Constants.APP_BAR_ICON_VOLUME;
        break;
      case PlayConstants.VOLUME_LOW < volume && volume <= PlayConstants.VOLUME_MEDIUM:
        volumeIcon = Constants.APP_BAR_ICON_VOLUME_MEDIUM;
        break;
      case PlayConstants.VOLUME_MUTE < volume && volume <= PlayConstants.VOLUME_LOW:
        volumeIcon = Constants.APP_BAR_ICON_VOLUME_LOW;
        break;
      case volume === PlayConstants.VOLUME_MUTE:
        volumeIcon = Constants.APP_BAR_ICON_SILENT;
        break;
      default:
        volumeIcon = Constants.APP_BAR_ICON_VOLUME;
    }
    return volumeIcon;
  }

  /**
   * 设置系统媒体音量。
   * @param volume 归一化音量 0~1（手势/UI 百分比），须换算为整数档位再调用 audioManager.setVolume
   */
  setSystemVolume(volume: number) {
    HiLog.i(TAG, `setSystemVolume: ${volume}`);
    try {
      const maxVolume = this.systemMaxVolume > 0 ? this.systemMaxVolume : 15;
      const clamped = Math.max(PlayConstants.MIN_VALUE, Math.min(PlayConstants.MAX_VALUE, volume));
      // audioManager.setVolume 第二参为整数 volumeLevel（0~max），浮点会被截断为 0 → 静音
      const volumeLevel = Math.round(clamped * maxVolume);
      HiLog.i(TAG, `setSystemVolume level:${volumeLevel} max:${maxVolume}`);
      this.isSetSystemVolume = true;
      this.audioManager?.setVolume(PlayConstants.VOLUME_TYPE, volumeLevel);
    } catch (e) {
      let err: BusinessError = e as BusinessError;
      HiLog.e(TAG, `setSystemVolume: error, message:${err.message} code:${err.code}`);
    }
  }


  async volumeAndBrightInit(windowClass: window.Window | undefined) {
    if (!this.playPage || !windowClass) {
      HiLog.e(TAG, `volumeAndBrightInit, windowClass or playPage is undefined`);
      return;
    }
    this.playPage.bright = WindowUtil.getCurrentBrightness(windowClass);
    this.updatePageBrightness(this.playPage.bright as number);
    this.audioManager = audio.getAudioManager();
    this.audioVolumeManager = this.audioManager.getVolumeManager();

    let groupId: number = audio.DEFAULT_VOLUME_GROUP_ID;
    try {
      if (!this.isPcConfig || this.playPage?.isPADModeInTable) {
        let manager: audio.AudioVolumeGroupManager = await this.audioVolumeManager.getVolumeGroupManager(groupId);
        let volumeValue: number = await manager?.getVolume(audio.AudioVolumeType.MEDIA) ?? 0;
        this.systemMaxVolume = await manager?.getMaxVolume(audio.AudioVolumeType.MEDIA) ?? 15;
        this.updatePageVolume(volumeValue, volumeValue / this.systemMaxVolume);
        HiLog.i(TAG, `init volume:${volumeValue}`);
      }

      this.audioVolumeManager.on('volumeChange', (volumeEvent: audio.VolumeEvent) => {
        if (!this.playPage) {
          HiLog.e(TAG, `volumeChange, playPage is undefined`);
          return;
        }

        if (volumeEvent.volumeType !== audio.AudioVolumeType.MEDIA) {
          HiLog.i(TAG, `VolumeChange is not media type`);
          return;
        }

        if (this.isSetSystemVolume) {
          this.isSetSystemVolume = false;
          return;
        }

        HiLog.i(TAG, `Volume level: ${volumeEvent.volume}`);
        if ((this.isPcConfig && !this.playPage?.isPADModeInTable) || volumeEvent.volume === this.playPage.volume) {
          HiLog.i(TAG, `volumeChange, no need to oprate`);
          return;
        }

        this.updatePageVolume(volumeEvent.volume, volumeEvent.volume / this.systemMaxVolume);
        if (this.showVolumeTimerId !== 0) {
          clearTimeout(this.showVolumeTimerId);
          this.showVolumeTimerId = 0;
        }
        this.setVolumePanelVisible(true);
        this.showVolumeTimerId = setTimeout(() => {
          if (!this.playPage) {
            HiLog.e(TAG, `hideVolumeProgress, playPage is undefined`);
            return;
          }

          this.setVolumePanelVisible(false);
          clearTimeout(this.showVolumeTimerId);
          this.showVolumeTimerId = 0;
        }, PlayConstants.HIDE_VOLUME_PROGRESS_TIME);
      });
    } catch (e) {
      let err: BusinessError = e as BusinessError;
      HiLog.e(TAG, `watch volume error, error:${err.message} code:${err.code}`);
    }
    this.preferOutputDeviceChangeCallback();
  }

  private preferOutputDeviceChangeCallback() {
    let preferredInputDeviceChangeCallback = (audioDeviceDescriptors: audio.AudioDeviceDescriptors) => {
      let isAppInBackground: boolean = this.localStorage?.get<boolean>(LocalStorageParam.APP_IN_BACKGROUND) ?? false;
      let deviceType = audioDeviceDescriptors[0]?.deviceType;
      HiLog.i(TAG, `Succeeded in using on or off function, deviceType: ${deviceType}.`);
      if (isAppInBackground) {
        HiLog.i(TAG, `playPage is appInBackground, no need play`);
        return;
      }
      if (!deviceType ||
        (deviceType !== audio.DeviceType.BLUETOOTH_SCO && deviceType !== audio.DeviceType.BLUETOOTH_A2DP)) {
        HiLog.i(TAG, `deviceType is not bluetooth device, no need play`);
        return;
      }
      this.play();
    };
    let rendererInfo: audio.AudioRendererInfo = {
      usage: this.isAudioPage ? audio.StreamUsage.STREAM_USAGE_MUSIC : audio.StreamUsage.STREAM_USAGE_MOVIE,
      rendererFlags: 0
    };

    let audioRoutingManager: audio.AudioRoutingManager | undefined = this.audioManager?.getRoutingManager();
    if (audioRoutingManager) {
      try {
        HiLog.i(TAG, `audio routing manager`);
        audioRoutingManager.on('preferOutputDeviceChangeForRendererInfo', rendererInfo,
          preferredInputDeviceChangeCallback);
      } catch (e) {
        let err: BusinessError = e as BusinessError;
        HiLog.e(TAG, `audioRoutingManager watch error, message:${err.message} code:${err.code}`);
      }
    }
  }

  private isPlayingForPlayState(): boolean {
    if (this.avPlayer === null || this.playProgress === null) {
      return false;
    }
    if (this.progressPlayState === PlayConstants.STATUS_PAUSE ||
      this.progressPlayState === PlayConstants.STATUS_COMPLETE ||
      this.progressPlayState === PlayConstants.STATUS_STOP ||
      this.avPlayer.state === 'completed' || this.avPlayer.state === 'stopped') {
      return false;
    }
    return true;
  }

  initProgress(time: number, isForced: boolean = false): void {
    if (this.avPlayer === null || this.playProgress === null) {
      HiLog.e(TAG, `initProgress avPlayer or playProgress is null`);
      return;
    }
    this.lastProgressUpdateTime = time;
    if (this.isPlayingForPlayState() || isForced) {
      if (this.isProgressVisible) {
        this.toFindSecondTime(time);
      }
      let curSec2ProgressVal = 0;
      let nextSec2ProgressVal = 0;
      let preciseTotalSecond = (this.avPlayer.duration / Constants.A_THOUSAND);
      if (preciseTotalSecond > 0 && this.nowSeconds !== null) {
        let oneSecond2ProgressVal = Constants.ONE_HUNDRED / preciseTotalSecond;
        curSec2ProgressVal = this.nowSeconds * oneSecond2ProgressVal;
        nextSec2ProgressVal = (this.nowSeconds + 1) * oneSecond2ProgressVal;
      }
      if (this.isMovingProgressSlider) {
        return;
      }
      if (this.playProgress.progressVal >= curSec2ProgressVal && this.playProgress.progressVal < nextSec2ProgressVal) {
        return;
      } else {
        this.playProgress.progressVal = curSec2ProgressVal;
        HiLog.i(TAG, `initProgress with progressVal: ${this.playProgress.progressVal}`);
      }
    }
  }

  progressUpdateTime(time: number): void {
    if (this.avPlayer === null || this.playProgress === null) {
      HiLog.e(TAG, `progressUpdateTime avPlayer or playProgress is null`);
      return;
    }
    this.toFindSecondTime(time);
  }

  toFindSecondTime(time: number): void {
    if (this.avPlayer === null || this.playProgress === null) {
      HiLog.e(TAG, `toFindSecondTime avPlayer or playProgress is null`);
      return;
    }
    this.lastProgressUpdateTime = time;
    this.nowSeconds = Math.floor(time / Constants.A_THOUSAND);
    let totalSeconds = Math.floor(this.avPlayer.duration / Constants.A_THOUSAND);
    this.playProgress.currentTime = DateFormatUtil.secondToTime(this.nowSeconds);
    this.playProgress.totalTime = DateFormatUtil.secondToTime(totalSeconds);
  }

  seekTime(value: number, mode: SliderChangeMode, isAuidoPage: boolean = true): void {
    if (this.avPlayer === null || this.playProgress === null || !AVPLAYER_PREPARED_STATE.has(this.avPlayer.state)) {
      HiLog.e(TAG, `avPlayer or playProgress is null, playState:${this.avPlayer?.state}`);
      return;
    }
    if (!AVPLAYER_PREPARED_STATE.has(this.avPlayer?.state as string)) {
      HiLog.w(TAG, `SeekTime, state is not prepared!`);
      return;
    }
    if (mode === SliderChangeMode.Begin) {
      if (this.playState === PlayConstants.STATUS_START && this.avPlayer?.state === 'playing') {
        this.wasPlayingBeforeSeek = true;
        this.avPlayer.pause();
      } else {
        this.wasPlayingBeforeSeek = false;
      }
      if (this.sliderPlayEvent !== null) {
        clearTimeout(this.sliderPlayEvent);
        this.sliderPlayEvent = null;
      }
      let time = value * this.avPlayer.duration / Constants.ONE_HUNDRED;
      this.lastProgressUpdateTime = time;
      HiLog.i(TAG, `seek begin, seek mode: ${mode}, seek value: ${value} time:${time}`);
    } else if (mode === SliderChangeMode.Moving || mode === SliderChangeMode.End) {
      if (mode === SliderChangeMode.End) {
        this.isSeekDone = false;
        HiLog.i(TAG, ` SliderChangeMode is End,isSeekDone is ${this.isSeekDone}`);
      }
      let isChangeEnd: boolean = mode === SliderChangeMode.End;
      let time = value * this.avPlayer.duration / Constants.ONE_HUNDRED;
      HiLog.i(TAG,
        `seek ${isChangeEnd ? 'end' : 'moving'}, seek mode: ${mode}, seek value: ${value}, seekTime: ${time}`);
      this.progressUpdateTime(time);
      if (isAuidoPage) {
        this.avPlayer.seek(time);
      } else {
        this.avPlayer.seek(time,
          mode === SliderChangeMode.Moving ? media.SeekMode.SEEK_PREV_SYNC : media.SeekMode.SEEK_CLOSEST);
      }

      this.currentTime = time;
      this.setPlayingTime(time);
      if (isChangeEnd && this.wasPlayingBeforeSeek) {
        const shouldResume = this.wasPlayingBeforeSeek;
        this.wasPlayingBeforeSeek = false;
        this.sliderPlayEvent = setTimeout(() => {
          if (shouldResume && this.avPlayer !== null) {
            this.localStorage?.setOrCreate<boolean>('swiperVideo', undefined);
            this.avPlayer.play();
          }
          clearTimeout(this.sliderPlayEvent);
          this.sliderPlayEvent = null;
        }, PlayConstants.PLAY_TIME_INTERVAL);
      }
    }
  }
}
