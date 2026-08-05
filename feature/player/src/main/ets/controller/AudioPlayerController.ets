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

import { media } from '@kit.MediaKit';

import { BusinessError } from '@ohos.base';
import { HiLog, MediaPlaybackSourceHelper, MediaSourceAccessState } from '@ohos/common';
import { LoadingStatus } from '@ohos/common/src/main/ets/constants/ui/Constants';
import { AudioOperate, EventName, TaskId } from '@ohos/common/src/main/ets/constants/system/EventName';
import { AudioLoopMode, PlayConstants } from '@ohos/common/src/main/ets/constants/player/PlayConstants';
import { LocalStorageParam } from '@ohos/common/src/main/ets/constants/storage/StorageParam';
import { TraceNameParam } from '@ohos/common/src/main/ets/constants/system/TraceParam';
import FileInfo from '@ohos/common/src/main/ets/model/FileInfo';
import { AVOperationParams, PreviewResultParams } from '@ohos/common/src/main/ets/player/Params';
import { PlaybackQueueManager } from '@ohos/common/src/main/ets/player/PlaybackQueueManager';
import { PlaybackResumeContext } from '@ohos/common/src/main/ets/player/PlaybackResumeContext';
import { appLocalStorage } from '@ohos/common/src/main/ets/storage/AppLocalStorage';
import { MediaPlaybackFileOpener, MediaPlaybackOpenResult } from '@ohos/common/src/main/ets/utils/MediaPlaybackFileOpener';
import { ReportUtil } from '@ohos/common/src/main/ets/utils/ReportUtil';
import hiTraceMeter from '@ohos.hiTraceMeter';
import image from '@ohos.multimedia.image';

import { IPlaybackQueueControlTarget } from '../session/PlaybackControlSessionHelper';
import { showMediaSourceFailureToast } from '../utils/MediaSourceFailureToast';
import { AVPlayerController } from './AVPlayerController';

const TAG: string = 'AudioPlayerController';

export class AudioPlayerController extends AVPlayerController implements IPlaybackQueueControlTarget {
  public fileInfo: FileInfo = new FileInfo('', '', '', 0, 0, 0, 0, 0);
  protected audioPlayerPage: Record<string, Object | null> | null = null;
  private storage: LocalStorage = appLocalStorage;
  private startTime: number = Date.now();
  private fileOpenCount: number = 1;
  private playingUri: string = '';
  /** 媒体库 asset.open 产生的 fd 需 asset.close，与 fs.open 区分 */
  private fdRelease: (() => Promise<void>) | null = null;
  /** 异步封面提取完成后通知 AudioPlayer 刷新 @State */
  private embeddedCoverListener: (() => void) | null = null;
  /** 封面旋转角度（持久化，跨组件生命周期） */
  private _coverAngle: number = 0;
  /** 封面旋转基础角度 */
  private _coverRotationBaseAngle: number = 0;
  /** 封面旋转开始时间戳 */
  private _coverRotationEpochMs: number = 0;
  /** 播放器是否已停止（用于中断异步播放流程，防止幽灵播放） */
  private _isStopped: boolean = false;

  /**
   * 注册封面刷新回调（AudioPlayer 注入，解决异步赋值不触发 UI 刷新）
   *
   * @param listener 封面就绪时调用；传 null 表示解绑
   */
  public setEmbeddedCoverListener(listener: (() => void) | null): void {
    this.embeddedCoverListener = listener;
  }

  /** 通知 View 同步嵌入式封面到 @State */
  private notifyEmbeddedCoverUpdated(): void {
    this.embeddedCoverListener?.();
  }

  /** 获取封面旋转角度 */
  public getCoverAngle(): number {
    return this._coverAngle;
  }

  /** 设置封面旋转角度 */
  public setCoverAngle(angle: number): void {
    this._coverAngle = angle;
  }

  /** 获取封面旋转基础角度 */
  public getCoverRotationBaseAngle(): number {
    return this._coverRotationBaseAngle;
  }

  /** 设置封面旋转基础角度 */
  public setCoverRotationBaseAngle(angle: number): void {
    this._coverRotationBaseAngle = angle;
  }

  /** 获取封面旋转开始时间戳 */
  public getCoverRotationEpochMs(): number {
    return this._coverRotationEpochMs;
  }

  /** 设置封面旋转开始时间戳 */
  public setCoverRotationEpochMs(ms: number): void {
    this._coverRotationEpochMs = ms;
  }

  /**
   * 当前正在播放或已加载的 URI
   *
   * @returns 音源 URI
   */
  public getActiveUri(): string {
    return this.playingUri;
  }

  /**
   * 是否已有活跃 AVPlayer 实例（用于避免重复 firstPlay）
   *
   * @returns 是否活跃
   */
  public hasActivePlayback(): boolean {
    if (this.playingUri.length === 0 || this.avPlayer === null) {
      return false;
    }
    const state = this.avPlayer.state;
    return state !== 'idle' && state !== 'released' && state !== 'error';
  }

  public switchAudioEvent: () => void = () => {
  };

  toCompleted(): void {
    if (this.audioLoopMode === AudioLoopMode.SINGLE) {
      HiLog.i(TAG, 'toCompleted single loop, avPlayer handles repeat');
      return;
    }
    if (this.audioLoopMode === AudioLoopMode.LIST) {
      HiLog.i(TAG, 'toCompleted list loop, play next track');
      if (PlaybackQueueManager.getInstance().advanceForListLoop()) {
        return;
      }
      if (this.avPlayer !== null) {
        this.avPlayer.seek(0);
        this.play();
      }
      return;
    }
    if (this.audioLoopMode === AudioLoopMode.RANDOM) {
      HiLog.i(TAG, 'toCompleted random play, pick next track');
      if (PlaybackQueueManager.getInstance().advanceForRandomPlay()) {
        return;
      }
      if (this.avPlayer !== null) {
        this.avPlayer.seek(0);
        this.play();
      }
      return;
    }
    super.toCompleted();
  }

  /** 下一曲：随机模式下随机选曲，否则顺序下一首 */
  skipToNextTrack(): void {
    HiLog.i(TAG, `skipToNextTrack mode=${this.audioLoopMode}`);
    if (this.audioLoopMode === AudioLoopMode.RANDOM) {
      if (PlaybackQueueManager.getInstance().skipToRandomNext()) {
        return;
      }
    } else if (PlaybackQueueManager.getInstance().skipToNext()) {
      return;
    }
    HiLog.i(TAG, 'skipToNextTrack no next track in queue');
  }

  public operatePath:number = 0;
  public operationSource: number = 0;

  initAudioPlayerPage(audioPlayerPage: Object): void {
    this.audioPlayerPage = audioPlayerPage as Record<string, Object>;
  }

  getCoverPixelMap(): image.PixelMap | null {
    if (this.audioPlayerPage === null || this.audioPlayerPage.audioImage === null) {
      return null;
    }
    return this.audioPlayerPage.audioImage as image.PixelMap;
  }

  /** 切换到新音频：重置 AVPlayer、清封面并加载新音源 */
  async switchToTrack(fileInfo: FileInfo): Promise<void> {
    if (fileInfo.uri.length === 0 || this.playingUri === fileInfo.uri) {
      HiLog.i(TAG, `switchToTrack skipped playingUri=%{private}s target=%{private}s`,
        this.playingUri, fileInfo.uri);
      return;
    }
    // 重置停止标志（允许正常切歌）
    this._isStopped = false;
    const generation = this.beginTrackSwitch();
    HiLog.i(TAG, `switchToTrack gen=${generation}  fileInfo=${JSON.stringify({
      fileName: fileInfo.fileName,
      uri: fileInfo.uri,
      mimeType: fileInfo.mimeType,
      coverUri: fileInfo.coverUri,
      thumbUri: fileInfo.thumbUri
    })}`);

    this.fileInfo = fileInfo;
    this.setFileInfo(fileInfo, true);
    await this.updateAvSessionMetadata();
    this.fileOpenCount = 1;
    this.startTime = Date.now();
    await this.releaseAudioImage();
    if (this.audioPlayerPage !== null) {
      this.audioPlayerPage.audioImage = null;
    }
    if (this.playPage !== null) {
      this.playPage.loadingStatus = LoadingStatus.LOAD_STATE_LOADING;
    }
    this.storage?.setOrCreate<boolean>(LocalStorageParam.LOADING_END, false);
    await this.prepareForTrackSwitch();
    if (!this.isTrackSwitchCurrent(generation)) {
      HiLog.i(TAG, `switchToTrack aborted stale gen=${generation}`);
      return;
    }
    // 再次检查是否已停止
    if (this._isStopped) {
      HiLog.i(TAG, `switchToTrack aborted after prepare: player is stopped`);
      return;
    }
    this.firstPlay(fileInfo.uri, generation);
  }

  constructor() {
    super();
  }

  firstPlay(uri: string, switchGeneration?: number): void {
    // 重置停止标志（允许正常播放）
    this._isStopped = false;
    this.startTime = Date.now();
    hiTraceMeter.startAsyncTrace(hiTraceMeter.HiTraceOutputLevel.COMMERCIAL,
      'AUDIO_PARSE_FILE', TaskId.PARSE_FILE, 'PARSE_FILE');
    HiLog.i(TAG, `uri: %{private}s start read file.`, uri);
    this.openAndPlay(uri, switchGeneration);
  }

  /**
   * 通话挂断/焦点失败后：关闭旧 fd，重新打开音源并 seek 续播。
   *
   * @param resumePositionMs 恢复位置
   * @returns 是否已启动重开流程
   */
  protected async rebindMediaSourceForRecovery(resumePositionMs: number): Promise<boolean> {
    const uri = this.playingUri.length > 0 ? this.playingUri : this.fileInfo.uri;
    if (uri.length === 0) {
      HiLog.e(TAG, 'rebindMediaSourceForRecovery no uri');
      return false;
    }
    HiLog.i(TAG, `rebindMediaSourceForRecovery ms=${resumePositionMs} uri=%{private}s`, uri);
    if (resumePositionMs > 0) {
      PlaybackResumeContext.setPendingStartMs(resumePositionMs);
    }
    this._isStopped = false;
    this.rendererNeedsRebuild = false;
    this.releaseResource();
    // 通话后 AudioRenderer 常卡在 Illegal state，必须重建 AVPlayer 而非 reset
    const recreated = await this.recreateAvPlayer();
    if (!recreated || !this.isAvPlayerIdle()) {
      HiLog.e(TAG, 'rebindMediaSourceForRecovery recreate failed');
      return false;
    }
    await this.openAndPlay(uri);
    return true;
  }

  /**
   * 打开音源并交给 AVPlayer：经 MediaPlaybackFileOpener 转为 fd（AVPlayer 仅支持 fd:// 或网络地址）
   *
   * @param uri 媒体 URI
   * @param switchGeneration 切歌代际，用于丢弃过期异步结果
   */
  private async openAndPlay(uri: string, switchGeneration?: number): Promise<void> {
    // 检查是否已停止（防止幽灵播放）
    if (this._isStopped) {
      HiLog.i(TAG, `openAndPlay aborted: player is stopped`);
      return;
    }
    const beforeOpen: MediaSourceAccessState = MediaPlaybackSourceHelper.checkAccess(
      uri, this.fileInfo.filePath, this.fileInfo.mediaPath);
    HiLog.i(TAG, `openAndPlay precheck state=${beforeOpen} fileName=${this.fileInfo.fileName}`);
    if (beforeOpen === MediaSourceAccessState.MISSING) {
      showMediaSourceFailureToast(MediaSourceAccessState.MISSING);
      this.failOpenSource();
      return;
    }
    const opened: MediaPlaybackOpenResult | null =
      await MediaPlaybackFileOpener.openReadOnly(uri, this.fileInfo.fileName);
    if (switchGeneration !== undefined && !this.isTrackSwitchCurrent(switchGeneration)) {
      if (opened) {
        await opened.release();
      }
      HiLog.i(TAG, `openAndPlay aborted stale gen=${switchGeneration}`);
      return;
    }
    // 再次检查是否已停止（文件打开是异步操作，可能在等待期间被停止）
    if (this._isStopped) {
      if (opened) {
        await opened.release();
      }
      HiLog.i(TAG, `openAndPlay aborted after open: player is stopped`);
      return;
    }
    if (opened) {
      await this.playWithFd(uri, opened, switchGeneration);
      return;
    }
    HiLog.e(TAG, `openAndPlay failed fileName=${this.fileInfo.fileName}`);
    const failureState: MediaSourceAccessState = MediaPlaybackSourceHelper.classifyOpenFailure(
      uri, this.fileInfo.filePath, this.fileInfo.mediaPath, beforeOpen);
    showMediaSourceFailureToast(failureState);
    this.failOpenSource();
  }

  /** 打开音源失败：更新 loading 并走 error 上报 */
  private failOpenSource(): void {
    if (this.playPage !== null) {
      this.playPage.loadingStatus = LoadingStatus.LOAD_STATE_FAILED;
    }
    hiTraceMeter.finishAsyncTrace(hiTraceMeter.HiTraceOutputLevel.COMMERCIAL, 'AUDIO_PARSE_FILE',
      TaskId.PARSE_FILE);
    this.error();
  }

  /**
   * 使用已打开 fd 播放并提取封面
   *
   * @param uri 媒体 URI
   * @param opened 只读打开结果
   * @param switchGeneration 切歌代际
   */
  private async playWithFd(uri: string, opened: MediaPlaybackOpenResult,
    switchGeneration?: number): Promise<void> {
    HiLog.i(TAG, `playWithFd uri=%{private}s fd=${opened.fd}`, uri);
    // 检查是否已停止（防止幽灵播放）
    if (this._isStopped) {
      await opened.release();
      HiLog.i(TAG, `playWithFd aborted: player is stopped`);
      return;
    }
    await this.extractAlbumCover(uri, opened.fd, opened.size);
    if (switchGeneration !== undefined && !this.isTrackSwitchCurrent(switchGeneration)) {
      await opened.release();
      return;
    }
    // 再次检查是否已停止
    if (this._isStopped) {
      await opened.release();
      HiLog.i(TAG, `playWithFd aborted after cover: player is stopped`);
      return;
    }
    const ready = await this.ensureAvPlayer();
    if (!ready) {
      HiLog.e(TAG, `playWithFd ensureAvPlayer failed fileName=${this.fileInfo.fileName}`);
      await opened.release();
      if (this.playPage !== null) {
        this.playPage.loadingStatus = LoadingStatus.LOAD_STATE_FAILED;
      }
      this.error();
      return;
    }
    if (switchGeneration !== undefined && !this.isTrackSwitchCurrent(switchGeneration)) {
      await opened.release();
      return;
    }
    // 最终检查是否已停止
    if (this._isStopped) {
      await opened.release();
      HiLog.i(TAG, `playWithFd aborted before bind: player is stopped`);
      return;
    }
    this.playingUri = uri;
    this.fdRelease = opened.release;
    this.setFdSrc(opened.fd);
    HiLog.i(TAG, `playWithFd bound playingUri=%{private}s fd=${opened.fd}`, uri);
  }

  /**
   * 提取嵌入式专辑封面：fdSrc → setUrlSource 回退，完成后通知 View 刷新
   *
   * @param uri 媒体 URI（fd 失败时用于 setUrlSource）
   * @param fd 可选文件描述符
   * @param fileSize 可选文件大小
   */
  private async extractAlbumCover(uri: string, fd?: number, fileSize?: number): Promise<void> {
    let avMetadataExtractor: media.AVMetadataExtractor | undefined = undefined;
    let pixelMap: image.PixelMap | undefined = undefined;
    try {
      avMetadataExtractor = await media.createAVMetadataExtractor();
      if (fd !== undefined && fileSize !== undefined) {
        const fdSrc: media.AVFileDescriptor = {
          fd: fd,
          offset: 0,
          length: fileSize
        };
        avMetadataExtractor.fdSrc = fdSrc;
      } else {
        avMetadataExtractor.setUrlSource(uri);
      }
      pixelMap = await avMetadataExtractor.fetchAlbumCover();
    } catch (err) {
      const error = err as BusinessError;
      HiLog.w(TAG, `extractAlbumCover fd pass failed message=${error.message} code=${error.code}`);
      if (fd !== undefined && uri.length > 0) {
        try {
          if (avMetadataExtractor) {
            await avMetadataExtractor.release();
          }
          avMetadataExtractor = await media.createAVMetadataExtractor();
          avMetadataExtractor.setUrlSource(uri);
          pixelMap = await avMetadataExtractor.fetchAlbumCover();
        } catch (fallbackErr) {
          const fallbackError = fallbackErr as BusinessError;
          HiLog.w(TAG, `extractAlbumCover uri fallback failed message=${fallbackError.message}`);
        }
      }
    } finally {
      if (avMetadataExtractor) {
        avMetadataExtractor.release();
      }
    }
    if (pixelMap !== undefined && pixelMap !== null && this.audioPlayerPage !== null) {
      this.audioPlayerPage.audioImage = pixelMap;
      HiLog.i(TAG, `extractAlbumCover success fileName=${this.fileInfo.fileName}`);
      this.notifyEmbeddedCoverUpdated();
      // 仅在内嵌封面就绪时补刷播控元数据；标题已在 switchToTrack 或 setSessionInfo 首次创建时写入
      void this.updateAvSessionMetadata();
    } else if (this.audioPlayerPage) {
      this.audioPlayerPage.audioImage = null;
      HiLog.i(TAG, `extractAlbumCover no embedded cover fileName=${this.fileInfo.fileName}`);
      this.notifyEmbeddedCoverUpdated();
    }
  }

  protected getSessionCoverPixelMap(): image.PixelMap | null {
    return this.getCoverPixelMap();
  }

  toInitialized(): void {
    super.toInitialized();
    if (this.playPage !== null) {
      this.playPage.loadingStatus = LoadingStatus.LOAD_STATE_SUCCESS;
      this.storage?.setOrCreate<boolean>('LOADING_END', true);
      HiLog.i(TAG, `successed to success page`);
    }

  }

  toPlaying(): void {
    this.applyControlCenterPlayingState(true);
    super.toPlaying();
  }

  toPaused(): void {
    super.toPaused();
    this.applyControlCenterPausedState();
  }

  async reset(): Promise<void> {
    await this.releaseAudioImage();
    super.reset();
  }

  /**
   * 释放播放器资源：设置停止标志，中断异步播放流程，防止幽灵播放
   */
  async release(): Promise<void> {
    this._isStopped = true;
    HiLog.i(TAG, `release: set _isStopped=true`);
    await super.release();
  }

  releaseResource(): void {
    if (this.fdRelease) {
      this.fdRelease()
        .catch((error: BusinessError) => {
          HiLog.e(TAG, `fdRelease failed message=${error.message} code=${error.code}`);
        });
      this.fdRelease = null;
      this.fdSrc = null;
      this.url = null;
      return;
    }
    super.releaseResource();
  }

  private async releaseAudioImage() {
    if (!this.audioPlayerPage?.audioImage) {
      HiLog.i(TAG, `audioImage is undefined`);
      return;
    }
    try {
      let audioImage: image.PixelMap = this.audioPlayerPage?.audioImage as image.PixelMap;
      await audioImage.release();
      HiLog.i(TAG, `releaseAudioImage audioImage:${audioImage === null}`);
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      HiLog.e(TAG, `audioImage release error, message:${error.message} code:${err.code}`);
    }
  }

  toIdle(): void {
    super.toIdle();
  }

  async toPrepared() {
    await super.toPrepared();
    this.storage?.setOrCreate<boolean>(LocalStorageParam.LOADING_END, true);
    if (this.fileInfo !== null) {
      let eventParams =
        new PreviewResultParams(this.fileInfo.mimeType, 0, Date.now() - this.startTime,
          this.fileInfo.fileSize);
      let recordParams: Record<string, Object> = {
        "mimeType": eventParams.mimeType,
        "openState": eventParams.openState,
        "costTime": eventParams.costTime,
        "fileSize": eventParams.fileSize
      };
      ReportUtil.reportFaultEvent(EventName.DFT_PREVIEW_RESULT, recordParams);
    }
    hiTraceMeter.finishAsyncTrace(hiTraceMeter.HiTraceOutputLevel.COMMERCIAL, TraceNameParam.AUDIO_PARSE_FILE,
      TaskId.PARSE_FILE);
  }

  error() {
    super.error();
    if (this.playPage !== null) {
      this.playPage.loadingStatus = LoadingStatus.LOAD_STATE_FAILED;
      HiLog.e(TAG, `avplayer error to failed page`);
    }
    if (this.fileInfo !== null) {
      let eventParams = new PreviewResultParams(this.fileInfo.mimeType, 2,
        Date.now() - this.startTime, this.fileInfo.fileSize);
      let recordParams: Record<string, Object> = {
        "mimeType": eventParams.mimeType,
        "openState": eventParams.openState,
        "costTime": eventParams.costTime,
        "fileSize": eventParams.fileSize
      };
      ReportUtil.reportFaultEvent(EventName.DFT_PREVIEW_RESULT, recordParams);
    }
    hiTraceMeter.finishAsyncTrace(hiTraceMeter.HiTraceOutputLevel.COMMERCIAL, TraceNameParam.AUDIO_PARSE_FILE,
      TaskId.PARSE_FILE);
  }

  async switchPlayOrPause() {
    await super.switchPlayOrPause();
    if (this.playState === PlayConstants.STATUS_START) {
      this.startContinuousTask(this.fileInfo);
      this.reportBehaviorEvent(AudioOperate.PLAY);
    } else if (this.playState === PlayConstants.STATUS_PAUSE) {
      this.reportBehaviorEvent(AudioOperate.PAUSE);
      this.stopContinuousTask();
    }
  }

  public reportBehaviorEvent(operation: AudioOperate): void {
    if (this.playPage === null) {
      return;
    }
    let params = new AVOperationParams(this.fileInfo.mimeType as string, operation, this.operatePath, this.operationSource);
    let recordParams: Record<string, Object>  = {
      "mimeType" : params.mimeType,
      "operation" : params.operation,
      "operatePath" : params.operatePath,
      "operationSource" : params.operationSource
    };
    ReportUtil.reportBehaviorEvent(EventName.BEV_AUDIO_OPERATION, recordParams);
  }
}
