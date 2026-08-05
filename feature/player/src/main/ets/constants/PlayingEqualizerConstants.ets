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

/** 播放指示器竖条均衡器图标常量（队列 3 条 / 音频页 5 条） */
export class PlayingEqualizerConstants {
  static readonly BAR_WIDTH: number = 2;
  static readonly BAR_GAP: number = 4;
  static readonly BARS_TOTAL_WIDTH: number = PlayingEqualizerConstants.BAR_WIDTH * 3 +
    PlayingEqualizerConstants.BAR_GAP * 2;
  static readonly BARS_TOTAL_WIDTH_FIVE: number = PlayingEqualizerConstants.BAR_WIDTH * 5 +
    PlayingEqualizerConstants.BAR_GAP * 4;
  /** 胶囊圆角：半宽，呈圆头竖条 */
  static readonly BAR_RADIUS: number = 1;
  static readonly BAR_FULL_HEIGHT: number = 23;
  static readonly CONTAINER_HEIGHT: number = 23;
  static readonly BAR_COLOR: Resource = AppThemeConstants.EQUALIZER_BAR;
  static readonly BAR_ANIM_FRAME_MS: number = 50;

  /** 正弦波步进（错开竖条节奏） */
  static readonly WAVE_STEP_BAR1: number = 0.28;
  static readonly WAVE_STEP_BAR2: number = 0.22;
  static readonly WAVE_STEP_BAR3: number = 0.25;
  static readonly WAVE_STEP_BAR4: number = 0.31;
  static readonly WAVE_STEP_BAR5: number = 0.19;

  /** 播放态缩放区间 */
  static readonly ANIM_SCALE_MIN: number = 0.3;
  static readonly ANIM_SCALE_MAX: number = 1;

  /**
   * 暂停/静态比例（设计稿五竖条：高-中-低-中高-中）
   * 约 100% / 58% / 40% / 78% / 58%
   */
  static readonly PAUSED_SCALE_BAR1: number = 0.7;
  static readonly PAUSED_SCALE_BAR2: number = 0.58;
  static readonly PAUSED_SCALE_BAR3: number = 0.4;
  static readonly PAUSED_SCALE_BAR4: number = 0.78;
  static readonly PAUSED_SCALE_BAR5: number = 0.58;

  /** 暂停态竖条高度 */
  static getPausedHeight(barIndex: number): number {
    let scale = PlayingEqualizerConstants.PAUSED_SCALE_BAR1;
    if (barIndex === 1) {
      scale = PlayingEqualizerConstants.PAUSED_SCALE_BAR2;
    } else if (barIndex === 2) {
      scale = PlayingEqualizerConstants.PAUSED_SCALE_BAR3;
    } else if (barIndex === 3) {
      scale = PlayingEqualizerConstants.PAUSED_SCALE_BAR4;
    } else if (barIndex === 4) {
      scale = PlayingEqualizerConstants.PAUSED_SCALE_BAR5;
    }
    return PlayingEqualizerConstants.BAR_FULL_HEIGHT * scale;
  }

  /** @deprecated 兼容旧调用 */
  static getPausedHeightBar1(): number {
    return PlayingEqualizerConstants.getPausedHeight(0);
  }

  static getPausedHeightBar2(): number {
    return PlayingEqualizerConstants.getPausedHeight(1);
  }

  static getPausedHeightBar3(): number {
    return PlayingEqualizerConstants.getPausedHeight(2);
  }

  static getPausedHeightBar4(): number {
    return PlayingEqualizerConstants.getPausedHeight(3);
  }
}
