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


import { common, Want } from '@kit.AbilityKit';
import backgroundTaskManager from '@ohos.resourceschedule.backgroundTaskManager';
import wantAgent, { WantAgent } from '@ohos.app.ability.wantAgent';
import { HiLog } from '../utils/HiLog';

const TAG = 'MediaProgressBackgroundHelper';

/**
 * 媒体导入/扫描后台长任务：回桌面或锁屏时保持进程活跃，便于实况窗与进度通知持续更新。
 */
export class MediaProgressBackgroundHelper {
  private static running: boolean = false;

  /**
   * 启动 DATA_TRANSFER 长任务
   *
   * @param context MainAbility 上下文
   */
  static async start(context: common.UIAbilityContext | null): Promise<void> {
    if (MediaProgressBackgroundHelper.running || context === null) {
      return;
    }
    try {
      const agent = await MediaProgressBackgroundHelper.buildWantAgent(context);
      await backgroundTaskManager.startBackgroundRunning(context,
        backgroundTaskManager.BackgroundMode.DATA_TRANSFER, agent);
      MediaProgressBackgroundHelper.running = true;
      HiLog.i(TAG, 'startBackgroundRunning DATA_TRANSFER success');
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      HiLog.w(TAG, `startBackgroundRunning failed message=${message}`);
    }
  }

  /**
   * 结束长任务
   *
   * @param context MainAbility 上下文
   */
  static async stop(context: common.UIAbilityContext | null): Promise<void> {
    if (!MediaProgressBackgroundHelper.running || context === null) {
      return;
    }
    try {
      await backgroundTaskManager.stopBackgroundRunning(context);
      MediaProgressBackgroundHelper.running = false;
      HiLog.i(TAG, 'stopBackgroundRunning success');
    } catch (error) {
      MediaProgressBackgroundHelper.running = false;
      const message = error instanceof Error ? error.message : String(error);
      HiLog.w(TAG, `stopBackgroundRunning failed message=${message}`);
    }
  }

  static isRunning(): boolean {
    return MediaProgressBackgroundHelper.running;
  }

  /**
   * 构建点击通知/实况窗回到应用的 WantAgent
   *
   * @param context MainAbility 上下文
   */
  private static async buildWantAgent(context: common.UIAbilityContext): Promise<WantAgent> {
    const want: Want = {
      bundleName: context.applicationInfo.name,
      abilityName: 'MainAbility',
      moduleName: 'phone'
    };
    const wantAgentInfo: wantAgent.WantAgentInfo = {
      wants: [want],
      actionType: wantAgent.OperationType.START_ABILITY,
      requestCode: 0,
      wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    };
    return wantAgent.getWantAgent(wantAgentInfo);
  }
}
