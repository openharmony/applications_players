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



import { MediaPermissionManager, PermissionState } from '@ohos/common/src/main/ets/permission/MediaPermissionManager';
import { AppContext } from '@ohos/common/src/main/ets/context/AppContext';
import { HiLog } from '@ohos/common/src/main/ets/utils/HiLog';

const TAG = 'PermissionViewModel';

/**
 * 权限弹窗 ViewModel：封装首次启动时的媒体权限申请流程
 */
export class PermissionViewModel {
  private static instance: PermissionViewModel;
  private permissionMgr: MediaPermissionManager = MediaPermissionManager.getInstance();
  /** 本会话内用户拒绝/暂不授权或系统授权失败，冷启动前不再弹自定义弹窗 */
  private dialogDismissedWithoutGrantThisSession: boolean = false;

  private constructor() {
  }

  /**
   * 获取 PermissionViewModel 单例
   *
   * @returns PermissionViewModel 实例
   */
  public static getInstance(): PermissionViewModel {
    if (!PermissionViewModel.instance) {
      PermissionViewModel.instance = new PermissionViewModel();
    }
    return PermissionViewModel.instance;
  }

  /**
   * 冷启动权限检查：同步系统授权状态并决定是否展示自定义弹窗
   *
   * @returns 需要展示自定义权限弹窗时返回 true
   */
  public async prepareLaunchPermissionCheck(): Promise<boolean> {
    const state = await this.permissionMgr.syncPermissionState();
    HiLog.i(TAG, `prepareLaunchPermissionCheck state=${state} dismissed=${this.dialogDismissedWithoutGrantThisSession}`);
    // 仅当系统读权限已具备时不弹窗；应用内 Preference 不能单独跳过
    if (state === PermissionState.GRANTED || state === PermissionState.PARTIAL) {
      const hasSystem = await this.permissionMgr.hasSystemMediaPermission();
      if (hasSystem) {
        return false;
      }
      HiLog.w(TAG, 'App-level allowed but system read permission missing, still showing auth dialog');
    }
    return !this.dialogDismissedWithoutGrantThisSession;
  }

  public getPermissionState(): PermissionState {
    return this.permissionMgr.getPermissionState();
  }

  /**
   * 用户在自定义弹窗确认后：申请系统权限（失败时会引导系统设置）
   *
   * @returns 授权结果
   */
  public async confirmGrantFromCustomDialog(): Promise<PermissionState> {
    const context = AppContext.getInstance().getMainAbilityContext();
    if (!context) {
      HiLog.e(TAG, 'Context is null, cannot request permission');
      this.markDialogDismissedWithoutGrant();
      return PermissionState.DENIED;
    }

    const state = await this.permissionMgr.requestSystemMediaPermission(context);
    HiLog.i(TAG, `confirmGrantFromCustomDialog result=${state}`);
    // 未授权时本会话不再重复弹自定义窗；顶部「授权」按钮与设置返回后的 sync 仍可用
    if (state !== PermissionState.GRANTED && state !== PermissionState.PARTIAL) {
      this.dialogDismissedWithoutGrantThisSession = true;
    }
    return state;
  }

  /**
   * 用户在自定义弹窗确认授权（仅 Preference，不申请系统权限）
   */
  public grantAppMediaConsent(): void {
    this.permissionMgr.grantAppMediaConsent();
    HiLog.i(TAG, 'App media consent granted via custom permission dialog');
  }

  /**
   * @deprecated 请使用 confirmGrantFromCustomDialog
   * @returns 授权结果
   */
  public async requestGrantPermission(): Promise<PermissionState> {
    return this.confirmGrantFromCustomDialog();
  }

  /** 用户点击「关闭」：本会话不再弹窗，下次冷启动再询问 */
  public dismissDialogWithoutGrant(): void {
    this.markDialogDismissedWithoutGrant();
    HiLog.i(TAG, 'Permission dialog closed by user, suppressed until next cold start');
  }

  /** 标记本会话已关闭未授权，避免同一次启动重复弹自定义弹窗 */
  private markDialogDismissedWithoutGrant(): void {
    this.dialogDismissedWithoutGrantThisSession = true;
    this.permissionMgr.setPermissionState(PermissionState.DENIED);
  }
}
