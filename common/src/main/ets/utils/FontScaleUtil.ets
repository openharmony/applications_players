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

/**
 * 字体缩放工具。
 *
 * 与系统联系人等应用对齐的策略：
 * - 应用已配置 fontSizeScale=followSystem：内容区数字字号按 fp 跟随「字体大小」
 * - AppScope configuration.fontSizeMaxScale 限制跟随上限（播放器为 1.45，避免播控密集页崩版）
 * - 播控 / Tab / 分段等密集控件区使用 {@link chromeSize}（vp），只随「显示大小」变化
 * - 勿在已 followSystem 的界面上再对 fp 字号套用 {@link scaleFont}，否则会双重放大
 */
export class FontScaleUtil {
  /** 应用内设置页缩放（Preferences） */
  static readonly STORAGE_KEY: string = 'fontScale';
  /** 系统字体大小缩放（Configuration.fontSizeScale → AppStorage） */
  static readonly SYSTEM_FONT_SIZE_SCALE_KEY: string = 'systemFontSizeScale';
  static readonly MIN_SCALE: number = 0.5;
  static readonly MAX_SCALE: number = 2;
  static readonly STEP: number = 0.05;
  static readonly DEFAULT_SCALE: number = 1.0;
  /**
   * 首页分类胶囊横向铺满阈值：系统字号达到该值及以上时用 100% 宽，否则保持设计稿 60%。
   */
  static readonly CATEGORY_FULL_WIDTH_SCALE: number = 1.2;

  public static clampScale(scale: number): number {
    if (scale < FontScaleUtil.MIN_SCALE) {
      return FontScaleUtil.MIN_SCALE;
    }
    if (scale > FontScaleUtil.MAX_SCALE) {
      return FontScaleUtil.MAX_SCALE;
    }
    return Math.round(scale * 100) / 100;
  }

  /**
   * 应用内设置页预览用：仅 Settings 等显式「应用内缩放」场景调用。
   * 内容列表/播放页请直接使用基数字号（fp）或 {@link chromeSize}。
   */
  public static scaleFont(baseSize: number, fontScale: number = FontScaleUtil.DEFAULT_SCALE): number {
    return Math.round(baseSize * fontScale * 10) / 10;
  }

  /**
   * 控件区字号/图标尺寸（vp）：随显示大小变化，不随字体大小二次放大。
   */
  public static chromeSize(sizeVp: number): string {
    return `${sizeVp}vp`;
  }

  public static formatScaleLabel(fontScale: number): string {
    return `${Math.round(fontScale * 100)}%`;
  }

  /** 将系统 Configuration.fontSizeScale 写入 AppStorage，供 UI 自适应布局 */
  public static syncSystemFontSizeScale(fontSizeScale: number | undefined): number {
    const scale = (fontSizeScale !== undefined && fontSizeScale > 0) ?
      fontSizeScale : FontScaleUtil.DEFAULT_SCALE;
    AppStorage.setOrCreate(FontScaleUtil.SYSTEM_FONT_SIZE_SCALE_KEY, scale);
    return scale;
  }

  /** 系统字号是否达到「特别大」，需放宽横向密集布局（如分类胶囊铺满） */
  public static needsExpandedHorizontalLayout(systemFontSizeScale?: number): boolean {
    const scale = systemFontSizeScale ??
      (AppStorage.get<number>(FontScaleUtil.SYSTEM_FONT_SIZE_SCALE_KEY) ?? FontScaleUtil.DEFAULT_SCALE);
    return scale >= FontScaleUtil.CATEGORY_FULL_WIDTH_SCALE;
  }
}
