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
import { PlaylistResumePlaybackBar } from './PlaylistResumePlaybackBar';

const TAG = 'PlaylistDetailActionBar';

/**
 * 详情页操作区：播放全部；续播条作为同一 Column 的第二行，避免与 List 并列挤压 layoutWeight
 * （编辑入口已移至顶栏与添加音乐同行）
 */
@Component
export struct PlaylistDetailActionBar {
  @Prop trackCount: number = 0;
  @Prop showResumeBar: boolean = false;
  @Prop resumeTrackLabel: string = '';
  onPlayAll: () => void = () => {};
  onContinueResume: () => void = () => {};
  onDismissResume: () => void = () => {};

  /** 续播条是否应展示 */
  private isResumeVisible(): boolean {
    return this.showResumeBar && this.resumeTrackLabel.length > 0;
  }

  build() {
    Column() {
      Row({ space: 10 }) {
        Button({ type: ButtonType.Normal, stateEffect: false }) {
          SymbolGlyph($r('sys.symbol.play_fill'))
            .fontSize(PlaylistConstants.DETAIL_ACTION_PLAY_ICON_SIZE)
            .fontColor([Color.White])
        }
        .width(PlaylistConstants.DETAIL_ACTION_PLAY_BUTTON_SIZE)
        .height(PlaylistConstants.DETAIL_ACTION_PLAY_BUTTON_SIZE)
        .borderRadius(PlaylistConstants.DETAIL_ACTION_PLAY_BUTTON_SIZE / 2)
        .backgroundColor(PlaylistConstants.PRIMARY_COLOR)

        Text($r('app.string.playlist_play_all', this.trackCount))
          .fontSize(PlaylistConstants.DETAIL_ACTION_FONT_SIZE)
          .fontWeight(500)
          .fontColor(PlaylistConstants.TEXT_PRIMARY)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({
        left: PlaylistConstants.DETAIL_HEADER_HORIZONTAL_PADDING,
        right: PlaylistConstants.DETAIL_HEADER_HORIZONTAL_PADDING,
        bottom: this.isResumeVisible() ? 0 : PlaylistConstants.DETAIL_ACTION_ROW_PADDING_BOTTOM
      })
      .onClick(() => {
        HiLog.i(TAG, `playAll clicked count=${this.trackCount}`);
        this.onPlayAll();
      })

      if (this.isResumeVisible()) {
        PlaylistResumePlaybackBar({
          resumeTrackLabel: this.resumeTrackLabel,
          onContinue: this.onContinueResume,
          onDismiss: this.onDismissResume
        })
      }
    }
    .width('100%')
  }
}
