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


import { Configuration, ConfigurationConstant } from '@kit.AbilityKit';
import { HiLog } from '../utils/HiLog';
import { AppThemeConstants } from '../constants/ui/AppThemeConstants';

const TAG = 'AppThemeModeHelper';

/**
 * 同步系统深浅色模式到 AppStorage，供 WindowUtil 与 View 读取。
 */
export class AppThemeModeHelper {
  /**
   * 根据 Configuration 刷新深浅色标记
   *
   * @param configuration 系统配置
   */
  static syncFromConfiguration(configuration: Configuration): void {
    const isDark = configuration.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    AppStorage.setOrCreate(AppThemeConstants.STORAGE_DARK_MODE, isDark);
    HiLog.i(TAG, `syncColorMode isDark=${isDark}`);
  }

  /** 当前是否为深色模式 */
  static isDarkMode(): boolean {
    return AppStorage.get<boolean>(AppThemeConstants.STORAGE_DARK_MODE) === true;
  }
}
