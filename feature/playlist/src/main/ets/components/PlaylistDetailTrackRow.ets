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
import { MediaFormatUtil } from '@ohos/common/src/main/ets/utils/MediaFormatUtil';
import { HiLog } from '@ohos/common/src/main/ets/utils/HiLog';
import { MediaItemDisplayUtil } from '@ohos/common/src/main/ets/utils/MediaItemDisplayUtil';
import { PlaylistConstants } from '../constants/PlaylistConstants';
import { PlaylistTrackThumb } from './PlaylistTrackThumb';

const TAG = 'PlaylistDetailTrackRow';

/**
 * 播放列表详情页单曲行（纯展示；长按高亮在 ListItem 层，本组件长按期�?prop 不变�?
 */
@Component
export struct PlaylistDetailTrackRow {
  @Prop track: FileInfo;

  @State thumbnailSrc: string | Resource = '';
  @State metaText: string = '';
  @State hasCustomThumb: boolean = false;
  @State placeholderIcon: Resource = $r('app.media.ic_normal_music');
  @State thumbObjectFit: ImageFit = ImageFit.Cover;
  private lastRenderedTrackKey: string = '';

  aboutToAppear(): void {
    this.lastRenderedTrackKey = this.buildTrackDisplayKey();
    this.bindTrackDisplay();
  }

  aboutToUpdate(): void {
    const trackKey = this.buildTrackDisplayKey();
    if (trackKey === this.lastRenderedTrackKey) {
      return;
    }
    this.lastRenderedTrackKey = trackKey;
    this.bindTrackDisplay();
  }

  /** 生成曲目展示键（URI + 封面，LazyForEach 复用时识别变更） */
  private buildTrackDisplayKey(): string {
    return `${this.track.uri}|${this.track.coverUri}|${this.track.thumbUri}`;
  }

  /** 绑定封面与元信息（仅�?appear / 展示键变更时调用，避免长按导�?Image 重绑�?*/
  private bindTrackDisplay(): void {
    this.hasCustomThumb = MediaItemDisplayUtil.hasCustomThumbnail(this.track);
    this.thumbnailSrc = MediaItemDisplayUtil.getThumbnail(this.track);
    this.placeholderIcon = MediaItemDisplayUtil.getPlaceholderIcon(this.track);
    this.thumbObjectFit = MediaItemDisplayUtil.getHomeThumbObjectFit(this.track);
    const format = MediaItemDisplayUtil.getFormatLabel(this.track);
    const size = MediaFormatUtil.formatFileSizeDecimal(this.track.fileSize);
    this.metaText = `${format} · ${size}`;
    HiLog.i(TAG, `bindTrackDisplay uri=${this.track.uri} hasCover=${this.hasCustomThumb}`);
  }

  build() {
    Row() {
      PlaylistTrackThumb({
        track: this.track,
        hasCustomThumb: this.hasCustomThumb,
        thumbnailSrc: this.thumbnailSrc,
        placeholderIcon: this.placeholderIcon,
        thumbObjectFit: this.thumbObjectFit,
        imageKeyPrefix: 'detail_track',
        imageDraggable: false
      })

      Column() {
        Text(this.track.fileName)
          .fontSize(15)
          .fontWeight(500)
          .fontColor(PlaylistConstants.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(this.metaText)
          .fontSize(12)
          .fontColor(PlaylistConstants.TEXT_SECONDARY)
          .margin({ top: 4 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 12 })
    }
    .width('100%')
    .padding({
      left: PlaylistConstants.DETAIL_HEADER_HORIZONTAL_PADDING,
      right: PlaylistConstants.DETAIL_HEADER_HORIZONTAL_PADDING,
      top: PlaylistConstants.DETAIL_FLAT_TRACK_ROW_PADDING_V,
      bottom: PlaylistConstants.DETAIL_FLAT_TRACK_ROW_PADDING_V
    })
    .draggable(false)
  }
}
