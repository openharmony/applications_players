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
import { DisplaySettingsPreference } from '@ohos/common/src/main/ets/persistence/preferences/DisplaySettingsPreference';
import { FontScaleUtil } from '@ohos/common/src/main/ets/utils/FontScaleUtil';

const TAG = 'SettingsViewModel';

/**
 * 显示设置 ViewModel：管理字体缩放读写与持久化
 */
export class SettingsViewModel {
  private static instance: SettingsViewModel;

  private constructor() {
  }

  /**
   * 获取 SettingsViewModel 单例
   *
   * @returns SettingsViewModel 实例
   */
  public static getInstance(): SettingsViewModel {
    if (!SettingsViewModel.instance) {
      SettingsViewModel.instance = new SettingsViewModel();
    }
    return SettingsViewModel.instance;
  }

  /**
   * 读取当前字体缩放比例
   *
   * @returns  clamp 后的缩放值
   */
  public getFontScale(): number {
    const fontScale = AppStorage.get<number>(FontScaleUtil.STORAGE_KEY);
    if (fontScale === undefined) {
      return FontScaleUtil.DEFAULT_SCALE;
    }
    return FontScaleUtil.clampScale(fontScale);
  }

  /**
   * 更新字体缩放：同步 AppStorage 与 Preferences
   *
   * @param fontScale 目标缩放值
   * @returns clamp 后的实际缩放值
   */
  public setFontScale(fontScale: number): number {
    const clampedScale = FontScaleUtil.clampScale(fontScale);
    AppStorage.setOrCreate(FontScaleUtil.STORAGE_KEY, clampedScale);
    DisplaySettingsPreference.getInstance().setFontScale(clampedScale);
    HiLog.i(TAG, `Pipeline[fontScale/1] setFontScale fontScale=${clampedScale}`);
    return clampedScale;
  }

  /**
   * 格式化缩放比例为展示文案（如 100%）
   *
   * @param fontScale 缩放值
   * @returns 百分比字符串
   */
  public getFontScaleLabel(fontScale: number): string {
    return FontScaleUtil.formatScaleLabel(fontScale);
  }
}
