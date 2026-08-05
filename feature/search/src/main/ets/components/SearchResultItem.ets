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

import { AudioItem } from '@ohos/common/src/main/ets/model/AudioItem';
import { VideoItem } from '@ohos/common/src/main/ets/model/VideoItem';
import { SearchHighlighter, HighlightSegment } from '@ohos/common/src/main/ets/utils/SearchHighlighter';
import { HiLog } from '@ohos/common/src/main/ets/utils/HiLog';
import { AppThemeConstants } from '@ohos/common/src/main/ets/constants/ui/AppThemeConstants';
import { SearchUiConstants } from '@ohos/common/src/main/ets/constants/SearchUiConstants';
import { MediaFormatUtil } from '@ohos/common/src/main/ets/utils/MediaFormatUtil';

const TAG = 'SearchResultItem';

@Component
export struct SearchResultItem {
  @Prop @Watch('onHighlightInputChange') fileName: string = '';
  @Prop @Watch('onHighlightInputChange') keywords: string[] = [];
  @Prop duration: number = 0;
  @Prop fileSize: number = 0;
  @Prop thumbUri: string = '';
  @Prop mimeType: string = '';
  /** 是否显示底部分割线（末项为 false） */
  @Prop showDivider: boolean = true;
  onItemClick: () => void = () => {};

  @State segments: HighlightSegment[] = [];
  @State highlightRevision: number = 0;

  aboutToAppear(): void {
    this.rebuildHighlightSegments();
  }

  onHighlightInputChange(): void {
    this.rebuildHighlightSegments();
  }

  private rebuildHighlightSegments(): void {
    this.segments = SearchHighlighter.highlight(this.fileName, this.keywords);
    this.highlightRevision++;
  }

  private formatDuration(ms: number): string {
    return MediaFormatUtil.formatDuration(ms);
  }

  /** 副标题仅展示文件大小（不拼接分辨率 / 时长 / 原始像素） */
  private formatSize(bytes: number): string {
    if (!bytes || bytes <= 0) {
      return '0B';
    }
    const kb: number = bytes / 1024;
    const mb: number = kb / 1024;
    const gb: number = mb / 1024;
    if (gb >= 1) {
      const value: number = Math.round(gb * 10) / 10;
      return `${value}GB`;
    }
    if (mb >= 1) {
      return `${Math.round(mb)}MB`;
    }
    if (kb >= 1) {
      return `${Math.round(kb)}KB`;
    }
    return `${bytes}B`;
  }

  private isAudio(): boolean {
    return this.mimeType?.startsWith('audio') ?? false;
  }

  build() {
    Column() {
      Row() {
        if (this.thumbUri) {
          Image(this.thumbUri)
            .width(SearchUiConstants.RESULT_ITEM_ICON_SIZE)
            .height(SearchUiConstants.RESULT_ITEM_ICON_SIZE)
            .objectFit(ImageFit.Cover)
            .borderRadius(SearchUiConstants.RESULT_ITEM_ICON_RADIUS)
            .flexShrink(0)
        } else if (this.isAudio()) {
          Image($r('app.media.ic_normal_audio'))
            .width(SearchUiConstants.RESULT_ITEM_ICON_SIZE)
            .height(SearchUiConstants.RESULT_ITEM_ICON_SIZE)
            .objectFit(ImageFit.Contain)
            .borderRadius(SearchUiConstants.RESULT_ITEM_ICON_RADIUS)
            .flexShrink(0)
        } else {
          Image($r('app.media.ic_normal_video'))
            .width(SearchUiConstants.RESULT_ITEM_ICON_SIZE)
            .height(SearchUiConstants.RESULT_ITEM_ICON_SIZE)
            .objectFit(ImageFit.Contain)
            .borderRadius(SearchUiConstants.RESULT_ITEM_ICON_RADIUS)
            .flexShrink(0)
        }

        Column() {
          // 多段高亮用 Span 拼进同一 Text，才能对整行生效 maxLines / Ellipsis，避免 Row+Text 横向撑破列宽
          Text() {
            ForEach(this.segments, (segment: HighlightSegment, index: number) => {
              Span(segment.text)
                .fontSize(SearchUiConstants.RESULT_ITEM_TITLE_FONT_SIZE)
                .fontWeight(segment.isHighlight ? FontWeight.Bold : FontWeight.Normal)
                .fontColor(segment.isHighlight ? AppThemeConstants.ACCENT : SearchUiConstants.TITLE_COLOR)
            }, (segment: HighlightSegment, index: number) =>
              `${this.highlightRevision}_${index}_${segment.isHighlight ? 1 : 0}_${segment.text}`)
          }
          .width('100%')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(this.formatSize(this.fileSize))
            .fontSize(SearchUiConstants.RESULT_ITEM_SUBTITLE_FONT_SIZE)
            .fontColor(SearchUiConstants.RESULT_ITEM_SUBTITLE_COLOR)
            .margin({ top: 4 })
            .width('100%')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .constraintSize({ minWidth: 0 })
        .margin({ left: SearchUiConstants.RESULT_ITEM_TEXT_MARGIN_LEFT })
        .alignItems(HorizontalAlign.Start)

        // 时长右缘与标题栏垃圾桶按钮右缘对齐（同处卡片内容区右边界）；不参与压缩
        if (this.duration > 0) {
          Text(this.formatDuration(this.duration))
            .fontSize(SearchUiConstants.RESULT_ITEM_DURATION_FONT_SIZE)
            .fontColor(SearchUiConstants.RESULT_ITEM_SUBTITLE_COLOR)
            .textAlign(TextAlign.End)
            .margin({ left: 8 })
            .padding({ right: 0 })
            .flexShrink(0)
        }
      }
      .width('100%')
      .padding({
        top: SearchUiConstants.RESULT_ITEM_PADDING_V,
        bottom: SearchUiConstants.RESULT_ITEM_PADDING_V
      })
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        HiLog.i(TAG, `Search result clicked: ${this.fileName}`);
        this.onItemClick();
      })

      // 分割线左缘对齐文本起点（图标右侧）
      if (this.showDivider) {
        Divider()
          .color($r('sys.color.ohos_id_color_list_separator'))
          .height('1px')
          .lineCap(LineCapStyle.Square)
          .margin({
            left: SearchUiConstants.RESULT_ITEM_DIVIDER_START,
            right: 0
          })
      }
    }
    .width('100%')
  }
}

@Component
export struct AudioSearchResultItem {
  @Prop audio: AudioItem;
  @Prop keywords: string[] = [];
  @Prop showDivider: boolean = true;
  onItemClick: (audio: AudioItem) => void = () => {};

  build() {
    SearchResultItem({
      fileName: this.audio.fileName,
      keywords: this.keywords,
      duration: this.audio.duration,
      fileSize: this.audio.size,
      thumbUri: this.audio.albumArtUrl || '',
      mimeType: this.audio.mimeType,
      showDivider: this.showDivider,
      onItemClick: () => {
        this.onItemClick(this.audio);
      }
    })
  }
}

@Component
export struct VideoSearchResultItem {
  @Prop video: VideoItem;
  @Prop keywords: string[] = [];
  @Prop showDivider: boolean = true;
  onItemClick: (video: VideoItem) => void = () => {};

  build() {
    SearchResultItem({
      fileName: this.video.fileName,
      keywords: this.keywords,
      duration: this.video.duration,
      fileSize: this.video.size,
      thumbUri: this.video.thumbnailUrl || '',
      mimeType: this.video.mimeType,
      showDivider: this.showDivider,
      onItemClick: () => {
        this.onItemClick(this.video);
      }
    })
  }
}
