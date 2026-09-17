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
import { MediaFormatUtil } from '@ohos/common/src/main/ets/utils/MediaFormatUtil';
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

/** 生命周期锁的释放回调，避免 ArkTS 在 Promise 闭包里直接改 let */
class AvPlayerLifecycleUnlock {
  resolve: () => void = (): void => {
  };
}

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
  protected wasPlayingBeforeSeek: boolean = false;
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
  protected lastProgressUpdateTime = 0;
  /**
   * 进度条/seek 使用的时长（毫秒）。AMR 等格式 demuxer 按时长码率估算可能严重偏长，
   * 此时用文件大小估算上限替代 avPlayer.duration，避免总时长虚高、进度提前拉满。
   */
  protected progressDurationMs: number = 0;
  /** 打开音源时的真实文件字节数（不依赖 FileInfo 字段是否带齐） */
  protected openedFileSize: number = 0;
  /**
   * 进度时长可增长的上限（AMR 校正后的 upper bound）。
   * 防止 timeUpdate 异常大值或错误 seek 后把 progressDuration 又撑回 demuxer 虚高值。
   */
  protected progressDurationCapMs: number = 0;
  /** AMR 按字节偏移重绑播放时的文件偏移（0 表示整文件） */
  protected amrFileOffset: number = 0;
  /** AMR 字节 seek 后 UI 进度基准（毫秒），displayTime = base + avPlayer.currentTime */
  protected amrSeekBaseMs: number = 0;
  /** AMR 整曲校正后的总时长，segment 重绑时不要被短 duration 覆盖 */
  protected amrFullDurationMs: number = 0;
  /** AMR 字节 seek 后是否在 prepared 时恢复播放 */
  private pendingAmrSeekPlay: boolean = false;
  /** 标记当前 prepared 来自 AMR 字节 seek（用于区分首播自动 play） */
  private amrSeekInFlight: boolean = false;
  /** AMR segment 内 timeUpdate 基准（相对片段，非整曲展示时间） */
  private lastSegmentProgressTime: number = 0;
  /** 带 #!AMR 头的临时片段 fd（中段重绑 demuxer 需要魔数头） */
  private amrSeekSegmentFd: number | null = null;
  private amrSeekSegmentPath: string = '';
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
  /** recreate / ensureIdle 串行队列，避免连点切歌并行重建两个 AVPlayer */
  private avPlayerLifecycleTail: Promise<void> = Promise.resolve();
  /** 切源单飞进行中：error 回调不弹「文件损坏」、不抢 recover */
  protected trackSwitchBusy: boolean = false;
  /** 切歌后到新源 prepared 前，丢弃旧曲迟到的 timeUpdate，避免进度条跳变 */
  protected suppressTimeUpdateUntilPrepared: boolean = false;
  /** 最近一次 setFdSrc 对应的切歌代际，用于丢弃上一首排队的 error */
  private sourceBindGeneration: number = 0;
  private continuousTaskRunning: boolean = false;
  private isSetSystemVolume: boolean = false;
  /**
   * 用户从进度条 End 触发 seek 进行中：true 时允许落到目标前关键帧的 timeUpdate，
   * 避免进度冻结。UI 由松手点 + 实际时间差映射，不跟关键帧回退。
   */
  private isSeekingFromSlider: boolean = false;
  /** 松手目标（毫秒），收到真实落点前用于识别 echo / 捕获基准 */
  private sliderSeekHoldUntilMs: number = -1;
  /** 第一次真实 timeUpdate（关键帧或精确落点） */
  private sliderSeekBaseActualMs: number = -1;
  /** 进度条显示原点 = 用户松手时间 */
  private sliderSeekDisplayOriginMs: number = -1;
  /** PREV_SYNC 落点过远时，已尝试一次 SEEK_CLOSEST */
  private sliderSeekClosestRetried: boolean = false;
  /** SEEK_CLOSEST 重试尚未收到 seekDone，忽略片头残留 timeUpdate */
  private sliderSeekClosestInFlight: boolean = false;
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
    this.closeAmrSeekSegment();
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
    // 切源中 AVPlayer.currentTime 仍是旧曲，不能写到新进度条（日志 1：5253ms 画成 3.17%）
    if (this.suppressTimeUpdateUntilPrepared || this.trackSwitchBusy || this.hasPendingTrackSwitch()) {
      this.paintSwitchProgressUi();
      HiLog.i(TAG, 'syncBoundPlayProgress skip stale avTime during track switch');
      return;
    }
    this.applyResolvedProgressDuration('syncBound');
    const avTime = this.avPlayer?.currentTime ?? 0;
    const syncTime = avTime > 0 ? avTime :
      (this.currentTime > 0 ? this.currentTime : this.lastProgressUpdateTime);
    HiLog.i(TAG, `syncBoundPlayProgress time=${syncTime} duration=${this.getProgressDurationMs()}`);
    // 强制刷新：新组件实例 totalTime 是初始 '00:00'，且 nowSeconds 在上次 timeUpdate
    // 已被设成 syncTime 对应秒数时，toFindSecondTime 节流会拦截，导致"暂停后再次进入
    // 播放页"currentTime/totalTime 文本保持 00:00 不会被刷新。isForce=true 跳过节流。
    // syncTime=0 也要走 initProgress，才能带上总时长，避免滑块/时间停在初始 00:00。
    const rawTime = syncTime > 0 ? syncTime : 0;
    this.dropInsaneSliderSeekRemap(rawTime);
    const uiTime = this.mapSliderSeekDisplayTime(rawTime);
    this.initProgress(uiTime, true, true);
    if (syncTime > 0 && this.sliderSeekBaseActualMs >= 0) {
      this.lastProgressUpdateTime = syncTime;
    }
  }

  /** 切源过程中进度条归零并预填新曲总时长，不读取旧曲 currentTime */
  private paintSwitchProgressUi(): void {
    if (this.playProgress === null) {
      return;
    }
    this.playProgress.progressVal = 0;
    this.playProgress.currentTime = '00:00';
    if (this.progressDurationMs <= 0 && this.saveFileInfo.duration > 0) {
      this.progressDurationMs = this.saveFileInfo.duration;
    }
    if (this.progressDurationMs > 0) {
      this.syncProgressTotalTimeUi();
    } else {
      this.playProgress.totalTime = '00:00';
    }
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
    // AMR：整文件或临时片段（含 #!AMR 头）。时间戳 seek 常错位，拖近结尾会提前 EOS
    if (this.isCurrentAmrMedia() && this.openedFileSize > 0) {
      if (this.amrSeekSegmentFd !== null) {
        let segmentLen = 0;
        try {
          segmentLen = fs.statSync(this.amrSeekSegmentFd).size;
        } catch (e) {
          HiLog.w(TAG, `amr segment stat failed: ${JSON.stringify(e)}`);
        }
        const fdDesc: media.AVFileDescriptor = {
          fd: this.amrSeekSegmentFd,
          offset: 0,
          length: segmentLen > 0 ? segmentLen : Math.max(0, this.openedFileSize - this.amrFileOffset)
        };
        this.avPlayer.fdSrc = fdDesc;
        HiLog.i(TAG,
          `applyPendingAvPlayerSource amr segmentFd=${this.amrSeekSegmentFd} len=${fdDesc.length} ` +
            `srcOffset=${this.amrFileOffset}`);
        return;
      }
      const fdDesc: media.AVFileDescriptor = {
        fd: this.fdSrc,
        offset: 0,
        length: this.openedFileSize
      };
      this.avPlayer.fdSrc = fdDesc;
      HiLog.i(TAG, `applyPendingAvPlayerSource amr fd=${this.fdSrc} length=${this.openedFileSize}`);
      return;
    }
    this.avPlayer.url = `fd://${this.fdSrc}`;
    HiLog.i(TAG, `applyPendingAvPlayerSource fd=${this.fdSrc}`);
  }

  /** 关闭并删除 AMR seek 临时片段 */
  private closeAmrSeekSegment(): void {
    if (this.amrSeekSegmentFd !== null) {
      try {
        fs.closeSync(this.amrSeekSegmentFd);
      } catch (e) {
        HiLog.w(TAG, `closeAmrSeekSegment fd failed: ${JSON.stringify(e)}`);
      }
      this.amrSeekSegmentFd = null;
    }
    if (this.amrSeekSegmentPath.length > 0) {
      try {
        fs.unlinkSync(this.amrSeekSegmentPath);
      } catch (e) {
        HiLog.w(TAG, `closeAmrSeekSegment unlink failed: ${JSON.stringify(e)}`);
      }
      this.amrSeekSegmentPath = '';
    }
  }

  /**
   * 从原文件 dataOffset 起拷贝帧数据，前置 #!AMR\\n 写入缓存临时文件并打开。
   * 中段无魔数头时 demuxer 无法探测 AMR。
   */
  private buildAmrSeekSegment(dataOffset: number): boolean {
    this.closeAmrSeekSegment();
    if (this.fdSrc === null || this.openedFileSize <= 0 || dataOffset <= 0) {
      return false;
    }
    if (dataOffset >= this.openedFileSize) {
      HiLog.e(TAG, `buildAmrSeekSegment offset=${dataOffset} >= size=${this.openedFileSize}`);
      return false;
    }
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const path = `${context.cacheDir}/amr_seek_segment.amr`;
      const outFile = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      const header = new Uint8Array([0x23, 0x21, 0x41, 0x4D, 0x52, 0x0A]); // #!AMR\n
      fs.writeSync(outFile.fd, header.buffer);
      const remain = this.openedFileSize - dataOffset;
      const bufSize = 64 * 1024;
      const buf = new ArrayBuffer(bufSize);
      let copied = 0;
      // 使用独立 seek 定位，避免不同 API 下 read options.offset 语义歧义
      fs.lseek(this.fdSrc, dataOffset, fs.WhenceType.SEEK_SET);
      while (copied < remain) {
        const toRead = Math.min(bufSize, remain - copied);
        const readN = fs.readSync(this.fdSrc, buf, { length: toRead });
        if (readN <= 0) {
          break;
        }
        fs.writeSync(outFile.fd, buf, { length: readN });
        copied += readN;
      }
      // 恢复原 fd 读指针到文件头，避免后续整文件重绑异常
      try {
        fs.lseek(this.fdSrc, 0, fs.WhenceType.SEEK_SET);
      } catch (_e) {
      }
      fs.closeSync(outFile.fd);
      if (copied <= 0) {
        HiLog.e(TAG, `buildAmrSeekSegment copied=0 offset=${dataOffset}`);
        try {
          fs.unlinkSync(path);
        } catch (_e) {
        }
        return false;
      }
      let inFile: fs.File | undefined = undefined;
      try {
        inFile = fs.openSync(path, fs.OpenMode.READ_ONLY);
        this.amrSeekSegmentFd = inFile.fd;
        this.amrSeekSegmentPath = path;
        HiLog.i(TAG, `buildAmrSeekSegment path=${path} srcOffset=${dataOffset} copied=${copied}`);
        return true;
      } catch (e) {
        HiLog.e(TAG, `buildAmrSeekSegment open failed: ${JSON.stringify(e)}`);
        return false;
      } finally {
        if (inFile) {
          fs.closeSync(inFile);
        }
      }
    } catch (e) {
      HiLog.e(TAG, `buildAmrSeekSegment failed: ${JSON.stringify(e)}`);
      this.closeAmrSeekSegment();
      return false;
    }
  }

  /**
   * 串行执行 AVPlayer 生命周期操作。ensureIdle 内部走 unlocked recreate，避免同锁重入死锁。
   */
  private async runSerializedAvPlayerOp<T>(op: () => Promise<T>): Promise<T> {
    const previous: Promise<void> = this.avPlayerLifecycleTail;
    const unlock: AvPlayerLifecycleUnlock = new AvPlayerLifecycleUnlock();
    this.avPlayerLifecycleTail = new Promise<void>((resolve: () => void) => {
      unlock.resolve = resolve;
    });
    try {
      await previous;
      return await op();
    } finally {
      unlock.resolve();
    }
  }

  /**
   * 销毁并惰性重建 AVPlayer（释放失败或非 idle 无法 reset 时自愈）。
   * 子类通过 onAvPlayerRecreated 在重建后重绑资源（视频勿在 idle 写 surfaceId）。
   */
  protected async recreateAvPlayer(): Promise<boolean> {
    return await this.runSerializedAvPlayerOp((): Promise<boolean> => {
      return this.recreateAvPlayerUnlocked();
    });
  }

  /**
   * 重建完成后的钩子（默认空实现）。视频只记录 surface，真正绑定放到 toInitialized。
   */
  protected onAvPlayerRecreated(): void {
  }

  private async recreateAvPlayerUnlocked(): Promise<boolean> {
    HiLog.i(TAG, 'recreateAvPlayer');
    this.avPlayerGeneration++;
    this.unregisterListeners();
    this.avPlayerEnsurePromise = null;
    if (this.avPlayer !== null) {
      try {
        await this.avPlayer.release();
      } catch (err) {
        const error = err as BusinessError;
        HiLog.e(TAG, `recreateAvPlayer release failed message=${error.message}`);
      }
      this.avPlayer = null;
    }
    const created: boolean = await this.ensureAvPlayer();
    if (created) {
      this.onAvPlayerRecreated();
    }
    return created;
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
    return await this.runSerializedAvPlayerOp((): Promise<boolean> => {
      return this.ensureIdleForSetSourceUnlocked();
    });
  }

  private async ensureIdleForSetSourceUnlocked(): Promise<boolean> {
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
      const recreated = await this.recreateAvPlayerUnlocked();
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
      const recreated = await this.recreateAvPlayerUnlocked();
      return recreated && this.isAvPlayerIdle();
    }
    if (this.isAvPlayerIdle()) {
      return true;
    }
    const stuckState = this.avPlayer !== null ? this.avPlayer.state : 'null';
    HiLog.w(TAG, `ensureIdleForSetSource still state=${stuckState}, recreate`);
    const recreated = await this.recreateAvPlayerUnlocked();
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
    this.sourceBindGeneration = this.trackSwitchGeneration;
    this.applyPendingAvPlayerSource();
  }

  setLoop(isLoop: boolean): void {
    HiLog.i(TAG, `setLoop: ${isLoop}`);
    this.isLoop = isLoop;
    if (this.avPlayer !== null) {
      this.avPlayer.loop = this.isLoop;
    }
  }

  setAudioLoopMode(mode: AudioLoopMode): void {
    this.audioLoopMode = mode;
    // 音频单曲循环不走 AVPlayer.loop：AMR 等格式 native loop 可能在真实结尾前重播
    this.setLoop(false);
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

  /**
   * 恢复默认倍速（1.0X），并同步播放页倍速文案。
   */
  resetPlaybackSpeed(): void {
    this.setSpeed(PlayConstants.PLAY_PAGE_PLAY_SPEED);
    if (this.playPage !== null) {
      this.playPage.speedLabel = '1.0X';
      this.playPage.currentSpeedLabel = '1.0X';
    }
  }

  setProgressVisible(visible: boolean) {
    this.isProgressVisible = visible;
    if (visible && this.playProgress) {
      // 控件隐藏期间只更新滑块、不写时间文案；再次显示必须强制同步，
      // 否则会出现滑块已到 98%、时间仍停在 00:04 / 00:00。
      this.syncBoundPlayProgress();
    }
  }

  getPlayState(): number {
    return this.playState;
  }

  /**
   * 暂停后 play 常从 0 起播。若滑条仍锁在松手点，先 CLOSEST 回到 hold，避免再走「片头 → 重试 → 卡顿」。
   */
  private ensureSeekHoldBeforePlay(): void {
    if (this.avPlayer === null || this.isAudioPage) {
      return;
    }
    const hold = this.sliderSeekHoldUntilMs;
    if (hold < 0) {
      return;
    }
    const pos = this.avPlayer.currentTime ?? 0;
    const gap = hold >= pos ? (hold - pos) : (pos - hold);
    if (gap <= this.getMaxSliderSeekRemapGapMs()) {
      return;
    }
    this.sliderSeekClosestRetried = true;
    this.sliderSeekClosestInFlight = true;
    HiLog.w(TAG, `play reseek to hold=${hold} pos=${pos}`);
    this.avPlayer.seek(hold, media.SeekMode.SEEK_CLOSEST);
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
        this.ensureSeekHoldBeforePlay();
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
    // 视频路径不需要此保护：SEEK_PREV_SYNC 让首帧 timeUpdate 总是 < seekTime，
    // 700ms 监控窗口内必然触发 stalled → 重建 AVPlayer → 1.5s 卡顿。
    // 视频 renderer 坏掉的恢复由 on('error') 事件 + recoverAvPlayerAfterError 单独处理。
    if (!this.isAudioPage) {
      return;
    }
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
    // 视频路径不触发该路径（armPlayProgressWatch 提前 return），双保险
    if (!this.isAudioPage) {
      return;
    }
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
    this.rendererNeedsRebuild = false;
    if (this.fdSrc === null) {
      return false;
    }
    // AMR 恢复也走字节偏移，避免 pendingStartMs + 时间戳 seek 再次错位
    this.ensureOpenedFileSizeFromFd();
    if (this.isCurrentAmrMedia() && this.openedFileSize > 0 && resumePositionMs > 0) {
      const fullDuration = this.progressDurationMs > 0 ? this.progressDurationMs :
        (this.amrFullDurationMs > 0 ? this.amrFullDurationMs : resumePositionMs);
      const percent = Math.max(0, Math.min(Constants.ONE_HUNDRED,
        resumePositionMs * Constants.ONE_HUNDRED / Math.max(fullDuration, 1)));
      if (forceRecreate) {
        const recreated = await this.recreateAvPlayer();
        if (!recreated || !this.isAvPlayerIdle()) {
          this.rendererNeedsRebuild = true;
          return false;
        }
      }
      this.wasPlayingBeforeSeek = true;
      await this.seekAmrByFilePercent(percent);
      return this.fdSrc !== null;
    }
    if (resumePositionMs > 0) {
      PlaybackResumeContext.setPendingStartMs(resumePositionMs);
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
    this.avPlayer?.off('durationUpdate');
    this.avPlayer?.off('audioInterrupt');
    this.avPlayer?.off('audioOutputDeviceChangeWithInfo');
    // 注意：切歌自愈 recreateAvPlayer() 也会走到这里，AVSession 回调生命周期独立于 AVPlayer 实例，
    // 绝不能在此注销桥接回调（off() 会把存活会话的 supportedCommands 删空且不会再恢复）。
    // 桥接回调的注销只允许出现在 release() 终端释放路径。
  }

  async release() {
    HiLog.i(TAG, `release`);
    this.avPlayerGeneration++;
    this.cancelPendingInterruptResume();
    this.cancelPlayProgressWatch();
    this.rendererNeedsRebuild = false;
    this.continuousTaskRunning = false;
    this.unregisterListeners();
    // 终端释放时才注销 AVSession 桥接回调（与 AVPlayer 实例重建解耦），
    // 保证切歌 recreateAvPlayer 期间会话 supportedCommands 不被 off() 清空。
    this.audioControlBridge.unregisterCallbacks();
    this.videoControlBridge.unregisterCallbacks();
    this.avPlayer !== null && await this.avPlayer.release();
    this.avPlayer = null;
    this.releaseResource();
    this.syncPlayState(PlayConstants.STATUS_PAUSE);
    this.playPage = null;
    this.playProgress = null;
    this.speed = PlayConstants.PLAY_PAGE_PLAY_SPEED;
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
    this.progressDurationMs = 0;
    this.progressDurationCapMs = 0;
    this.openedFileSize = 0;
    this.amrFileOffset = 0;
    this.amrSeekBaseMs = 0;
    this.amrFullDurationMs = 0;
    this.pendingAmrSeekPlay = false;
    this.amrSeekInFlight = false;
    this.lastSegmentProgressTime = 0;
    this.clearSliderSeekRemap();
    if (this.playProgress) {
      this.playProgress.progressVal = 0;
      this.playProgress.currentTime = '00:00';
    }
  }

  /** 开始一次切歌，返回代际 token 供后续校验 */
  protected beginTrackSwitch(): number {
    this.trackSwitchGeneration++;
    this.suppressTimeUpdateUntilPrepared = true;
    this.markTrackSwitchBusy();
    return this.trackSwitchGeneration;
  }

  /** 判断切歌 token 是否仍为最新（未被更新的切歌请求取代） */
  protected isTrackSwitchCurrent(generation: number): boolean {
    return generation === this.trackSwitchGeneration;
  }

  protected markTrackSwitchBusy(): void {
    this.trackSwitchBusy = true;
  }

  protected markTrackSwitchSettled(): void {
    this.trackSwitchBusy = false;
    this.suppressTimeUpdateUntilPrepared = false;
  }

  /** 子类覆盖：单飞队列里还有更新的待切目标 */
  protected hasPendingTrackSwitch(): boolean {
    return false;
  }

  /**
   * 连点切歌时立即重置进度 UI，并用 FileInfo.duration 预填总时长，保证跟手。
   */
  protected resetProgressUiForSwitch(fileInfo: FileInfo): void {
    this.suppressTimeUpdateUntilPrepared = true;
    this.markTrackSwitchBusy();
    this.currentTime = 0;
    this.lastProgressUpdateTime = 0;
    this.openedFileSize = 0;
    this.amrFileOffset = 0;
    this.amrSeekBaseMs = 0;
    this.amrFullDurationMs = 0;
    this.pendingAmrSeekPlay = false;
    this.amrSeekInFlight = false;
    this.lastSegmentProgressTime = 0;
    this.progressDurationCapMs = 0;
    this.clearSliderSeekRemap();
    this.progressDurationMs = fileInfo.duration > 0 ? fileInfo.duration : 0;
    this.paintSwitchProgressUi();
    if (this.playPage !== null) {
      this.playPage.loadingStatus = LoadingStatus.LOAD_STATE_LOADING;
    }
  }

  /** 新源已绑定 fd，后续 error 按当前代际判断是否迟到 */
  protected markTrackSourceBound(): void {
    this.sourceBindGeneration = this.trackSwitchGeneration;
  }

  private isAvPlayerPlaybackHealthy(): boolean {
    if (this.avPlayer === null) {
      return false;
    }
    const state = this.avPlayer.state;
    return state === 'playing' || state === 'prepared' || state === 'paused' ||
      state === 'initialized' || state === 'completed';
  }

  /** 切歌前重置播放器状态，保留 AVPlayer 实例与监听；失败则重建以保证 idle */
  async prepareForTrackSwitch(): Promise<void> {
    HiLog.i(TAG, 'prepareForTrackSwitch');
    this.suppressTimeUpdateUntilPrepared = true;
    this.markTrackSwitchBusy();
    this.releaseResource();
    const idle = await this.ensureIdleForSetSource();
    if (!idle) {
      HiLog.e(TAG, 'prepareForTrackSwitch failed to reach idle');
    }
    this.resetProgressUiForSwitch(this.saveFileInfo);
  }

  private handleStateChange() {
    if (this.avPlayer === null) {
      return;
    }
    const boundGeneration: number = this.avPlayerGeneration;
    this.avPlayer.on('stateChange', async (state) => {
      // 丢弃已释放旧实例入队的 stateChange，防止旧 initialized 打到新 idle 实例
      if (boundGeneration !== this.avPlayerGeneration) {
        HiLog.w(TAG, `stateChange stale gen=${boundGeneration} current=${this.avPlayerGeneration} ` +
          `state=${state}, skip`);
        return;
      }
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
    const errorBoundGeneration: number = this.avPlayerGeneration;
    this.avPlayer.on('error', (err: BusinessError) => {
      if (errorBoundGeneration !== this.avPlayerGeneration) {
        HiLog.w(TAG, `avPlayer error stale gen=${errorBoundGeneration} ` +
          `current=${this.avPlayerGeneration} code=${err.code}, skip`);
        return;
      }
      const fromInterruptResume = this.pendingInterruptResume;
      const operateNotPermit = err.code === 5400102;
      const staleSwitch = this.trackSwitchGeneration !== this.sourceBindGeneration;
      const playerState = this.avPlayer !== null ? this.avPlayer.state : 'null';
      HiLog.e(TAG, `avPlayer error message: ${err.message}, code: ${err.code} ` +
        `fromInterruptResume=${fromInterruptResume} retry=${this.interruptResumeRetryCount} ` +
        `switchBusy=${this.trackSwitchBusy} staleSwitch=${staleSwitch} state=${playerState}`);
      // 上一首 stop/reset 排队的回调，或尚未绑定当前源
      if (staleSwitch && !fromInterruptResume) {
        HiLog.w(TAG, 'avPlayer error ignored: stale track switch');
        return;
      }
      // 5400102 是状态机错误（切源/写渲染表面/scale），不是文件损坏
      if (operateNotPermit) {
        if (!fromInterruptResume &&
          (this.trackSwitchBusy || this.hasPendingTrackSwitch() || this.isAvPlayerPlaybackHealthy())) {
          HiLog.w(TAG, 'avPlayer 5400102 ignored (not file corrupt)');
          return;
        }
        if (!fromInterruptResume) {
          HiLog.w(TAG, 'avPlayer 5400102 recover without toast');
          this.error();
          void this.recoverAvPlayerAfterError();
          return;
        }
      }
      // 连点切歌时上一首 demux 失败回调可能晚到，此时新曲已在播
      if (this.trackSwitchBusy || this.hasPendingTrackSwitch()) {
        if (this.isAvPlayerPlaybackHealthy() || playerState !== 'error') {
          HiLog.w(TAG, `avPlayer error ignored during track switch state=${playerState}`);
          return;
        }
      }
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
      this.sliderSeekClosestInFlight = false;
      HiLog.i(TAG, `onSeekDone,isSeekDone: ${this.isSeekDone},seekDoneTime: ${seekDoneTime}`);
    });

    // demuxer 可能在 prepared 之后才回调真实/估算 duration；AMR 虚高时常在此时才出现 05:29
    this.avPlayer.on('durationUpdate', (durationMs: number) => {
      if (this.suppressTimeUpdateUntilPrepared) {
        return;
      }
      HiLog.i(TAG, `durationUpdate durationMs=${durationMs} openedSize=${this.openedFileSize}`);
      this.applyResolvedProgressDuration('durationUpdate');
    });

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
    // 旧实例 initialized 入队后 this.avPlayer 可能已换成 idle 新实例
    if (this.avPlayer.state !== 'initialized') {
      HiLog.w(TAG, `toInitialized skip: stale state=${this.avPlayer.state}`);
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
    this.markTrackSwitchSettled();
    this.suppressTimeUpdateUntilPrepared = false;

    this.applyShareInterruptMode();
    this.avPlayer.setVolume(this.volume);
    this.avPlayer.setPlaybackRate(this.resolvePlaybackRate(this.speed));
    // 音频禁用 native loop，单曲循环由 AudioPlayerController.toCompleted 重播，避免 AMR 提前循环
    if (this.isAudioPage) {
      this.isLoop = false;
      this.avPlayer.loop = false;
    } else {
      this.avPlayer.loop = this.isLoop;
    }
    this.progressDurationMs = this.resolveProgressDurationMs();
    this.syncProgressTotalTimeUi();
    HiLog.i(TAG,
      `toPrepared: totalTime=${this.playProgress !== null ? this.playProgress.totalTime : 'null'} ` +
        `progressDuration=${this.progressDurationMs} cap=${this.progressDurationCapMs} ` +
        `avDuration=${this.avPlayer.duration} openedSize=${this.openedFileSize} isAmr=${this.isCurrentAmrMedia()}`);
    // size 可能在 setFdSrc 触发 prepared 之后才写入；若仍虚高再补一次
    if (this.isCurrentAmrMedia() && this.openedFileSize <= 0) {
      this.ensureOpenedFileSizeFromFd();
      this.applyResolvedProgressDuration('toPrepared-retry');
    }
    if (this.amrFileOffset > 0) {
      this.lastSegmentProgressTime = 0;
      this.currentTime = this.amrSeekBaseMs;
      this.lastProgressUpdateTime = this.amrSeekBaseMs;
      this.initProgress(this.amrSeekBaseMs, true);
      HiLog.i(TAG, `toPrepared amr segment baseMs=${this.amrSeekBaseMs} offset=${this.amrFileOffset}`);
    }
    const pendingResumeMs = PlaybackResumeContext.consumePendingStartMs();
    const startPaused = PlaybackResumeContext.consumePendingStartPaused();
    if (pendingResumeMs > 0 && this.amrFileOffset <= 0) {
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
    if (this.amrSeekInFlight) {
      this.amrSeekInFlight = false;
      if (this.pendingAmrSeekPlay) {
        this.pendingAmrSeekPlay = false;
        HiLog.i(TAG, 'toPrepared resume after amr byte seek');
        await this.play();
      } else {
        this.pendingAmrSeekPlay = false;
        HiLog.i(TAG, 'toPrepared stay paused after amr byte seek');
        this.syncPlayState(PlayConstants.STATUS_PAUSE);
        this.updatePlayButtonAccessibility(false);
      }
    } else {
      await this.play();
    }

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
    this.markTrackSwitchSettled();
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
    this.clearSliderSeekRemap();
    this.fillProgressToEnd();
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

  /**
   * 播放结束时将进度条拉满。部分格式（短录音/AMR）末尾 timeUpdate 会跳变或停在 duration 之前，
   * 若仍按整秒取整计算，进度会停在 95%~99%。
   */
  protected fillProgressToEnd(): void {
    if (this.playProgress === null) {
      return;
    }
    const duration = this.getProgressDurationMs();
    const avDuration = this.avPlayer?.duration ?? 0;
    const avTime = this.avPlayer?.currentTime ?? 0;
    const totalTimeText: string = (this.playProgress.totalTime as string) ?? '';
    // AMR 字节 seek 后片段 EOS 即整曲结束：直接拉满，勿按片段时钟回缩总时长
    if (this.amrFileOffset > 0 && this.amrFullDurationMs > 0) {
      this.playProgress.progressVal = Constants.ONE_HUNDRED;
      if (totalTimeText.length > 0) {
        this.playProgress.currentTime = totalTimeText;
      }
      this.lastProgressUpdateTime = this.amrFullDurationMs;
      this.currentTime = this.amrFullDurationMs;
      HiLog.i(TAG,
        `fillProgressToEnd amr segment eos full=${this.amrFullDurationMs} base=${this.amrSeekBaseMs} avTime=${avTime}`);
      return;
    }
    // completed 瞬间 native 常把 currentTime 写成 duration（本日志 319004→329352），
    // 不能 Math.max 采信，否则会吃掉真实结束点，表现为“最后约 10s 被掐断”。
    let position = Math.max(this.currentTime, this.lastProgressUpdateTime);
    if (avDuration <= 0 || avTime + PlayConstants.TIME_UPDATE_NEAR_END_MS < avDuration) {
      position = Math.max(position, avTime);
    }
    const compareDuration = duration > 0 ? duration : avDuration;
    if (this.avPlayer?.state === 'completed' && compareDuration > 0 && position > 0 &&
      position + PlayConstants.TIME_UPDATE_NEAR_END_MS < compareDuration) {
      // 仅 native completed 时修正虚高时长。进度映射提前结束不得回缩总时长。
      const actualSeconds = Math.max(1, Math.ceil(position / Constants.A_THOUSAND));
      const correctedTotal = DateFormatUtil.secondToTime(actualSeconds);
      this.playProgress.totalTime = correctedTotal;
      this.playProgress.currentTime = correctedTotal;
      this.progressDurationMs = Math.max(position, actualSeconds * Constants.A_THOUSAND);
      HiLog.i(TAG,
        `fillProgressToEnd correct totalTime pos=${position} progressDuration=${duration} avDuration=${avDuration} avTime=${avTime}`);
    } else if (totalTimeText.length > 0) {
      this.playProgress.currentTime = totalTimeText;
    }
    this.playProgress.progressVal = Constants.ONE_HUNDRED;
    if (position > 0) {
      this.lastProgressUpdateTime = position;
    }
  }

  /**
   * 从当前 fd 补齐 openedFileSize（部分打开路径未带回 size 时兜底）。
   */
  private ensureOpenedFileSizeFromFd(): void {
    if (this.openedFileSize > 0 || this.fdSrc === null) {
      return;
    }
    try {
      const stat = fs.statSync(this.fdSrc);
      if (stat.size > 0) {
        this.openedFileSize = stat.size;
        this.saveFileInfo.fileSize = stat.size;
        HiLog.i(TAG, `ensureOpenedFileSizeFromFd size=${stat.size}`);
      }
    } catch (e) {
      HiLog.w(TAG, `ensureOpenedFileSizeFromFd failed: ${JSON.stringify(e)}`);
    }
  }

  private isCurrentAmrMedia(): boolean {
    return MediaFormatUtil.isAmrMedia(
      this.saveFileInfo.fileName,
      this.saveFileInfo.uri,
      this.saveFileInfo.filePath.length > 0 ? this.saveFileInfo.filePath : this.saveFileInfo.mediaPath
    );
  }

  private isCurrentMp3Media(): boolean {
    return MediaFormatUtil.isMp3Media(
      this.saveFileInfo.fileName,
      this.saveFileInfo.uri,
      this.saveFileInfo.filePath.length > 0 ? this.saveFileInfo.filePath : this.saveFileInfo.mediaPath
    );
  }

  /**
   * 解析进度条使用的时长：优先可信的 avPlayer.duration；
   * AMR 在 demuxer 按时长码率估算严重偏长时，改用文件大小估算。
   */
  protected resolveProgressDurationMs(): number {
    this.ensureOpenedFileSizeFromFd();
    const avDuration = this.avPlayer?.duration ?? 0;
    const fileSize = this.openedFileSize > 0 ? this.openedFileSize : this.saveFileInfo.fileSize;
    const isAmr = this.isCurrentAmrMedia();
    // 字节 segment 重绑后 avDuration 只是剩余片段，保持整曲时长
    if (isAmr && this.amrFileOffset > 0 && this.amrFullDurationMs > 0) {
      this.progressDurationCapMs = this.amrFullDurationMs;
      HiLog.i(TAG,
        `resolveProgressDuration keep full amrFull=${this.amrFullDurationMs} segmentAv=${avDuration} offset=${this.amrFileOffset}`);
      return this.amrFullDurationMs;
    }
    this.progressDurationCapMs = 0;
    HiLog.i(TAG,
      `resolveProgressDuration begin isAmr=${isAmr} size=${fileSize} opened=${this.openedFileSize} ` +
        `fileSizeField=${this.saveFileInfo.fileSize} av=${avDuration} name=${this.saveFileInfo.fileName}`);
    if (isAmr && fileSize > 0) {
      const amrUpper = MediaFormatUtil.estimateAmrDurationUpperBoundMs(fileSize);
      const amrTypical = MediaFormatUtil.estimateAmrDurationTypicalMs(fileSize);
      // 1) 严重虚高：超过 mode0 上限
      // 2) 轻度虚高：超过 mode7 典型值 + 阈值（本日志 5:29 vs 5:19）
      const severelyInflated = amrUpper > 0 && avDuration > amrUpper * PlayConstants.AMR_DURATION_INFLATE_RATIO;
      const mildlyInflated = amrTypical > 0 && avDuration > amrTypical + PlayConstants.AMR_DURATION_OVER_TYPICAL_MS;
      if (avDuration > 0 && (severelyInflated || mildlyInflated)) {
        const corrected = amrTypical > 0 ? amrTypical : amrUpper;
        this.progressDurationCapMs = amrUpper > 0 ? amrUpper : corrected;
        this.amrFullDurationMs = corrected;
        HiLog.w(TAG,
          `resolveProgressDuration AMR inflated av=${avDuration} typical=${amrTypical} upper=${amrUpper} ` +
            `size=${fileSize} use=${corrected} severe=${severelyInflated} mild=${mildlyInflated}`);
        return corrected;
      }
      if (amrTypical > 0) {
        this.amrFullDurationMs = amrTypical;
      }
      HiLog.i(TAG,
        `resolveProgressDuration AMR keep av=${avDuration} typical=${amrTypical} upper=${amrUpper} size=${fileSize}`);
    } else if (isAmr) {
      HiLog.w(TAG,
        `resolveProgressDuration AMR size unavailable name=${this.saveFileInfo.fileName} uri=${this.saveFileInfo.uri} av=${avDuration}`);
    }
    const metaDuration = this.saveFileInfo.duration;
    if (isAmr && metaDuration > 0 && avDuration > 0 &&
      avDuration > metaDuration * PlayConstants.AMR_DURATION_INFLATE_RATIO) {
      this.progressDurationCapMs = Math.max(metaDuration, MediaFormatUtil.estimateAmrDurationUpperBoundMs(fileSize));
      this.amrFullDurationMs = metaDuration;
      HiLog.w(TAG, `resolveProgressDuration use meta=${metaDuration} av=${avDuration}`);
      return metaDuration;
    }
    // 非 AMR mp3：入库精确时长（帧头扫描）明显长于 demuxer 估算时采用精确值，
    // 避免 VBR 无 Xing 头文件进度条到顶而音频未播完；估算偏长的反向场景
    // 仍由 fillProgressToEnd 在 EOS 时修正，此处不干预
    if (!isAmr && metaDuration > 0 && avDuration > 0 && this.isCurrentMp3Media() &&
      metaDuration > avDuration * PlayConstants.MP3_META_DURATION_PREFER_RATIO) {
      HiLog.w(TAG, `resolveProgressDuration mp3 prefer meta=${metaDuration} av=${avDuration} name=${this.saveFileInfo.fileName}`);
      return metaDuration;
    }
    return avDuration > 0 ? avDuration : (this.progressDurationMs > 0 ? this.progressDurationMs : 0);
  }

  public getProgressDurationMs(): number {
    if (this.progressDurationMs > 0) {
      return this.progressDurationMs;
    }
    return this.avPlayer?.duration ?? 0;
  }

  /** 将 progressDurationMs 同步到进度条总时长文案 */
  private syncProgressTotalTimeUi(): void {
    if (this.playProgress === null || this.progressDurationMs <= 0) {
      return;
    }
    const totalSeconds = Math.floor(this.progressDurationMs / Constants.A_THOUSAND);
    this.playProgress.totalTime = DateFormatUtil.secondToTime(totalSeconds);
  }

  /**
   * 重新解析并应用进度时长（toPrepared / durationUpdate / 打开文件拿到 size 后）。
   */
  private applyResolvedProgressDuration(reason: string): void {
    const previous = this.progressDurationMs;
    const resolved = this.resolveProgressDurationMs();
    if (resolved <= 0) {
      return;
    }
    // 已按真实播放拉长过的时长不要被二次 resolve 缩回去（非 AMR 虚高场景）
    if (previous > 0 && resolved < previous && this.progressDurationCapMs <= 0) {
      HiLog.i(TAG, `applyResolvedProgressDuration skip shrink prev=${previous} resolved=${resolved} reason=${reason}`);
      return;
    }
    this.progressDurationMs = resolved;
    this.syncProgressTotalTimeUi();
    if (previous !== resolved) {
      HiLog.i(TAG,
        `applyResolvedProgressDuration reason=${reason} prev=${previous} now=${resolved} cap=${this.progressDurationCapMs}`);
      if (this.playProgress !== null && this.currentTime > 0) {
        this.initProgress(this.currentTime, true);
      }
    }
  }

  toReleased(): void {
    HiLog.i(TAG, `toReleased`);
  }

  toUnknown(): void {
    HiLog.i(TAG, `toUnknown`);
  }

  timeUpdate(time: number): void {
    if (this.suppressTimeUpdateUntilPrepared) {
      return;
    }
    // time 为 AVPlayer 时间轴；AMR 字节 seek 后是片段相对时间
    const displayTime = this.amrSeekBaseMs + time;
    HiLog.d(TAG, `timeUpdate:${time} display:${displayTime} lastSeg:${this.lastSegmentProgressTime} last:${this.lastProgressUpdateTime}`);
    if (!this.shouldAcceptTimeUpdate(time)) {
      HiLog.w(TAG,
        `time update back, lastSeg:${this.lastSegmentProgressTime} last:${this.lastProgressUpdateTime} time:${time}`);
      // 丢弃异常跳变，且不改 last/UI。否则 isSeekDone 默认 true 时，
      // 结尾 318s→duration 的大跳仍会把进度条提前拉满。
      return;
    }
    if (this.amrFileOffset > 0) {
      this.lastSegmentProgressTime = time;
    }
    // 仅在真正 playing 且进度前进时清除重建标记；暂停后迟到的 timeUpdate 不得清掉
    if (this.playState === PlayConstants.STATUS_START && this.avPlayer?.state === 'playing' &&
      displayTime > this.lastProgressUpdateTime) {
      this.rendererNeedsRebuild = false;
      this.interruptResumeRetryCount = 0;
      this.cancelPlayProgressWatch();
    }
    this.currentTime = displayTime;
    if (this.playProgress) {
      if (this.noteSliderSeekTargetEcho(displayTime)) {
        this.savePlaylistResumeIfNeeded(false);
        return;
      }
      this.resolveSliderSeekLanding(displayTime);
      // CLOSEST 重试尚未落地：保持松手点，避免滑块先跳到片头再跳回
      if (this.isAwaitingSliderSeekLanding()) {
        this.savePlaylistResumeIfNeeded(false);
        return;
      }
      this.dropInsaneSliderSeekRemap(displayTime);
      const uiTime = this.mapSliderSeekDisplayTime(displayTime);
      this.initProgress(uiTime);
      // initProgress 会把 last 写成 uiTime；恢复为解码器时间，后续 timeUpdate 才能继续前进。
      this.lastProgressUpdateTime = displayTime;
    }
    this.savePlaylistResumeIfNeeded(false);
  }

  /**
   * 是否接受本次 timeUpdate：正常前进或轻微回退。
   * 不放行接近结尾的大跨度跳变——日志中曾把 318s 直接跳到 duration(329s)，
   * 进度条提前满格而当前时间尚未走到总时长；未满进度改由 toCompleted → fillProgressToEnd 处理。
   * AMR 字节 seek 后用片段相对时间与 lastSegmentProgressTime 比较。
   */
  private shouldAcceptTimeUpdate(time: number): boolean {
    const last = this.amrFileOffset > 0 ? this.lastSegmentProgressTime : this.lastProgressUpdateTime;
    if (time >= last && time <= last + PlayConstants.TIME_UPDATE_MAX_INTERVAL) {
      return true;
    }
    if (time < last && last - time <= PlayConstants.TIME_UPDATE_BACKWARD_TOLERANCE_MS) {
      return true;
    }
    if (this.isAwaitingSliderSeekLanding() && time < last &&
      last - time <= PlayConstants.TIME_UPDATE_SEEK_KEYFRAME_BACK_MAX_MS) {
      return true;
    }
    return false;
  }

  private isAwaitingSliderSeekLanding(): boolean {
    return this.sliderSeekHoldUntilMs >= 0 && this.sliderSeekBaseActualMs < 0;
  }

  protected clearSliderSeekRemap(): void {
    this.isSeekingFromSlider = false;
    this.sliderSeekHoldUntilMs = -1;
    this.sliderSeekBaseActualMs = -1;
    this.sliderSeekDisplayOriginMs = -1;
    this.sliderSeekClosestRetried = false;
    this.sliderSeekClosestInFlight = false;
  }

  /** 短片按时长 12% 收紧，长片不超过 4s，避免片头关键帧把整段进度映射错位 */
  private getMaxSliderSeekRemapGapMs(): number {
    const duration = this.getProgressDurationMs();
    const byRatio = duration > 0 ?
      duration * PlayConstants.SLIDER_SEEK_REMAP_MAX_DURATION_RATIO :
      PlayConstants.SLIDER_SEEK_REMAP_MAX_GAP_MS;
    const minGap = PlayConstants.TIME_UPDATE_BACKWARD_TOLERANCE_MS * 4;
    let capped = byRatio;
    if (capped < minGap) {
      capped = minGap;
    }
    if (capped > PlayConstants.SLIDER_SEEK_REMAP_MAX_GAP_MS) {
      capped = PlayConstants.SLIDER_SEEK_REMAP_MAX_GAP_MS;
    }
    return capped;
  }

  /**
   * 映射后的 UI 时间若与解码器差过远（残留 remap / 整段拉伸），丢弃映射，跟真实时钟。
   */
  private dropInsaneSliderSeekRemap(displayTime: number): void {
    if (this.sliderSeekBaseActualMs < 0 || this.sliderSeekDisplayOriginMs < 0) {
      return;
    }
    const mapped = this.mapSliderSeekDisplayTime(displayTime);
    const gap = mapped >= displayTime ? (mapped - displayTime) : (displayTime - mapped);
    if (gap > this.getMaxSliderSeekRemapGapMs()) {
      HiLog.w(TAG, `slider seek remap dropped mapped=${mapped} actual=${displayTime} gap=${gap}`);
      this.clearSliderSeekRemap();
    }
  }

  /**
   * seek / seekDone 会回打松手目标（常见为 floor(hold)），比 hold 略小，不是关键帧时钟。
   * 只忽略「等于或略早于」hold 的回打；hold 之后的 timeUpdate 是真正在走，
   * 若也当 echo 丢掉，滑块会冻住再跳（log：1154 被当成 1121 的 echo，卡 1.8s 才到 15%）。
   */
  private noteSliderSeekTargetEcho(displayTime: number): boolean {
    if (!this.isAwaitingSliderSeekLanding()) {
      return false;
    }
    const delta = displayTime - this.sliderSeekHoldUntilMs;
    if (delta <= 0 && delta >= -PlayConstants.TIME_UPDATE_BACKWARD_TOLERANCE_MS) {
      HiLog.i(TAG, `slider seek echo ignored time=${displayTime} hold=${this.sliderSeekHoldUntilMs}`);
      return true;
    }
    return false;
  }

  /**
   * 关键帧明显落后于松手点 → 建立映射；已超过松手点 → 无需映射，跟真实时钟。
   * 落点过远（短视频只有片头关键帧）先 SEEK_CLOSEST 一次，仍过远则放弃映射。
   */
  private resolveSliderSeekLanding(displayTime: number): void {
    if (!this.isAwaitingSliderSeekLanding()) {
      return;
    }
    const hold = this.sliderSeekHoldUntilMs;
    if (displayTime + PlayConstants.TIME_UPDATE_BACKWARD_TOLERANCE_MS >= hold) {
      HiLog.i(TAG, `slider seek exact landing time=${displayTime} hold=${hold}`);
      this.clearSliderSeekRemap();
      return;
    }
    const gap = hold - displayTime;
    if (gap > this.getMaxSliderSeekRemapGapMs()) {
      if (!this.sliderSeekClosestRetried && this.avPlayer !== null && !this.isAudioPage) {
        this.sliderSeekClosestRetried = true;
        this.sliderSeekClosestInFlight = true;
        HiLog.w(TAG, `slider seek landing too far actual=${displayTime} hold=${hold}, retry SEEK_CLOSEST`);
        this.avPlayer.seek(hold, media.SeekMode.SEEK_CLOSEST);
        return;
      }
      if (this.sliderSeekClosestInFlight) {
        HiLog.i(TAG, `slider seek wait closest actual=${displayTime} hold=${hold}`);
        return;
      }
      HiLog.w(TAG, `slider seek remap abandoned actual=${displayTime} hold=${hold}`);
      this.clearSliderSeekRemap();
      return;
    }
    this.sliderSeekBaseActualMs = displayTime;
    this.sliderSeekDisplayOriginMs = hold;
    this.isSeekingFromSlider = false;
    HiLog.i(TAG, `slider seek remap base=${displayTime} origin=${this.sliderSeekDisplayOriginMs}`);
  }

  /**
   * 进度条从松手点继续走，并在片尾与解码器对齐：
   * ui = origin + (actual - base) * (duration - origin) / (duration - base)
   * 避免恒定 GOP 偏移把进度/当前时间提前拉满，而画面仍在播。
   */
  private mapSliderSeekDisplayTime(displayTime: number): number {
    if (this.sliderSeekBaseActualMs < 0 || this.sliderSeekDisplayOriginMs < 0) {
      return displayTime;
    }
    const origin = this.sliderSeekDisplayOriginMs;
    const base = this.sliderSeekBaseActualMs;
    const duration = this.getProgressDurationMs();
    let mapped = origin + (displayTime - base);
    if (duration > base && duration > origin) {
      mapped = origin + (displayTime - base) * (duration - origin) / (duration - base);
    }
    if (mapped < 0) {
      mapped = 0;
    }
    if (duration > 0 && mapped > duration) {
      mapped = duration;
    }
    return mapped;
  }

  /**
   * 获取当前播放进度（毫秒）
   *
   * @returns 播放位置
   */
  public getPlaybackPositionMs(): number {
    if (this.avPlayer !== null && this.avPlayer.currentTime >= 0) {
      return this.amrSeekBaseMs + this.avPlayer.currentTime;
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
    this.markTrackSwitchSettled();
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
    // 冷启动恢复后页面 FileInfo.size 常为 0；同 URI 绑定时保留已 open 的真实大小
    if (fileInfo.fileSize <= 0 && this.openedFileSize > 0 &&
      (this.saveFileInfo.uri.length === 0 || this.saveFileInfo.uri === fileInfo.uri)) {
      fileInfo.fileSize = this.openedFileSize;
      HiLog.i(TAG, `setFileInfo keep openedSize=${this.openedFileSize} fileName=${fileInfo.fileName}`);
    }
    this.saveFileInfo = fileInfo;
    this.isAudioPage = isAudioPage;
  }

  /** 已打开音源的文件字节数（未打开为 0） */
  public getOpenedFileSize(): number {
    return this.openedFileSize;
  }

  /** 打开音源后同步文件大小，供 AMR 等时长校正使用 */
  protected syncOpenedFileSize(fileSize: number): void {
    if (fileSize <= 0) {
      return;
    }
    this.openedFileSize = fileSize;
    this.saveFileInfo.fileSize = fileSize;
    HiLog.i(TAG, `syncOpenedFileSize size=${fileSize}`);
    // prepared 已触发但当时 size 尚未写入时，拿到 size 后立即校正
    if (this.avPlayer !== null && AVPLAYER_PREPARED_STATE.has(this.avPlayer.state)) {
      this.applyResolvedProgressDuration('syncOpenedFileSize');
    }
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
   * ✅ 修复: setSessionInfo/ensureActive 现已解耦 metadata 写入，
   *    ensureActive 内 PLAY state 通过 callback-based setAVPlaybackState 立即派发，
   *    metadata 改走 fire-and-forget 异步链。因此 setSessionInfo 不再被 setAVMetadata 阻塞 3.5s，
   *    整个 await 链路毫秒级返回，避免 CardMediaController 在 metadata 未到位窗口期
   *    先发空通知、随后又视作"已发布"拒绝刷新的问题。
   *
   * 元数据写入已合并到 ensureActive 内的 scheduleMetadataPublish，不再单独二次刷新；
   * 切歌后的封面就绪等场景仍由 extractAlbumCover → updateAvSessionMetadata 异步补刷。
   *
   * @param refreshMetadata 已废弃，保留签名仅为子类 override 兼容
   */
  protected applyControlCenterPlayingState(refreshMetadata: boolean = false): void {
    this.startContinuousTask(this.saveFileInfo);
    void this.syncControlCenterPlayingState();
  }

  private async syncControlCenterPlayingState(): Promise<void> {
    // ensureActive 已解耦 metadata 后, 此 await 毫秒级返回 (PLAY state 在 ensureActive 内部同步派发)。
    try {
      await this.setSessionInfo(AVSessionManager.PlaybackState.PLAYBACK_STATE_PLAY);
    } catch (err) {
      const error = err as BusinessError;
      HiLog.w(TAG, `syncControlCenterPlayingState setSessionInfo failed code=${error.code} message=${error.message}`);
      // 不向上抛, 仍执行下面兜底 PLAY state 写入
    }
    // 兜底再写一次 PLAY state: ensureActive 早退 (uiContext 未绑定/会话失效) 时仍能拿到 PLAY 状态。
    this.setPlaybackState(AVSessionManager.PlaybackState.PLAYBACK_STATE_PLAY);
    this.setPlayingTime(this.avPlayer?.currentTime ?? 0);
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
   * ✅ 修复: ensureActive 内部已将 PLAY state 与 metadata 解耦, 此 await 链路毫秒级返回。
   *    metadata 写入 (setAVMetadata) 在 ensureActive 末尾通过 scheduleMetadataPublish fire-and-forget
   *    异步发出, 即使系统忙 (PublicStorageScanner 阻塞 fd) 也不会卡住 PLAY state 上报。
   *
   * @param state 播放状态
   */
  async setSessionInfo(state: AVSessionManager.PlaybackState) {
    this.ensureControlBridgeBound();
    // 全设备设置 LaunchAbility：冷启/会话重建后点击媒体通知才能稳定回前台
    const launchOptions: PlaybackControlLaunchOptions = { fileInfo: this.saveFileInfo };
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
    // 图片加载传输
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
      this.replayCurrentTrackFromStart();
    }
  }

  skipToNextTrack(): void {
    HiLog.i(TAG, `skipToNextTrack currentTime:${this.currentTime}`);
    if (PlaybackQueueManager.getInstance().skipToNext()) {
      return;
    }
    HiLog.i(TAG, 'skipToNextTrack: no next track in queue, replay current');
    this.replayCurrentTrackFromStart();
  }

  /**
   * 队列仅一首时，上一首/下一首都从开头重播；暂停或结束态也恢复播放。
   */
  protected replayCurrentTrackFromStart(): void {
    if (this.avPlayer === null) {
      return;
    }
    HiLog.i(TAG, 'replayCurrentTrackFromStart');
    this.clearSliderSeekRemap();
    this.currentTime = 0;
    this.lastProgressUpdateTime = 0;
    if (this.playProgress !== null) {
      this.playProgress.progressVal = 0;
      this.playProgress.currentTime = '00:00';
    }
    this.seek(0);
    this.play();
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
        // 按音量键路径：系统音量条已由系统显示，本地不再弹音量面板，
        // 避免与系统音量条同时出现（issue IKBXP0 解决方案）。
        // 手势路径由 VideoPlayerController.onVolumeActionStart 单独显示本地面板。
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

  initProgress(time: number, isForced: boolean = false, isTextForce: boolean = false): void {
    if (this.playProgress === null || (this.avPlayer === null && !isForced)) {
      HiLog.e(TAG, `initProgress avPlayer or playProgress is null`);
      return;
    }
    this.lastProgressUpdateTime = time;
    if (this.isPlayingForPlayState() || isForced) {
      // 拖动期间允许 toFindSecondTime 节流文本；其他路径（timeUpdate/syncBoundPlayProgress）
      // 一律不节流，保证 currentTime/totalTime 在非拖动阶段始终完整显示。
      const allowThrottle = this.isMovingProgressSlider && !this.isSeekingFromSlider;
      if (this.isProgressVisible || isForced || isTextForce) {
        this.toFindSecondTime(time, isTextForce || isForced, allowThrottle);
      } else {
        // 隐藏时仍按秒刷新文案，避免再次显示时滑块与时间严重偏离
        const hiddenSeconds = Math.floor(time / Constants.A_THOUSAND);
        if (hiddenSeconds !== this.nowSeconds) {
          this.toFindSecondTime(time, false, false);
        } else {
          this.nowSeconds = hiddenSeconds;
        }
      }
      if (this.isMovingProgressSlider && !this.isSeekingFromSlider) {
        return;
      }
      const duration = this.getProgressDurationMs();
      // 估算偏短时随真实播放拉长；有 AMR cap 时不得超过 cap，避免撑回 demuxer 虚高时长
      let effectiveDuration = duration;
      if (effectiveDuration > 0 && time > effectiveDuration) {
        const avDuration = this.avPlayer?.duration ?? 0;
        let growCap = avDuration > 0 ? avDuration : time;
        if (this.progressDurationCapMs > 0) {
          growCap = Math.min(growCap, this.progressDurationCapMs);
        }
        const grown = Math.min(time, growCap);
        if (grown > effectiveDuration) {
          this.progressDurationMs = grown;
          effectiveDuration = grown;
          this.syncProgressTotalTimeUi();
          HiLog.i(TAG, `initProgress grow duration to ${effectiveDuration} cap=${this.progressDurationCapMs}`);
        }
      }
      // 按毫秒比例计算进度，避免 floor(秒)/总秒 导致短录音永远到不了 100%
      let progressVal = 0;
      if (effectiveDuration > 0) {
        progressVal = time * Constants.ONE_HUNDRED / effectiveDuration;
        if (progressVal > Constants.ONE_HUNDRED) {
          progressVal = Constants.ONE_HUNDRED;
        }
        if (progressVal < 0) {
          progressVal = 0;
        }
      }
      const currentProgressVal = this.playProgress.progressVal as number;
      const progressDelta = progressVal >= currentProgressVal ?
        (progressVal - currentProgressVal) : (currentProgressVal - progressVal);
      // 细粒度更新，避免虚高总时长下按整百分位刷新造成“卡顿着跳”
      if (!isForced &&
        progressDelta < PlayConstants.PROGRESS_UPDATE_MIN_DELTA &&
        progressVal < Constants.ONE_HUNDRED - PlayConstants.PROGRESS_UPDATE_MIN_DELTA) {
        return;
      }
      this.playProgress.progressVal = progressVal;
      HiLog.i(TAG, `initProgress with progressVal: ${this.playProgress.progressVal}`);
    }
  }

  progressUpdateTime(time: number, isForceText: boolean = false): void {
    if (this.avPlayer === null || this.playProgress === null) {
      HiLog.e(TAG, `progressUpdateTime avPlayer or playProgress is null`);
      return;
    }
    // 拖动期间 Slider.onChange 每秒触发 30~60 次,允许 toFindSecondTime 节流文本文本
    // 避免视频页 videoPlayer 持续渲染挤压下重复写 Text state 导致 Slider 跟手变慢。
    // isForceText 用于 End 时强制刷新文本(seekTime End 走这条路)。
    const allowThrottle = this.isMovingProgressSlider && !this.isSeekingFromSlider;
    this.toFindSecondTime(time, isForceText, allowThrottle);
  }

  toFindSecondTime(time: number, isTextForce: boolean = false, isThrottleAllowed: boolean = false): void {
    if (this.avPlayer === null || this.playProgress === null) {
      HiLog.e(TAG, `toFindSecondTime avPlayer or playProgress is null`);
      return;
    }
    this.lastProgressUpdateTime = time;
    const newNowSeconds = Math.floor(time / Constants.A_THOUSAND);
    // 节流：仅在拖动期间（progressUpdateTime 调用路径）生效。
    // 拖动时 Slider.onChange 每秒触发 30~60 次，currentTime/totalTime 文本按秒跳变，
    // 节流可避免视频页 videoPlayer 持续渲染挤压下重复写 Text state 导致 Slider 跟手变慢。
    // 非拖动阶段（timeUpdate/syncBoundPlayProgress）一律不节流，保证数据完整刷新。
    // isTextForce 用于跨页面/新组件首次绑定时强制刷新（见 syncBoundPlayProgress 注释）。
    if (!isTextForce &&
      isThrottleAllowed &&
      newNowSeconds === this.nowSeconds && typeof this.playProgress.totalTime === 'string') {
      return;
    }
    this.nowSeconds = newNowSeconds;
    let totalSeconds = Math.floor(this.getProgressDurationMs() / Constants.A_THOUSAND);
    this.playProgress.currentTime = DateFormatUtil.secondToTime(newNowSeconds);
    this.playProgress.totalTime = DateFormatUtil.secondToTime(totalSeconds);
  }

  /**
   * AMR 按文件百分比重绑 fdSrc+offset。
   * demuxer 时间戳 seek 常落到错误字节（日志曾 seek 306s → SeekTo offset:4710），拖近结尾会提前 EOS。
   */
  protected async seekAmrByFilePercent(percent: number): Promise<void> {
    this.ensureOpenedFileSizeFromFd();
    if (this.avPlayer === null || this.openedFileSize <= 0) {
      HiLog.e(TAG, `seekAmrByFilePercent skipped: size=${this.openedFileSize}`);
      return;
    }
    const fullDuration = this.getProgressDurationMs();
    if (fullDuration <= 0) {
      HiLog.e(TAG, `seekAmrByFilePercent skipped: fullDuration=${fullDuration}`);
      return;
    }
    const clamped = Math.max(0, Math.min(percent, Constants.ONE_HUNDRED));
    const targetMs = clamped * fullDuration / Constants.ONE_HUNDRED;
    const header = PlayConstants.AMR_HEADER_BYTES;
    const frameBytes = PlayConstants.AMR_NB_MODE7_FRAME_BYTES;
    const fileSize = this.openedFileSize;
    let offset = 0;
    if (clamped > 0) {
      const payload = Math.max(0, fileSize - header);
      let payloadOff = Math.floor((clamped / Constants.ONE_HUNDRED) * payload);
      // 至少保留一帧，避免 offset 顶到文件尾导致立即 EOS
      const maxPayloadOff = Math.max(0, payload - frameBytes);
      payloadOff = Math.min(payloadOff, maxPayloadOff);
      payloadOff = Math.floor(payloadOff / frameBytes) * frameBytes;
      offset = header + payloadOff;
    }
    this.amrFullDurationMs = fullDuration;
    this.amrSeekBaseMs = targetMs;
    this.amrFileOffset = offset;
    this.lastSegmentProgressTime = 0;
    this.lastProgressUpdateTime = targetMs;
    this.currentTime = targetMs;
    const shouldResume = this.wasPlayingBeforeSeek;
    this.pendingAmrSeekPlay = shouldResume;
    this.wasPlayingBeforeSeek = false;
    this.isSeekDone = true;
    this.amrSeekInFlight = true;
    HiLog.i(TAG,
      `seekAmrByFilePercent percent=${clamped} offset=${offset} length=${fileSize - offset} ` +
        `baseMs=${targetMs} full=${fullDuration} resume=${shouldResume}`);
    // 先释放 AVPlayer 对原 fd 的占用，再读文件拷贝临时片段
    const idle = await this.ensureIdleForSetSource();
    if (!idle || this.avPlayer === null) {
      HiLog.e(TAG, 'seekAmrByFilePercent failed to reach idle');
      this.amrFileOffset = 0;
      this.amrSeekBaseMs = 0;
      this.pendingAmrSeekPlay = false;
      this.amrSeekInFlight = false;
      this.closeAmrSeekSegment();
      return;
    }
    if (offset > 0) {
      if (!this.buildAmrSeekSegment(offset)) {
        HiLog.e(TAG, 'seekAmrByFilePercent build segment failed, rebind full file');
        this.closeAmrSeekSegment();
        this.amrFileOffset = 0;
        this.amrSeekBaseMs = 0;
        this.amrSeekInFlight = false;
        this.pendingAmrSeekPlay = false;
        this.applyPendingAvPlayerSource();
        return;
      }
    } else {
      this.closeAmrSeekSegment();
    }
    this.applyPendingAvPlayerSource();
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
    const seekDuration = this.getProgressDurationMs();
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
      // 新一轮拖动开始，清除上一次 End 的进度映射
      this.clearSliderSeekRemap();
      let time = value * seekDuration / Constants.ONE_HUNDRED;
      this.lastProgressUpdateTime = time;
      HiLog.i(TAG, `seek begin, seek mode: ${mode}, seek value: ${value} time:${time}`);
    } else if (mode === SliderChangeMode.Moving || mode === SliderChangeMode.End) {
      if (mode === SliderChangeMode.End) {
        this.isSeekDone = false;
        HiLog.i(TAG, ` SliderChangeMode is End,isSeekDone is ${this.isSeekDone}`);
      }
      let isChangeEnd: boolean = mode === SliderChangeMode.End;
      let time = value * seekDuration / Constants.ONE_HUNDRED;
      // End 时强制刷新进度条 + 文本；Moving 时只更新内部 lastProgressUpdateTime / currentTime，
      // 跳过 toFindSecondTime 节流判断 + DateFormatUtil 调用，避免视频页 videoPlayer 渲染
      // 挤压下每秒数十次 DateFormatUtil.secondToTime 让 Slider 跟手变慢。
      // 松手后 timeUpdate 自然会写正确文本,首次 Enter/syncBoundPlayProgress 走 isTextForce 路径。
      if (isChangeEnd) {
        this.progressUpdateTime(time, true);
      } else {
        this.lastProgressUpdateTime = time;
      }
      this.currentTime = time;
      // 拖动中只刷新进度 UI；连续 seek 会与未完成的上一次冲突（Seeking not completed）导致卡顿
      if (!isChangeEnd) {
        // 用户重新进入拖动，清除上一次 End 的进度映射，
        // 避免之前那次 seek 完成的 timeUpdate 错误地把 progressVal 写回关键帧位置
        this.clearSliderSeekRemap();
        return;
      }
      HiLog.i(TAG, `seek end, seek mode: ${mode}, seek value: ${value}, seekTime: ${time}`);
      this.setPlayingTime(time);
      // isAmr 只在 End 时需要,Moving 算它是浪费（拖动每秒触发 onChange 数十次）
      const isAmr = this.isCurrentAmrMedia() && this.openedFileSize > 0;
      if (isAmr) {
        void this.seekAmrByFilePercent(value);
        return;
      }
      if (isAuidoPage) {
        this.avPlayer.seek(time);
      } else {
        // SEEK_CLOSEST 落在目标附近（可略后）；SEEK_PREV_SYNC 在短视频上常落到片头，
        // 再补 CLOSEST 会让进度条冻结 1s+ 然后跳变。松手点先锁住滑块，落点后再跟时钟。
        this.avPlayer.seek(time, media.SeekMode.SEEK_CLOSEST);
        this.isSeekingFromSlider = true;
        this.sliderSeekHoldUntilMs = time;
        this.sliderSeekDisplayOriginMs = time;
        this.sliderSeekBaseActualMs = -1;
        this.initProgress(time, true);
      }

      if (this.wasPlayingBeforeSeek) {
        const shouldResume = this.wasPlayingBeforeSeek;
        this.wasPlayingBeforeSeek = false;
        this.sliderPlayEvent = setTimeout(() => {
          if (shouldResume && this.avPlayer !== null) {
            this.localStorage?.setOrCreate<boolean>('swiperVideo', undefined);
            this.ensureSeekHoldBeforePlay();
            this.avPlayer.play();
          }
          clearTimeout(this.sliderPlayEvent);
          this.sliderPlayEvent = null;
        }, PlayConstants.PLAY_TIME_INTERVAL);
      }
    }
  }
}
