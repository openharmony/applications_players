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



import { AppThemeConstants } from '@ohos/common/src/main/ets/constants/ui/AppThemeConstants';

/** 播放列表页 UI 固定常量 */
export class PlaylistConstants {
  static readonly PAGE_BACKGROUND: Resource = AppThemeConstants.PAGE_BACKGROUND;
  static readonly CARD_BACKGROUND: Resource = AppThemeConstants.CARD_BACKGROUND;
  static readonly PRIMARY_COLOR: Resource = AppThemeConstants.ACCENT;
  static readonly TEXT_PRIMARY: Resource = AppThemeConstants.TEXT_PRIMARY;
  static readonly TEXT_SECONDARY: Resource = AppThemeConstants.TEXT_SECONDARY;
  static readonly BORDER_COLOR: Resource = AppThemeConstants.BORDER;
  static readonly CHIP_BACKGROUND: Resource = AppThemeConstants.CHIP_BACKGROUND;
  /** 顶栏圆形加号按钮底色（与首页搜索/更多一致） */
  static readonly HEADER_ICON_BACKGROUND: Resource = AppThemeConstants.HEADER_ICON_BACKGROUND;
  static readonly DIALOG_MASK: Resource = AppThemeConstants.SCRIM_OVERLAY;
  /** 无遮罩（新建歌单等弹窗与列表页同色，不压暗背景） */
  static readonly DIALOG_MASK_NONE: string = '#00000000';
  static readonly DELETE_COLOR: Resource = AppThemeConstants.DELETE;
  static readonly THUMB_SIZE: number = 48;
  /** 详情页单曲行左右外边距（内容区与屏幕边缘留白） */
  static readonly DETAIL_TRACK_ROW_HORIZONTAL_MARGIN: number = 16;
  /** 详情页单曲行左右内边距 */
  static readonly DETAIL_TRACK_ROW_HORIZONTAL_PADDING: number = 12;
  static readonly DETAIL_TRACK_ROW_VERTICAL_PADDING: number = 10;
  /** 详情页单曲行上下间距（卡片之间留白） */
  static readonly DETAIL_TRACK_ROW_VERTICAL_MARGIN: number = 4;
  static readonly GRID_LANE_COUNT: number = 2;
  /** 宫格列间距 */
  static readonly GRID_COLUMNS_GAP: number = 12;
  static readonly GRID_ROWS_GAP: number = 12;
  /** 宫格左右留白 */
  static readonly GRID_HORIZONTAL_PADDING: number = 16;
  static readonly GRID_TOP_PADDING: number = 8;
  static readonly GRID_BOTTOM_PADDING: number = 16;
  /** 宫格 LazyForEach 预加载行数（约 2 列 × 2 行） */
  static readonly GRID_CACHED_COUNT: number = 4;
  /** 宫格菜单已弹出时，平移超过该距离（vp）视为起拖并关闭菜单 */
  static readonly GRID_MENU_DRAG_CLOSE_PAN_DISTANCE: number = 12;
  /** 详情页曲目 List LazyForEach 预加载项数 */
  static readonly DETAIL_TRACK_LIST_CACHED_COUNT: number = 8;
  /** 详情页曲目 LongPress 识别时长（毫秒） */
  static readonly DETAIL_TRACK_LONG_PRESS_DURATION_MS: number = 400;
  /** 详情页曲目长按拖拽高亮底色（与播放队列一致：仅改背景，不做 scale 动画） */
  static readonly DETAIL_TRACK_DRAG_HIGHLIGHT_BACKGROUND: Resource = AppThemeConstants.DRAG_HIGHLIGHT;
  /** 编辑页曲目长按第一阶段：缩小比例 */
  static readonly DETAIL_TRACK_LONG_PRESS_SHRINK_SCALE: number = 0.94;
  /** 编辑页曲目长按第二阶段：放大比例 */
  static readonly DETAIL_TRACK_LONG_PRESS_ENLARGE_SCALE: number = 1.03;
  /** 编辑页曲目长按缩小阶段不透明度 */
  static readonly DETAIL_TRACK_LONG_PRESS_SHRINK_OPACITY: number = 0.9;
  /** 编辑页曲目长按缩小动画时长（毫秒） */
  static readonly DETAIL_TRACK_LONG_PRESS_SHRINK_MS: number = 100;
  /** 编辑页曲目长按放大动画时长（毫秒） */
  static readonly DETAIL_TRACK_LONG_PRESS_ENLARGE_MS: number = 150;
  /** 编辑页曲目长按放大态阴影颜色 */
  static readonly DETAIL_TRACK_LONG_PRESS_SHADOW_COLOR: string = 'rgba(0,0,0,0.2)';
  /** 编辑页曲目长按放大态阴影半径 */
  static readonly DETAIL_TRACK_LONG_PRESS_SHADOW_RADIUS: number = 12;
  /** 添加音频页 List LazyForEach 预加载项数 */
  static readonly ADD_AUDIO_LIST_CACHED_COUNT: number = 10;
  /** 添加音频页搜索框高度（vp） */
  static readonly ADD_AUDIO_SEARCH_BAR_HEIGHT: number = 44;
  static readonly ADD_AUDIO_SEARCH_BAR_RADIUS: number = 22;
  /** 搜索框距屏幕左右留白（vp） */
  static readonly ADD_AUDIO_SEARCH_BAR_HORIZONTAL_MARGIN: number = 16;
  static readonly ADD_AUDIO_SEARCH_BAR_PADDING_H: number = 12;
  static readonly ADD_AUDIO_SEARCH_BAR_MARGIN_BOTTOM: number = 12;
  static readonly ADD_AUDIO_SEARCH_ICON_SIZE: number = 18;
  /** 添加按钮 /「已添加」文案固定占位宽度，避免切换时挤压文件信息换行 */
  static readonly ADD_AUDIO_ACTION_SLOT_WIDTH: number = 48;
  static readonly ADD_AUDIO_ACTION_LABEL_FONT_SIZE: number = 13;
  /** 搜索框样式由 @ohos/search SearchBar / SearchUiConstants 统一提供 */
  /** 播放列表网格卡片 */
  static readonly GRID_CARD_BORDER_RADIUS: number = 16;
  static readonly GRID_CARD_GRADIENT_START: string = '#667EEA';
  static readonly GRID_CARD_GRADIENT_END: string = '#764BA2';
  static readonly GRID_CARD_COVER_ICON_COLOR: string = 'rgba(255,255,255,0.92)';
  static readonly GRID_CARD_COVER_ICON_SIZE: number = 40;
  /** 网格卡无封面：浅灰蓝底（参考设计稿） */
  static readonly GRID_CARD_COVER_PLACEHOLDER_BACKGROUND: string = '#D6E2EE';
  static readonly GRID_CARD_COVER_PLACEHOLDER_ICON_COLOR: string = '#A8B8C8';
  /** 网格卡更多按钮 */
  static readonly GRID_CARD_MORE_ICON_SIZE: number = 20;
  static readonly GRID_CARD_MORE_ICON_COLOR: Resource = AppThemeConstants.TEXT_PRIMARY;
  static readonly GRID_CARD_MORE_HIT_SIZE: number = 32;
  static readonly GRID_CARD_MORE_MARGIN: number = 4;
  /** 歌单列表行无封面占位：浅灰底圆角框（多选页） */
  static readonly LIST_CARD_COVER_PLACEHOLDER_BACKGROUND: Resource = PlaylistConstants.BORDER_COLOR;
  /** 歌单列表行无封面占位：居中白色音乐符号 */
  static readonly LIST_CARD_COVER_PLACEHOLDER_ICON_COLOR: Resource = AppThemeConstants.ON_ACCENT_TEXT;
  static readonly LIST_CARD_COVER_PLACEHOLDER_ICON_SIZE: number = 22;
  static readonly LIST_CARD_COVER_PLACEHOLDER_RADIUS: number = 6;
  static readonly GRID_CARD_NAME_FONT_SIZE: number = 14;
  static readonly GRID_CARD_COUNT_FONT_SIZE: number = 12;
  static readonly GRID_CARD_TEXT_PADDING_HORIZONTAL: number = 12;
  static readonly GRID_CARD_TEXT_PADDING_VERTICAL: number = 10;
  static readonly GRID_CARD_TEXT_GAP: number = 4;
  static readonly LIST_CREATE_BUTTON_SIZE: number = 36;
  static readonly LIST_CREATE_BUTTON_ICON_SIZE: number = 18;
  static readonly LIST_CREATE_BUTTON_SHADOW: string = 'rgba(0,122,255,0.35)';
  static readonly SELECTION_DELETE_BAR_HEIGHT: number = 48;
  static readonly SELECTION_DELETE_BAR_BORDER_RADIUS: number = 12;
  static readonly SELECTION_DELETE_BAR_FONT_SIZE: number = 16;
  /** 卡片封面区与文字区高度比：2 : 1 */
  static readonly GRID_CARD_COVER_WEIGHT: number = 2;
  static readonly GRID_CARD_TEXT_WEIGHT: number = 1;
  static readonly HEADER_FONT_SIZE: number = 26;
  static readonly LIST_HEADER_HORIZONTAL_PADDING: number = 16;
  static readonly EMPTY_STATE_ICON_COLOR: Resource = AppThemeConstants.TEXT_TERTIARY;
  static readonly EMPTY_STATE_TITLE_FONT_SIZE: number = 15;
  static readonly EMPTY_STATE_HINT_FONT_SIZE: number = 12;
  static readonly EMPTY_STATE_HORIZONTAL_PADDING: number = 24;
  /** 顶栏圆形按钮（与首页搜索 / 新建歌单 IconButton 统一：36 / 图标 18） */
  static readonly DETAIL_HEADER_BUTTON_SIZE: number = 36;
  static readonly DETAIL_HEADER_BUTTON_RADIUS: number = 18;
  static readonly DETAIL_HEADER_BUTTON_BACKGROUND: Resource = AppThemeConstants.HEADER_ICON_BACKGROUND;
  static readonly DETAIL_HEADER_ICON_FONT_SIZE: number = 18;
  /** 顶栏 Image 图标边长（与 Symbol 字号对齐） */
  static readonly DETAIL_HEADER_IMAGE_ICON_SIZE: number = 18;
  /** 顶栏右侧操作图标间距（添加音乐 / 编辑等同排） */
  static readonly DETAIL_HEADER_ACTION_GAP: number = 8;
  static readonly DETAIL_HEADER_HORIZONTAL_PADDING: number = 16;
  static readonly DETAIL_HEADER_TITLE_GAP: number = 15;
  static readonly DETAIL_HEADER_TITLE_FONT_SIZE: number = 22;
  /** 详情页第二行：播放全部 */
  static readonly DETAIL_ACTION_PLAY_BUTTON_SIZE: number = 36;
  static readonly DETAIL_ACTION_PLAY_ICON_SIZE: number = 16;
  static readonly DETAIL_ACTION_FONT_SIZE: number = 15;
  static readonly DETAIL_ACTION_ROW_PADDING_BOTTOM: number = 8;
  /** 续播条（与播放全部同行扁平样式，无独立底色） */
  static readonly RESUME_BAR_HEIGHT: number = 44;
  static readonly RESUME_BAR_BOTTOM_PADDING: number = 8;
  static readonly RESUME_BAR_FONT_SIZE: number = 15;
  static readonly RESUME_BAR_PLAY_ICON_SIZE: number = 16;
  static readonly RESUME_BAR_CLOSE_ICON_SIZE: number = 18;
  static readonly RESUME_BAR_CLOSE_BUTTON_SIZE: number = 40;
  static readonly RESUME_BAR_ICON_TEXT_GAP: number = 10;
  /** 详情页扁平列表行上下内边距 */
  static readonly DETAIL_FLAT_TRACK_ROW_PADDING_V: number = 10;
  /** 白底列表行间距：分割线样式下不再使用行间 margin */
  static readonly DETAIL_FLAT_TRACK_LIST_ITEM_TOP_MARGIN: number = 0;
  static readonly DETAIL_FLAT_TRACK_LIST_ITEM_BOTTOM_MARGIN: number = 0;
  /**
   * 列表内容白底圆角卡片（对齐首页列表视图）
   * 分割线起点 = 行左 padding + 缩略图 + 文字左间距 = 16 + 48 + 12
   */
  static readonly LIST_CARD_MARGIN_H: number = 16;
  static readonly LIST_CARD_MARGIN_TOP: number = 8;
  static readonly LIST_CARD_MARGIN_BOTTOM: number = 32;
  static readonly LIST_CARD_RADIUS: number = 24;
  static readonly LIST_CARD_BACKGROUND: Resource = AppThemeConstants.CARD_BACKGROUND;
  static readonly LIST_DIVIDER_STROKE_WIDTH: Length = '1px';
  static readonly LIST_DIVIDER_COLOR: Resource = $r('sys.color.ohos_id_color_list_separator');
  static readonly LIST_DIVIDER_START_MARGIN: number = 76;
  /** 多选行含 Checkbox(24)+间距(10) 时分割线起点 */
  static readonly LIST_DIVIDER_START_MARGIN_WITH_CHECKBOX: number = 110;
  static readonly LIST_DIVIDER_END_MARGIN: number = 16;
  /** 页面灰底（顶栏/空态外层）；列表内容在白底卡片内 */
  static readonly DETAIL_CONTENT_BACKGROUND: Resource = PlaylistConstants.PAGE_BACKGROUND;
  /** 曲目缩略图无封面占位（白底卡片上用浅灰区分） */
  static readonly DETAIL_TRACK_THUMB_PLACEHOLDER_BACKGROUND: Resource = AppThemeConstants.CHIP_BACKGROUND;
  /** 曲目行无封面时缩略图区背景（与 PlaylistAddAudioRow 一致） */
  static readonly TRACK_THUMB_NO_COVER_BACKGROUND: Resource = PlaylistConstants.DETAIL_TRACK_THUMB_PLACEHOLDER_BACKGROUND;
  static readonly MAX_NAME_LENGTH: number = 40;
  static readonly PLAYLIST_NAME_INPUT_FILTER: string = '[^\\s\\\\/:*?"<>|]';
  static readonly NAME_DIALOG_WIDTH: string = '88%';
  static readonly NAME_DIALOG_BORDER_RADIUS: number = 28;
  static readonly NAME_DIALOG_TITLE_FONT_SIZE: number = 17;
  static readonly NAME_DIALOG_HINT_FONT_SIZE: number = 12;
  static readonly NAME_DIALOG_HINT_AREA_HEIGHT: number = 20;
  static readonly NAME_DIALOG_ACTION_FONT_SIZE: number = 17;
  static readonly NAME_DIALOG_ACTION_HEIGHT: number = 50;
  static readonly NAME_DIALOG_ACTION_DIVIDER_HEIGHT: number = 18;
  static readonly NAME_DIALOG_INPUT_HEIGHT: number = 36;
  static readonly NAME_DIALOG_INPUT_BOTTOM_PADDING: number = 8;
  static readonly NAME_DIALOG_HORIZONTAL_PADDING: number = 24;
  static readonly CONFIRM_DIALOG_WIDTH: string = '80%';
  static readonly CONFIRM_DIALOG_BORDER_RADIUS: number = 14;
  static readonly PLAYLIST_MENU_WIDTH: number = 160;
  static readonly PLAYLIST_MENU_ITEM_HEIGHT: number = 44;
  static readonly PLAYLIST_MENU_RADIUS: number = 12;
  static readonly PLAYLIST_MENU_PRESS_INSET: number = 6;
}

/** 播放列表 Toast 文案资源（正文见 string.json） */
export class PlaylistToastConstants {
  static readonly ADD_SUCCESS: Resource = $r('app.string.playlist_add_success');
  static readonly ADD_DUPLICATE: Resource = $r('app.string.playlist_add_duplicate');
  static readonly PLAY_EMPTY: Resource = $r('app.string.playlist_play_empty');
}

/** 播放列表页内子页面 */
export enum PlaylistScreen {
  LIST = 0,
  DETAIL = 1,
  ADD_AUDIO = 2,
  EDIT = 3,
  LIST_SELECT = 4
}

/** 名称输入弹窗模式 */
export enum PlaylistNameDialogMode {
  NONE = 0,
  CREATE = 1,
  RENAME = 2
}

/** 确认弹窗模式 */
export enum PlaylistConfirmMode {
  NONE = 0,
  DELETE_PLAYLIST = 1,
  DELETE_TRACKS = 2,
  DELETE_PLAYLISTS = 3
}

/** bindPopup onStateChange 事件 */
export interface PopupStateEvent {
  isVisible: boolean;
}

/** 名称输入提示类型 */
export enum PlaylistNameInputHintType {
  NONE = 0,
  INVALID_CHAR = 1,
  TOO_LONG = 2
}


