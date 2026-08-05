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

import { media } from '@kit.MediaKit';

export enum WindowType {
  MAIN_WINDOW = 0,
  DIALOG_WINDOW = 1,
  UI_EXTENSION_WINDOW = 2
}

export enum LoadingStatus {
  LOAD_STATE_SUCCESS = 0,
  LOAD_STATE_FAILED = 1,
  LOAD_STATE_LOADING = 2,
  LOAD_STATE_ENCRYPTED = 3
}

export enum ViewFileType {
  SINGLE = 'single',
  MULTIPLE = 'multiple'
}

export enum FileStatus {
  UN_EXIST = 0,
  IS_DIRECTORY = 1,
  IS_FILE = 2
}

export class Constants {
  public static readonly ALL_PERCENT: string = '100%';
  public static readonly ONE_HUNDRED: number = 100;
  public static readonly A_THOUSAND: number = 1000;
  public static readonly ORIGIN_X: number = 0;
  public static readonly ORIGIN_Y: number = 0;
  public static readonly BAR_HEIGHT: number = 56;
  public static readonly BREAKPOINTS_MD: number = 600;
  public static readonly DOUBLE_CLICK: number = 2;
  public static readonly SINGLE_CLICK: number = 1;
  public static readonly ZINDEX_SECOND: number = 2;
  public static readonly ZINDEX_THIRD: number = 3;
  public static readonly ZINDEX_FOURTH: number = 4;
  public static readonly NEW_PC_WINDOW_DECOR_HEIGHT = 40;
  public static readonly NEW_PC_DIALOG_WINDOW_DECOR_HEIGHT = 32;
  public static readonly SEEK_CLOSEST: number = 2;
  public static readonly ERROR_NOT_FILE = 13900002;
  public static readonly COLOR_BACKGROUND: string = '#FFFFFF';
  public static readonly UNKNOWN_FILE_NAME: string = 'unknown_file_name';
  public static readonly PLAYER_PROGRESS_ICON_PLAY: Resource = $r('sys.symbol.play_circle');
  public static readonly PLAYER_PROGRESS_ICON_PAUSE: Resource = $r('sys.symbol.pause_circle');
  public static readonly APP_BAR_ICON_VOLUME: Resource = $r('sys.symbol.speaker_wave_2_fill');
  public static readonly APP_BAR_ICON_VOLUME_MEDIUM: Resource = $r('sys.symbol.speaker_wave_2_fill');
  public static readonly APP_BAR_ICON_VOLUME_LOW: Resource = $r('sys.symbol.speaker_wave_1_fill');
  public static readonly APP_BAR_ICON_SILENT: Resource = $r('sys.symbol.speaker_slash_fill');
  public static readonly APP_BAR_ICON_IMMERSION: Resource = $r('sys.symbol.arrow_up_left_and_arrow_down_right');
  public static readonly APP_BAR_ICON_RECOVER: Resource = $r('sys.symbol.arrow_down_right_and_arrow_up_left');
  public static readonly APP_BAR_ICON_FAST_FORWARD: Resource = $r('sys.symbol.goforward_30');
  public static readonly APP_BAR_ICON_GO_BACKWARD_10: Resource = $r('sys.symbol.gobackward_10');
  public static readonly APP_BAR_ICON_GO_FORWARD_30: Resource = $r('sys.symbol.goforward_30');
  public static readonly APP_BAR_ICON_LOOP: Resource = $r('sys.symbol.repeat');
  public static readonly APP_BAR_ICON_SINGLE_LOOP: Resource = $r('sys.symbol.repeat_1');
  public static readonly PLAYER_PROGRESS_BG_GRADIENT_VIDEO: ([string, number])[] = [
    ['rgba(0,0,0,0)', 0],
    ['rgba(0,0,0,0.6)', 1]
  ];
  public static readonly PADDING_ANIMATE_PARAM: AnimateParam = {
    duration: 300,
    curve: Curve.Smooth,
    iterations: 1,
    playMode: PlayMode.Normal
  };
}

export enum ShortKey {
  SPACE = 'Space'
}

export enum OpenType {
  LOAD_STATE_FAILED = 0,
  LOAD_STATE_LOADING = 1,
  LOAD_STATE_TEXT = 2,
  LOAD_STATE_IMAGE = 3,
  LOAD_STATE_VIDEO = 4,
  LOAD_STATE_AUDIO = 5,
  LOAD_STATE_WEB = 6,
  LOAD_STATE_FOLDERS = 7,
  LOAD_STATE_UNSUPPORTED = 8,
  LOAD_STATE_DIALOG_PERMISSION = 9,
  LOAD_STATE_PDF = 10,
  LOAD_STATE_OFFICE = 11
}

export const SPEED_MAP = new Map<number, number>([
  [media.PlaybackSpeed.SPEED_FORWARD_0_75_X, 0.75],
  [media.PlaybackSpeed.SPEED_FORWARD_1_00_X, 1],
  [media.PlaybackSpeed.SPEED_FORWARD_1_25_X, 1.25],
  [media.PlaybackSpeed.SPEED_FORWARD_1_75_X, 1.75],
  [media.PlaybackSpeed.SPEED_FORWARD_2_00_X, 2],
  [media.PlaybackSpeed.SPEED_FORWARD_0_50_X, 0.5],
  [media.PlaybackSpeed.SPEED_FORWARD_1_50_X, 1.5],
  [media.PlaybackSpeed.SPEED_FORWARD_3_00_X, 3],
  [media.PlaybackSpeed.SPEED_FORWARD_0_25_X, 0.25],
  [media.PlaybackSpeed.SPEED_FORWARD_0_125_X, 0.125]
]);