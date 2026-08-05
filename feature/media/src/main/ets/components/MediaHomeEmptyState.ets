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



import { MediaViewUiConstants } from '@ohos/common/src/main/ets/constants/MediaViewUiConstants';

/**
 * 首页媒体列表空态 View：文件夹图标 + 标题 + 提示文案。
 */
@Component
export struct MediaHomeEmptyState {
  @Prop title: ResourceStr = '';
  @Prop hint: ResourceStr = '';

  build() {
    Column() {
      Image($r('app.media.ic_empty_state'))
        .width(MediaViewUiConstants.EMPTY_FOLDER_ICON_SIZE)
        .height(MediaViewUiConstants.EMPTY_FOLDER_ICON_SIZE)

      Text(this.title)
        .fontSize(MediaViewUiConstants.EMPTY_TITLE_FONT_SIZE)
        .fontWeight(600)
        .fontColor(MediaViewUiConstants.COLOR_FILE_NAME)
        .margin({
          top: MediaViewUiConstants.EMPTY_TITLE_MARGIN_TOP,
          bottom: MediaViewUiConstants.EMPTY_TITLE_MARGIN_BOTTOM
        })

      Text(this.hint)
        .fontSize(MediaViewUiConstants.EMPTY_HINT_FONT_SIZE)
        .fontColor(MediaViewUiConstants.COLOR_FILE_META)
        .textAlign(TextAlign.Center)
        .lineHeight(MediaViewUiConstants.EMPTY_HINT_LINE_HEIGHT)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .padding({
      left: MediaViewUiConstants.EMPTY_VIEW_HORIZONTAL_PADDING,
      right: MediaViewUiConstants.EMPTY_VIEW_HORIZONTAL_PADDING
    })
  }
}
