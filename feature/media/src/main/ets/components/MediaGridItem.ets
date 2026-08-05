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
import { MediaType } from '@ohos/common/src/main/ets/datasource/MediaDataSource';
import { MediaFormatUtil } from '@ohos/common/src/main/ets/utils/MediaFormatUtil';
import { FontScaleUtil } from '@ohos/common/src/main/ets/utils/FontScaleUtil';
import { HiLog } from '@ohos/common/src/main/ets/utils/HiLog';
import { MediaItemDisplayUtil } from '@ohos/common/src/main/ets/utils/MediaItemDisplayUtil';
import { MediaViewUiConstants } from '@ohos/common/src/main/ets/constants/MediaViewUiConstants';
import { MediaSelectionConstants } from '../constants/MediaSelectionConstants';

const TAG = 'MediaGridItem';

/**
 * 媒体宫格单项：1:1 封面 + 格式/时长角标 + 文件名 + 文件大小。
 * 列数由外层 Grid 的 columnsTemplate 控制，单项宽度自适应单元格。
 * 多选模式下封面右上角展示勾选框，点击/长按手势由外层 GridItem 统一处理。
 */
@Reusable
@Component
export struct MediaGridItem {
  @Prop media: FileInfo;
  @Prop mediaType: MediaType;
  @Prop fontScale: number = FontScaleUtil.DEFAULT_SCALE;
  /** 是否处于多选模式：为 true 时展示右上角勾选框 */
  @Prop isSelectionMode: boolean = false;
  /** 当前项是否被选中 */
  @Prop isSelected: boolean = false;

  @State formatLabel: string = '';
  @State fileName: string = '';
  @State durationText: string = '';
  @State fileSizeText: string = '';
  @State thumbBackgroundColor: Resource = MediaViewUiConstants.COLOR_VIDEO_THUMB_BG;
  @State hasCustomThumb: boolean = false;
  @State thumbnailSrc: string | Resource = '';
  @State placeholderIcon: Resource = $r('app.media.ic_normal_video');
  @State thumbObjectFit: ImageFit = ImageFit.Cover;
  @State thumbAspectRatio: number = MediaViewUiConstants.HOME_GRID_COVER_ASPECT_RATIO;
  @State durationBadgeBg: string = 'rgba(0,0,0,0.45)';
  @State formatFontSize: number = 9;
  @State durationFontSize: number = 10;
  @State nameFontSize: number = 13;
  @State sizeFontSize: number = 11;

  aboutToAppear(): void {
    this.refreshDisplayData();
  }

  aboutToReuse(params: Record<string, Object>): void {
    this.refreshDisplayData();
  }

  aboutToUpdate(): void {
    HiLog.i(TAG, 'aboutToUpdate');
    this.refreshDisplayData();
  }

  /** 在生命周期内汇总展示字段，避免 build / @Builder 中调用工具函数 */
  private refreshDisplayData(): void {
    this.formatLabel = MediaItemDisplayUtil.getFormatLabel(this.media);
    this.fileName = this.media.fileName;
    this.durationText = MediaFormatUtil.formatDuration(this.media.duration);
    this.fileSizeText = MediaFormatUtil.formatFileSizeDecimal(this.media.fileSize);
    this.thumbBackgroundColor = MediaItemDisplayUtil.getHomeThumbBackgroundColor(this.media);
    this.hasCustomThumb = MediaItemDisplayUtil.hasCustomThumbnail(this.media);
    this.thumbnailSrc = MediaItemDisplayUtil.getThumbnail(this.media);
    this.placeholderIcon = MediaItemDisplayUtil.getPlaceholderIcon(this.media);
    this.thumbObjectFit = MediaItemDisplayUtil.getHomeThumbObjectFit(this.media);
    this.thumbAspectRatio = MediaItemDisplayUtil.getGridCoverAspectRatio(this.media);
    this.durationBadgeBg = MediaItemDisplayUtil.isAudio(this.media) ?
      MediaViewUiConstants.AUDIO_DURATION_BADGE_BG : MediaViewUiConstants.VIDEO_DURATION_BADGE_BG;

    this.formatFontSize = FontScaleUtil.scaleFont(MediaViewUiConstants.FORMAT_BADGE_FONT_BASE, this.fontScale);
    this.durationFontSize = FontScaleUtil.scaleFont(MediaViewUiConstants.HOME_DURATION_FONT_BASE, this.fontScale);
    this.nameFontSize = FontScaleUtil.scaleFont(MediaViewUiConstants.HOME_NAME_FONT_BASE, this.fontScale);
    this.sizeFontSize = FontScaleUtil.scaleFont(MediaViewUiConstants.HOME_SIZE_FONT_BASE, this.fontScale);
  }

  build() {
    Column() {
      Stack() {
        this.ThumbContent()

        Column() {
          Text(this.formatLabel)
            .fontSize(this.formatFontSize)
            .fontWeight(FontWeight.Bold)
            .fontColor(MediaViewUiConstants.COLOR_FORMAT_BADGE_TEXT)
            .padding({
              left: MediaViewUiConstants.FORMAT_BADGE_PADDING_H,
              right: MediaViewUiConstants.FORMAT_BADGE_PADDING_H,
              top: MediaViewUiConstants.FORMAT_BADGE_PADDING_V,
              bottom: MediaViewUiConstants.FORMAT_BADGE_PADDING_V
            })
            .backgroundColor(MediaViewUiConstants.COLOR_FORMAT_BADGE_BG)
            .borderRadius({
              topLeft: MediaViewUiConstants.FORMAT_BADGE_RADIUS_TOP_LEFT,
              topRight: 0,
              bottomLeft: 0,
              bottomRight: MediaViewUiConstants.FORMAT_BADGE_RADIUS_BOTTOM_RIGHT
            })
        }
        .width('100%')
        .height('100%')
        .alignItems(HorizontalAlign.Start)
        .justifyContent(FlexAlign.Start)
        .hitTestBehavior(HitTestMode.None)

        Column() {
          Text(this.durationText)
            .fontSize(this.durationFontSize)
            .fontWeight(500)
            .fontColor(MediaViewUiConstants.COLOR_FORMAT_BADGE_TEXT)
            .padding({
              left: MediaViewUiConstants.DURATION_BADGE_PADDING_H,
              right: MediaViewUiConstants.DURATION_BADGE_PADDING_H,
              top: MediaViewUiConstants.DURATION_BADGE_PADDING_V,
              bottom: MediaViewUiConstants.DURATION_BADGE_PADDING_V
            })
            .backgroundColor(this.durationBadgeBg)
            .borderRadius(MediaViewUiConstants.DURATION_BADGE_RADIUS)
        }
        .width('100%')
        .height('100%')
        .alignItems(HorizontalAlign.End)
        .justifyContent(FlexAlign.End)
        .padding({
          right: MediaViewUiConstants.DURATION_BADGE_MARGIN,
          bottom: MediaViewUiConstants.DURATION_BADGE_MARGIN
        })
        .hitTestBehavior(HitTestMode.None)

        // 多选模式：选中遮罩 + 右上角勾选框（仅展示，手势由外层处理）
        if (this.isSelectionMode) {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor(this.isSelected ?
              MediaSelectionConstants.SELECTED_OVERLAY_COLOR : $r('sys.color.ohos_id_color_background_transparent'))
            .hitTestBehavior(HitTestMode.None)

          Column() {
            Checkbox()
              .select(this.isSelected)
              .selectedColor(MediaSelectionConstants.SELECTION_PRIMARY_COLOR)
              .unselectedColor(MediaSelectionConstants.CHECKBOX_BORDER_COLOR)
              .width(MediaSelectionConstants.GRID_CHECKBOX_SIZE)
              .height(MediaSelectionConstants.GRID_CHECKBOX_SIZE)
              .hitTestBehavior(HitTestMode.None)
          }
          .width('100%')
          .height('100%')
          .alignItems(HorizontalAlign.End)
          .justifyContent(FlexAlign.Start)
          .padding(MediaSelectionConstants.GRID_CHECKBOX_MARGIN)
          .hitTestBehavior(HitTestMode.None)
        }
      }
      .width('100%')
      .aspectRatio(this.thumbAspectRatio)
      .borderRadius(MediaViewUiConstants.HOME_COVER_RADIUS)
      .clip(true)
      .border(this.isSelectionMode && this.isSelected ? {
        width: MediaSelectionConstants.SELECTED_BORDER_WIDTH,
        color: MediaSelectionConstants.SELECTION_PRIMARY_COLOR,
        radius: MediaViewUiConstants.HOME_COVER_RADIUS
      } : {
        width: 0,
        color: $r('sys.color.ohos_id_color_background_transparent'),
        radius: MediaViewUiConstants.HOME_COVER_RADIUS
      })

      Column({ space: MediaViewUiConstants.HOME_TEXT_BLOCK_SPACE }) {
        Text(this.fileName)
          .fontSize(this.nameFontSize)
          .fontWeight(600)
          .fontColor(MediaViewUiConstants.COLOR_FILE_NAME)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        Text(this.fileSizeText)
          .fontSize(this.sizeFontSize)
          .fontColor(MediaViewUiConstants.COLOR_FILE_META)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({
        top: MediaViewUiConstants.HOME_TEXT_PADDING_TOP,
        bottom: MediaViewUiConstants.HOME_TEXT_PADDING_BOTTOM
      })
    }
    .width('100%')
  }

  /** 1:1 封面区：有缩略图按类型适配，无缩略图占位图标居中 */
  @Builder
  ThumbContent() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.thumbBackgroundColor)

      if (this.hasCustomThumb) {
        Image(this.thumbnailSrc)
          .width('100%')
          .height('100%')
          .objectFit(this.thumbObjectFit)
      } else {
        Column() {
          Image(this.placeholderIcon)
            .width(MediaViewUiConstants.PLACEHOLDER_ICON_SIZE)
            .height(MediaViewUiConstants.PLACEHOLDER_ICON_SIZE)
            .objectFit(ImageFit.Contain)
            .opacity(MediaViewUiConstants.PLACEHOLDER_ICON_OPACITY)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
  }
}
