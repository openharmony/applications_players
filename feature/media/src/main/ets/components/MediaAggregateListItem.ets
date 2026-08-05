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

const TAG = 'MediaAggregateListItem';

/**
 * 媒体列表单项：首页紧凑行（小缩略图 + 文件名/元信息 + 时长 + 右箭头）。
 * 多选模式下右侧以勾选框替换右箭头，点击/长按手势由外层 ListItem 统一处理。
 */
@Reusable
@Component
export struct MediaAggregateListItem {
  @Prop media: FileInfo;
  @Prop mediaType: MediaType;
  @Prop fontScale: number = FontScaleUtil.DEFAULT_SCALE;
  /** 是否处于多选模式：为 true 时右侧展示勾选框 */
  @Prop isSelectionMode: boolean = false;
  /** 当前项是否被选中 */
  @Prop isSelected: boolean = false;

  @State fileName: string = '';
  @State thumbnailSrc: string | Resource = '';
  @State metaText: string = '';
  @State durationText: string = '';
  @State showDuration: boolean = false;
  @State nameFontSize: number = 14;
  @State metaFontSize: number = 11;
  @State durationFontSize: number = 12;

  aboutToAppear(): void {
    HiLog.i(TAG, `MediaAggregateListItem aboutToAppear start`);
    this.refreshDisplayData();
  }

  aboutToReuse(params: Record<string, Object>): void {
    this.refreshDisplayData();
  }

  aboutToUpdate(): void {
    this.refreshDisplayData();
  }

  /** 在生命周期内汇总展示字段，避免 build / @Builder 中调用工具函数 */
  private refreshDisplayData(): void {
    this.fileName = this.media.fileName;
    this.thumbnailSrc = MediaItemDisplayUtil.getThumbnail(this.media);
    this.durationText = MediaFormatUtil.formatDuration(this.media.duration);
    this.showDuration = this.media.duration > 0;

    const sizeText = MediaFormatUtil.formatFileSizeDecimal(this.media.fileSize);
    // 副标题仅展示文件大小，不拼接时长 / 分辨率
    this.metaText = sizeText;

    this.nameFontSize = FontScaleUtil.scaleFont(MediaViewUiConstants.HOME_LIST_NAME_FONT_BASE, this.fontScale);
    this.metaFontSize = FontScaleUtil.scaleFont(MediaViewUiConstants.HOME_LIST_META_FONT_BASE, this.fontScale);
    this.durationFontSize = FontScaleUtil.scaleFont(MediaViewUiConstants.HOME_LIST_DURATION_FONT_BASE, this.fontScale);
  }

  build() {
    Row() {
      Image(this.thumbnailSrc)
        .width(MediaViewUiConstants.HOME_LIST_THUMB_SIZE)
        .height(MediaViewUiConstants.HOME_LIST_THUMB_SIZE)
        .objectFit(ImageFit.Cover)
        .borderRadius(MediaViewUiConstants.HOME_LIST_ROW_RADIUS)
        .backgroundColor($r('sys.color.ohos_id_color_sub_background'))

      Column() {
        Text(this.fileName)
          .fontSize(this.nameFontSize)
          .fontWeight(500)
          .fontColor(MediaViewUiConstants.COLOR_FILE_NAME)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        Text(this.metaText)
          .fontSize(this.metaFontSize)
          .fontColor(MediaViewUiConstants.COLOR_FILE_META)
          .margin({ top: MediaViewUiConstants.HOME_LIST_META_MARGIN_TOP })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: MediaViewUiConstants.HOME_LIST_TEXT_MARGIN_LEFT })

      if (this.showDuration) {
        Text(this.durationText)
          .fontSize(this.durationFontSize)
          .fontColor(MediaViewUiConstants.COLOR_FILE_META)
          .margin({ left: MediaViewUiConstants.HOME_LIST_DURATION_MARGIN_LEFT })
      }

      if (this.isSelectionMode) {
        // 仅展示选中态，勿绑 onChange，避免全选回写触发连环 toggle
        Checkbox()
          .select(this.isSelected)
          .selectedColor(MediaSelectionConstants.SELECTION_PRIMARY_COLOR)
          .width(MediaSelectionConstants.LIST_CHECKBOX_SIZE)
          .height(MediaSelectionConstants.LIST_CHECKBOX_SIZE)
          .margin({ left: MediaSelectionConstants.LIST_CHECKBOX_MARGIN_LEFT })
          .hitTestBehavior(HitTestMode.None)
      } else {
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(MediaViewUiConstants.HOME_LIST_CHEVRON_FONT_SIZE)
          .fontColor([MediaViewUiConstants.COLOR_EMPTY_ICON])
          .margin({ left: MediaViewUiConstants.HOME_LIST_CHEVRON_MARGIN_LEFT })
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({
      left: MediaViewUiConstants.HOME_LIST_ROW_PADDING_LEFT,
      right: MediaViewUiConstants.HOME_LIST_ROW_PADDING_RIGHT,
      top: MediaViewUiConstants.HOME_LIST_ROW_PADDING_V,
      bottom: MediaViewUiConstants.HOME_LIST_ROW_PADDING_V
    })
    .borderRadius(MediaViewUiConstants.HOME_LIST_ROW_RADIUS)
    .backgroundColor(this.isSelectionMode && this.isSelected ?
      MediaSelectionConstants.SELECTED_OVERLAY_COLOR : $r('sys.color.ohos_id_color_background_transparent'))
  }
}
