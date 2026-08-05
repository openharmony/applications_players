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

const TAG = 'MediaPermissionPreference';
const FILE_NAME = 'media_permission_preference';
const KEY_APP_CONSENT_GRANTED = 'appMediaConsentGranted';

/**
 * 应用内媒体授权偏好：记录用户在自定义权限弹窗中的授权选择（非系统权限）
 */
export class MediaPermissionPreference {
  private static instance: MediaPermissionPreference;
  private preferenceInstance: preferences.Preferences | null = null;
  private context: common.UIAbilityContext | null = null;

  private constructor() {
  }

  /**
   * 获取 MediaPermissionPreference 单例
   *
   * @returns MediaPermissionPreference 实例
   */
  public static getInstance(): MediaPermissionPreference {
    if (!MediaPermissionPreference.instance) {
      MediaPermissionPreference.instance = new MediaPermissionPreference();
    }
    return MediaPermissionPreference.instance;
  }

  /**
   * 使用 Ability 上下文初始化 Preferences
   *
   * @param context UIAbility 上下文
   */
  public init(context: common.UIAbilityContext): void {
    this.context = context;
    if (!this.preferenceInstance) {
      this.loadPreference();
    }
  }

  /** 加载 Preferences 实例 */
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
      HiLog.e(TAG, `load preference err=${String(err)}`);
    }
  }

  /**
   * 是否已在自定义弹窗中授权
   *
   * @returns 已授权返回 true
   */
  public isAppConsentGranted(): boolean {
    if (!this.preferenceInstance) {
      return false;
    }
    try {
      return this.preferenceInstance.getSync(KEY_APP_CONSENT_GRANTED, false) as boolean;
    } catch (err) {
      HiLog.e(TAG, `isAppConsentGranted err=${String(err)}`);
      return false;
    }
  }

  /**
   * 持久化应用内授权结果
   *
   * @param granted 是否授权
   */
  public setAppConsentGranted(granted: boolean): void {
    if (!this.preferenceInstance) {
      HiLog.w(TAG, 'preferenceInstance is null, cannot save');
      return;
    }
    try {
      this.preferenceInstance.putSync(KEY_APP_CONSENT_GRANTED, granted);
      this.preferenceInstance.flush();
      HiLog.i(TAG, `setAppConsentGranted granted=${granted}`);
    } catch (err) {
      HiLog.e(TAG, `setAppConsentGranted err=${String(err)}`);
    }
  }
}
