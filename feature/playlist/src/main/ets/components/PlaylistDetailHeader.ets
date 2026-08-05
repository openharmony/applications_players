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
import { NavBackButton } from '@ohos/common';

/**
 * 歌单详情顶栏：返回 + 标题 + 添加/编辑（圆形深底图标，与首页搜索按钮统一）
 */
@Component
export struct PlaylistDetailHeader {
  @Prop detailName: string = '';
  /** 空歌单时隐藏编辑入口 */
  @Prop showEdit: boolean = false;
  onBack: () => void = () => {};
  onAddAudio: () => void = () => {};
  onEnterEdit: () => void = () => {};

  build() {
    Row() {
      Row({ space: PlaylistConstants.DETAIL_HEADER_TITLE_GAP }) {
        NavBackButton({
          onBack: () => {
            this.onBack();
          }
        })

        Text(this.detailName)
          .fontSize(PlaylistConstants.DETAIL_HEADER_TITLE_FONT_SIZE)
          .fontWeight(600)
          .fontColor(PlaylistConstants.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(VerticalAlign.Center)

      Row({ space: PlaylistConstants.DETAIL_HEADER_ACTION_GAP }) {
        this.IconButton($r('sys.symbol.plus'), () => {
          this.onAddAudio();
        })

        if (this.showEdit) {
          this.IconButton($r('sys.symbol.square_and_pencil'), () => {
            this.onEnterEdit();
          })
        }
      }
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({
      left: PlaylistConstants.DETAIL_HEADER_HORIZONTAL_PADDING,
      right: PlaylistConstants.DETAIL_HEADER_HORIZONTAL_PADDING,
      top: 8,
      bottom: 10
    })
  }

  /** 与首页搜索 / 新建歌单按钮统一：36 圆 + 深底 + 图标 18 */
  @Builder
  IconButton(icon: Resource, onClick: () => void) {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph(icon)
        .fontSize(18)
        .fontColor([AppThemeConstants.TEXT_PRIMARY])
        .fontWeight(FontWeight.Medium)
    }
    .buttonStyle(ButtonStyleMode.NORMAL)
    .width(36)
    .height(36)
    .backgroundColor(AppThemeConstants.HEADER_ICON_BACKGROUND)
    .onClick(onClick)
  }
}
