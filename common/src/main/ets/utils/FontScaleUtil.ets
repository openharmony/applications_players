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



export class FontScaleUtil {
  static readonly STORAGE_KEY: string = 'fontScale';
  static readonly MIN_SCALE: number = 0.5;
  static readonly MAX_SCALE: number = 2;
  static readonly STEP: number = 0.05;
  static readonly DEFAULT_SCALE: number = 1.0;

  public static clampScale(scale: number): number {
    if (scale < FontScaleUtil.MIN_SCALE) {
      return FontScaleUtil.MIN_SCALE;
    }
    if (scale > FontScaleUtil.MAX_SCALE) {
      return FontScaleUtil.MAX_SCALE;
    }
    return Math.round(scale * 100) / 100;
  }

  public static scaleFont(baseSize: number, fontScale: number = FontScaleUtil.DEFAULT_SCALE): number {
    return Math.round(baseSize * fontScale * 10) / 10;
  }

  public static formatScaleLabel(fontScale: number): string {
    return `${Math.round(fontScale * 100)}%`;
  }
}
