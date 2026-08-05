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

/** 进度通知发布模式 */
export enum MediaProgressPublishMode {
  NONE = 'NONE',
  /** 系统实况窗（notificationManager.publish + NOTIFICATION_CONTENT_SYSTEM_LIVE_VIEW） */
  SYSTEM_LIVE_VIEW = 'SYSTEM_LIVE_VIEW',
  /** 普通持续文本通知（实况窗不可用时的兜底） */
  FALLBACK = 'FALLBACK'
}

/**
 * 媒体导入/扫描进度通知与实况窗固定常量
 */
export class MediaProgressConstants {
  /** 进度实况通知 ID（创建/更新共用） */
  static readonly LIVE_VIEW_NOTIFICATION_ID: number = 88005;
  /** 系统实况窗 typeCode（与 notification-demo 一致） */
  static readonly LIVE_VIEW_TYPE_CODE: number = 1;
  /** 实况胶囊背景色 */
  static readonly LIVE_VIEW_CAPSULE_BG_COLOR: string = '#FF317AF7';
  /** 兜底普通通知 ID */
  static readonly FALLBACK_NOTIFICATION_ID: number = 88002;
  /** 完成通知 ID */
  static readonly COMPLETE_NOTIFICATION_ID: number = 88003;
  /** 进度通知最小更新间隔（ms） */
  static readonly MIN_UPDATE_INTERVAL_MS: number = 500;
  /** 实况窗时间字段刷新间隔（ms），进度不变时也刷新已用时长 */
  static readonly MIN_TIME_TICK_INTERVAL_MS: number = 1000;
  /** 进度变化低于该阈值且未超间隔则跳过刷新 */
  static readonly MIN_PERCENT_DELTA: number = 1;
}
