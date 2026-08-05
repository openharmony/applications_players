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



import { HiLog } from '@ohos/common/src/main/ets/utils/HiLog';
import { PlaylistConstants } from '../constants/PlaylistConstants';

const TAG = 'PlaylistResumePlaybackBar';

/**
 * 歌单详情续播条：扁平行样式（与「播放全部」一致，无底�?边框�?
 */
@Component
export struct PlaylistResumePlaybackBar {
  @Prop resumeTrackLabel: string = '';
  onContinue: () => void = () => {};
  onDismiss: () => void = () => {};

  build() {
    Row() {
      Row({ space: PlaylistConstants.RESUME_BAR_ICON_TEXT_GAP }) {
        SymbolGlyph($r('sys.symbol.play_fill'))
          .fontSize(PlaylistConstants.RESUME_BAR_PLAY_ICON_SIZE)
          .fontColor([PlaylistConstants.TEXT_PRIMARY])

        Row({ space: 0 }) {
          Text($r('app.string.playlist_resume_prefix'))
            .fontSize(PlaylistConstants.RESUME_BAR_FONT_SIZE)
            .fontWeight(500)
            .fontColor(PlaylistConstants.TEXT_PRIMARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.resumeTrackLabel)
            .fontSize(PlaylistConstants.RESUME_BAR_FONT_SIZE)
            .fontWeight(500)
            .fontColor(PlaylistConstants.TEXT_PRIMARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        }
        .layoutWeight(1)
      }
      .layoutWeight(1)
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        HiLog.i(TAG, `continue clicked file=${this.resumeTrackLabel}`);
        this.onContinue();
      })

      Button({ type: ButtonType.Normal, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.xmark'))
          .fontSize(PlaylistConstants.RESUME_BAR_CLOSE_ICON_SIZE)
          .fontColor([PlaylistConstants.TEXT_SECONDARY])
      }
      .width(PlaylistConstants.RESUME_BAR_CLOSE_BUTTON_SIZE)
      .height(PlaylistConstants.RESUME_BAR_CLOSE_BUTTON_SIZE)
      .backgroundColor($r('sys.color.ohos_id_color_background_transparent'))
      .onClick(() => {
        HiLog.i(TAG, `dismiss clicked file=${this.resumeTrackLabel}`);
        this.onDismiss();
      })
    }
    .width('100%')
    .height(PlaylistConstants.RESUME_BAR_HEIGHT)
    .alignItems(VerticalAlign.Center)
    .padding({
      left: PlaylistConstants.DETAIL_HEADER_HORIZONTAL_PADDING,
      right: PlaylistConstants.DETAIL_HEADER_HORIZONTAL_PADDING,
      bottom: PlaylistConstants.RESUME_BAR_BOTTOM_PADDING
    })
  }
}
