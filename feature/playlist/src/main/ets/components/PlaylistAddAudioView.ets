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


import FileInfo from '@ohos/common/src/main/ets/model/FileInfo';
import { PlaylistTrackDataSource } from '../datasource/PlaylistTrackDataSource';
import { PlaylistConstants } from '../constants/PlaylistConstants';
import { PlaylistAddAudioRow } from './PlaylistAddAudioRow';
import { NavBackButton } from '@ohos/common';
import { SearchBar } from '@ohos/common/src/main/ets/component/SearchBar';

/**
 * ???????? + ????? SearchBar + ???????
 */
@Component
export struct PlaylistAddAudioView {
  @Prop searchKeyword: string = '';
  @Prop isEmpty: boolean = true;
  @Prop alreadyAddedUris: string[] = [];
  trackDataSource: PlaylistTrackDataSource = new PlaylistTrackDataSource();
  onBack: () => void = () => {};
  onSearchTextChange: (keyword: string) => void = () => {};
  onAddTrack: (track: FileInfo) => void = () => {};

  /** 当前歌单是否已包含该音频 */
  private isAlreadyAdded(uri: string): boolean {
    return this.alreadyAddedUris.indexOf(uri) >= 0;
  }

  build() {
    Column() {
      Row({ space: PlaylistConstants.DETAIL_HEADER_TITLE_GAP }) {
        NavBackButton({
          onBack: () => {
            this.onBack();
          }
        })

        Text($r('app.string.playlist_add_audio_title'))
          .fontSize(17)
          .fontWeight(600)
          .fontColor(PlaylistConstants.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })

      Row() {
        SearchBar({
          text: this.searchKeyword,
          placeholder: $r('app.string.playlist_search_audio'),
          onTextChange: (value: string) => {
            this.onSearchTextChange(value);
          }
        })
      }
      .width('100%')
      .padding({
        left: PlaylistConstants.ADD_AUDIO_SEARCH_BAR_HORIZONTAL_MARGIN,
        right: PlaylistConstants.ADD_AUDIO_SEARCH_BAR_HORIZONTAL_MARGIN,
        bottom: PlaylistConstants.ADD_AUDIO_SEARCH_BAR_MARGIN_BOTTOM
      })

      if (this.isEmpty) {
        Column() {
          Text($r('app.string.playlist_add_audio_empty'))
            .fontSize(14)
            .fontColor(PlaylistConstants.TEXT_SECONDARY)
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        Column() {
          Column() {
            List() {
              LazyForEach(this.trackDataSource, (track: FileInfo) => {
                ListItem() {
                  PlaylistAddAudioRow({
                    track: track,
                    searchKeyword: this.searchKeyword,
                    isAlreadyAdded: this.isAlreadyAdded(track.uri),
                    onAddClick: () => {
                      this.onAddTrack(track);
                    }
                  })
                }
              }, (track: FileInfo) =>
                `${track.uri}_${this.isAlreadyAdded(track.uri) ? 1 : 0}`)
            }
            .divider({
              strokeWidth: PlaylistConstants.LIST_DIVIDER_STROKE_WIDTH,
              color: PlaylistConstants.LIST_DIVIDER_COLOR,
              startMargin: PlaylistConstants.LIST_DIVIDER_START_MARGIN,
              endMargin: PlaylistConstants.LIST_DIVIDER_END_MARGIN
            })
            .cachedCount(PlaylistConstants.ADD_AUDIO_LIST_CACHED_COUNT)
            .layoutWeight(1)
            .width('100%')
            .scrollBar(BarState.Off)
          }
          .width('100%')
          .layoutWeight(1)
          .backgroundColor(PlaylistConstants.LIST_CARD_BACKGROUND)
          .borderRadius(PlaylistConstants.LIST_CARD_RADIUS)
          .clip(true)
        }
        .width('100%')
        .layoutWeight(1)
        .padding({
          left: PlaylistConstants.LIST_CARD_MARGIN_H,
          right: PlaylistConstants.LIST_CARD_MARGIN_H,
          top: PlaylistConstants.LIST_CARD_MARGIN_TOP,
          bottom: PlaylistConstants.LIST_CARD_MARGIN_BOTTOM
        })
      }
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(PlaylistConstants.PAGE_BACKGROUND)
  }
}
