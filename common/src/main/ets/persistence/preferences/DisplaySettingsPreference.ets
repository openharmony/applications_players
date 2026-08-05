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



import preferences from '@ohos.data.preferences';
import { common } from '@kit.AbilityKit';
import { HiLog } from '../../utils/HiLog';
import { FontScaleUtil } from '../../utils/FontScaleUtil';

const TAG = 'DisplaySettingsPreference';
const FILE_NAME = 'display_settings_preference';
const KEY_FONT_SCALE = 'fontScale';

export class DisplaySettingsPreference {
  private static instance: DisplaySettingsPreference;
  private preferenceInstance: preferences.Preferences | null = null;
  private context: common.UIAbilityContext | null = null;

  private constructor() {
  }

  public static getInstance(): DisplaySettingsPreference {
    if (!DisplaySettingsPreference.instance) {
      DisplaySettingsPreference.instance = new DisplaySettingsPreference();
    }
    return DisplaySettingsPreference.instance;
  }

  public init(context: common.UIAbilityContext): void {
    this.context = context;
    if (!this.preferenceInstance) {
      this.loadPreference();
    }
  }

  private loadPreference(): void {
    if (!this.context) {
      HiLog.e(TAG, 'context is null, cannot load preference');
      return;
    }
    try {
      const options: preferences.Options = { name: FILE_NAME };
      this.preferenceInstance = preferences.getPreferencesSync(this.context, options);
      HiLog.i(TAG, 'load preference success');
    } catch (err) {
      HiLog.e(TAG, 'load preference err: %{public}s', String(err));
    }
  }

  public getFontScale(): number {
    if (!this.preferenceInstance) {
      HiLog.w(TAG, 'preferenceInstance is null, return default');
      return FontScaleUtil.DEFAULT_SCALE;
    }
    try {
      const fontScale = this.preferenceInstance.getSync(KEY_FONT_SCALE, FontScaleUtil.DEFAULT_SCALE) as number;
      return FontScaleUtil.clampScale(fontScale);
    } catch (err) {
      HiLog.e(TAG, 'getFontScale err: %{public}s', String(err));
      return FontScaleUtil.DEFAULT_SCALE;
    }
  }

  public setFontScale(fontScale: number): void {
    if (!this.preferenceInstance) {
      HiLog.w(TAG, 'preferenceInstance is null, cannot save');
      return;
    }
    try {
      const clampedScale: number = FontScaleUtil.clampScale(fontScale);
      this.preferenceInstance.putSync(KEY_FONT_SCALE, clampedScale);
      this.preferenceInstance.flush();
      HiLog.i(TAG, `setFontScale: ${clampedScale}`);
    } catch (err) {
      HiLog.e(TAG, 'setFontScale err: %{public}s', String(err));
    }
  }
}
