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
 * 详情页多选底部删除条
 */
@Component
export struct PlaylistSelectionDeleteBar {
  onDeleteClick: () => void = () => {};

  build() {
    Row() {
      Button($r('app.string.delete'))
        .width('100%')
        .height(PlaylistConstants.SELECTION_DELETE_BAR_HEIGHT)
        .fontSize(PlaylistConstants.SELECTION_DELETE_BAR_FONT_SIZE)
        .fontWeight(600)
        .fontColor(Color.White)
        .backgroundColor(PlaylistConstants.DELETE_COLOR)
        .borderRadius(PlaylistConstants.SELECTION_DELETE_BAR_BORDER_RADIUS)
        .onClick(() => {
          this.onDeleteClick();
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, bottom: 16, top: 8 })
  }
}
