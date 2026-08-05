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


import deviceInfo from '@ohos.deviceInfo';
import display from '@ohos.display';
import ConfigUtil, { GlobalConfig } from './ConfigUtil';
import { HiLog } from './HiLog';

const TAG = 'DeviceTypeUtil';

/**
 * 设备类型判断（基于构建产物 GlobalConfig；日后 Pad 模块切换 TABLET_CONFIG 即可生效）。
 * 新代码请统一 import 本类，例如 `DeviceTypeUtil.isPhone()`。
 */
export class DeviceTypeUtil {
  /**
   * 当前是否为手机产物。
   *
   * @returns PHONE_CONFIG 时为 true
   */
  static isPhone(): boolean {
    return ConfigUtil.getConfig() === GlobalConfig.PHONE_CONFIG;
  }

  /**
   * 当前是否为平板 / Pad 产物。
   *
   * @returns TABLET_CONFIG 时为 true
   */
  static isTablet(): boolean {
    return ConfigUtil.getConfig() === GlobalConfig.TABLET_CONFIG;
  }

  /**
   * 与 {@link isTablet} 等价，便于 Pad 语义调用。
   *
   * @returns TABLET_CONFIG 时为 true
   */
  static isPad(): boolean {
    return DeviceTypeUtil.isTablet();
  }

  /**
   * 当前是否为 PC 产物。
   *
   * @returns PC_CONFIG 时为 true
   */
  static isPC(): boolean {
    return ConfigUtil.getConfig() === GlobalConfig.PC_CONFIG;
  }

  /**
   * 当前硬件是否为折叠屏（运行时能力检测，与构建产物无关）。
   *
   * @returns 支持且检测到折叠屏时为 true
   */
  static isFoldable(): boolean {
    if (!canIUse('SystemCapability.Window.SessionManager')) {
      return false;
    }
    try {
      return display.isFoldable();
    } catch (err) {
      HiLog.e(TAG, `isFoldable failed errorCode=${err?.code} errorMessage=${err?.message}`);
      return false;
    }
  }

  /**
   * 运行时是否为平板 / 2in1 大屏（与 phone HAP 跑在 PAD 硬件上兼容）。
   *
   * @returns deviceType 为 tablet 或 2in1 时为 true
   */
  static isRuntimeLargeScreen(): boolean {
    const type = deviceInfo.deviceType;
    return type === 'tablet' || type === '2in1';
  }

  /**
   * 音频播放页是否应按手机策略锁竖屏（真手机为 true，PAD 跑 phone 产物为 false）。
   *
   * @returns 需要锁竖屏时为 true
   */
  static shouldLockAudioPortrait(): boolean {
    return DeviceTypeUtil.isPhone() && !DeviceTypeUtil.isRuntimeLargeScreen();
  }
}
