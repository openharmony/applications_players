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

export class AppStorageParam {
  static readonly AUDIO_AV_SESSION = 'audio_av_session';
  static readonly VIDEO_AV_SESSION = 'video_av_session';
  static readonly UI_EXTENSION_PLAYING_VIDEO_CACHE = 'ui_extension_playing_video_cache';
}

export class LocalStorageParam {
  static readonly LOADING_END = 'loading_end';
  static readonly VIDEO_INFORMATION = 'video_information';
  /** 应用是否处于后台可见性（由 MainAbility 前后台同步），非 UIAbility.onBackground 生命周期 */
  static readonly APP_IN_BACKGROUND = 'app_in_background';
  static readonly SWIPER_VIDEO = 'swiper_video';
  static readonly SWIPER_AUDIO = 'swiper_audio';
  static readonly WINDOW_CLASS = 'windowClass';
  static readonly WINDOW_SIZE = 'windowSize';
}
