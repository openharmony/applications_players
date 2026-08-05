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
  LOAD_STATE_OFFICE = 11,
}

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

export enum AppBarType {
  TITLE_BAR = 'title_bar',
  TOOL_BAR = 'tool_bar',
  DIALOG_BAR = 'dialog_bar'
}

export enum FileStatus {
  UN_EXIST = 0,
  IS_DIRECTORY = 1,
  IS_FILE = 2
}

export enum ViewFileType {
  SINGLE = 'single',
  MULTIPLE = 'multiple'
}

export enum ShortKey {
  COPY = 'Ctrl+C',
  PRINT = 'Ctrl+P',
  DELETE = 'Ctrl+D',
  SPACE = 'Space',
  SKIP_BACKWARD = 'Ctrl+Left',
  SKIP_FORWARD = 'Ctrl+Right',
  SPEED_0_25 = 'Ctrl+Shift+G',
  SPEED_0_50 = 'Ctrl+Shift+H',
  SPEED_1_00 = 'Ctrl+Shift+J',
  SPEED_1_50 = 'Ctrl+Shift+K',
  SPEED_2_00 = 'Ctrl+Shift+L',
  LOOP = 'Ctrl+T',
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

export class Constants {
  public static readonly EMPTY_STRING: string = '';
  public static readonly WEIGHT: string = '100%';
  public static readonly ALL_PERCENT: string = '100%';
  public static readonly ORIGIN_X: number = 0;
  public static readonly ORIGIN_Y: number = 0;
  public static readonly MAIN_PAGE: string = 'pages/Index';
  public static readonly DIALOG_PAGE: string = 'pages/DialogPage';
  public static readonly MOUNTED_TASK_TIMEOUT: number = 50;
  public static readonly UNKNOWN_FILE_NAME: string = 'unknown_file';
  public static readonly TEXT_COLOR_SECONDARY: Resource = $r('sys.color.ohos_id_color_text_secondary');
  public static readonly TEXT_SIZE_BODY: Resource = $r('sys.float.ohos_id_text_size_body2');
  public static readonly COLOR_SUB_BACKGROUND: Resource = $r('sys.color.ohos_id_color_sub_background');
  public static readonly BACKGROUND_SECONDARY: Resource = $r('sys.color.background_secondary');
  public static readonly COLOR_BACKGROUND: Resource = $r('sys.color.ohos_id_color_background');
  public static readonly BAR_HEIGHT: number = 56;
  public static readonly TOAST_PLAYERPROGRESS_BOTTOM: number = 96;
  public static readonly BAR_MARGIN_HORIZONTAL: number = 24;
  public static readonly APP_BAR_ICON_IMMERSION: Resource = $r('sys.symbol.arrow_up_left_and_arrow_down_right');
  public static readonly APP_BAR_ICON_RECOVER: Resource = $r('sys.symbol.arrow_down_right_and_arrow_up_left');
  public static readonly APP_BAR_ICON_SHARE: Resource = $r('sys.symbol.share');
  public static readonly APP_BAR_ICON_BACK: Resource = $r('sys.symbol.chevron_backward');
  public static readonly APP_BAR_ICON_SAVE: Resource = $r('sys.symbol.save');
  public static readonly APP_BAR_ICON_DETAILS: Resource = $r('sys.symbol.doc_text');
  public static readonly APP_BAR_ICON_MORE: Resource = $r('sys.symbol.dot_grid_2x2');
  public static readonly APP_BAR_ICON_CLEAR: Resource = $r('sys.symbol.xmark');
  public static readonly APP_BAR_ICON_OTHER: Resource = $r('sys.symbol.square_grid_2x2');
  public static readonly APP_BAR_ICON_ABOUT: Resource = $r('sys.symbol.info_circle');
  public static readonly APP_BAR_ICON_FULL_SCREEN: Resource = $r('sys.symbol.full_screen_fill');
  public static readonly APP_BAR_ICON_SEARCH: Resource = $r('sys.symbol.magnifyingglass');
  public static readonly APP_BAR_ICON_ARROW_LEFT: Resource = $r('sys.symbol.arrow_left');
  public static readonly APP_BAR_ICON_RIGHT: Resource = $r('sys.symbol.chevron_right');
  public static readonly APP_BAR_ICON_CHECK_MARK: Resource = $r('sys.symbol.checkmark');
  public static readonly APP_BAR_ICON_VOLUME: Resource = $r('sys.symbol.speaker_wave_3');
  public static readonly APP_BAR_ICON_SILENT: Resource = $r('sys.symbol.speaker_slash');
  public static readonly PLAYER_PROGRESS_ICON_PAUSE: Resource = $r('sys.symbol.pause');
  public static readonly PLAYER_PROGRESS_ICON_PLAY: Resource = $r('sys.symbol.play_fill');
  public static readonly APP_BAR_ICON_LOOP: Resource = $r('sys.symbol.arrow_counterclockwise');
  public static readonly APP_BAR_ICON_REPEAT_LIST: Resource = $r('sys.symbol.repeat');
  public static readonly APP_BAR_ICON_REPEAT_ONE: Resource = $r('sys.symbol.repeat_1');
  public static readonly APP_BAR_ICON_REPEAT_OFF: Resource = $r('sys.symbol.arrow_counterclockwise');
  public static readonly APP_BAR_ICON_SHUFFLE: Resource = $r('sys.symbol.shuffle');
  public static readonly APP_BAR_ICON_GO_BACKWARD_10: Resource = $r('sys.symbol.gobackward_10');
  public static readonly APP_BAR_ICON_GO_FORWARD_30: Resource = $r('sys.symbol.goforward_30');
  public static readonly APP_BAR_ICON_GO_BACKWARD_15: Resource = $r('sys.symbol.gobackward_15');
  public static readonly APP_BAR_ICON_GO_FORWARD_15: Resource = $r('sys.symbol.goforward_15');
  public static readonly APP_BAR_ICON_ROTATE_LANDSCAPE: Resource = $r('sys.symbol.rectangle_rotate');
  public static readonly APP_BAR_ICON_SKIP_PREVIOUS: Resource = $r('sys.symbol.backward_end_fill');
  public static readonly APP_BAR_ICON_SKIP_NEXT: Resource = $r('sys.symbol.forward_end_fill');
  public static readonly APP_BAR_ICON_PLAYLIST: Resource = $r('sys.symbol.music_note_list');
  public static readonly APP_BAR_ICON_VOLUME_LOW: Resource = $r('sys.symbol.speaker_wave_1');
  public static readonly APP_BAR_ICON_VOLUME_MEDIUM: Resource = $r('sys.symbol.speaker_wave_2');
  public static readonly APP_BAR_ICON_BRIGHTNESS: Resource = $r('sys.symbol.sun_max_fill');
  public static readonly APP_BAR_ICON_FAST_FORWARD: Resource = $r('sys.symbol.fast_forward');
  public static readonly APP_BAR_ICON_LOCK: Resource = $r('sys.symbol.lock_fill');
  public static readonly APP_BAR_ICON_UNLOCK: Resource = $r('sys.symbol.lock_open');
  public static readonly APP_BAR_HEIGHT: number = 52;
  public static readonly APP_BAR_BUTTON_WIDTH: number = 40;
  public static readonly ACTUALLY_APP_BAR_BUTTON_WIDTH: number = 48;
  public static readonly TITLE_BAR_PC_DEFAULT_WIDTH: number = 210;
  public static readonly APP_BAR_IMAGE_ICON_WIDTH: number = 24;
  public static readonly APP_BAR_IMAGE_ICON_HEIGHT: number = 24;
  public static readonly DIALOG_WINDOW_BG_COLOR: string = '#6bf0f0f0';
  public static readonly APP_BAR_ICON_MARGIN: number = 8;
  public static readonly TITLE_BAR_ICON_BACKGROUND_COLOR = $r('sys.color.ohos_id_color_button_normal');
  public static readonly TITLE_BAR_MARGIN_SIDE: number = 16;
  public static readonly TITLE_BAR_MARGIN_12: number = 12;
  public static readonly TITLE_BAR_ICON_MARGIN_AROUND: number = 8;
  public static readonly TITLE_BAR_ICON_MARGIN_BUTTON: number = 4;
  public static readonly TITLE_BAR_PADDING_148: number = 148;
  public static readonly TITLE_BAR_PADDING_24: number = 24;
  public static readonly TITLE_BAR_PADDING_16: number = 16;
  public static readonly TOOL_BAR_TEXT_MARGIN: number = 4;
  public static readonly TOOL_BAR_PRESS_PADDING = 2;
  public static readonly TOOL_BAR_ICON_MARGIN_TOP: number = 3;
  public static readonly PLAYER_PROGRESS_BG_GRADIENT_VIDEO: ([ResourceColor, number])[] =
    [['#00000000', 0], ['#99000000', 1]];
  public static readonly BIND_POPUP_TARGET_SPACE: number = 8;
  public static readonly BIND_POPUP_PADDING_16: number = 16;
  public static readonly BIND_POPUP_PADDING_8: number = 8;
  public static readonly BIND_POPUP_TEXT_MAX_WIDTH: number = 604;
  public static readonly BIND_POPUP_WIDTH_MARGIN: number = 48;
  public static readonly ONE_HUNDRED: number = 100;
  public static readonly A_THOUSAND: number = 1000;
  public static readonly ZINDEX_FIRST: number = 1;
  public static readonly ZINDEX_SECOND: number = 2;
  public static readonly ZINDEX_THIRD: number = 3;
  public static readonly ZINDEX_FOURTH: number = 4;
  public static readonly SINGLE_CLICK: number = 1;
  public static readonly DOUBLE_CLICK: number = 2;
  public static readonly TRANSPARENT_BACKGROUND: Resource = $r('sys.color.ohos_id_color_background_transparent');
  public static readonly COLOR_PRIMARY: Resource = $r('sys.color.ohos_id_color_primary');
  public static readonly CLICK_EFFECT_COLOR: Resource = $r('sys.color.ohos_id_color_click_effect');
  public static readonly COLOR_HOVER: Resource = $r('sys.color.ohos_id_color_hover');
  public static readonly COLOR_HOVER_DARK: Resource = $r('sys.color.ohos_id_color_hover_dark');
  public static readonly CLICKED_CORNER_RADIUS: Resource = $r('sys.float.ohos_id_corner_radius_clicked');
  public static readonly CORNER_RADIUS_DEFAULT_M: Resource = $r('sys.float.ohos_id_corner_radius_default_m');
  public static readonly BREAKPOINTS_SM: number = 360;
  public static readonly BREAKPOINTS_MD: number = 550;
  public static readonly BREAKPOINTS_MD_2: number = 600;
  public static readonly BREAKPOINTS_LG: number = 840;
  public static readonly DEFAULT_WIDTH: number = 0;
  public static readonly EPSILON: number = 1e-6;
  public static readonly SEEK_CLOSEST = 2;
  public static readonly DIALOG_BAR_HEIGHT: number = 48;
  public static readonly DIALOG_TITLE_BAR_PC_DEFAULT_WIDTH: number = 142;
  public static readonly DIALOG_BTN_WIDTH = 40;
  public static readonly DIALOG_TEXT_PADDING: number = 16;
  public static readonly DIALOG_TITLE_PADDING_LEFT: number = 24;
  public static readonly DIALOG_TITLE_PADDING_RIGHT: number = 56;
  public static readonly DIALOG_WINDOW_MIN_WIDTH = 600;
  public static readonly DIALOG_WINDOW_MIN_HEIGHT = 452;
  public static readonly ERROR_NOT_FILE = 13900002;
  public static readonly PERMISSION_DENIED = 13900012;
  public static readonly RIGHT_MENU_MIN_WIDTH = 160;
  public static readonly RIGHT_MENU_MAX_WIDTH = '67%';
  public static readonly MENU_AUTO_WIDTH = 'auto';
  public static readonly MENU_ITEM_INNER_WIDTH = 216;
  public static readonly MENU_ITEM_INNER_HEIGHT = 40;
  public static readonly MENU_ITEM_WIDTH = 252;
  public static readonly MENU_ITEM_HEIGHT = 40;
  public static readonly WEB_MENU_HEIGHT: number = 48;
  public static readonly EDGE_ANTIALIASING: number = 0.4;
  public static readonly EDGE_ANTIALIASING_SUB: number = 0.34;
  public static readonly FULL_SCREEN_MODE_TEXT: string = 'full_screen_mode';
  public static readonly PDF_LIST_CASHED_COUNT: number = 2;
  public static readonly PDF_FREE_TEXT_ANNOTATION_TYPE: number = 20;
  public static readonly SEARCH_BAR_HEIGHT: number = 40;
  public static readonly PLACEHOLDER_FONT_SIZE: number = 16;
  public static readonly SEARCH_BAR_BUTTON_MARGIN_2: number = 2;
  public static readonly SEARCH_BAR_BUTTON_HEIGHT: number = 40;
  public static readonly CLEAR_BUTTON_WIDTH: number = 36;
  public static readonly CLEAR_BUTTON_MARGIN_RIGHT: number = 2;
  public static readonly SEARCH_BAR_TEXT_INPUT_ID: string = 'SearchBar_TextInput';
  public static readonly PUBLIC_VIEW_FILE_LIST: Resource = $r('sys.symbol.list_bullet');
  public static readonly LIST_FILE_ICON_WIDTH: number = 48;
  public static readonly LIST_FILE_ICON_RADIUS: number = 12;
  public static readonly LIST_FILE_ICON_PADDING: Padding = {
    left: 8,
    top: 12,
    bottom: 12,
    right: 16
  };
  public static readonly LIST_FILE_ITEM_PADDING: Padding = { left: 8, right: 8 };
  public static readonly LIST_FILE_BLACK_HEIGHT: number = 32;
  public static readonly LIST_FILE_LIST_WIDTH: number = 368;
  public static readonly LIST_FILE_LIST_HEIGHT: number = 250;
  public static readonly LIST_FILE_LIST_CACHE_COUNT: number = 3;
  public static readonly LIST_BUTTON_OPTION_PADDING_MAX: number = 24;
  public static readonly LIST_BUTTON_OPTION_PADDING_MID: number = 20;
  public static readonly LIST_BUTTON_OPTION_PADDING_MIN: number = 16;
  public static readonly LIST_BUTTON_BACKGROUND_EFFECT: string = '#1a0a59f7';
  public static readonly THUMBNAIL_LIST_COMPONENT_WIDTH: number = 240;
  public static readonly THUMBNAIL_LIST_COMPONENT_MAX_WIDTH: number = 304;
  public static readonly THUMBNAIL_LIST_COMPONENT_HEIGHT: number = 708;
  public static readonly VIDEO_THUMBNAIL_WIDTH: number = 200;
  public static readonly PDF_CORNER_RADIUS: number = 12;
  public static readonly PDF_SIDEBAR_CONTAINER_COLOR: Resource = $r('sys.color.ohos_id_color_panel_bg');
  public static readonly PDF_ANIMATETO_DURATION: number = 300;
  public static readonly PDF_SCROLL_COUNT_LIMIT: number = 20;
  public static readonly PDF_SCROLL_COUNT_CLEAR_TIME: number = 300;
  public static readonly PDF_PAN_OPTION_FINGERS_ONE: number = 1;
  public static readonly PDF_POSITION_SCROLL_LIMIT_Y: number = 0.5;
  public static readonly PDFVIEW_SCROLLBAR_PADDING: number = 12;
  public static readonly PDF_BAR_ICON_PEN_KIT: Resource = $r('sys.symbol.ballpointpen_tip_crop_circle');
  public static readonly PDF_DIVIDER_WIDTH: string = '1px';
  public static readonly PDF_DIVIDER_OPACITY: number = 0.2;
  public static readonly DIALOG_CORNER_RADIUS_32: number = 32;
  public static readonly DIALOG_CORNER_RADIUS_16: number = 16;
  public static readonly DIALOG_TEXT_FONT_SIZE_20: number = 20;
  public static readonly DIALOG_TEXT_FONT_SIZE_16: number = 16;
  public static readonly DIALOG_TEXT_MARGIN_16: number = 16;
  public static readonly DIALOG_TEXT_MARGIN_BOTTOM_8: number = 8;
  public static readonly DIALOG_TEXT_MARGIN_VERTICAL: number = 15;
  public static readonly DIALOG_BUTTON_MARGIN_16: number = 16;
  public static readonly DIALOG_TEXT_MARGIN: number = 24;
  public static readonly DIALOG_DIVIDER_WIDTH_16: number = 16;
  public static readonly MARGIN_ZERO: number = 0;
  public static readonly BORDER_RADIUS_20: number = 20;
  public static readonly SIDEBAR_WIDTH: number = 240;
  public static readonly PHONE_SIDEBAR_WIDTH_RATION: number = 0.2;
  public static readonly SIDEBAR_BACKGROUND_COLOR: number = 0x330A59F7;
  public static readonly SIDEBAR_DELAY_TIME: number = 20;
  public static readonly SIDEBAR_SPACE_6: number = 6;
  public static readonly SIDEBAR_DEFAULT_IMAGE_HEIGHT: number = 200;
  public static readonly MARK_MENU_ITEM_HEIGHT: number = 40;
  public static readonly HIGHLIGHT_SUB_MENU_ITEM_HEIGHT: number = 40;
  public static readonly PAD_FOLDED_MENU_SIZE: number = 32;
  public static readonly PAD_FOLDED_BUTTON_BORDER: number = 16;
  public static readonly PAD_FOLDED_BUTTON_PADDING: number = 6;
  public static readonly PAD_FOLDED_MENU_OFFSET_X: number = 4;
  public static readonly PAD_FOLDED_MENU_OFFSET_Y: number = 8;
  public static readonly PAD_FOLDED_MENU_BASE_OFFSET: number = 7;
  public static readonly DIVIDER_STROKE_WIDTH: number = 1;
  public static readonly DIVIDER_MARGIN_LEFT: number = 44;
  public static readonly DIVIDER_MARGIN_RIGHT: number = 12;
  public static readonly SEARCH_BAR_SPACE: number = 8;
  public static readonly SEARCH_BAR_BORDER_RADIUS: number = 24;
  public static readonly TEXT_INPUT_PADDING_12: number = 12;
  public static readonly TEXT_INPUT_PADDING_0: number = 0;
  public static readonly TEXT_INPUT_PADDING_8: number = 8;
  public static readonly SEARCH_BAR_PADDING_8: number = 8;
  public static readonly SEARCH_BAR_PADDING_12: number = 12;
  public static readonly EVENT_SEARCH_CONTENT_CHANGE: number = 1100;
  public static readonly MARK_COLOR_RED: number = 0x99E84026;
  public static readonly MARK_COLOR_YELLOW: number = 0x99F7CE00;
  public static readonly MARK_COLOR_GREEN: number = 0x9964BB5C;
  public static readonly MARK_COLOR_BLUE: number = 0x9946B1E3;
  public static readonly MARK_COLOR_CYAN: number = 0x9961CFBE;
  public static readonly MARK_COLOR_PURPLE: number = 0x99AC49F5;
  public static readonly SHARE_BUTTON_KEY: string = 'shareBtn';
  public static readonly DEFAULT_APP_BUTTON_KEY: string = 'defaultAppBtn';
  public static readonly TOOL_BUTTON_PRIORITY_ZERO: number = 0;
  public static readonly TOOL_BUTTON_PRIORITY_ONE: number = 1;
  public static readonly TOOL_BUTTON_PRIORITY_TWO: number = 2;
  public static readonly TOOL_BUTTON_PRIORITY_THREE: number = 3;
  public static readonly TOOL_BUTTON_PRIORITY_FOUR: number = 4;
  public static readonly TOOL_BUTTON_PRIORITY_FIVE: number = 5;
  public static readonly TOOL_BUTTON_PRIORITY_SIX: number = 6;
  public static readonly TOOL_BUTTON_PRIORITY_SEVEN: number = 7;
  public static readonly TOOL_BUTTON_PRIORITY_EIGHT: number = 8;
  public static readonly TOOL_BUTTON_PRIORITY_NINE: number = 9;
  public static readonly NEW_PC_WINDOW_DECOR_HEIGHT = 56;
  public static readonly NEW_PC_DIALOG_WINDOW_DECOR_HEIGHT = 48;
  public static readonly DEFAULT_SCALE: number = 1;
  public static readonly DELAY_MILLISECOND: number = 3000;
  public static readonly MOVE_IN_DELAY_FOR_FIRST_TIME: number = 700;
  public static readonly MOVE_IN_DELAY_FOR_NON_FIRST_TIME: number = 300;
  public static readonly MOVE_OUT_DELAY_FOR_FIRST_TIME: number = 300;
  public static readonly MOVE_OUT_DELAY_FOR_NON_FIRST_TIME: number = 0;
  public static readonly NUMBER_2: number = 2;
  public static readonly WPS_ICON_MARGIN_BOTTOM: number = 78;
  public static readonly WPS_ICON_WIDTH: number = 123;
  public static readonly WPS_ICON_HEIGHT: number = 36;
  public static readonly DEFAULT_SCREEN_DPI = 360;
  public static readonly PWD_DIALOG_DARK_BORDER_COLOR = '#66000000';
  public static readonly PWD_DIALOG_LIGHT_BORDER_COLOR = '#19000000';
  public static readonly PWD_DIALOG_NORMAL_BORDER_COLOR = '#33FFFFFF';
  public static readonly DELETE_FILE_DIALOG_CANCEL_BUTTON_COLOR = $r('sys.color.font_emphasize');
  public static readonly DELETE_FILE_DIALOG_DELETE_BUTTON_COLOR = $r('sys.color.warning');
  public static readonly MENU_NORMAL_SHADOW_RADIUS = 16;
  public static readonly MENU_NORMAL_SHADOW_COLOR = '#33000000';
  public static readonly MENU_ITEM_NORMAL_WIDTH = 152;
  public static readonly WINDOW_BORDER_WIDTH = '1.5vp';
  public static readonly WINDOW_BORDER_COLOR_FOCUS: string = '#66808080';
  public static readonly WINDOW_BORDER_COLOR_BLUR: string = '#4D808080';
  public static readonly DEFAULT_CLOSE_LONG_PRESS_TIME: number = 5000000000;
  public static readonly UNIQUE_ID_LENGTH = 8;
  public static readonly immersiveOnRefocusTime: number = 500;
  public static readonly DURATION_SHOW_TOAST_LONG = 3500;
  public static readonly DURATION_SHOW_TOAST_SHORT = 2000;
  public static readonly ONE_SECOND = 1000;
  public static readonly FILE_DETAILS_DECOR_HEIGHT: number = 48;
  public static readonly FILE_DETAILS_ITEM_LINE_HEIGHT: number = 21;
  public static readonly FILE_DETAILS_ITEM_MARGIN_BOTTOM: number = 8;
  public static readonly LAST_FILE_DETAILS_ITEM_MARGIN_BOTTOM: number = 16;
  public static readonly PADDING_ANIMATE_PARAM: AnimateParam = {
    duration: 500,
    curve: Curve.EaseInOut,
    iterations: 1,
    playMode: PlayMode.Normal
  };
  public static readonly TOAST_FILE_UNSUPPORTED_BOTTOM = 50;
}
