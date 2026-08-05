/*
 * Copyright (c) 2025. All rights reserved.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import UIAbility from '@ohos.app.ability.UIAbility';
import testsuite from './test/List.test';
import AbilityDelegatorRegistry from '@ohos.app.ability.abilityDelegatorRegistry';
import { HiLog } from '@ohos/common';
import { MediaPermissionManager, PermissionState } from '@ohos/common/src/main/ets/permission/MediaPermissionManager';
import { AppContext } from '@ohos/common/src/main/ets/context/AppContext';
import { Hypium } from '@ohos/hypium';
import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import window from '@ohos.window';
import Want from '@ohos.app.ability.Want';
import { TestUtil } from './test/utils/TestUtil';

const TAG = 'TestAbility';

export default class TestAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam) {
    HiLog.i(TAG, 'TestAbility onCreate start');
    
    // 设置context但不尝试授权（避免系统API权限问题导致崩溃）
    try {
      AppContext.getInstance().setMainAbilityContext(this.context);
      AppContext.getInstance().setAppContext(this.context.getApplicationContext());
      AppContext.getInstance().abilityStageContext = this.context;
      HiLog.i(TAG, 'Context set to AppState successfully');
    } catch (error) {
      HiLog.e(TAG, 'Failed to set context: ' + String(error));
    }
    
    HiLog.i(TAG, 'TestAbility onCreate end');
  }

  onDestroy(): void {
    HiLog.i(TAG, 'TestAbility onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage) {
    HiLog.i(TAG, 'TestAbility onWindowStageCreate');
    windowStage.loadContent('testability/pages/Index', (err, data) => {
      if (err.code) {
        HiLog.e(TAG, 'Failed to load content: ' + err.message);
        return;
      }
      HiLog.i(TAG, 'Succeeded in loading content');
      
      // Run tests after window stage is created and content is loaded
      HiLog.i(TAG, 'Starting test execution');
      let abilityDelegator: AbilityDelegatorRegistry.AbilityDelegator;
      abilityDelegator = AbilityDelegatorRegistry.getAbilityDelegator();
      let abilityDelegatorArguments: AbilityDelegatorRegistry.AbilityDelegatorArgs;
      abilityDelegatorArguments = AbilityDelegatorRegistry.getArguments();
      HiLog.i(TAG, 'start run testcase!!!');
      Hypium.hypiumTest(abilityDelegator, abilityDelegatorArguments, testsuite);
    });
  }

  onWindowStageDestroy(): void {
    HiLog.i(TAG, 'TestAbility onWindowStageDestroy');
  }

  onForeground(): void {
    HiLog.i(TAG, 'TestAbility onForeground');
  }

  onBackground(): void {
    HiLog.i(TAG, 'TestAbility onBackground');
  }
}