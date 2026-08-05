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


import type common from '@ohos.app.ability.common';
import { abilityAccessCtrl, bundleManager, Want } from '@kit.AbilityKit';
import type { Permissions } from '@ohos.abilityAccessCtrl';
import { MediaPermissionPreference } from '../persistence/preferences/MediaPermissionPreference';
import { HiLog } from '../utils/HiLog';
import WindowUtil from '../utils/WindowUtil';
import window from '@ohos.window';

const TAG = 'MediaPermissionManager';

/** 媒体访问权限状态（应用内授权 + 系统授权合并后的业务态） */
export enum PermissionState {
  PENDING = 'pending',
  GRANTED = 'granted',
  DENIED = 'denied',
  PARTIAL = 'partial'
}

/** 媒体读权限细分（用于按授权范围扫描，避免 File Access 绕过） */
export interface MediaReadAccess {
  hasAudio: boolean;
  hasImageVideo: boolean;
  hasAny: boolean;
  hasAll: boolean;
}

const MEDIA_READ_PERMISSIONS: Permissions[] = [
  'ohos.permission.READ_AUDIO',
  'ohos.permission.READ_IMAGEVIDEO'
];

const MEDIA_WRITE_PERMISSIONS: Permissions[] = [
  'ohos.permission.WRITE_AUDIO',
  'ohos.permission.WRITE_IMAGEVIDEO'
];

const AUDIO_PERMISSION_GROUP: Permissions[] = [
  'ohos.permission.READ_AUDIO',
  'ohos.permission.WRITE_AUDIO'
];

const IMAGEVIDEO_PERMISSION_GROUP: Permissions[] = [
  'ohos.permission.READ_IMAGEVIDEO',
  'ohos.permission.WRITE_IMAGEVIDEO'
];

const MEDIA_PERMISSION_GROUPS: Permissions[][] = [
  AUDIO_PERMISSION_GROUP,
  IMAGEVIDEO_PERMISSION_GROUP
];

/**
 * 媒体权限状态管理器单例。
 * 负责权限检查、授权申请、状态监听与系统权限设置页跳转。
 */
export class MediaPermissionManager {
  private static instance: MediaPermissionManager | null = null;
  private permissionState: PermissionState = PermissionState.PENDING;
  private permissionListeners: ((state: PermissionState) => void)[] = [];
  private cachedMediaReadAccess: MediaReadAccess = {
    hasAudio: false,
    hasImageVideo: false,
    hasAny: false,
    hasAll: false
  };

  private constructor() {
  }

  public static getInstance(): MediaPermissionManager {
    if (!MediaPermissionManager.instance) {
      MediaPermissionManager.instance = new MediaPermissionManager();
    }
    return MediaPermissionManager.instance;
  }

  setPermissionState(state: PermissionState): void {
    this.permissionState = state;
    this.notifyPermissionListeners(state);
  }

  getPermissionState(): PermissionState {
    return this.permissionState;
  }

  initMediaPermissionPreference(context: common.UIAbilityContext): void {
    MediaPermissionPreference.getInstance().init(context);
  }

  async syncPermissionState(): Promise<PermissionState> {
    const readState = await this.checkMediaReadPermission();
    const preference = MediaPermissionPreference.getInstance();
    HiLog.i(TAG, `syncPermissionState systemRead=${readState} appConsent=${preference.isAppConsentGranted()} ` +
      `readHasAll=${this.cachedMediaReadAccess.hasAll}`);

    if (readState === PermissionState.GRANTED || readState === PermissionState.PARTIAL) {
      preference.setAppConsentGranted(true);
      if (readState === PermissionState.GRANTED) {
        const fullState = await this.checkMediaPermission();
        this.setPermissionState(fullState);
        return fullState;
      }
      this.setPermissionState(PermissionState.PARTIAL);
      return PermissionState.PARTIAL;
    }

    if (preference.isAppConsentGranted()) {
      preference.setAppConsentGranted(false);
      HiLog.w(TAG, 'System media read permission invalidated, clearing app consent flag');
    }
    this.setPermissionState(PermissionState.DENIED);
    return PermissionState.DENIED;
  }

  grantAppMediaConsent(): void {
    MediaPermissionPreference.getInstance().setAppConsentGranted(true);
  }

  addPermissionListener(listener: (state: PermissionState) => void): void {
    this.permissionListeners.push(listener);
  }

  removePermissionListener(listener: (state: PermissionState) => void): void {
    const index = this.permissionListeners.indexOf(listener);
    if (index !== -1) {
      this.permissionListeners.splice(index, 1);
    }
  }

  private notifyPermissionListeners(state: PermissionState): void {
    for (const listener of this.permissionListeners) {
      try {
        listener(state);
      } catch (error) {
        HiLog.e(TAG, `Permission listener error: ${String(error)}`);
      }
    }
  }

  async hasSystemMediaPermission(): Promise<boolean> {
    const access = await this.getMediaReadAccess();
    return access.hasAny;
  }

  async getMediaReadAccess(): Promise<MediaReadAccess> {
    try {
      const bundleInfo = await bundleManager.getBundleInfoForSelf(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION
      );
      const tokenId = bundleInfo.appInfo.accessTokenId;
      const atManager = abilityAccessCtrl.createAtManager();
      const audioStatus = await atManager.checkAccessToken(tokenId, 'ohos.permission.READ_AUDIO');
      const imageVideoStatus = await atManager.checkAccessToken(tokenId, 'ohos.permission.READ_IMAGEVIDEO');
      const hasAudio = audioStatus === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
      const hasImageVideo = imageVideoStatus === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
      const access: MediaReadAccess = {
        hasAudio: hasAudio,
        hasImageVideo: hasImageVideo,
        hasAny: hasAudio || hasImageVideo,
        hasAll: hasAudio && hasImageVideo
      };
      this.cachedMediaReadAccess = access;
      HiLog.i(TAG,
        `getMediaReadAccess audio=${hasAudio} imageVideo=${hasImageVideo} hasAll=${access.hasAll}`);
      return access;
    } catch (error) {
      HiLog.e(TAG, `getMediaReadAccess error: ${String(error)}`);
      const denied: MediaReadAccess = {
        hasAudio: false,
        hasImageVideo: false,
        hasAny: false,
        hasAll: false
      };
      this.cachedMediaReadAccess = denied;
      return denied;
    }
  }

  getCachedMediaReadAccess(): MediaReadAccess {
    return this.cachedMediaReadAccess;
  }

  async checkMediaReadPermission(): Promise<PermissionState> {
    try {
      const access = await this.getMediaReadAccess();
      const grantedCount = (access.hasAudio ? 1 : 0) + (access.hasImageVideo ? 1 : 0);
      const state = this.resolvePermissionState(grantedCount, MEDIA_READ_PERMISSIONS.length);
      HiLog.i(TAG, `checkMediaReadPermission granted=${grantedCount}/${MEDIA_READ_PERMISSIONS.length} state=${state}`);
      return state;
    } catch (error) {
      HiLog.e(TAG, `Check read permission error: ${String(error)}`);
      return PermissionState.DENIED;
    }
  }

  async checkMediaPermission(): Promise<PermissionState> {
    const readState = await this.checkMediaReadPermission();
    if (readState !== PermissionState.GRANTED) {
      return readState;
    }
    try {
      const bundleInfo = await bundleManager.getBundleInfoForSelf(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION
      );
      const tokenId = bundleInfo.appInfo.accessTokenId;
      const writeGranted = await this.countGrantedPermissions(tokenId, MEDIA_WRITE_PERMISSIONS);
      if (writeGranted === MEDIA_WRITE_PERMISSIONS.length) {
        return PermissionState.GRANTED;
      }
      return PermissionState.PARTIAL;
    } catch (error) {
      HiLog.e(TAG, `Check permission error: ${String(error)}`);
      return readState;
    }
  }

  private applyPermissionState(state: PermissionState): PermissionState {
    if (state === PermissionState.GRANTED || state === PermissionState.PARTIAL) {
      MediaPermissionPreference.getInstance().setAppConsentGranted(true);
    } else {
      MediaPermissionPreference.getInstance().setAppConsentGranted(false);
    }
    this.setPermissionState(state);
    return state;
  }

  private async isPermissionGroupFullyGranted(group: Permissions[]): Promise<boolean> {
    try {
      const bundleInfo = await bundleManager.getBundleInfoForSelf(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION
      );
      const tokenId = bundleInfo.appInfo.accessTokenId;
      const atManager = abilityAccessCtrl.createAtManager();
      for (const permission of group) {
        const status = await atManager.checkAccessToken(tokenId, permission);
        if (status !== abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
          return false;
        }
      }
      return true;
    } catch (error) {
      HiLog.e(TAG, `isPermissionGroupFullyGranted error: ${String(error)}`);
      return false;
    }
  }

  private async getIncompleteMediaPermissionGroups(): Promise<Permissions[][]> {
    const incomplete: Permissions[][] = [];
    for (const group of MEDIA_PERMISSION_GROUPS) {
      if (!(await this.isPermissionGroupFullyGranted(group))) {
        incomplete.push(group);
      }
    }
    return incomplete;
  }

  private getMainWindow(context: common.UIAbilityContext): window.Window | undefined {
    try {
      return context.windowStage.getMainWindowSync();
    } catch (error) {
      HiLog.w(TAG, `getMainWindow failed: ${String(error)}`);
      return undefined;
    }
  }

  private async runWithPermissionSheetWindowChrome<T>(
    context: common.UIAbilityContext,
    action: () => Promise<T>
  ): Promise<T> {
    const windowClass = this.getMainWindow(context);
    await WindowUtil.prepareSystemPermissionSheet(windowClass);
    try {
      return await action();
    } finally {
      await WindowUtil.restoreAfterSystemPermissionSheet(windowClass);
    }
  }

  async reassertPermissionSheetChromeIfNeeded(context: common.UIAbilityContext): Promise<void> {
    if (!WindowUtil.isPermissionSheetChromeActive()) {
      return;
    }
    const windowClass = this.getMainWindow(context);
    await WindowUtil.reassertSystemPermissionSheetChrome(windowClass);
  }

  async requestSystemMediaPermission(context: common.UIAbilityContext): Promise<PermissionState> {
    const currentState = await this.checkMediaPermission();
    if (currentState === PermissionState.GRANTED) {
      const incomplete = await this.getIncompleteMediaPermissionGroups();
      if (incomplete.length === 0) {
        return this.applyPermissionState(PermissionState.GRANTED);
      }
      return this.runWithPermissionSheetWindowChrome(context, async () => {
        await this.requestMediaPermissionOnSettingInternal(context);
        return this.applyPermissionState(await this.checkMediaPermission());
      });
    }

    return this.runWithPermissionSheetWindowChrome(context, async () => {
      return this.requestSystemMediaPermissionInternal(context);
    });
  }

  private async requestSystemMediaPermissionInternal(
    context: common.UIAbilityContext
  ): Promise<PermissionState> {
    const atManager = abilityAccessCtrl.createAtManager();
    try {
      for (const group of MEDIA_PERMISSION_GROUPS) {
        if (await this.isPermissionGroupFullyGranted(group)) {
          continue;
        }
        const result = await atManager.requestPermissionsFromUser(context, group);
        HiLog.i(TAG,
          `requestPermissionsFromUser group=${JSON.stringify(group)} ` +
          `authResults=${JSON.stringify(result.authResults)}`);
      }

      let readState = await this.checkMediaReadPermission();
      if (readState === PermissionState.GRANTED || readState === PermissionState.PARTIAL) {
        const incomplete = await this.getIncompleteMediaPermissionGroups();
        if (incomplete.length > 0) {
          await this.requestMediaPermissionOnSettingInternal(context);
        }
        if (readState === PermissionState.GRANTED) {
          return this.applyPermissionState(await this.checkMediaPermission());
        }
        return this.applyPermissionState(PermissionState.PARTIAL);
      }

      const guided = await this.guideUserToMediaPermissionSettings(context);
      const afterGuide = await this.checkMediaReadPermission();
      if (afterGuide === PermissionState.GRANTED || afterGuide === PermissionState.PARTIAL) {
        return this.applyPermissionState(afterGuide === PermissionState.GRANTED ?
          await this.checkMediaPermission() : PermissionState.PARTIAL);
      }
      if (guided) {
        this.setPermissionState(PermissionState.DENIED);
        return PermissionState.DENIED;
      }
      return this.applyPermissionState(afterGuide);
    } catch (error) {
      HiLog.e(TAG, `Request system permission error: ${String(error)}`);
      const guided = await this.guideUserToMediaPermissionSettings(context);
      const afterGuide = await this.checkMediaReadPermission();
      if (afterGuide === PermissionState.GRANTED || afterGuide === PermissionState.PARTIAL) {
        return this.applyPermissionState(afterGuide === PermissionState.GRANTED ?
          await this.checkMediaPermission() : PermissionState.PARTIAL);
      }
      if (guided) {
        this.setPermissionState(PermissionState.DENIED);
        return PermissionState.DENIED;
      }
      return this.applyPermissionState(afterGuide);
    }
  }

  private async guideUserToMediaPermissionSettings(
    context: common.UIAbilityContext
  ): Promise<boolean> {
    const openedOnSetting = await this.requestMediaPermissionOnSettingInternal(context);
    if (openedOnSetting) {
      return true;
    }
    return this.openAppPermissionSettings(context);
  }

  private async requestMediaPermissionOnSettingInternal(
    context: common.UIAbilityContext
  ): Promise<boolean> {
    const atManager = abilityAccessCtrl.createAtManager();
    let groups = await this.getIncompleteMediaPermissionGroups();
    if (groups.length === 0) {
      groups = MEDIA_PERMISSION_GROUPS;
    }

    let anySuccess = false;
    for (let i = 0; i < groups.length; i++) {
      const group = groups[i];
      try {
        HiLog.i(TAG, `requestPermissionOnSetting group=${JSON.stringify(group)}`);
        const results = await atManager.requestPermissionOnSetting(context, group);
        HiLog.i(TAG, `requestPermissionOnSetting result=${JSON.stringify(results)}`);
        anySuccess = true;
      } catch (settingError) {
        HiLog.w(TAG, `requestPermissionOnSetting group=${JSON.stringify(group)} failed: ${String(settingError)}`);
      }
    }

    if (!anySuccess) {
      return false;
    }

    const afterState = await this.checkMediaReadPermission();
    const audioGroupOk = await this.isPermissionGroupFullyGranted(AUDIO_PERMISSION_GROUP);
    const imageGroupOk = await this.isPermissionGroupFullyGranted(IMAGEVIDEO_PERMISSION_GROUP);
    HiLog.i(TAG,
      `requestPermissionOnSetting done read=${afterState} ` +
      `audioGroup=${audioGroupOk} imageVideoGroup=${imageGroupOk}`);
    if (afterState === PermissionState.GRANTED || afterState === PermissionState.PARTIAL) {
      this.applyPermissionState(afterState === PermissionState.GRANTED ?
        await this.checkMediaPermission() : PermissionState.PARTIAL);
    }
    return true;
  }

  async openAppPermissionSettings(context: common.UIAbilityContext): Promise<boolean> {
    const bundleName = context.applicationInfo.name;
    const wantCandidates: Want[] = [
      {
        bundleName: 'com.ohos.permissionmanager',
        abilityName: 'com.ohos.permissionmanager.MainAbility',
        action: 'action.access.privacy.center',
        parameters: {
          'bundleName': bundleName
        }
      },
      {
        action: 'action.access.privacy.center',
        bundleName: 'com.ohos.permissionmanager',
        parameters: {
          'bundleName': bundleName
        }
      }
    ];

    for (let i = 0; i < wantCandidates.length; i++) {
      try {
        await context.startAbility(wantCandidates[i]);
        HiLog.i(TAG, `openAppPermissionSettings success index=${i}`);
        return true;
      } catch (error) {
        HiLog.w(TAG, `openAppPermissionSettings index=${i} failed: ${String(error)}`);
      }
    }
    HiLog.w(TAG, 'Cannot navigate to permission management-app-media player directly, skipped error fallback page');
    return false;
  }

  async requestMediaPermission(context: common.UIAbilityContext): Promise<PermissionState> {
    return this.requestSystemMediaPermission(context);
  }

  private resolvePermissionState(grantedCount: number, total: number): PermissionState {
    if (grantedCount === total) {
      return PermissionState.GRANTED;
    }
    if (grantedCount > 0) {
      return PermissionState.PARTIAL;
    }
    return PermissionState.DENIED;
  }

  private async getDeniedMediaReadPermissions(): Promise<Permissions[]> {
    const access = await this.getMediaReadAccess();
    const denied: Permissions[] = [];
    if (!access.hasAudio) {
      denied.push('ohos.permission.READ_AUDIO');
    }
    if (!access.hasImageVideo) {
      denied.push('ohos.permission.READ_IMAGEVIDEO');
    }
    return denied;
  }

  private async countGrantedPermissions(
    tokenId: number,
    permissions: Permissions[]
  ): Promise<number> {
    const atManager = abilityAccessCtrl.createAtManager();
    let grantedCount = 0;
    for (const permission of permissions) {
      const status = await atManager.checkAccessToken(tokenId, permission);
      HiLog.i(TAG, `checkAccessToken ${permission}=${status}`);
      if (status === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
        grantedCount++;
      }
    }
    return grantedCount;
  }
}
