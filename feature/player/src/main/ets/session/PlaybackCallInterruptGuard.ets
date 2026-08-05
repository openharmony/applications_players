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


import { call, observer } from '@kit.TelephonyKit';
import { HiLog } from '@ohos/common/src/main/ets/utils/HiLog';
import { AudioPlaybackSession } from './AudioPlaybackSession';
import { CallInterruptState } from './CallInterruptState';
import { VideoPlaybackSession } from './VideoPlaybackSession';

const TAG = 'PlaybackCallInterruptGuard';

/**
 * 订阅系统通话状态，在 audioInterrupt 未触发时兜底暂停/恢复播放。
 * 非 IDLE 均视为通话占用；挂断后延迟恢复，避免电话音频/听筒路由未释放时抢焦点。
 * TC_EXCEPT_003 / TC_EXCEPT_004
 */
export class PlaybackCallInterruptGuard {
  private static registered: boolean = false;
  private static resumeTimerId: number = -1;
  /** 挂断后等待电话音频会话与路由恢复 */
  private static readonly RESUME_DELAY_MS: number = 1000;

  /**
   * 在 MainAbility 启动时注册通话状态监听（重复调用安全）。
   */
  static register(): void {
    if (PlaybackCallInterruptGuard.registered) {
      return;
    }
    try {
      observer.on('callStateChange', PlaybackCallInterruptGuard.onCallStateChange);
      PlaybackCallInterruptGuard.registered = true;
      HiLog.i(TAG, 'callStateChange observer registered');
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      HiLog.e(TAG, `register failed message=${message}`);
    }
  }

  private static onCallStateChange = (data: observer.CallStateInfo): void => {
    HiLog.i(TAG, `callStateChange state=${data.state}`);
    const state = data.state;
    // 不同卡/网络上报的中间态可能不是 RINGING/OFFHOOK（如 state=3），凡非 IDLE 均视为通话中
    const isIdle = state === call.CallState.CALL_STATE_IDLE;
    if (!isIdle) {
      PlaybackCallInterruptGuard.cancelResumeTimer();
      if (!CallInterruptState.isCallActive()) {
        CallInterruptState.setCallActive(true);
        PlaybackCallInterruptGuard.pauseAllForCall();
      }
      return;
    }
    if (CallInterruptState.isCallActive()) {
      CallInterruptState.setCallActive(false);
      PlaybackCallInterruptGuard.scheduleResumeAllAfterCall();
    }
  };

  private static cancelResumeTimer(): void {
    if (PlaybackCallInterruptGuard.resumeTimerId >= 0) {
      clearTimeout(PlaybackCallInterruptGuard.resumeTimerId);
      PlaybackCallInterruptGuard.resumeTimerId = -1;
    }
  }

  private static scheduleResumeAllAfterCall(): void {
    PlaybackCallInterruptGuard.cancelResumeTimer();
    HiLog.i(TAG, `scheduleResumeAllAfterCall delayMs=${PlaybackCallInterruptGuard.RESUME_DELAY_MS}`);
    PlaybackCallInterruptGuard.resumeTimerId = setTimeout(() => {
      PlaybackCallInterruptGuard.resumeTimerId = -1;
      if (CallInterruptState.isCallActive()) {
        HiLog.w(TAG, 'scheduleResumeAllAfterCall aborted: call active again');
        return;
      }
      PlaybackCallInterruptGuard.resumeAllAfterCall();
    }, PlaybackCallInterruptGuard.RESUME_DELAY_MS);
  }

  private static pauseAllForCall(): void {
    HiLog.i(TAG, 'pauseAllForCall');
    AudioPlaybackSession.getInstance().getController().handlePhoneCallBegin();
    const videoController = VideoPlaybackSession.getInstance().getActiveController();
    videoController?.handlePhoneCallBegin();
  }

  private static resumeAllAfterCall(): void {
    HiLog.i(TAG, 'resumeAllAfterCall');
    AudioPlaybackSession.getInstance().getController().handlePhoneCallEnd();
    const videoController = VideoPlaybackSession.getInstance().getActiveController();
    videoController?.handlePhoneCallEnd();
  }
}
