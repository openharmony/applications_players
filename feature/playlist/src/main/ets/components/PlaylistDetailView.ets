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
import { PlaylistDetailHeader } from './PlaylistDetailHeader';
import { PlaylistDetailActionBar } from './PlaylistDetailActionBar';
import { PlaylistEmptyState } from './PlaylistEmptyState';
import { PlaylistDetailTrackList } from './PlaylistDetailTrackList';
import { PlaylistConstants } from '../constants/PlaylistConstants';

/**
 * ???????????? + ????????�? ???? / ?�?
 */
@Component
export struct PlaylistDetailView {
  @Prop detailName: string = '';
  @Prop detailTrackCount: number = 0;
  @Prop isDetailEmpty: boolean = true;
  @Prop showResumeBar: boolean = false;
  @Prop resumeTrackLabel: string = '';
  trackDataSource: PlaylistTrackDataSource = new PlaylistTrackDataSource();
  onBack: () => void = () => {};
  onAddAudio: () => void = () => {};
  onPlayAll: () => void = () => {};
  onContinueResume: () => void = () => {};
  onDismissResume: () => void = () => {};
  onEnterEdit: () => void = () => {};
  onPlayTrack: (track: FileInfo) => void = () => {};
  onReorderTrack: (from: number, to: number) => void = () => {};
  onRemoveTrack: (uri: string) => void = () => {};

  build() {
    Column() {
      PlaylistDetailHeader({
        detailName: this.detailName,
        showEdit: !this.isDetailEmpty,
        onBack: this.onBack,
        onAddAudio: this.onAddAudio,
        onEnterEdit: this.onEnterEdit
      })

      if (!this.isDetailEmpty) {
        PlaylistDetailActionBar({
          trackCount: this.detailTrackCount,
          showResumeBar: this.showResumeBar,
          resumeTrackLabel: this.resumeTrackLabel,
          onPlayAll: this.onPlayAll,
          onContinueResume: this.onContinueResume,
          onDismissResume: this.onDismissResume
        })
      }

      if (this.isDetailEmpty) {
        PlaylistEmptyState({
          title: $r('app.string.playlist_detail_empty_title'),
          hint: $r('app.string.playlist_detail_empty_hint')
        })
      } else {
        PlaylistDetailTrackList({
          trackDataSource: this.trackDataSource,
          onPlayTrack: this.onPlayTrack,
          onReorderTrack: this.onReorderTrack,
          onRemoveTrack: this.onRemoveTrack
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(PlaylistConstants.DETAIL_CONTENT_BACKGROUND)
  }
}
