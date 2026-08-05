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



import { PlaylistConstants } from '../constants/PlaylistConstants';

/**
 * 播放列表通用空态：居中图标 + 标题 + 说明
 */
@Component
export struct PlaylistEmptyState {
  @Prop title: ResourceStr = '';
  @Prop hint: ResourceStr = '';

  build() {
    Column() {
      Image($r('app.media.ic_empty_state'))
        .width(200)
        .height(200)

      Text(this.title)
        .fontSize(PlaylistConstants.EMPTY_STATE_TITLE_FONT_SIZE)
        .fontWeight(600)
        .fontColor(PlaylistConstants.TEXT_PRIMARY)
        .margin({ top: 12, bottom: 8 })

      Text(this.hint)
        .fontSize(PlaylistConstants.EMPTY_STATE_HINT_FONT_SIZE)
        .fontColor(PlaylistConstants.TEXT_SECONDARY)
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({
      left: PlaylistConstants.EMPTY_STATE_HORIZONTAL_PADDING,
      right: PlaylistConstants.EMPTY_STATE_HORIZONTAL_PADDING
    })
  }
}
