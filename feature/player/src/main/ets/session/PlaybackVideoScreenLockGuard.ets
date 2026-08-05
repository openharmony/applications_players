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


import commonEventManager from '@ohos.commonEventManager';
import { BusinessError } from '@kit.BasicServicesKit';
import { HiLog } from '@ohos/common/src/main/ets/utils/HiLog';
import { appLocalStorage } from '@ohos/common/src/main/ets/storage/AppLocalStorage';
import { LocalStorageParam } from '@ohos/common/src/main/ets/constants/storage/StorageParam';
import { VideoPlaybackSession } from './VideoPlaybackSession';

const TAG = 'PlaybackVideoScreenLockGuard';

/**
 * 订阅系统锁屏/解锁公共事件：视频播放时锁屏暂停，回到桌面后在 PiP 小窗续播。
 */
export class PlaybackVideoScreenLockGuard {
  private static registered: boolean = false;
  private static subscriber: commonEventManager.CommonEventSubscriber | undefined = undefined;

  /**
   * 在 MainAbility 启动时注册锁屏事件监听（重复调用安全）。
   */
  static register(): void {
    if (PlaybackVideoScreenLockGuard.registered) {
      return;
    }
    void PlaybackVideoScreenLockGuard.ensureSubscriber();
  }

  /**
   * 创建并订阅系统锁屏/解锁公共事件。
   */
  private static async ensureSubscriber(): Promise<void> {
    try {
      const subscribeInfo: commonEventManager.CommonEventSubscribeInfo = {
        events: [
          commonEventManager.Support.COMMON_EVENT_SCREEN_LOCKED,
          commonEventManager.Support.COMMON_EVENT_SCREEN_UNLOCKED,
        ],
      };
      const subscriber = await commonEventManager.createSubscriber(subscribeInfo);
      PlaybackVideoScreenLockGuard.subscriber = subscriber;
      commonEventManager.subscribe(subscriber, PlaybackVideoScreenLockGuard.onCommonEvent);
      PlaybackVideoScreenLockGuard.registered = true;
      HiLog.i(TAG, 'screenLock subscriber registered');
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      const code = (error as BusinessError).code;
      HiLog.e(TAG, `ensureSubscriber failed code=${code} message=${message}`);
    }
  }

  /**
   * 系统锁屏/解锁公共事件回调，委托给当前视频 PiP 会话。
   */
  private static onCommonEvent = (err: BusinessError, data: commonEventManager.CommonEventData): void => {
    if (err) {
      HiLog.w(TAG, `onCommonEvent failed code=${err.code} message=${err.message}`);
      return;
    }
    if (data.event === commonEventManager.Support.COMMON_EVENT_SCREEN_LOCKED) {
      HiLog.i(TAG, 'systemScreenLocked');
      VideoPlaybackSession.getInstance().onSystemScreenLocked();
      return;
    }
    if (data.event === commonEventManager.Support.COMMON_EVENT_SCREEN_UNLOCKED) {
      const isAppInBackground = appLocalStorage.get<boolean>(LocalStorageParam.APP_IN_BACKGROUND) ?? false;
      HiLog.i(TAG, `systemScreenUnlocked isAppInBackground=${isAppInBackground}`);
      VideoPlaybackSession.getInstance().onSystemScreenUnlocked(isAppInBackground);
    }
  };
}
