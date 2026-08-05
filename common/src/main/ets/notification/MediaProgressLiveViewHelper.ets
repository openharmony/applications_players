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


import { common, wantAgent, WantAgent } from '@kit.AbilityKit';
import { notificationManager } from '@kit.NotificationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { image } from '@kit.ImageKit';
import { MediaProgressConstants, MediaProgressPublishMode } from '../constants/notification/MediaProgressConstants';
import { HiLog } from '../utils/HiLog';

const TAG = 'MediaProgressLiveViewHelper';

/** 实况窗进度快照 */
export interface MediaProgressLiveViewSnapshot {
  title: string;
  percent: number;
  processed: number;
  total: number;
}

/**
 * 媒体导入/扫描系统实况窗（对齐 notification-demo 的 NotificationManager.publishLiveViewNotification）。
 * 通过 notificationManager.publish + NOTIFICATION_CONTENT_SYSTEM_LIVE_VIEW 实现胶囊/卡片进度展示。
 */
export class MediaProgressLiveViewHelper {
  private static active: boolean = false;
  private static publishMode: MediaProgressPublishMode = MediaProgressPublishMode.NONE;
  private static lastPercent: number = -1;
  private static lastUpdateAt: number = 0;
  private static currentTitle: string = '';
  private static pixelMap: image.PixelMap | undefined = undefined;
  private static clickWantAgent: WantAgent | undefined = undefined;
  private static subscribed: boolean = false;
  private static progressStartAt: number = 0;

  /**
   * 创建系统实况窗进度通知
   *
   * @param title 主标题
   * @param context MainAbility 上下文（构建 wantAgent）
   */
  static async start(title: string, context: common.UIAbilityContext | null): Promise<MediaProgressPublishMode> {
    MediaProgressLiveViewHelper.active = true;
    MediaProgressLiveViewHelper.currentTitle = title;
    MediaProgressLiveViewHelper.lastPercent = -1;
    MediaProgressLiveViewHelper.lastUpdateAt = 0;
    MediaProgressLiveViewHelper.publishMode = MediaProgressPublishMode.NONE;
    MediaProgressLiveViewHelper.progressStartAt = Date.now();

    if (context === null) {
      HiLog.w(TAG, 'start aborted: context is null');
      MediaProgressLiveViewHelper.active = false;
      return MediaProgressPublishMode.NONE;
    }

    const ready = await MediaProgressLiveViewHelper.ensureAssets(context);
    if (!ready) {
      MediaProgressLiveViewHelper.active = false;
      return MediaProgressPublishMode.NONE;
    }

    await MediaProgressLiveViewHelper.ensureLiveViewSubscribed();

    const ok = await MediaProgressLiveViewHelper.publishSnapshot({
      title: title,
      percent: 0,
      processed: 0,
      total: 100
    }, true);
    if (!ok) {
      MediaProgressLiveViewHelper.active = false;
      return MediaProgressPublishMode.NONE;
    }
    HiLog.i(TAG, `start mode=${MediaProgressLiveViewHelper.publishMode}`);
    return MediaProgressLiveViewHelper.publishMode;
  }

  /**
   * 刷新系统实况窗进度（相同 notificationId 重复 publish）
   *
   * @param title 主标题
   * @param percent 0-100
   * @param processed 已处理数量
   * @param total 总数量
   */
  static async update(title: string, percent: number, processed: number = 0, total: number = 100): Promise<boolean> {
    if (!MediaProgressLiveViewHelper.active ||
      MediaProgressLiveViewHelper.publishMode !== MediaProgressPublishMode.SYSTEM_LIVE_VIEW) {
      return false;
    }
    const clamped = MediaProgressLiveViewHelper.clampPercent(percent);
    if (!MediaProgressLiveViewHelper.shouldPublish(clamped)) {
      return true;
    }
    MediaProgressLiveViewHelper.currentTitle = title.length > 0 ? title : MediaProgressLiveViewHelper.currentTitle;
    MediaProgressLiveViewHelper.lastPercent = clamped;
    MediaProgressLiveViewHelper.lastUpdateAt = Date.now();
    return MediaProgressLiveViewHelper.publishSnapshot({
      title: MediaProgressLiveViewHelper.currentTitle,
      percent: clamped,
      processed: processed,
      total: total > 0 ? total : 100
    }, false);
  }

  /** 结束并取消实况窗通知 */
  static async stop(): Promise<void> {
    if (!MediaProgressLiveViewHelper.active &&
      MediaProgressLiveViewHelper.publishMode === MediaProgressPublishMode.NONE) {
      return;
    }
    try {
      await notificationManager.cancel(MediaProgressConstants.LIVE_VIEW_NOTIFICATION_ID);
      HiLog.i(TAG, 'cancel live view notification success');
    } catch (error) {
      HiLog.w(TAG, `cancel live view notification failed: ${error}`);
    }
    MediaProgressLiveViewHelper.resetState();
  }

  static getPublishMode(): MediaProgressPublishMode {
    return MediaProgressLiveViewHelper.publishMode;
  }

  static isActive(): boolean {
    return MediaProgressLiveViewHelper.active;
  }

  /** 文本进度条（兜底普通通知用） */
  static buildProgressLine(percent: number): string {
    const clamped = MediaProgressLiveViewHelper.clampPercent(percent);
    const filled = Math.floor(clamped / 10);
    let bar = '';
    for (let i = 0; i < 10; i++) {
      bar += i < filled ? '█' : '░';
    }
    return `[${bar}] ${clamped}%`;
  }

  /** 初始化 PixelMap 与点击跳转 WantAgent */
  private static async ensureAssets(context: common.UIAbilityContext): Promise<boolean> {
    if (MediaProgressLiveViewHelper.pixelMap === undefined) {
      const color = new ArrayBuffer(4);
      MediaProgressLiveViewHelper.pixelMap = await image.createPixelMap(color, {
        size: {
          height: 1,
          width: 1
        }
      });
    }
    if (MediaProgressLiveViewHelper.pixelMap === undefined) {
      HiLog.e(TAG, 'ensureAssets failed: pixelMap is undefined');
      return false;
    }
    try {
      MediaProgressLiveViewHelper.clickWantAgent = await MediaProgressLiveViewHelper.createWantAgent(context);
      return true;
    } catch (error) {
      const err = error as BusinessError;
      HiLog.e(TAG, `createWantAgent failed code=${err.code} message=${err.message}`);
      return false;
    }
  }

  /** 订阅系统实况窗（与 notification-demo 一致，发布前必须订阅） */
  private static async ensureLiveViewSubscribed(): Promise<void> {
    if (MediaProgressLiveViewHelper.subscribed) {
      return;
    }
    const subscriber: notificationManager.SystemLiveViewSubscriber = {
      onResponse: (id: number, option: notificationManager.ButtonOptions) => {
        HiLog.i(TAG, `liveView onResponse id=${id} button=${option.buttonName}`);
      }
    };
    await notificationManager.subscribeSystemLiveView(subscriber);
    MediaProgressLiveViewHelper.subscribed = true;
    HiLog.i(TAG, 'subscribeSystemLiveView success');
  }

  /**
   * 构建点击实况窗回到应用的 WantAgent
   *
   * @param context MainAbility 上下文
   */
  private static async createWantAgent(context: common.UIAbilityContext): Promise<WantAgent> {
    const wantAgentInfo: wantAgent.WantAgentInfo = {
      wants: [{
        deviceId: '',
        bundleName: context.applicationInfo.name,
        abilityName: 'MainAbility',
        moduleName: 'phone',
        action: '',
        entities: [],
        uri: '',
        parameters: {}
      }],
      actionType: wantAgent.OperationType.START_ABILITY,
      requestCode: 0,
      wantAgentFlags: [wantAgent.WantAgentFlags.CONSTANT_FLAG]
    };
    return wantAgent.getWantAgent(wantAgentInfo);
  }

  /**
   * 发布或更新系统实况窗
   *
   * @param snapshot 进度快照
   * @param isCreate 是否首次创建
   */
  private static async publishSnapshot(snapshot: MediaProgressLiveViewSnapshot,
    isCreate: boolean): Promise<boolean> {
    if (MediaProgressLiveViewHelper.pixelMap === undefined ||
      MediaProgressLiveViewHelper.clickWantAgent === undefined) {
      return false;
    }
    const detailText = MediaProgressLiveViewHelper.buildDetailText(snapshot);
    const elapsedSec = MediaProgressLiveViewHelper.getElapsedSeconds();
    const systemLiveView: notificationManager.NotificationSystemLiveViewContent = {
      title: snapshot.title,
      text: detailText,
      typeCode: MediaProgressConstants.LIVE_VIEW_TYPE_CODE,
      capsule: {
        title: `${snapshot.percent}%`,
        icon: MediaProgressLiveViewHelper.pixelMap,
        backgroundColor: MediaProgressConstants.LIVE_VIEW_CAPSULE_BG_COLOR
      },
      progress: {
        maxValue: 100,
        currentValue: snapshot.percent,
        isPercentage: false
      },
      time: {
        initialTime: elapsedSec,
        isCountDown: false,
        isPaused: false,
        isInTitle: false
      }
    };
    const content: notificationManager.NotificationContent = {
      notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_SYSTEM_LIVE_VIEW,
      systemLiveView: systemLiveView
    };
    const request: notificationManager.NotificationRequest = {
      notificationSlotType: notificationManager.SlotType.LIVE_VIEW,
      id: MediaProgressConstants.LIVE_VIEW_NOTIFICATION_ID,
      content: content,
      wantAgent: MediaProgressLiveViewHelper.clickWantAgent
    };

    return new Promise<boolean>((resolve) => {
      notificationManager.publish(request, (err: BusinessError) => {
        if (err) {
          HiLog.w(TAG, `publishSystemLiveView failed create=${isCreate} code=${err.code} message=${err.message}`);
          resolve(false);
          return;
        }
        MediaProgressLiveViewHelper.publishMode = MediaProgressPublishMode.SYSTEM_LIVE_VIEW;
        HiLog.i(TAG, `publishSystemLiveView success percent=${snapshot.percent} elapsedSec=${elapsedSec} create=${isCreate}`);
        resolve(true);
      });
    });
  }

  private static buildDetailText(snapshot: MediaProgressLiveViewSnapshot): string {
    if (snapshot.total > 0 && snapshot.processed >= 0) {
      return `当前进度: ${snapshot.processed}/${snapshot.total}`;
    }
    return `当前进度: ${snapshot.percent}%`;
  }

  private static shouldPublish(percent: number): boolean {
    if (MediaProgressLiveViewHelper.lastPercent < 0) {
      return true;
    }
    if (percent >= 100) {
      return true;
    }
    if (Math.abs(percent - MediaProgressLiveViewHelper.lastPercent) >=
      MediaProgressConstants.MIN_PERCENT_DELTA) {
      return true;
    }
    if (Date.now() - MediaProgressLiveViewHelper.lastUpdateAt >=
      MediaProgressConstants.MIN_TIME_TICK_INTERVAL_MS) {
      return true;
    }
    return Date.now() - MediaProgressLiveViewHelper.lastUpdateAt >=
      MediaProgressConstants.MIN_UPDATE_INTERVAL_MS;
  }

  /** 自 start 起的已用秒数，驱动实况窗 time 字段刷新 */
  private static getElapsedSeconds(): number {
    if (MediaProgressLiveViewHelper.progressStartAt <= 0) {
      return 0;
    }
    return Math.floor((Date.now() - MediaProgressLiveViewHelper.progressStartAt) / 1000);
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
    MediaProgressLiveViewHelper.active = false;
    MediaProgressLiveViewHelper.publishMode = MediaProgressPublishMode.NONE;
    MediaProgressLiveViewHelper.lastPercent = -1;
    MediaProgressLiveViewHelper.lastUpdateAt = 0;
    MediaProgressLiveViewHelper.currentTitle = '';
    MediaProgressLiveViewHelper.pixelMap = undefined;
    MediaProgressLiveViewHelper.clickWantAgent = undefined;
    MediaProgressLiveViewHelper.progressStartAt = 0;
  }
}
