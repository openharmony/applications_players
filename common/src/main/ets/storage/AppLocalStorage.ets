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


import VideoInformation from '../model/VideoInformation';
import { SafeAreaConstants } from '../constants/ui/SafeAreaConstants';
import { LocalStorageParam } from '../constants/storage/StorageParam';

/** 与 @Entry 绑定的全局 LocalStorage，供播放器页面及子组件直接引用 */
export const appLocalStorage: LocalStorage = new LocalStorage();

export function initAppLocalStorageDefaults(): void {
  appLocalStorage.setOrCreate<boolean>('isPcFullScreen', false);
  appLocalStorage.setOrCreate<number>(SafeAreaConstants.AVOID_BOTTOM_AREA_KEY, 0);
  appLocalStorage.setOrCreate<number>(SafeAreaConstants.AVOID_CUTOUT_AREA_KEY, 0);
  appLocalStorage.setOrCreate<boolean>(LocalStorageParam.APP_IN_BACKGROUND, false);
  appLocalStorage.setOrCreate<boolean>('playVideo', true);
  appLocalStorage.setOrCreate<boolean>('swiperVideo', true);
  appLocalStorage.setOrCreate<boolean>('swiperAudio', true);
  appLocalStorage.setOrCreate<boolean>('loadingEnd', false);
  appLocalStorage.setOrCreate<VideoInformation>(LocalStorageParam.VIDEO_INFORMATION, new VideoInformation());
}

/** 将 AppStorage 安全区高度镜像到播放器 LocalStorage（键须在 init 中已注册） */
export function syncAppLocalStorageSafeArea(): void {
  const navHeight = AppStorage.get<number>(SafeAreaConstants.NAVI_INDICATOR_HEIGHT_KEY) ?? 0;
  const statusHeight = AppStorage.get<number>(SafeAreaConstants.STATUS_BAR_HEIGHT_KEY) ?? 0;
  appLocalStorage.set<number>(SafeAreaConstants.AVOID_BOTTOM_AREA_KEY, navHeight);
  appLocalStorage.set<number>(SafeAreaConstants.AVOID_CUTOUT_AREA_KEY, statusHeight);
}
