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


import { PlayingEqualizerConstants } from '../constants/PlayingEqualizerConstants';

/**
 * 播放指示器竖条：纯展示，高度由 ViewModel / 页面下发的 animTick 驱动
 */
@Component
export struct PlayingEqualizerBars {
  /** 为 true 时暂停也占位显示静止竖条（播放队列当前项 / 音频封面下方） */
  @Prop alwaysVisible: boolean = false;
  /** 是否正在播放 */
  @Prop isPlaying: boolean = false;
  /** ViewModel 动画帧序号，驱动竖条高度变化 */
  @Prop animTick: number = 0;
  /** 竖条数量：队列 3，音频播放页设计稿 5 */
  @Prop barCount: number = 3;
  /** 竖条颜色；未设置时用主题色（队列红条），音频页传白色 */
  @Prop barColor: ResourceColor = PlayingEqualizerConstants.BAR_COLOR;

  /** 按正弦波计算单根竖条高度 */
  private calcBarHeight(tick: number, waveStep: number, phase: number): number {
    const wave = 0.5 + 0.5 * Math.sin(tick * waveStep + phase);
    const scale = PlayingEqualizerConstants.ANIM_SCALE_MIN +
      (PlayingEqualizerConstants.ANIM_SCALE_MAX - PlayingEqualizerConstants.ANIM_SCALE_MIN) * wave;
    return PlayingEqualizerConstants.BAR_FULL_HEIGHT * scale;
  }

  private getWaveStep(barIndex: number): number {
    if (barIndex === 0) {
      return PlayingEqualizerConstants.WAVE_STEP_BAR1;
    }
    if (barIndex === 1) {
      return PlayingEqualizerConstants.WAVE_STEP_BAR2;
    }
    if (barIndex === 2) {
      return PlayingEqualizerConstants.WAVE_STEP_BAR3;
    }
    if (barIndex === 3) {
      return PlayingEqualizerConstants.WAVE_STEP_BAR4;
    }
    return PlayingEqualizerConstants.WAVE_STEP_BAR5;
  }

  /** 单根竖条高度：播放中用 animTick 计算，暂停用静止高度 */
  private resolveBarHeight(barIndex: number, phase: number): number {
    if (this.isPlaying) {
      return this.calcBarHeight(this.animTick, this.getWaveStep(barIndex), phase);
    }
    return PlayingEqualizerConstants.getPausedHeight(barIndex);
  }

  /** 是否渲染竖条区域 */
  private shouldShowBars(): boolean {
    return this.alwaysVisible || this.isPlaying;
  }

  private resolveBarCount(): number {
    if (this.barCount >= 5) {
      return 5;
    }
    return 3;
  }

  private resolveTotalWidth(): number {
    return this.resolveBarCount() >= 5 ?
      PlayingEqualizerConstants.BARS_TOTAL_WIDTH_FIVE : PlayingEqualizerConstants.BARS_TOTAL_WIDTH;
  }

  @Builder
  EqualizerBar(barIndex: number, phase: number) {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width(PlayingEqualizerConstants.BAR_WIDTH)
        .height(this.resolveBarHeight(barIndex, phase))
        .backgroundColor(this.barColor)
        .borderRadius(PlayingEqualizerConstants.BAR_RADIUS)
    }
    .width(PlayingEqualizerConstants.BAR_WIDTH)
    .height(PlayingEqualizerConstants.CONTAINER_HEIGHT)
  }

  build() {
    Row({ space: PlayingEqualizerConstants.BAR_GAP }) {
      if (this.shouldShowBars()) {
        this.EqualizerBar(0, 0)
        this.EqualizerBar(1, 1.2)
        this.EqualizerBar(2, 2.4)
        if (this.resolveBarCount() >= 5) {
          this.EqualizerBar(3, 3.1)
          this.EqualizerBar(4, 0.7)
        }
      }
    }
    .width(this.shouldShowBars() ? this.resolveTotalWidth() : 0)
    .height(PlayingEqualizerConstants.CONTAINER_HEIGHT)
    .alignItems(VerticalAlign.Bottom)
    .justifyContent(FlexAlign.Center)
  }
}
