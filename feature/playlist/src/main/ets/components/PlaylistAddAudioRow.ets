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
import { AppThemeConstants } from '@ohos/common/src/main/ets/constants/ui/AppThemeConstants';
import { MediaItemDisplayUtil } from '@ohos/common/src/main/ets/utils/MediaItemDisplayUtil';
import { SearchHighlighter, HighlightSegment } from '@ohos/common/src/main/ets/utils/SearchHighlighter';
import { SearchScorer } from '@ohos/common/src/main/ets/utils/SearchScorer';
import { PlaylistConstants } from '../constants/PlaylistConstants';
import { PlaylistTrackThumb } from './PlaylistTrackThumb';

const TAG = 'PlaylistAddAudioRow';

/**
 * 添加音频页列表行：封面 + 文件名（搜索高亮）+ 副标题 + 添加按钮 /「已添加」文案
 */
@Component
export struct PlaylistAddAudioRow {
  @Prop @Watch('onTrackOrKeywordChange') track: FileInfo;
  @Prop @Watch('onTrackOrKeywordChange') searchKeyword: string = '';
  @Prop isAlreadyAdded: boolean = false;
  onAddClick: () => void = () => {};

  @State thumbnailSrc: string | Resource = '';
  @State metaText: string = '';
  @State hasCustomThumb: boolean = false;
  @State placeholderIcon: Resource = $r('app.media.ic_normal_music');
  @State thumbObjectFit: ImageFit = ImageFit.Cover;
  @State segments: HighlightSegment[] = [];
  @State highlightRevision: number = 0;
  private lastRenderedTrackKey: string = '';

  aboutToAppear(): void {
    this.lastRenderedTrackKey = this.buildTrackDisplayKey();
    this.bindTrackDisplay();
    this.rebuildHighlightSegments();
  }

  onTrackOrKeywordChange(): void {
    const trackKey = this.buildTrackDisplayKey();
    if (trackKey !== this.lastRenderedTrackKey) {
      this.lastRenderedTrackKey = trackKey;
      this.bindTrackDisplay();
    }
    this.rebuildHighlightSegments();
  }

  /** 生成曲目展示键（URI + 封面，LazyForEach 复用时识别变更） */
  private buildTrackDisplayKey(): string {
    return `${this.track.uri}|${this.track.coverUri}|${this.track.thumbUri}`;
  }

  /** 绑定封面与元信息 */
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

  /** 与首页搜索一致：SearchScorer 分词 + SearchHighlighter 前缀高亮 */
  private rebuildHighlightSegments(): void {
    const keywords: string[] = SearchScorer.parseKeywords(this.searchKeyword);
    this.segments = SearchHighlighter.highlight(this.track.fileName, keywords);
    this.highlightRevision++;
  }

  build() {
    Row() {
      PlaylistTrackThumb({
        track: this.track,
        hasCustomThumb: this.hasCustomThumb,
        thumbnailSrc: this.thumbnailSrc,
        placeholderIcon: this.placeholderIcon,
        thumbObjectFit: this.thumbObjectFit,
        imageKeyPrefix: 'add_audio'
      })

      Column() {
        Row() {
          ForEach(this.segments, (segment: HighlightSegment, index: number) => {
            Text(segment.text)
              .fontSize(15)
              .fontWeight(segment.isHighlight ? FontWeight.Bold : FontWeight.Normal)
              .fontColor(segment.isHighlight ? AppThemeConstants.ACCENT : PlaylistConstants.TEXT_PRIMARY)
          }, (segment: HighlightSegment, index: number) =>
            `${this.highlightRevision}_${index}_${segment.isHighlight ? 1 : 0}_${segment.text}`)
        }
        .width('100%')

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

      Row() {
        if (this.isAlreadyAdded) {
          Text($r('app.string.playlist_already_added'))
            .fontSize(PlaylistConstants.ADD_AUDIO_ACTION_LABEL_FONT_SIZE)
            .fontColor(PlaylistConstants.TEXT_SECONDARY)
            .textAlign(TextAlign.Center)
            .maxLines(1)
        } else {
          Button({ type: ButtonType.Circle, stateEffect: true }) {
            SymbolGlyph($r('sys.symbol.plus_square'))
              .fontSize(18)
              .fontColor([AppThemeConstants.TEXT_PRIMARY])
              .fontWeight(FontWeight.Medium)
          }
          .buttonStyle(ButtonStyleMode.NORMAL)
          .width(36)
          .height(36)
          .backgroundColor($r('sys.color.ohos_id_color_background_transparent'))
          .onClick(() => {
            this.onAddClick();
          })
        }
      }
      .width(PlaylistConstants.ADD_AUDIO_ACTION_SLOT_WIDTH)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding({
      left: PlaylistConstants.DETAIL_HEADER_HORIZONTAL_PADDING,
      right: PlaylistConstants.DETAIL_HEADER_HORIZONTAL_PADDING,
      top: PlaylistConstants.DETAIL_FLAT_TRACK_ROW_PADDING_V,
      bottom: PlaylistConstants.DETAIL_FLAT_TRACK_ROW_PADDING_V
    })
  }
}
