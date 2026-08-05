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


import { HiLog } from '@ohos/common/src/main/ets/utils/HiLog';
import {
  PlaybackMediaKind,
  PlaybackQueueManager
} from '@ohos/common/src/main/ets/player/PlaybackQueueManager';
import { AudioPlayerController } from '../controller/AudioPlayerController';
import { PlaybackControlSessionHelper } from './PlaybackControlSessionHelper';

const TAG = 'AudioPlaybackSession';

/**
 * 全局音频播放会话：全屏页与迷你播放条共用同一 AudioPlayerController，
 * 最小化时不释放 AVPlayer。
 */
export class AudioPlaybackSession {
  private static instance: AudioPlaybackSession | null = null;
  private readonly controller: AudioPlayerController = new AudioPlayerController();
  private minimizing: boolean = false;
  private queueTrackListenerRegistered: boolean = false;

  private constructor() {
  }

  /**
   * 获取播放会话单例
   *
   * @returns AudioPlaybackSession 实例
   */
  public static getInstance(): AudioPlaybackSession {
    if (AudioPlaybackSession.instance === null) {
      AudioPlaybackSession.instance = new AudioPlaybackSession();
    }
    AudioPlaybackSession.instance.ensureQueueTrackListener();
    return AudioPlaybackSession.instance;
  }

  /**
   * 注册队列切歌监听：后台播控中心切歌时不依赖 ArkUI @Watch，直接切换 AVPlayer 并刷新元数据
   */
  private ensureQueueTrackListener(): void {
    if (this.queueTrackListenerRegistered) {
      return;
    }
    PlaybackQueueManager.getInstance().addTrackChangeListener(this.handleQueueTrackChange);
    this.queueTrackListenerRegistered = true;
    HiLog.i(TAG, 'queue track change listener registered');
  }

  /**
   * 队列当前曲目变更：直接驱动共享控制器切歌（与 UI 层并行，弥补后台 @Watch 不触发）
   *
   * @param uri 当前曲目 URI
   * @param kind 媒体类型
   */
  private handleQueueTrackChange = (uri: string, kind: PlaybackMediaKind): void => {
    PlaybackControlSessionHelper.handleQueueTrackChange(
      TAG, uri, kind, PlaybackMediaKind.AUDIO, this.controller);
  };

  /**
   * 获取共享音频控制器
   *
   * @returns AudioPlayerController 实例
   */
  public getController(): AudioPlayerController {
    return this.controller;
  }

  /**
   * 标记即将最小化（全屏页 aboutToDisappear 时跳过 release）
   *
   * @param minimizing 是否处于最小化流程
   */
  public markMinimizing(minimizing: boolean): void {
    this.minimizing = minimizing;
    HiLog.i(TAG, `markMinimizing minimizing=${minimizing}`);
  }

  /**
   * 全屏页销毁时是否应释放播放器
   *
   * @returns true 表示应 release
   */
  public shouldReleaseOnPageDisappear(): boolean {
    return !this.minimizing;
  }

  /** 最小化流程结束，清除标记 */
  public clearMinimizing(): void {
    this.minimizing = false;
  }

  /**
   * 停止播放并释放 AVPlayer 资源
   */
  public async stopPlayback(): Promise<void> {
    HiLog.i(TAG, 'stopPlayback');
    this.minimizing = false;
    await this.controller.release();
  }
}
