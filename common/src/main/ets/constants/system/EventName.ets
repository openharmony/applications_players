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

export enum OperationPath {
  RIGHT_CLICK_MENU = 0,
  OPERATION_AREA = 1
}

export enum OperationSource {
  MOUSE = 0,
  KEYBOARD = 1,
  TOUCH = 2
}

export enum EventName {
  BEV_VIDEO_OPERATION = 'bev_video_operation',
  BEV_AUDIO_OPERATION = 'bev_audio_operation',
  DFT_PREVIEW_RESULT = 'dft_preview_result'
}

export enum VideoOperate {
  PLAY = 'play',
  PAUSE = 'pause',
  ENTER_FULL_SCREEN = 'enter_full_screen',
  EXIT_FULL_SCREEN = 'exit_full_screen',
  SKIP_FORWARD = 'skip_forward',
  SKIP_BACK = 'skip_back'
}

export enum AudioOperate {
  PLAY = 'play',
  PAUSE = 'pause'
}

export enum ResultOpenState {
  SUCCESS = 'success',
  FAIL = 'fail',
  FAILED_TO_LOAD_CONTROLLER = 'failed_to_load_controller',
  FILE_INFO_UNDEFINED = 'file_info_undefined'
}

export enum TaskId {
  PARSE_FILE = 1001,
  LOAD_PLAYER = 1002,
  PREPARE_PLAYER = 1003,
  LOAD_PAGE = 1004
}
