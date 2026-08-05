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


import { AppNavRoutes } from '../constants/AppNavRoutes';
import { NavPageSafeAreaShell } from '../components/NavPageSafeAreaShell';
import { AppThemeConstants } from '@ohos/common/src/main/ets/constants/ui/AppThemeConstants';
import { PlaylistConstants } from '@ohos/playlist';
import { SearchNavPage } from '../pages/nav/SearchNavPage';
import { SettingsNavPage } from '../pages/nav/SettingsNavPage';
import { PlaylistDetailNavPage } from '../pages/nav/PlaylistDetailNavPage';
import { PlaylistEditNavPage } from '../pages/nav/PlaylistEditNavPage';
import { PlaylistAddAudioNavPage } from '../pages/nav/PlaylistAddAudioNavPage';
import { PlaylistListSelectNavPage } from '../pages/nav/PlaylistListSelectNavPage';
import { AudioPlayerNavPage } from '../pages/nav/AudioPlayerNavPage';
import { VideoPlayerNavPage } from '../pages/nav/VideoPlayerNavPage';
import { HomeMediaEditNavPage } from '../pages/nav/HomeMediaEditNavPage';
import { HomeViewModel } from '../viewmodel/HomeViewModel';
import { NavRouterHelper } from '../utils/NavRouterHelper';

/**
 * MainPage Navigation 路由表：NavPathStack name → NavDestination（仅整页切换）
 */
@Builder
export function AppNavPageMap(name: string, _param: Object) {
  if (name === AppNavRoutes.SEARCH) {
    NavDestination() {
      NavPageSafeAreaShell() {
        SearchNavPage()
      }
    }
    .hideTitleBar(true)
    .backgroundColor(AppThemeConstants.PAGE_BACKGROUND)
  } else if (name === AppNavRoutes.SETTINGS) {
    NavDestination() {
      NavPageSafeAreaShell() {
        SettingsNavPage()
      }
    }
    .hideTitleBar(true)
    .backgroundColor(AppThemeConstants.PAGE_BACKGROUND)
  } else if (name === AppNavRoutes.HOME_MEDIA_EDIT) {
    NavDestination() {
      NavPageSafeAreaShell() {
        HomeMediaEditNavPage();
      }
    }
    .hideTitleBar(true)
    .backgroundColor(AppThemeConstants.PAGE_BACKGROUND)
  } else if (name === AppNavRoutes.PLAYLIST_DETAIL) {
    NavDestination() {
      NavPageSafeAreaShell() {
        PlaylistDetailNavPage()
      }
    }
    .hideTitleBar(true)
    .backgroundColor(PlaylistConstants.PAGE_BACKGROUND)
  } else if (name === AppNavRoutes.PLAYLIST_EDIT) {
    NavDestination() {
      NavPageSafeAreaShell() {
        PlaylistEditNavPage()
      }
    }
    .hideTitleBar(true)
    .backgroundColor(PlaylistConstants.PAGE_BACKGROUND)
  } else if (name === AppNavRoutes.PLAYLIST_LIST_SELECT) {
    NavDestination() {
      NavPageSafeAreaShell() {
        PlaylistListSelectNavPage()
      }
    }
    .hideTitleBar(true)
    .backgroundColor(PlaylistConstants.PAGE_BACKGROUND)
  } else if (name === AppNavRoutes.PLAYLIST_ADD_AUDIO) {
    NavDestination() {
      NavPageSafeAreaShell() {
        PlaylistAddAudioNavPage()
      }
    }
    .hideTitleBar(true)
    .backgroundColor(PlaylistConstants.PAGE_BACKGROUND)
  } else if (name === AppNavRoutes.AUDIO_PLAYER) {
    NavDestination() {
      AudioPlayerNavPage()
    }
    .hideTitleBar(true)
    .backgroundColor(AppThemeConstants.PAGE_BACKGROUND)
    .onBackPressed(() => {
      const homeViewModel: HomeViewModel = HomeViewModel.getInstance();
      if (homeViewModel.getUiState().currentAudio !== undefined) {
        homeViewModel.minimizeAudioPlayer();
      } else {
        NavRouterHelper.closePlayerRoute();
      }
      return true;
    })
  } else if (name === AppNavRoutes.VIDEO_PLAYER) {
    NavDestination() {
      VideoPlayerNavPage()
    }
    .hideTitleBar(true)
    .backgroundColor(AppThemeConstants.PAGE_BACKGROUND)
  }
}
