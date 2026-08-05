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

/** 平板/PC 点击播控卡片回应用时的 LaunchAbility 配置 */
export interface PlaybackControlLaunchOptions {
  fileInfo: FileInfo;
}

/**
 * 系统播控中心（AVSession）桥接：音频/视频各持独立实例，共享同一套封装逻辑。
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
  }

  /**
   * 确保当前媒体类型的 AVSession 已创建并激活，与对端媒体互斥
   *
   * @param state 初始播放状态
   * @param metadata 元数据
   * @param launchOptions 非空时在平板/PC 设置 LaunchAbility
   * @returns 是否为新创建的会话（新会话须由调用方决定是否立即刷元数据）
   */
  async ensureActive(
    state: AVSessionManager.PlaybackState,
    metadata: AVSessionManager.AVMetadata,
    launchOptions?: PlaybackControlLaunchOptions
  ): Promise<boolean> {
    if (!this.uiContext) {
      HiLog.w(TAG, `ensureActive aborted noContext kind=${this.mediaKind}`);
      return false;
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
      const storedSession = AppStorage.get(storageKey) as AVSessionManager.AVSession | undefined;
      if (storedSession !== undefined && this.avSession?.sessionId !== storedSession.sessionId) {
        await this.destroySession(storedSession);
        if (this.avSession) {
          await this.destroySession(this.avSession);
          this.avSession = undefined;
        }
      }
      if (!this.avSession) {
        const sessionType = this.mediaKind === PlaybackMediaKind.AUDIO ? 'audio' : 'video';
        this.avSession = await AVSessionManager.createAVSession(this.uiContext, 'HiPreview', sessionType);
        this.registerCallbacks();
        AppStorage.setOrCreate(storageKey, this.avSession);
        created = true;
        HiLog.i(TAG, `ensureActive created kind=${this.mediaKind}`);
      }
    } catch (err) {
      const error = err as BusinessError;
      HiLog.e(TAG, `ensureActive failed kind=${this.mediaKind} message=${error.message} code=${error.code}`);
      return false;
    }

    if (!this.avSession) {
      return false;
    }

    await this.avSession.activate();
    // 先写元数据再落状态，避免后续仅带 position 的 setAVPlaybackState 把 state 清成 INITIAL(0)
    if (created) {
      await this.publishMetadata(metadata);
    }
    this.updatePlaybackState(state);
    if (launchOptions !== undefined) {
      this.applyLaunchAbility(launchOptions.fileInfo);
    }
    return created;
  }

  /**
   * 刷新播控中心元数据（切歌、封面就绪后调用）
   *
   * @param metadata AVSession 元数据
   */
  async publishMetadata(metadata: AVSessionManager.AVMetadata): Promise<void> {
    if (!this.avSession) {
      return;
    }
    try {
      await this.avSession.setAVMetadata(metadata);
      HiLog.i(TAG, `publishMetadata kind=${this.mediaKind} assetId=${metadata.assetId} title=${metadata.title}`);
    } catch (err) {
      const error = err as BusinessError;
      HiLog.e(TAG, `publishMetadata failed kind=${this.mediaKind} code=${error.code} message=${error.message}`);
    }
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
        HiLog.e(TAG, `updatePlaybackState failed kind=${this.mediaKind} state=${state} code=${err.code}`);
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
        HiLog.e(TAG, `updatePosition failed kind=${this.mediaKind} code=${err.code}`);
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
        HiLog.e(TAG, `updateSpeed failed kind=${this.mediaKind} code=${err.code}`);
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
        HiLog.e(TAG, `reportSeekBuffering failed kind=${this.mediaKind} code=${err.code}`);
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
        HiLog.e(TAG, `completeSeek failed kind=${this.mediaKind} code=${err.code}`);
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
    this.avSession.off('play');
    this.avSession.off('pause');
    this.avSession.off('stop');
    this.avSession.off('seek');
    this.avSession.off('playNext');
    this.avSession.off('playPrevious');
    this.callbacksRegistered = false;
  }

  /**
   * 销毁本会话并清理 AppStorage
   */
  async release(): Promise<void> {
    this.unregisterCallbacks();
    this.ignoreRemotePauseUntilMs = 0;
    this.lastPlaybackState = AVSessionManager.PlaybackState.PLAYBACK_STATE_INITIAL;
    if (!this.avSession) {
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
        HiLog.e(TAG, `reaffirmPlayState failed kind=${this.mediaKind} code=${err.code}`);
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
          bundleName: 'com.ohos.preview_system_app',
          abilityName: 'ApiAbility',
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
