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


/**
 * 系统播控中心（AVSession）与后台音频长任务相关常量
 */
export class PlaybackControlConstants {
  static readonly APP_BUNDLE_NAME: string = 'com.ohos.players';
  static readonly MAIN_ABILITY_NAME: string = 'MainAbility';
  /** 播控中心封面最大边长（过大 PixelMap 会导致 setAVMetadata 6600101） */
  static readonly SESSION_COVER_MAX_PX: number = 512;
  /**
   * 向播控中心上报 PLAY 后，忽略远端 pause 的宽限期（毫秒）。
   * 系统媒体控制卡片在会话刚激活时可能误发 pause（见 isShowPlayButton during render）。
   */
  static readonly REMOTE_PAUSE_GUARD_MS: number = 1500;
  /** AVSession 错误码：会话不存在（原生句柄已失效，JS 包装仍可能非空） */
  static readonly ERR_SESSION_NOT_EXIST: number = 6600102;
  /** 冷启创建会话失败时的最大重试次数 */
  static readonly SESSION_CREATE_RETRY_TIMES: number = 3;
  /** 创建重试基础间隔（毫秒），第 n 次为 n * BASE */
  static readonly SESSION_CREATE_RETRY_BASE_DELAY_MS: number = 120;
  /** 播放态下会话失效自动恢复的冷却时间（毫秒），避免死循环 */
  static readonly SESSION_RECOVER_COOLDOWN_MS: number = 2000;
  /** uiContext 未绑定时 ensureActive 重试上限；总耗时不超 3 * 200 = 600ms */
  static readonly UI_CONTEXT_RETRY_TIMES: number = 3;
  /** uiContext 重试基础间隔（毫秒），第 n 次为 n * BASE */
  static readonly UI_CONTEXT_RETRY_DELAY_MS: number = 200;
  /**
   * setAVMetadata 临时性失败 (系统忙/并发写) 时的退避重试次数。
   * 修复 setAVMetadata 长耗时阻塞 ensureActive 整体 await 链路的问题。
   */
  static readonly METADATA_PUBLISH_RETRY_TIMES: number = 3;
  /** setAVMetadata 重试基础间隔 (毫秒), 第 n 次为 n * BASE */
  static readonly METADATA_PUBLISH_RETRY_DELAY_MS: number = 150;
}
