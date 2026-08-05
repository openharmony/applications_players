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
import { VideoPlayerController } from '../controller/VideoPlayerController';
import { PlaybackControlSessionHelper } from './PlaybackControlSessionHelper';

const TAG = 'VideoPlaybackSession';

/** 系统锁屏时 PiP 协调回调（由 VideoPlayPage 绑定 VideoPipViewModel） */
export interface IVideoPipSystemLockDelegate {
  onSystemScreenLocked(): void;
  onSystemScreenUnlocked(isAppInBackground: boolean): void;
}

/**
 * 全局视频播放会话：绑定当前 VideoPlayerController，供后台播控中心切歌时直接驱动 AVPlayer。
 */
export class VideoPlaybackSession {
  private static instance: VideoPlaybackSession | null = null;
  private activeController: VideoPlayerController | null = null;
  private pipSystemLockDelegate: IVideoPipSystemLockDelegate | null = null;
  private queueTrackListenerRegistered: boolean = false;

  private constructor() {
  }

  /**
   * 获取视频播放会话单例
   *
   * @returns VideoPlaybackSession 实例
   */
  public static getInstance(): VideoPlaybackSession {
    if (VideoPlaybackSession.instance === null) {
      VideoPlaybackSession.instance = new VideoPlaybackSession();
    }
    VideoPlaybackSession.instance.ensureQueueTrackListener();
    return VideoPlaybackSession.instance;
  }

  /**
   * 绑定当前视频页控制器（initPlayPage 时注册）
   *
   * @param controller 视频控制器
   */
  public bindController(controller: VideoPlayerController): void {
    this.activeController = controller;
    HiLog.i(TAG, `bindController uri=${controller.getActiveUri()}`);
  }

  /**
   * 获取当前绑定的视频控制器（来电中断等全局场景使用）
   */
  public getActiveController(): VideoPlayerController | null {
    return this.activeController;
  }

  /**
   * 解绑视频控制器（release 或页面销毁时）
   *
   * @param controller 待解绑的控制器
   */
  public unbindController(controller: VideoPlayerController): void {
    if (this.activeController !== controller) {
      return;
    }
    this.activeController = null;
    HiLog.i(TAG, 'unbindController');
  }

  /**
   * 绑定 PiP 系统锁屏协调器（视频页 aboutToAppear 时注册）
   *
   * @param delegate PiP 锁屏/解锁回调
   */
  public bindPipSystemLockDelegate(delegate: IVideoPipSystemLockDelegate): void {
    this.pipSystemLockDelegate = delegate;
    HiLog.i(TAG, 'bindPipSystemLockDelegate');
  }

  /**
   * 解绑 PiP 系统锁屏协调器（视频页 aboutToDisappear 时注销）
   *
   * @param delegate 待解绑的协调器
   */
  public unbindPipSystemLockDelegate(delegate: IVideoPipSystemLockDelegate): void {
    if (this.pipSystemLockDelegate !== delegate) {
      return;
    }
    this.pipSystemLockDelegate = null;
    HiLog.i(TAG, 'unbindPipSystemLockDelegate');
  }

  /**
   * 系统锁屏：暂停正在播放的视频。
   */
  public onSystemScreenLocked(): void {
    this.pipSystemLockDelegate?.onSystemScreenLocked();
  }

  /**
   * 系统解锁：应用内直接续播；已在桌面则在 PiP 小窗续播。
   *
   * @param isAppInBackground 应用是否处于后台（桌面/多任务）
   */
  public onSystemScreenUnlocked(isAppInBackground: boolean): void {
    this.pipSystemLockDelegate?.onSystemScreenUnlocked(isAppInBackground);
  }

  /**
   * 注册队列切歌监听：后台播控下一首/上一首时不依赖 ArkUI @Watch
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
   * 队列当前视频变更：驱动已绑定的 VideoPlayerController 切源
   *
   * @param uri 当前视频 URI
   * @param kind 媒体类型
   */
  private handleQueueTrackChange = (uri: string, kind: PlaybackMediaKind): void => {
    PlaybackControlSessionHelper.handleQueueTrackChange(
      TAG, uri, kind, PlaybackMediaKind.VIDEO, this.activeController);
  };
}
