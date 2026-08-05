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



/** 应用级 NavPathStack 整页路由名（弹窗不走 Nav） */
export class AppNavRoutes {
  public static readonly SEARCH: string = 'search';
  public static readonly SETTINGS: string = 'settings';

  /** 是否为搜索相关子页 */
  static isSearchRoute(route: string): boolean {
    return route === AppNavRoutes.SEARCH;
  }
  public static readonly HOME_MEDIA_EDIT: string = 'homeMediaEdit';
  public static readonly PLAYLIST_DETAIL: string = 'playlistDetail';
  public static readonly PLAYLIST_EDIT: string = 'playlistEdit';
  public static readonly PLAYLIST_ADD_AUDIO: string = 'playlistAddAudio';
  public static readonly PLAYLIST_LIST_SELECT: string = 'playlistListSelect';
  public static readonly AUDIO_PLAYER: string = 'audioPlayer';
  public static readonly VIDEO_PLAYER: string = 'videoPlayer';

  /**
   * 是否为播放列表 Tab 子页面路由
   *
   * @param route 路由名
   * @returns 是否歌单子页
   */
  static isPlaylistRoute(route: string): boolean {
    return route === AppNavRoutes.PLAYLIST_DETAIL ||
      route === AppNavRoutes.PLAYLIST_EDIT ||
      route === AppNavRoutes.PLAYLIST_ADD_AUDIO ||
      route === AppNavRoutes.PLAYLIST_LIST_SELECT;
  }

  /**
   * 是否为全屏播放器路由
   *
   * @param route 路由名
   * @returns 是否播放器页
   */
  static isPlayerRoute(route: string): boolean {
    return route === AppNavRoutes.AUDIO_PLAYER ||
      route === AppNavRoutes.VIDEO_PLAYER;
  }
}
