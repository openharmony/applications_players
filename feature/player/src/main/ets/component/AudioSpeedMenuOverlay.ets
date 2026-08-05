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

import { PlayerUiConstants } from '../constants/PlayerUiConstants';
import { PlayerSpeedMenuPanel } from './PlayerSpeedMenuPanel';

export interface SpeedOptionItem {
  label: string;
  speed: number;
}

export const AUDIO_SPEED_OPTIONS: SpeedOptionItem[] = [
  { label: '0.5X', speed: 0.5 },
  { label: '0.75X', speed: 0.75 },
  { label: '1.0X', speed: 1.0 },
  { label: '1.25X', speed: 1.25 },
  { label: '1.5X', speed: 1.5 },
  { label: '2.0X', speed: 2.0 },
  { label: '4.0X', speed: 4.0 },
];

/**
 * 全屏遮罩倍速菜单（备用）：点击遮罩关闭，面板右上角对齐
 */
@Component
export struct AudioSpeedMenuOverlay {
  @Link visible: boolean;
  @Prop currentSpeedLabel: string = '1.0X';
  onSelect?: (option: SpeedOptionItem) => void;

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(PlayerUiConstants.SPEED_MENU_MASK_COLOR)
        .onClick(() => {
          this.visible = false;
        })

      PlayerSpeedMenuPanel({
        currentSpeedLabel: this.currentSpeedLabel,
        onSelect: (option: SpeedOptionItem) => {
          if (this.onSelect) {
            this.onSelect(option);
          }
          this.visible = false;
        }
      })
        .margin({
          top: PlayerUiConstants.SPEED_MENU_OVERLAY_MARGIN_TOP,
          right: PlayerUiConstants.SPEED_MENU_OVERLAY_MARGIN_RIGHT
        })
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.Default)
  }
}
