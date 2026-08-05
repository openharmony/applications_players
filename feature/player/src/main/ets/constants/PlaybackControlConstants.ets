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
}
