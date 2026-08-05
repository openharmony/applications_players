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



import { AppThemeConstants } from '@ohos/common/src/main/ets/constants/ui/AppThemeConstants';
import { PlaylistConstants } from '../constants/PlaylistConstants';

/**
 * 我的歌单首页顶栏：左上角歌单标题 + 新建按钮（圆形加号，与首页搜索按钮样式一致）
 */
@Component
export struct PlaylistListHeader {
  onCreateClick: () => void = () => {};

  build() {
    Row() {
      Text($r('app.string.Song_List'))
        .fontSize($r('sys.float.ohos_id_text_size_headline6'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))

      Blank()

      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.plus'))
          .fontSize(18)
          .fontColor([AppThemeConstants.TEXT_PRIMARY])
          .fontWeight(FontWeight.Medium)
      }
      .buttonStyle(ButtonStyleMode.NORMAL)
      .width(36)
      .height(36)
      .backgroundColor(AppThemeConstants.HEADER_ICON_BACKGROUND)
      .onClick(() => {
        this.onCreateClick();
      })
    }
    .width('100%')
    .padding({
      left: PlaylistConstants.LIST_HEADER_HORIZONTAL_PADDING,
      right: PlaylistConstants.LIST_HEADER_HORIZONTAL_PADDING,
      top: 8,
      bottom: 10
    })
  }
}
