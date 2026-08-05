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


import { AppThemeConstants } from '@ohos/common/src/main/ets/constants/ui/AppThemeConstants';
import { SafeAreaConstants } from '@ohos/common/src/main/ets/constants/ui/SafeAreaConstants';
import { HiLog } from '@ohos/common/src/main/ets/utils/HiLog';

const TAG = 'NavPageSafeAreaShell';

/**
 * Nav 子页内容区壳：状态栏由 Ability 级沉浸式固定，此处仅预留内容区 inset
 */
@Component
export struct NavPageSafeAreaShell {
  /** 壳层背景，需与 NavDestination 一致 */
  @Prop surfaceBackground: Resource = AppThemeConstants.PAGE_BACKGROUND;
  @StorageProp(SafeAreaConstants.STATUS_BAR_HEIGHT_KEY) statusBarHeight: number = 0;
  @StorageProp(SafeAreaConstants.NAVI_INDICATOR_HEIGHT_KEY) naviIndicatorHeight: number = 0;
  @BuilderParam content: () => void = this.defaultContent;

  aboutToAppear(): void {
    HiLog.i(TAG, `aboutToAppear statusBarHeight=${this.statusBarHeight}`);
  }

  @Builder
  defaultContent(): void {
  }

  build() {
    Column() {
      this.content()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.surfaceBackground)
    .padding({
      top: this.statusBarHeight,
      bottom: this.naviIndicatorHeight
    })
  }
}
