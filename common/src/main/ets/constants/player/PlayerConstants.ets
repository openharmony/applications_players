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

export enum AVPlayerState {
  IDLE = 'idle',
  INITIALIZED = 'initialized',
  PREPARED = 'prepared',
  PLAYING = 'playing',
  PAUSED = 'paused',
  STOPPED = 'stopped',
  COMPLETED = 'completed',
  RELEASED = 'released',
  ERROR = 'error',
  UNDEFINED = 'undefined'
}

export enum PlaybackMode {
  ORDER = 'order',
  RANDOM = 'random',
  SINGLE_CYCLE = 'single_cycle'
}

export enum PlaybackSpeed {
  SPEED_FORWARD_0_75_X = 0.75,
  SPEED_FORWARD_1_00_X = 1.0,
  SPEED_FORWARD_1_25_X = 1.25,
  SPEED_FORWARD_1_50_X = 1.5,
  SPEED_FORWARD_2_00_X = 2.0
}
