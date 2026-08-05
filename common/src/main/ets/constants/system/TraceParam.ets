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
export enum TraceCategoryParam {
  PREVIEW_AUDIO_FILE = 'preview_audio_file',
  PREVIEW_VIDEO_FILE = 'preview_video_file',
  PARSE_FILE = 'parse_file'
}

export enum TraceNameParam {
  AUDIO_LOAD_PLAYER = 'audio_load_player',
  AUDIO_LOAD_PAGE = 'audio_load_page',
  AUDIO_PARSE_FILE = 'audio_parse_file',
  VIDEO_LOAD_PLAYER = 'video_load_player',
  VIDEO_LOAD_PAGE = 'video_load_page',
  VIDEO_PARSE_FILE = 'video_parse_file',
  VIDEO_PREPARE_PLAYER = 'video_prepare_player'
}
