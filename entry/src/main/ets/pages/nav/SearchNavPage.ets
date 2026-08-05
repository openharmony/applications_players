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


import { SearchOverlay } from '@ohos/search/src/main/ets/components/SearchOverlay';
import { AudioItem } from '@ohos/common/src/main/ets/model/AudioItem';
import { VideoItem } from '@ohos/common/src/main/ets/model/VideoItem';
import { HomeViewModel } from '../../viewmodel/HomeViewModel';

/**
 * 搜索单页 NavDestination：即时反馈型全局搜索（历史/快捷 ↔ 实时结果）
 */
@Component
export struct SearchNavPage {
  private homeViewModel: HomeViewModel = HomeViewModel.getInstance();

  build() {
    SearchOverlay({
      onClose: () => {
        this.homeViewModel.closeSearchOverlay();
      },
      onPlayAudio: (audio: AudioItem) => {
        this.homeViewModel.playAudio(audio);
      },
      onPlayVideo: (video: VideoItem) => {
        this.homeViewModel.playVideo(video);
      }
    })
  }
}
