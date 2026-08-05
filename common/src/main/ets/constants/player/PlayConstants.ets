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

export const AVPLAYER_PREPARED_STATE =
  new Set<string>(['prepared', 'playing', 'paused', 'completed']);

export const AVPLAYER_LOADING_STATE =
  new Set<string>(['idle', 'initialized']);

export enum Speed {
  SPEED_0_25X = '0.25X',
  SPEED_0_50X = '0.5X',
  SPEED_1_00X = '1.0X',
  SPEED_1_50X = '1.5X',
  SPEED_2_00X = '2.0X',
  SPEED_3_00X = '3.0X',
}

export enum LoopState {
  CLOSE_LOOP_BUTTON = 'closeLoopButton',
  SINGLE_LOOP_BUTTON = 'singleLoopButton',
}

export enum AudioLoopMode {
  NONE = 'none',
  /** 列表循环 */
  LIST = 'list',
  /** 单曲循环 */
  SINGLE = 'single',
  /** 随机播放 */
  RANDOM = 'random',
}

export class PlayConstants {
  static readonly PLAY_PROGRESS_CURRENT_TIME = '00:00';
  static readonly PLAY_PROGRESS_TOTAL_TIME = '00:00';
  static readonly PLAY_PROGRESS_PROGRESS_VAL = 0;
  static readonly PLAY_PROGRESS_STEP = 1;
  static readonly PLAY_PROGRESS_PROGRESS_HIDE_TIME = 2000;
  static readonly PLAY_PROGRESS_VIDEO_HIDE_TIME = 4000;
  static readonly PLAY_PROGRESS_PLAY_SLIDER_LAYOUT_WEIGHT = 1;
  static readonly PLAY_PROGRESS_VOLUME_SLIDER_MAX = 100;

  static readonly INITIAL_TIME_UNIT: string = '00';
  static readonly PADDING_LENGTH: number = 2;
  static readonly PADDING_STR: string = '0';
  static readonly TIME_UNIT: number = 60;

  static readonly PLAY_PAGE_PLAY_SPEED = 1;
  public static readonly PLAY_PAGE_DEFAULT_VOLUME = 1;
  public static readonly PLAY_PAGE_DEFAULT_BRIGHTNESS = 1;
  static readonly POSITION_Y: number = 0;
  static readonly MAX_AUDIO_LEVEL: number = 1;
  static readonly VOLUME_LOW: number = 0.33;
  static readonly VOLUME_MEDIUM: number = 0.66;
  static readonly VOLUME_MUTE: number = 0;
  static readonly VOLUME_TYPE: number = 3;
  static readonly MAX_VALUE: number = 1;
  static readonly MIN_VALUE: number = 0;
  static readonly FOLLOW_SYSTEM_BRIGHTNESS: number = -1;
  static readonly HIDE_VOLUME_PROGRESS_TIME: number = 3000;
  static readonly PLAY_PAGE_SILENT = 0;
  static readonly PLAY_PAGE_DISAPPEAR_TIME = 200;
  static readonly PLAY_PAGE_PADDING = 8;
  static readonly PLAY_PAGE_PADDING_DOUBLE = 16;

  static readonly VIDEO_PLAY_PLAYER_ID = '';
  static readonly VIDEO_PLAY_PLAYER_TYPE = 'surface';
  static readonly VIDEO_PLAY_PLAYER_LIBRARY_NAME = '';
  static readonly VIDEO_PLAY_PLAYER_SURFACE_WIDTH = 1920;
  static readonly VIDEO_PLAY_PLAYER_SURFACE_HEIGHT = 1080;

  static readonly AUDIO_PLAY_PLAYER_COLUMN_SPACE = 16;
  static readonly AUDIO_PLAY_PLAYER_IMAGE_LG_SIZE = 180;
  static readonly AUDIO_PLAY_PLAYER_IMAGE_MD_SIZE = 160;
  static readonly AUDIO_PLAY_PLAYER_IMAGE_SM_SIZE = 120;
  static readonly AUDIO_PLAY_PLAYER_BREAKPOINTS_SM = 600;
  static readonly AUDIO_PLAY_PLAYER_BREAKPOINTS_LG = 800;

  public static readonly STATUS_START: number = 1;
  public static readonly STATUS_PAUSE: number = 2;
  public static readonly STATUS_COMPLETE: number = 3;
  public static readonly STATUS_STOP: number = 4;

  static readonly PLAY_TIME_INTERVAL = 100;

  public static readonly ORIGIN_FRAME_RATE: number = 4800;
  public static readonly TIME_UPDATE_MAX_INTERVAL = 2000;

  public static readonly VIDEO_SHOW_LOADING_TIMEOUT = 300;
  public static readonly MAX_VIDEO_SHOW_LOADING_TIME = 5000;
  public static readonly UI_EXTENSION_PLAYING_THRESHOLD = 10;
  public static readonly PLAYING_VIDEO_EXCEED_THRESHOLD_EVENT = 1501;

  public static readonly SECONDS_30 = 30000;
  public static readonly SECONDS_15 = 15000;
  public static readonly SECONDS_10 = 10000;
  static readonly SWITCH_VIDEO_SHOW_LOADING_TIMEOUT = 200;
  static readonly PLAYER_PROGRESS_MARGIN_RIGHT: number = 40;
  static readonly PLAYER_PROGRESS_MARGIN_LEFT: number = 40;
  static readonly PLAYER_PROGRESS_IMAGE_SIZE: number = 32;
  static readonly PLAYER_PROGRESS_IMAGE_BUTTON_SIZE: number = 48;
  static readonly PLAYER_PROGRESS_IMAGE_BUTTON_PADDING: number = 8;
  static readonly PLAYER_PROGRESS_BUTTON_SIZE: number = 48;
  static readonly PLAYER_PROGRESS_BUTTON_PADDING: number = 12;
  static readonly PLAYER_PROGRESS_TEXT_SIZE: number = 16;
  static readonly PLAYER_PROGRESS_TEXT_MARGIN: number = 12;
  static readonly PLAYER_PROGRESS_SPEED_BUTTON_SIZE: number = 40;
  static readonly PLAYER_PROGRESS_SPEED_BUTTON_PADDING: number = 8;
  static readonly PLAYER_PROGRESS_SPEED_TEXT_SIZE: number = 14;
  static readonly PLAYER_PROGRESS_SPEED_TEXT_MARGIN: number = 8;
  static readonly PLAYER_PROGRESS_VOLUME_SLIDER_WIDTH: number = 200;
  static readonly PLAYER_PROGRESS_VOLUME_SLIDER_HEIGHT: number = 4;
  static readonly PLAYER_PROGRESS_VOLUME_SLIDER_PADDING: number = 12;
  static readonly PLAYER_PROGRESS_VOLUME_TEXT_SIZE: number = 14;
  static readonly PLAYER_PROGRESS_VOLUME_TEXT_MARGIN: number = 8;
  static readonly PLAYER_PROGRESS_LOOP_BUTTON_SIZE: number = 40;
  static readonly PLAYER_PROGRESS_LOOP_BUTTON_PADDING: number = 8;
  static readonly PLAYER_PROGRESS_MAX_AUDIO_LEVEL: number = 1;
  static readonly PLAYER_PROGRESS_VOLUME_TYPE: number = 3;
  static readonly PLAYER_PROGRESS_VOLUME_LOW: number = 0.33;
  static readonly PLAYER_PROGRESS_VOLUME_MEDIUM: number = 0.66;
  static readonly PLAYER_PROGRESS_VOLUME_MUTE: number = 0;
  static readonly PLAYER_PROGRESS_VOLUME_HIGH: number = 1;
  static readonly PLAYER_PROGRESS_POSITION_Y: number = 0;
  static readonly PLAYER_PROGRESS_ONE_THOUSAND: number = 1000;
  static readonly PLAYER_PROGRESS_ONE_HUNDRED: number = 100;
  static readonly PLAYER_PROGRESS_ALL_PERCENT: string = '100%';
  static readonly PLAYER_PROGRESS_AUDIO_FILE_NAME_MAX_FONT_SCALE: number = 1.3;
  static readonly PLAYER_PROGRESS_AUDIO_PLAYER_TEXT_MARGIN_LEFT: number = 16;
  static readonly PLAYER_PROGRESS_AUDIO_PLAYER_TEXT_MARGIN_RIGHT: number = 16;
  static readonly PLAYER_PROGRESS_AUDIO_PLAYER_TEXT_MAX_WIDTH: number = 300;
  static readonly PLAYER_PROGRESS_PLAY_PROGRESS_PLAY_VOLUME_IMAGE_MARGIN_TOP: number = 12;
  static readonly PLAYER_PROGRESS_PLAY_PROGRESS_PLAY_VOLUME_IMAGE_MARGIN_BOTTOM: number = 12;
  static readonly PLAYER_PROGRESS_PLAY_PROGRESS_CENTER_PLAY_IMAGE_SIZE: number = 56;
  static readonly PLAYER_PROGRESS_ANIMATE_LOAD_TIME: number = 300;
  static readonly PLAYER_PROGRESS_HIDE_VOLUME_PROGRESS_TIME: number = 3000;
  static readonly PLAYER_PROGRESS_MAX_VALUE: number = 1;
  static readonly PLAYER_PROGRESS_MIN_VALUE: number = 0;
  static readonly PLAYER_PROGRESS_FOLLOW_SYSTEM_BRIGHTNESS: number = -1;
  static readonly PLAYER_PROGRESS_TEN_SECONDS: number = 10;
  static readonly PLAYER_PROGRESS_THIRTY_SECONDS: number = 30;
  static readonly PLAYER_PROGRESS_NEW_PC_WINDOW_DECOR_HEIGHT: number = 40;
  static readonly PLAYER_PROGRESS_NEW_PC_DIALOG_WINDOW_DECOR_HEIGHT: number = 32;
  static readonly PLAYER_PROGRESS_BREAKPOINTS_MD: number = 600;
  static readonly PLAYER_PROGRESS_ORIGIN_X: number = 0;
  static readonly PLAYER_PROGRESS_DOUBLE_CLICK: number = 2;
  static readonly PLAYER_PROGRESS_SINGLE_CLICK: number = 1;
  static readonly PLAYER_PROGRESS_ZINDEX_SECOND: number = 2;
  static readonly PLAYER_PROGRESS_ZINDEX_THIRD: number = 3;
  static readonly PLAYER_PROGRESS_ZINDEX_FOURTH: number = 4;
  static readonly PLAYER_PROGRESS_WINDOW_TYPE_UI_EXTENSION_WINDOW: number = 2;
  static readonly PLAYER_PROGRESS_WINDOW_TYPE_MAIN_WINDOW: number = 0;
  static readonly PLAYER_PROGRESS_WINDOW_TYPE_DIALOG_WINDOW: number = 1;
  static readonly PLAYER_PROGRESS_VIEW_FILE_TYPE_MULTIPLE: number = 1;
  static readonly PLAYER_PROGRESS_VIEW_FILE_TYPE_SINGLE: number = 0;
  static readonly PLAYER_PROGRESS_LOADING_STATUS_LOAD_STATE_SUCCESS: number = 0;
  static readonly PLAYER_PROGRESS_LOADING_STATUS_LOAD_STATE_FAILED: number = 1;
  static readonly PLAYER_PROGRESS_LOADING_STATUS_LOAD_STATE_LOADING: number = 2;
  static readonly PLAYER_PROGRESS_LOADING_STATUS_LOAD_STATE_ENCRYPTED: number = 3;
  static readonly PLAYER_PROGRESS_FILE_STATUS_UN_EXIST: number = 0;
  static readonly PLAYER_PROGRESS_FILE_STATUS_IS_DIRECTORY: number = 1;
  static readonly PLAYER_PROGRESS_FILE_STATUS_IS_FILE: number = 2;
  static readonly PLAYER_PROGRESS_LOCATION_TYPE_LOCAL: number = 1;
  static readonly PLAYER_PROGRESS_LOCATION_TYPE_CLOUD: number = 2;
  static readonly PLAYER_PROGRESS_LOCATION_TYPE_LOCAL_AND_CLOUD: number = 3;
  static readonly PLAYER_PROGRESS_FILE_CHANGE_EVENT_IN_MODIFY: number = 0x2;
  static readonly PLAYER_PROGRESS_FILE_CHANGE_EVENT_IN_ATTRIB: number = 0x4;
  static readonly PLAYER_PROGRESS_FILE_CHANGE_EVENT_IN_CLOSE_WRITE: number = 0x8;
  static readonly PLAYER_PROGRESS_FILE_CHANGE_EVENT_IN_MOVED_FROM: number = 0x40;
  static readonly PLAYER_PROGRESS_FILE_CHANGE_EVENT_IN_RENAME: number = 0x60;
  static readonly PLAYER_PROGRESS_FILE_CHANGE_EVENT_IN_MOVED_TO: number = 0x80;
  static readonly PLAYER_PROGRESS_FILE_CHANGE_EVENT_IN_CREATE: number = 0x100;
  static readonly PLAYER_PROGRESS_FILE_CHANGE_EVENT_IN_DELETE: number = 0x200;
  static readonly PLAYER_PROGRESS_FILE_CHANGE_EVENT_IN_DELETE_SELF: number = 0x400;
  static readonly PLAYER_PROGRESS_FILE_CHANGE_EVENT_IN_MOVE_SELF: number = 0x800;
  static readonly PLAYER_PROGRESS_APP_BAR_TYPE_TITLE_BAR: string = 'title_bar';
  static readonly PLAYER_PROGRESS_APP_BAR_TYPE_TOOL_BAR: string = 'tool_bar';
  static readonly PLAYER_PROGRESS_APP_BAR_TYPE_DIALOG_BAR: string = 'dialog_bar';
  static readonly PLAYER_PROGRESS_SCROLL_BAR_TYPE_VERTICAL: number = 0;
  static readonly PLAYER_PROGRESS_SCROLL_BAR_TYPE_HORIZONTAL: number = 1;
  static readonly PLAYER_PROGRESS_OFFICE_TYPE_OFFICE_WORD: string = 'Word';
  static readonly PLAYER_PROGRESS_OFFICE_TYPE_OFFICE_EXCEL: string = 'Excel';
  static readonly PLAYER_PROGRESS_OFFICE_TYPE_OFFICE_PPT: string = 'PowerPoint';
  static readonly PLAYER_PROGRESS_OFFICE_TYPE_OFFICE_OFD: string = 'OFD';
  static readonly PLAYER_PROGRESS_OFFICE_TYPE_OFFICE_OTHER: string = 'Other';
  static readonly PLAYER_PROGRESS_OPEN_TYPE_LOAD_STATE_FAILED: number = 0;
  static readonly PLAYER_PROGRESS_OPEN_TYPE_LOAD_STATE_LOADING: number = 1;
  static readonly PLAYER_PROGRESS_OPEN_TYPE_LOAD_STATE_TEXT: number = 2;
  static readonly PLAYER_PROGRESS_OPEN_TYPE_LOAD_STATE_IMAGE: number = 3;
  static readonly PLAYER_PROGRESS_OPEN_TYPE_LOAD_STATE_VIDEO: number = 4;
  static readonly PLAYER_PROGRESS_OPEN_TYPE_LOAD_STATE_AUDIO: number = 5;
  
  static PLAYER_PROGRESS_OPEN_TYPE_FUNC(state: number): string {
    switch (state) {
      case 0:
        return 'LOAD_STATE_FAILED';
      case 1:
        return 'LOAD_STATE_LOADING';
      case 2:
        return 'LOAD_STATE_TEXT';
      case 3:
        return 'LOAD_STATE_IMAGE';
      case 4:
        return 'LOAD_STATE_VIDEO';
      case 5:
        return 'LOAD_STATE_AUDIO';
      default:
        return 'LOAD_STATE_FAILED';
    }
  }
}
