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


import { uiExtensionHost } from '@kit.ArkUI';
import type common from '@ohos.app.ability.common';

/**
 * 全局上下文持有者单例。
 * 存储各类鸿蒙系统上下文引用，供各层模块按需获取。
 */
export class AppContext {
  private static instance: AppContext | null = null;
  private commonContext: common.Context | null = null;
  private appContext: common.ApplicationContext | null = null;
  private mainAbilityContext: common.UIAbilityContext | null = null;
  private extensionContext: common.ServiceExtensionContext | null = null;
  private uiExtensionContext: common.UIExtensionContext | null = null;
  private _windowProxy: uiExtensionHost.UIExtensionHostWindowProxy | null = null;
  private _shareExtensionContext: common.ExtensionContext | null = null;
  private _abilityStageContext: common.AbilityStageContext | null = null;

  private constructor() {
  }

  public static getInstance(): AppContext {
    if (!AppContext.instance) {
      AppContext.instance = new AppContext();
    }
    return AppContext.instance;
  }

  public set abilityStageContext(value: common.AbilityStageContext | null) {
    this._abilityStageContext = value;
  }

  public get abilityStageContext(): common.AbilityStageContext | null {
    return this._abilityStageContext;
  }

  public setShareExtensionContext(value: common.ExtensionContext): void {
    this._shareExtensionContext = value;
  }

  public getShareExtensionContext(): common.ExtensionContext | null {
    return this._shareExtensionContext;
  }

  public set windowProxy(value: uiExtensionHost.UIExtensionHostWindowProxy | null) {
    this._windowProxy = value;
  }

  public get windowProxy(): uiExtensionHost.UIExtensionHostWindowProxy | null {
    return this._windowProxy;
  }

  public setCommonContext(context: common.Context): void {
    this.commonContext = context;
  }

  public getCommonContext(): common.Context | null {
    return this.commonContext;
  }

  public setAppContext(context: common.ApplicationContext): void {
    this.appContext = context;
  }

  public getAppContext(): common.ApplicationContext | null {
    return this.appContext;
  }

  public setMainAbilityContext(context: common.UIAbilityContext): void {
    this.mainAbilityContext = context;
  }

  public getMainAbilityContext(): common.UIAbilityContext | null {
    return this.mainAbilityContext;
  }

  public setExtensionContext(context: common.ServiceExtensionContext): void {
    this.extensionContext = context;
  }

  public getExtensionContext(): common.ServiceExtensionContext | null {
    return this.extensionContext;
  }

  public setUIExtensionContext(context: common.UIExtensionContext): void {
    this.uiExtensionContext = context;
  }

  public getUIExtensionContext(): common.UIExtensionContext | null {
    return this.uiExtensionContext;
  }
}
