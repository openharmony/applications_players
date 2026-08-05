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


import { DeviceTypeUtil } from './DeviceTypeUtil';

/**
 * @deprecated 新代码请使用 {@link DeviceTypeUtil}（如 `DeviceTypeUtil.isPhone()`）。
 */
class DeviceConfigUtil {
  checkConfigForTablet(): boolean {
    return DeviceTypeUtil.isTablet();
  }

  checkConfigForPC(): boolean {
    return DeviceTypeUtil.isPC();
  }

  checkConfigForPhone(): boolean {
    return DeviceTypeUtil.isPhone();
  }

  checkConfigForFoldable(): boolean {
    return DeviceTypeUtil.isFoldable();
  }
}

export default new DeviceConfigUtil()
