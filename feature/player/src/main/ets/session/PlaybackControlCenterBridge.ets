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


import AVSessionManager from '@ohos.multimedia.avsession';
import wantAgent, { WantAgent } from '@ohos.app.ability.wantAgent';
import wantA from '@ohos.wantAgent';
import common from '@ohos.app.ability.common';
import { BusinessError } from '@ohos.base';
import FileInfo from '@ohos/common/src/main/ets/model/FileInfo';
import { AppStorageParam } from '@ohos/common/src/main/ets/constants/storage/StorageParam';
import { PlaybackMediaKind } from '@ohos/common/src/main/ets/player/PlaybackQueueManager';
import { HiLog } from '@ohos/common/src/main/ets/utils/HiLog';
import { PlaybackControlConstants } from '../constants/PlaybackControlConstants';

const TAG = 'PlaybackControlCenterBridge';

/**
 * 播控中心反向控制播放器时的委托（与具体 AVPlayerController 解耦）
 */
export interface IPlaybackControlHandler {
  onControlPlay(): void;
  onControlPause(): void;
  onControlStop(): void;
  onControlSeek(time: number): void;
  onControlPlayNext(): void;
  onControlPlayPrevious(): void;
}

/** 点击播控卡片 / 媒体通知回应用时的 LaunchAbility 配置 */
export interface PlaybackControlLaunchOptions {
  fileInfo: FileInfo;
}

/**
 * 系统播控中心（AVSession）桥接：音频/视频各持独立实例，共享同一套封装逻辑。
 *
 * 冷启竞态下原生会话可能被系统回收，JS 侧仍持有包装对象；此后 setAVPlaybackState
 * 会报 6600102（session is nullptr），媒体通知永久缺失。本类在探测失效后丢弃句柄并重建。
 */
export class PlaybackControlCenterBridge {
  private readonly mediaKind: PlaybackMediaKind;
  private avSession: AVSessionManager.AVSession | undefined = undefined;
  private handler: IPlaybackControlHandler | undefined = undefined;
  private uiContext: common.UIAbilityContext | undefined = undefined;
  private callbacksRegistered: boolean = false;
  /** 最近一次成功意图上报的播放状态（updatePosition/updateSpeed 必须带回，避免被清成 INITIAL） */
  private lastPlaybackState: AVSessionManager.PlaybackState =
    AVSessionManager.PlaybackState.PLAYBACK_STATE_INITIAL;
  /** 忽略播控中心误发 pause 的截止时间戳（毫秒） */
  private ignoreRemotePauseUntilMs: number = 0;
  /** 最近一次 ensureActive / publishMetadata 的元数据，供失效后恢复 */
  private lastMetadata: AVSessionManager.AVMetadata | undefined = undefined;
  private lastLaunchOptions: PlaybackControlLaunchOptions | undefined = undefined;
  private recovering: boolean = false;
  private lastRecoverAttemptMs: number = 0;
  /** uiContext 未就绪时 ensureActive 早退后的重试计数；bind() 时清零 */
  private uiContextRetryCount: number = 0;

  /**
   * @param mediaKind 音频或视频，决定 AVSession 类型与 AppStorage 键
   */
  constructor(mediaKind: PlaybackMediaKind) {
    this.mediaKind = mediaKind;
  }

  /**
   * 绑定 UI 上下文与播控反向控制委托（每次播放前可重复绑定）
   *
   * @param handler 播放/暂停/seek 等回调
   * @param context UIAbility 上下文
   */
  bind(handler: IPlaybackControlHandler, context: common.UIAbilityContext): void {
    this.handler = handler;
    this.uiContext = context;
    // uiContext 就绪，清零可能挂起的重试计数，避免下一轮正常链路误以为仍在重试
    this.uiContextRetryCount = 0;
  }

  /**
   * 确保当前媒体类型的 AVSession 已创建并激活，与对端媒体互斥。
   * 若本地句柄对应的原生会话已失效（6600102），丢弃后重建。
   *
   * @param state 初始播放状态
   * @param metadata 元数据
   * @param launchOptions 非空时设置 LaunchAbility（点击通知/胶囊回应用）
   * @returns 是否为新创建的会话
   */
  async ensureActive(
    state: AVSessionManager.PlaybackState,
    metadata: AVSessionManager.AVMetadata,
    launchOptions?: PlaybackControlLaunchOptions
  ): Promise<boolean> {
    // 提前缓存 state/metadata/launchOptions：早退分支要拿去调度重试，
    // handleSessionWriteError→recoverActiveSession 也依赖 lastMetadata 重建会话。
    this.lastPlaybackState = state;
    this.lastMetadata = metadata;
    this.lastLaunchOptions = launchOptions;
    if (!this.uiContext) {
      HiLog.w(TAG, `ensureActive aborted noContext kind=${this.mediaKind}`);
      this.scheduleEnsureActiveRetry(state, metadata, launchOptions);
      return false;
    }
    // 高频切歌快速路径：avSession 已存在且仍 alive 时跳过 destroy/create/activate，
    // 只写 metadata + state，避免反复触发系统侧通知销毁重绘节流。
    // 跨媒体切换（音 → 视频 / 对端 avSession 未创建）时 avSession 为 undefined，自动走全链路。
    if (this.avSession !== undefined) {
      try {
        const alive = await this.probeSessionAlive();
        if (alive) {
          HiLog.i(TAG, `ensureActive fast path kind=${this.mediaKind} assetId=${metadata.assetId}`);
          // 幂等自愈：会话存活但回调/命令可能已丢失（异常重建/旧链路 off 过）时重新 on()，
          // 恢复服务端 supportedCommands；callbacksRegistered 为 true 时本调用空转，无副作用。
          this.registerCallbacks();
          // ✅ 修复: PLAY state 与 metadata 解耦。
          //    setAVPlaybackState 是 callback-based, 立即派发不阻塞; metadata 改为 fire-and-forget 异步链 (内置退避重试)。
          //    解决 setAVMetadata 阻塞 3.5s 导致 CardMediaController 先发空 metadata 通知、又视作"已发布"拒绝刷新的问题。
          this.updatePlaybackState(state);
          if (launchOptions !== undefined) {
            this.applyLaunchAbility(launchOptions.fileInfo);
          }
          this.scheduleMetadataPublish(metadata);
          return false;
        }
        this.invalidateDeadSession('ensureActive_probe_dead');
      } catch (err) {
        HiLog.w(TAG, `ensureActive fast path probe failed kind=${this.mediaKind}`);
        // probe 异常时落回全链路，依靠 createSessionWithRetry 重建
      }
    }
    let created = false;
    const storageKey = this.resolveStorageKey();
    const oppositeKey = this.resolveOppositeStorageKey();
    try {
      const oppositeSession = AppStorage.get(oppositeKey) as AVSessionManager.AVSession | undefined;
      if (oppositeSession !== undefined) {
        await this.destroySession(oppositeSession);
        AppStorage.setOrCreate(oppositeKey, undefined);
        HiLog.i(TAG, `ensureActive destroyedOpposite kind=${this.mediaKind}`);
      }
      if (this.avSession !== undefined) {
        const alive = await this.probeSessionAlive();
        if (!alive) {
          this.invalidateDeadSession('ensureActive_probe');
        }
      }
      const storedSession = AppStorage.get(storageKey) as AVSessionManager.AVSession | undefined;
      if (storedSession !== undefined && this.avSession?.sessionId !== storedSession.sessionId) {
        await this.destroySession(storedSession);
        if (this.avSession) {
          await this.destroySession(this.avSession);
          this.avSession = undefined;
          this.callbacksRegistered = false;
        }
      }
      if (this.avSession === undefined) {
        created = await this.createSessionWithRetry(storageKey);
      }
    } catch (err) {
      const error = err as BusinessError;
      HiLog.e(TAG, `ensureActive failed kind=${this.mediaKind} message=${error.message} code=${error.code}`);
      this.invalidateDeadSession('ensureActive_catch');
      return false;
    }

    if (this.avSession === undefined) {
      return false;
    }

    try {
      await this.avSession.activate();
    } catch (err) {
      const error = err as BusinessError;
      HiLog.e(TAG, `ensureActive activate failed kind=${this.mediaKind} code=${error.code}`);
      if (!this.isSessionGoneError(error)) {
        return false;
      }
      this.invalidateDeadSession('ensureActive_activate');
      created = await this.createSessionWithRetry(storageKey);
      if (this.avSession === undefined) {
        return false;
      }
      try {
        await this.avSession.activate();
      } catch (retryErr) {
        const retryError = retryErr as BusinessError;
        HiLog.e(TAG,
          `ensureActive activate retry failed kind=${this.mediaKind} code=${retryError.code}`);
        this.invalidateDeadSession('ensureActive_activate_retry');
        return false;
      }
    }

    // 每次激活都写元数据：冷启/恢复后仅靠 state 不足以让 SystemUI 发媒体通知。
    // ✅ 修复: 与快速路径一致, PLAY state 先于 metadata 派发 (setAVPlaybackState callback-based 不阻塞);
    //    metadata 走 fire-and-forget 异步链, 避免 setAVMetadata 阻塞 ensureActive 整体 await 链。
    this.updatePlaybackState(state);
    if (launchOptions !== undefined) {
      this.applyLaunchAbility(launchOptions.fileInfo);
    }
    this.scheduleMetadataPublish(metadata);
    return created;
  }

  /**
   * 刷新播控中心元数据（切歌、封面就绪后调用）
   *
   * @param metadata AVSession 元数据
   */
  async publishMetadata(metadata: AVSessionManager.AVMetadata): Promise<void> {
    this.lastMetadata = metadata;
    if (!this.avSession) {
      return;
    }
    // ✅ 修复: 临时性失败 (系统忙/并发写) 不应被视作写失败丢消息;
    //    退避重试 N 次, session-gone (6600102) 仍走 handleSessionWriteError 重建会话。
    const maxAttempts = PlaybackControlConstants.METADATA_PUBLISH_RETRY_TIMES;
    for (let attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        await this.avSession.setAVMetadata(metadata);
        HiLog.i(TAG,
          `publishMetadata kind=${this.mediaKind} assetId=${metadata.assetId} ` +
            `title=${metadata.title} attempt=${attempt}`);
        return;
      } catch (err) {
        const error = err as BusinessError;
        HiLog.w(TAG,
          `publishMetadata failed kind=${this.mediaKind} attempt=${attempt}/${maxAttempts} ` +
            `code=${error.code} message=${error.message}`);
        if (this.isSessionGoneError(error)) {
          // 会话失效: 走重建路径, 不再重试 (重建后由 ensureActive/recoverActiveSession 补刷)
          this.handleSessionWriteError('publishMetadata', error);
          return;
        }
        if (attempt < maxAttempts) {
          await this.delayMs(PlaybackControlConstants.METADATA_PUBLISH_RETRY_DELAY_MS * attempt);
          // 退避期间会话可能被回收, 重新校验避免在 dead session 上重试
          if (this.avSession === undefined) {
            return;
          }
        }
      }
    }
    HiLog.e(TAG, `publishMetadata exhausted retries kind=${this.mediaKind} assetId=${metadata.assetId}`);
  }

  /**
   * fire-and-forget 写入元数据, 不阻塞 ensureActive 调用方。
   * 与 updatePlaybackState 解耦: PLAY state 先发 (callback-based 立即派发),
   * metadata 后写 (Promise + 内置重试), 系统侧 CardMediaController 不会再
   * 在 metadata 未到位时先用空 metadata 抢先发通知。
   *
   * @param metadata AVSession 元数据
   */
  private scheduleMetadataPublish(metadata: AVSessionManager.AVMetadata): void {
    this.lastMetadata = metadata;
    if (!this.avSession) {
      HiLog.w(TAG, `scheduleMetadataPublish skipped no avSession kind=${this.mediaKind}`);
      return;
    }
    // 启动异步链, 不 await。失败已被内部 try/catch 隔离, 此处 catch 仅兜住
    // publishMetadata 自身抛出的非 BusinessError (例如代码 bug 触发的同步异常)。
    void this.publishMetadata(metadata).catch((err: Error) => {
      HiLog.e(TAG,
        `scheduleMetadataPublish unhandled kind=${this.mediaKind} message=${err.message}`);
    });
  }

  /**
   * 同步播放状态到播控中心
   *
   * @param state 播放状态枚举
   */
  updatePlaybackState(state: AVSessionManager.PlaybackState): void {
    this.lastPlaybackState = state;
    if (state === AVSessionManager.PlaybackState.PLAYBACK_STATE_PLAY) {
      this.armRemotePauseGuard();
    }
    const playbackState: AVSessionManager.AVPlaybackState = {
      state: state,
    };
    this.avSession?.setAVPlaybackState(playbackState, (err: BusinessError) => {
      if (err) {
        this.handleSessionWriteError(`updatePlaybackState state=${state}`, err);
      }
    });
  }

  /**
   * 同步播放进度到播控中心。
   * 必须携带 lastPlaybackState：仅写 position 时底层会把 state 记为 -1 并落到 INITIAL(0)，
   * 播控中心据此误显播放按钮并可能误发 pause。
   *
   * @param time 当前位置（毫秒）
   */
  updatePosition(time: number): void {
    const playbackState: AVSessionManager.AVPlaybackState = {
      state: this.lastPlaybackState,
      position: {
        elapsedTime: time,
        updateTime: new Date().getTime(),
      },
    };
    this.avSession?.setAVPlaybackState(playbackState, (err: BusinessError) => {
      if (err) {
        this.handleSessionWriteError('updatePosition', err);
      }
    });
  }

  /**
   * 同步倍速到播控中心（同样必须带回当前 state，避免被清成 INITIAL）
   *
   * @param speed 倍速值
   */
  updateSpeed(speed: number): void {
    const playbackState: AVSessionManager.AVPlaybackState = {
      state: this.lastPlaybackState,
      speed: speed,
    };
    this.avSession?.setAVPlaybackState(playbackState, (err: BusinessError) => {
      if (err) {
        this.handleSessionWriteError('updateSpeed', err);
      }
    });
  }

  reportSeekBuffering(): void {
    this.lastPlaybackState = AVSessionManager.PlaybackState.PLAYBACK_STATE_BUFFERING;
    const playbackState: AVSessionManager.AVPlaybackState = {
      state: AVSessionManager.PlaybackState.PLAYBACK_STATE_BUFFERING,
    };
    this.avSession?.setAVPlaybackState(playbackState, (err: BusinessError) => {
      if (err) {
        this.handleSessionWriteError('reportSeekBuffering', err);
      }
    });
  }

  /**
   * seek 完成后恢复 PLAY 状态并触发播放
   *
   * @param time 目标位置（毫秒）
   */
  completeSeek(time: number): void {
    this.lastPlaybackState = AVSessionManager.PlaybackState.PLAYBACK_STATE_PLAY;
    this.armRemotePauseGuard();
    const playbackState: AVSessionManager.AVPlaybackState = {
      state: AVSessionManager.PlaybackState.PLAYBACK_STATE_PLAY,
      position: {
        elapsedTime: time,
        updateTime: new Date().getTime(),
      },
    };
    this.avSession?.setAVPlaybackState(playbackState, (err: BusinessError) => {
      if (err) {
        this.handleSessionWriteError('completeSeek', err);
        return;
      }
      this.handler?.onControlPlay();
    });
  }

  /** 注销播控回调监听 */
  unregisterCallbacks(): void {
    if (!this.avSession || !this.callbacksRegistered) {
      return;
    }
    try {
      this.avSession.off('play');
      this.avSession.off('pause');
      this.avSession.off('stop');
      this.avSession.off('seek');
      this.avSession.off('playNext');
      this.avSession.off('playPrevious');
    } catch (e) {
      HiLog.w(TAG, `unregisterCallbacks ignored kind=${this.mediaKind} cause=${JSON.stringify(e)}`);
    }
    this.callbacksRegistered = false;
  }

  /**
   * 销毁本会话并清理 AppStorage
   */
  async release(): Promise<void> {
    this.unregisterCallbacks();
    this.ignoreRemotePauseUntilMs = 0;
    this.lastPlaybackState = AVSessionManager.PlaybackState.PLAYBACK_STATE_INITIAL;
    this.lastMetadata = undefined;
    this.lastLaunchOptions = undefined;
    this.recovering = false;
    this.uiContextRetryCount = 0;
    if (!this.avSession) {
      AppStorage.setOrCreate(this.resolveStorageKey(), undefined);
      return;
    }
    await this.destroySession(this.avSession);
    this.avSession = undefined;
    AppStorage.setOrCreate(this.resolveStorageKey(), undefined);
    HiLog.i(TAG, `release kind=${this.mediaKind}`);
  }

  private resolveStorageKey(): string {
    return this.mediaKind === PlaybackMediaKind.AUDIO ?
      AppStorageParam.AUDIO_AV_SESSION : AppStorageParam.VIDEO_AV_SESSION;
  }

  private resolveOppositeStorageKey(): string {
    return this.mediaKind === PlaybackMediaKind.AUDIO ?
      AppStorageParam.VIDEO_AV_SESSION : AppStorageParam.AUDIO_AV_SESSION;
  }

  private isSessionGoneError(err: BusinessError): boolean {
    return err !== undefined && err.code === PlaybackControlConstants.ERR_SESSION_NOT_EXIST;
  }

  /**
   * 探测本地会话是否仍可 activate；失败则视为原生侧已回收。
   */
  private async probeSessionAlive(): Promise<boolean> {
    if (this.avSession === undefined) {
      return false;
    }
    try {
      await this.avSession.activate();
      return true;
    } catch (err) {
      const error = err as BusinessError;
      HiLog.w(TAG, `probeSessionAlive dead kind=${this.mediaKind} code=${error.code}`);
      return false;
    }
  }

  /**
   * 丢弃已失效的 JS 会话句柄（不再 destroy，避免二次 6600102）。
   *
   * @param reason 失效来源
   */
  private invalidateDeadSession(reason: string): void {
    HiLog.w(TAG, `invalidateDeadSession kind=${this.mediaKind} reason=${reason}`);
    this.unregisterCallbacks();
    this.avSession = undefined;
    this.callbacksRegistered = false;
    AppStorage.setOrCreate(this.resolveStorageKey(), undefined);
  }

  private async createSessionWithRetry(storageKey: string): Promise<boolean> {
    if (!this.uiContext) {
      return false;
    }
    const sessionType = this.mediaKind === PlaybackMediaKind.AUDIO ? 'audio' : 'video';
    const maxAttempts = PlaybackControlConstants.SESSION_CREATE_RETRY_TIMES;
    for (let attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        this.avSession = await AVSessionManager.createAVSession(this.uiContext, 'HiPreview', sessionType);
        this.callbacksRegistered = false;
        this.registerCallbacks();
        AppStorage.setOrCreate(storageKey, this.avSession);
        HiLog.i(TAG, `ensureActive created kind=${this.mediaKind} attempt=${attempt}`);
        return true;
      } catch (err) {
        const error = err as BusinessError;
        HiLog.e(TAG,
          `createAVSession failed kind=${this.mediaKind} attempt=${attempt}/${maxAttempts} ` +
            `code=${error.code} message=${error.message}`);
        this.avSession = undefined;
        if (attempt < maxAttempts) {
          const delay =
            PlaybackControlConstants.SESSION_CREATE_RETRY_BASE_DELAY_MS * attempt;
          await this.delayMs(delay);
        }
      }
    }
    return false;
  }

  private delayMs(ms: number): Promise<void> {
    return new Promise<void>((resolve: () => void) => {
      setTimeout((): void => {
        resolve();
      }, ms);
    });
  }

  /**
   * uiContext 未绑定时调度 ensureActive 重试；指数退避，UI_CONTEXT_RETRY_TIMES 上限。
   * 重试用同一组 metadata/launchOptions/state，避免上游重新构建。
   */
  private scheduleEnsureActiveRetry(
    state: AVSessionManager.PlaybackState,
    metadata: AVSessionManager.AVMetadata,
    launchOptions?: PlaybackControlLaunchOptions
  ): void {
    if (this.uiContextRetryCount >= PlaybackControlConstants.UI_CONTEXT_RETRY_TIMES) {
      HiLog.e(TAG,
        `ensureActive retry exhausted kind=${this.mediaKind} count=${this.uiContextRetryCount}`);
      return;
    }
    this.uiContextRetryCount++;
    const attempt = this.uiContextRetryCount;
    const delay = PlaybackControlConstants.UI_CONTEXT_RETRY_DELAY_MS * attempt;
    HiLog.i(TAG,
      `ensureActive scheduled retry kind=${this.mediaKind} attempt=${attempt}/${PlaybackControlConstants.UI_CONTEXT_RETRY_TIMES} delay=${delay}ms`);
    setTimeout((): void => {
      // 仍未绑定：递归调度下一次重试（counter 已增加，下次会因到顶退出）
      if (!this.uiContext) {
        HiLog.w(TAG, `ensureActive retry still noContext kind=${this.mediaKind} attempt=${attempt}`);
        this.scheduleEnsureActiveRetry(state, metadata, launchOptions);
        return;
      }
      // 已绑定：清零计数（本次成功链路结束），重新走正常 ensureActive
      this.uiContextRetryCount = 0;
      void this.ensureActive(state, metadata, launchOptions);
    }, delay);
  }

  /**
   * 写会话失败时：若为 6600102 则丢弃句柄；播放态下冷却后自动重建。
   */
  private handleSessionWriteError(op: string, err: BusinessError): void {
    HiLog.e(TAG, `${op} failed kind=${this.mediaKind} code=${err.code}`);
    if (!this.isSessionGoneError(err)) {
      return;
    }
    this.invalidateDeadSession(op);
    if (this.lastPlaybackState === AVSessionManager.PlaybackState.PLAYBACK_STATE_PLAY) {
      void this.recoverActiveSession();
    }
  }

  private async recoverActiveSession(): Promise<void> {
    const now = new Date().getTime();
    if (this.recovering) {
      return;
    }
    if (now - this.lastRecoverAttemptMs < PlaybackControlConstants.SESSION_RECOVER_COOLDOWN_MS) {
      HiLog.w(TAG, `recoverActiveSession skipped cooldown kind=${this.mediaKind}`);
      return;
    }
    if (!this.uiContext || this.lastMetadata === undefined) {
      HiLog.w(TAG, `recoverActiveSession aborted noCache kind=${this.mediaKind}`);
      return;
    }
    this.recovering = true;
    this.lastRecoverAttemptMs = now;
    try {
      HiLog.w(TAG, `recoverActiveSession begin kind=${this.mediaKind}`);
      const created = await this.ensureActive(
        AVSessionManager.PlaybackState.PLAYBACK_STATE_PLAY,
        this.lastMetadata,
        this.lastLaunchOptions
      );
      HiLog.i(TAG, `recoverActiveSession done kind=${this.mediaKind} created=${created}`);
    } catch (err) {
      const error = err as BusinessError;
      HiLog.e(TAG, `recoverActiveSession failed kind=${this.mediaKind} code=${error.code}`);
    } finally {
      this.recovering = false;
    }
  }

  private registerCallbacks(): void {
    if (!this.avSession || this.callbacksRegistered) {
      return;
    }
    this.avSession.on('play', () => {
      HiLog.i(TAG, `onPlay kind=${this.mediaKind}`);
      this.handler?.onControlPlay();
    });
    this.avSession.on('pause', () => {
      if (this.shouldIgnoreRemotePause()) {
        HiLog.w(TAG, `onPause ignored kind=${this.mediaKind} guard active, re-affirm PLAY`);
        this.reaffirmPlayState();
        return;
      }
      HiLog.i(TAG, `onPause kind=${this.mediaKind}`);
      this.handler?.onControlPause();
    });
    this.avSession.on('stop', () => {
      HiLog.i(TAG, `onStop kind=${this.mediaKind}`);
      this.handler?.onControlStop();
    });
    this.avSession.on('seek', (time: number) => {
      HiLog.i(TAG, `onSeek kind=${this.mediaKind} time=${time}`);
      this.handler?.onControlSeek(time);
    });
    this.avSession.on('playNext', () => {
      HiLog.i(TAG, `onPlayNext kind=${this.mediaKind}`);
      this.handler?.onControlPlayNext();
    });
    this.avSession.on('playPrevious', () => {
      HiLog.i(TAG, `onPlayPrevious kind=${this.mediaKind}`);
      this.handler?.onControlPlayPrevious();
    });
    this.callbacksRegistered = true;
  }

  /**
   * 上报 PLAY 后短暂忽略播控中心 pause，规避系统媒体卡片初始化误触。
   */
  private armRemotePauseGuard(): void {
    this.ignoreRemotePauseUntilMs =
      new Date().getTime() + PlaybackControlConstants.REMOTE_PAUSE_GUARD_MS;
  }

  private shouldIgnoreRemotePause(): boolean {
    return this.lastPlaybackState === AVSessionManager.PlaybackState.PLAYBACK_STATE_PLAY &&
      new Date().getTime() < this.ignoreRemotePauseUntilMs;
  }

  /** 回写 PLAY 但不延长 ignore 窗口，避免与播控中心互相顶状态 */
  private reaffirmPlayState(): void {
    this.lastPlaybackState = AVSessionManager.PlaybackState.PLAYBACK_STATE_PLAY;
    const playbackState: AVSessionManager.AVPlaybackState = {
      state: AVSessionManager.PlaybackState.PLAYBACK_STATE_PLAY,
    };
    this.avSession?.setAVPlaybackState(playbackState, (err: BusinessError) => {
      if (err) {
        this.handleSessionWriteError('reaffirmPlayState', err);
      }
    });
  }

  private applyLaunchAbility(fileInfo: FileInfo): void {
    if (!this.avSession) {
      return;
    }
    const wantAgentInfo: wantAgent.WantAgentInfo = PlaybackControlCenterBridge.buildWantAgentInfo(fileInfo);
    wantAgent.getWantAgent(wantAgentInfo)
      .then((agent: WantAgent) => {
        this.avSession?.setLaunchAbility(agent)
          .then(() => {
            HiLog.i(TAG, `setLaunchAbility success kind=${this.mediaKind}`);
          })
          .catch((err: BusinessError) => {
            HiLog.e(TAG, `setLaunchAbility failed kind=${this.mediaKind} code=${err.code}`);
          });
      })
      .catch((err: BusinessError) => {
        HiLog.e(TAG, `getWantAgent failed kind=${this.mediaKind} code=${err.code}`);
      });
  }

  private async destroySession(session: AVSessionManager.AVSession): Promise<void> {
    try {
      const sessionId = session.sessionId;
      await session.destroy();
      HiLog.i(TAG, `destroySession kind=${this.mediaKind} sessionId=${sessionId}`);
    } catch (e) {
      HiLog.e(TAG, `destroySession failed kind=${this.mediaKind} cause=${JSON.stringify(e)}`);
    }
  }

  /**
   * 构建后台长任务 / LaunchAbility 共用的 WantAgentInfo
   *
   * @param fileInfo 当前媒体文件
   * @returns WantAgentInfo
   */
  static buildWantAgentInfoForFile(fileInfo: FileInfo): wantAgent.WantAgentInfo {
    return PlaybackControlCenterBridge.buildWantAgentInfo(fileInfo);
  }

  private static buildWantAgentInfo(fileInfo: FileInfo): wantAgent.WantAgentInfo {
    return {
      wants: [
        {
          deviceId: '',
          bundleName: PlaybackControlConstants.APP_BUNDLE_NAME,
          abilityName: PlaybackControlConstants.MAIN_ABILITY_NAME,
          action: 'ohos.want.action.viewData',
          uri: fileInfo.uri,
          type: fileInfo.mimeType,
        }
      ],
      actionType: wantAgent.OperationType.START_ABILITY,
      requestCode: 1,
      operationType: wantA.OperationType.START_ABILITIES,
    };
  }
}
