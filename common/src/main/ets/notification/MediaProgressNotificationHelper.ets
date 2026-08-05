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



import { common } from '@kit.AbilityKit';
import { notificationManager } from '@kit.NotificationKit';
import notification from '@ohos.notification';
import { MediaProgressConstants, MediaProgressPublishMode } from '../constants/notification/MediaProgressConstants';
import { MediaProgressBackgroundHelper } from './MediaProgressBackgroundHelper';
import { MediaProgressLiveViewHelper } from './MediaProgressLiveViewHelper';
import { HiLog } from '../utils/HiLog';

const TAG = 'MediaProgressNotificationHelper';

const REQUEST_SLOT_TYPE: notificationManager.SlotType = notificationManager.SlotType.OTHER_TYPES;
const CHANNEL_SLOT_TYPE: notification.SlotType = notification.SlotType.OTHER_TYPES;

/**
 * 媒体导入/扫描进度对外入口：优先 Live View 实况窗（通知中心/锁屏），不可用时回退普通持续通知。
 */
export class MediaProgressNotificationHelper {
  private static active: boolean = false;
  private static notificationReady: boolean = false;
  private static useLiveView: boolean = false;
  private static publishMode: MediaProgressPublishMode = MediaProgressPublishMode.NONE;
  private static lastPercent: number = -1;
  private static lastUpdateAt: number = 0;
  private static currentTitle: string = '';
  private static lastProcessed: number = 0;
  private static lastTotal: number = 100;
  private static progressStartAt: number = 0;

  static async ensureNotificationEnabled(context: common.UIAbilityContext | null): Promise<boolean> {
    try {
      let enabled = await notificationManager.isNotificationEnabled();
      if (!enabled && context) {
        await notificationManager.requestEnableNotification(context);
        enabled = await notificationManager.isNotificationEnabled();
      }
      MediaProgressNotificationHelper.notificationReady = enabled;
      if (!enabled) {
        HiLog.w(TAG, 'notification permission not granted');
      }
      return enabled;
    } catch (error) {
      HiLog.w(TAG, `ensureNotificationEnabled failed: ${error}`);
      MediaProgressNotificationHelper.notificationReady = false;
      return false;
    }
  }

  /** 注册通知渠道：LIVE_VIEW 须与 notification-demo 相同用法直接 addSlot */
  static async addNotificationSlots(): Promise<void> {
    try {
      await notificationManager.addSlot(notificationManager.SlotType.LIVE_VIEW);
      const progressSlot: notificationManager.NotificationSlot = {
        type: CHANNEL_SLOT_TYPE,
        level: notificationManager.SlotLevel.LEVEL_DEFAULT,
        desc: '媒体导入与扫描进度',
        badgeFlag: false
      };
      await notificationManager.addSlot(progressSlot);
      HiLog.i(TAG, 'addNotificationSlots LIVE_VIEW + OTHER_TYPES success');
    } catch (error) {
      HiLog.w(TAG, `addNotificationSlots skipped: ${error}`);
    }
  }

  /**
   * 开始进度展示：后台长任务 + 实况窗/兜底通知
   *
   * @param title 进度标题
   * @param context MainAbility 上下文（用于长任务）
   */
  static async startProgress(title: string, context: common.UIAbilityContext | null = null): Promise<void> {
    MediaProgressNotificationHelper.active = true;
    MediaProgressNotificationHelper.currentTitle = title;
    MediaProgressNotificationHelper.lastPercent = -1;
    MediaProgressNotificationHelper.lastUpdateAt = 0;
    MediaProgressNotificationHelper.lastProcessed = 0;
    MediaProgressNotificationHelper.lastTotal = 100;
    MediaProgressNotificationHelper.progressStartAt = Date.now();

    await MediaProgressBackgroundHelper.start(context);
    MediaProgressNotificationHelper.publishMode = await MediaProgressLiveViewHelper.start(title, context);
    MediaProgressNotificationHelper.useLiveView =
      MediaProgressNotificationHelper.publishMode === MediaProgressPublishMode.SYSTEM_LIVE_VIEW;
    if (!MediaProgressNotificationHelper.useLiveView) {
      await MediaProgressNotificationHelper.publishFallbackNotification(title, 0, 0, 100);
      MediaProgressNotificationHelper.publishMode = MediaProgressPublishMode.FALLBACK;
    }
    HiLog.i(TAG, `startProgress title=${title} mode=${MediaProgressNotificationHelper.publishMode}`);
  }

  /**
   * 刷新进度
   *
   * @param percent 0-100
   * @param processed 已处理数量
   * @param total 总数量
   */
  static async updateProgress(percent: number, processed: number = 0, total: number = 100): Promise<void> {
    if (!MediaProgressNotificationHelper.active) {
      return;
    }
    const clamped = MediaProgressNotificationHelper.clampPercent(percent);
    if (!MediaProgressNotificationHelper.shouldPublish(clamped)) {
      return;
    }
    MediaProgressNotificationHelper.lastPercent = clamped;
    MediaProgressNotificationHelper.lastUpdateAt = Date.now();
    MediaProgressNotificationHelper.lastProcessed = processed;
    MediaProgressNotificationHelper.lastTotal = total > 0 ? total : 100;

    if (MediaProgressNotificationHelper.useLiveView) {
      const ok = await MediaProgressLiveViewHelper.update(
        MediaProgressNotificationHelper.currentTitle,
        clamped,
        MediaProgressNotificationHelper.lastProcessed,
        MediaProgressNotificationHelper.lastTotal
      );
      if (!ok) {
        MediaProgressNotificationHelper.useLiveView = false;
        MediaProgressNotificationHelper.publishMode = MediaProgressPublishMode.FALLBACK;
        await MediaProgressNotificationHelper.publishFallbackNotification(
          MediaProgressNotificationHelper.currentTitle, clamped,
          MediaProgressNotificationHelper.lastProcessed,
          MediaProgressNotificationHelper.lastTotal);
      }
      return;
    }
    await MediaProgressNotificationHelper.publishFallbackNotification(
      MediaProgressNotificationHelper.currentTitle, clamped,
      MediaProgressNotificationHelper.lastProcessed,
      MediaProgressNotificationHelper.lastTotal);
  }

  static async finishProgress(completeTitle: string, completeText: string,
    context: common.UIAbilityContext | null = null): Promise<void> {
    if (!MediaProgressNotificationHelper.active) {
      return;
    }
    await MediaProgressNotificationHelper.updateProgress(100,
      MediaProgressNotificationHelper.lastProcessed,
      MediaProgressNotificationHelper.lastTotal);
    await MediaProgressLiveViewHelper.stop();
    await MediaProgressNotificationHelper.cancelFallbackNotification();
    await MediaProgressNotificationHelper.publishCompleteNotification(completeTitle, completeText);
    await MediaProgressBackgroundHelper.stop(context);
    MediaProgressNotificationHelper.resetState();
    HiLog.i(TAG, `finishProgress completeTitle=${completeTitle}`);
  }

  static async cancelProgress(context: common.UIAbilityContext | null = null): Promise<void> {
    if (!MediaProgressNotificationHelper.active) {
      return;
    }
    await MediaProgressLiveViewHelper.stop();
    await MediaProgressNotificationHelper.cancelFallbackNotification();
    await MediaProgressBackgroundHelper.stop(context);
    MediaProgressNotificationHelper.resetState();
    HiLog.i(TAG, 'cancelProgress');
  }

  private static async cancelFallbackNotification(): Promise<void> {
    try {
      await notificationManager.cancel(MediaProgressConstants.FALLBACK_NOTIFICATION_ID);
    } catch (error) {
      HiLog.w(TAG, `cancel fallback notification failed: ${error}`);
    }
  }

  private static async publishFallbackNotification(title: string, percent: number,
    processed: number = 0, total: number = 100): Promise<void> {
    if (!MediaProgressNotificationHelper.notificationReady) {
      return;
    }
    try {
      const progressLine = MediaProgressLiveViewHelper.buildProgressLine(percent);
      const countText = total > 0 ? `${processed}/${total}` : `${percent}%`;
      const normal: notificationManager.NotificationBasicContent = {
        title: title,
        text: `${progressLine}  ${countText}`,
        additionalText: title
      };
      const content: notificationManager.NotificationContent = {
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
        normal: normal
      };
      const request: notificationManager.NotificationRequest = {
        id: MediaProgressConstants.FALLBACK_NOTIFICATION_ID,
        notificationSlotType: REQUEST_SLOT_TYPE,
        isOngoing: true,
        content: content
      };
      await notificationManager.publish(request);
      HiLog.d(TAG, `publishFallback title=${title} percent=${percent}`);
    } catch (error) {
      HiLog.e(TAG, `publishFallback failed percent=${percent}: ${error}`);
    }
  }

  private static async publishCompleteNotification(title: string, text: string): Promise<void> {
    if (!MediaProgressNotificationHelper.notificationReady) {
      return;
    }
    try {
      const normal: notificationManager.NotificationBasicContent = {
        title: title,
        text: text
      };
      const content: notificationManager.NotificationContent = {
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
        normal: normal
      };
      const request: notificationManager.NotificationRequest = {
        id: MediaProgressConstants.COMPLETE_NOTIFICATION_ID,
        notificationSlotType: REQUEST_SLOT_TYPE,
        content: content
      };
      await notificationManager.publish(request);
      HiLog.i(TAG, `publishComplete title=${title}`);
    } catch (error) {
      HiLog.e(TAG, `publishComplete failed: ${error}`);
    }
  }

  private static shouldPublish(percent: number): boolean {
    if (MediaProgressNotificationHelper.lastPercent < 0) {
      return true;
    }
    if (percent >= 100) {
      return true;
    }
    if (Math.abs(percent - MediaProgressNotificationHelper.lastPercent) >=
      MediaProgressConstants.MIN_PERCENT_DELTA) {
      return true;
    }
    if (Date.now() - MediaProgressNotificationHelper.lastUpdateAt >=
      MediaProgressConstants.MIN_TIME_TICK_INTERVAL_MS) {
      return true;
    }
    return Date.now() - MediaProgressNotificationHelper.lastUpdateAt >=
      MediaProgressConstants.MIN_UPDATE_INTERVAL_MS;
  }

  private static clampPercent(percent: number): number {
    if (percent < 0) {
      return 0;
    }
    if (percent > 100) {
      return 100;
    }
    return Math.floor(percent);
  }

  private static resetState(): void {
    MediaProgressNotificationHelper.active = false;
    MediaProgressNotificationHelper.useLiveView = false;
    MediaProgressNotificationHelper.publishMode = MediaProgressPublishMode.NONE;
    MediaProgressNotificationHelper.lastPercent = -1;
    MediaProgressNotificationHelper.lastUpdateAt = 0;
    MediaProgressNotificationHelper.currentTitle = '';
    MediaProgressNotificationHelper.lastProcessed = 0;
    MediaProgressNotificationHelper.lastTotal = 100;
    MediaProgressNotificationHelper.progressStartAt = 0;
  }
}
