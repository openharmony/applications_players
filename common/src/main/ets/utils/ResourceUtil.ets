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
import { BusinessError } from '@kit.BasicServicesKit';
import { HiLog } from '../utils/HiLog';
import { AppContext } from '../context/AppContext';
import { ObjectUtil } from './ObjectUtil';

const TAG = 'ResourceUtil';

/**
 * Resource 与字符串资源读取工具类
 */
export class ResourceUtil {
  private static context: common.ApplicationContext | null = null;

  /**
   * 获取 ApplicationContext，优先使用缓存，否则从 AppState 读取
   *
   * @returns ApplicationContext
   */
  public static getContext(): common.ApplicationContext {
    if (ObjectUtil.isNullOrUndefined(ResourceUtil.context)) {
      ResourceUtil.context = AppContext.getInstance().getAppContext();
    }
    if (ResourceUtil.context === null) {
      HiLog.e(TAG, 'getContext err: ApplicationContext is null');
      throw new Error('ApplicationContext is null');
    }
    return ResourceUtil.context;
  }

  /**
   * 更新缓存的 ApplicationContext
   *
   * @param context ApplicationContext
   */
  public static updateContext(context: common.ApplicationContext): void {
    ResourceUtil.context = context;
  }

  /**
   * 根据 Resource 读取字符串；带 params 时走格式化分支
   *
   * @param resource 字符串资源
   * @param context 可选 UI 上下文，不传则用 ApplicationContext
   * @returns 字符串，失败返回空串
   */
  public static getStringByResource(resource: Resource, context?: common.Context): string {
    if (!resource) {
      HiLog.e(TAG, 'getStringByResource err: resource is undefined or null');
      return '';
    }
    if (resource.params && (resource.params.length > 0)) {
      return ResourceUtil.getFormatStringByResource(resource, context);
    }
    try {
      if (!context) {
        return ResourceUtil.getContext().resourceManager.getStringSync(resource.id);
      } else {
        return context.resourceManager.getStringSync(resource.id);
      }
    } catch (err) {
      const message = (err as BusinessError).message;
      HiLog.e(TAG, `getStringByResource err: ${message}`);
    }
    return '';
  }

  /**
   * 根据资源 id 读取 number 类型资源
   *
   * @param resourceId 资源 id
   * @returns 数值，失败返回 0
   */
  public static getResourceNumberById(resourceId: number): number {
    try {
      return ResourceUtil.getContext().resourceManager.getNumber(resourceId);
    } catch (e) {
      const error = e as BusinessError;
      HiLog.e(TAG, `getResourceNumberById error code=${error.code} message=${error.message}`);
      return 0;
    }
  }

  /**
   * 读取带占位参数的格式化字符串
   *
   * @param resource 字符串资源（含 params）
   * @param context 可选上下文
   * @returns 格式化字符串
   */
  private static getFormatStringByResource(resource: Resource, context?: common.Context): string {
    try {
      const rm = context ? context.resourceManager : ResourceUtil.getContext().resourceManager;
      const params = resource.params as (string | number)[];
      if (params.length === 1) {
        return rm.getStringSync(resource.id, params[0]);
      }
      if (params.length === 2) {
        return rm.getStringSync(resource.id, params[0], params[1]);
      }
      if (params.length === 3) {
        return rm.getStringSync(resource.id, params[0], params[1], params[2]);
      }
      if (params.length > 3) {
        HiLog.w(TAG, `getFormatStringByResource unsupported param count=${params.length}`);
      }
      return rm.getStringSync(resource.id);
    } catch (err) {
      const message = (err as BusinessError).message;
      HiLog.e(TAG, `getFormatStringByResource err: ${message}`);
    }
    return '';
  }

  /**
   * 根据 Resource 读取颜色值
   *
   * @param resource 颜色资源
   * @param context 可选上下文
   * @returns 颜色数值，失败返回 0
   */
  public static getColorByResource(resource: Resource, context?: common.Context): number {
    try {
      if (!context) {
        return ResourceUtil.getContext().resourceManager.getColorSync(resource.id);
      } else {
        return context.resourceManager.getColorSync(resource.id);
      }
    } catch (err) {
      const error = err as BusinessError;
      HiLog.e(TAG, `getColorByResource err: ${error.message}`);
    }
    return 0;
  }

  /**
   * 单参数格式化字符串
   *
   * @param resource 字符串资源
   * @param param 占位参数
   * @returns 格式化字符串
   */
  public static getStringByOneParamResource(resource: Resource, param: string | number): string {
    try {
      return ResourceUtil.getContext().resourceManager.getStringSync(resource.id, param);
    } catch (err) {
      const message = (err as BusinessError).message;
      HiLog.e(TAG, `getStringByOneParamResource err: ${message}`);
    }
    return '';
  }

  /**
   * 双参数格式化字符串
   *
   * @param resource 字符串资源
   * @param param1 第一个占位参数
   * @param param2 第二个占位参数
   * @returns 格式化字符串
   */
  public static getStringByDoubleParamResource(resource: Resource, param1: string, param2: string): string {
    try {
      return ResourceUtil.getContext().resourceManager.getStringSync(resource.id, param1, param2);
    } catch (err) {
      const message = (err as BusinessError).message;
      HiLog.e(TAG, `getStringByDoubleParamResource err: ${message}`);
    }
    return '';
  }

  /**
   * 三参数格式化字符串
   *
   * @param resource 字符串资源
   * @param param1 第一个占位参数
   * @param param2 第二个占位参数
   * @param param3 第三个占位参数
   * @returns 格式化字符串
   */
  public static getStringByThreeParamResource(resource: Resource, param1: string, param2: string,
    param3: string): string {
    try {
      return ResourceUtil.getContext().resourceManager.getStringSync(resource.id, param1, param2, param3);
    } catch (err) {
      const message = (err as BusinessError).message;
      HiLog.e(TAG, `getStringByThreeParamResource err: ${message}`);
    }
    return '';
  }

  /**
   * 异步读取复数字符串
   *
   * @param resource 字符串资源
   * @param param 数量参数
   * @returns 复数字符串
   */
  public static async getStringByPluralParamResource(resource: Resource, param: number): Promise<string> {
    try {
      return await ResourceUtil.getContext().resourceManager.getPluralStringValue(resource.id, param);
    } catch (err) {
      const message = (err as BusinessError).message;
      HiLog.e(TAG, `getStringByPluralParamResource err: ${message}`);
    }
    return '';
  }

  /**
   * 同步读取复数字符串
   *
   * @param resource 字符串资源
   * @param param 数量参数
   * @returns 复数字符串
   */
  public static getStringByPluralParamResourceSync(resource: Resource, param: number): string {
    try {
      return ResourceUtil.getContext().resourceManager.getPluralStringValueSync(resource.id, param);
    } catch (err) {
      const message = (err as BusinessError).message;
      HiLog.e(TAG, `getStringByPluralParamResourceSync err: ${message}`);
    }
    return '';
  }

  /**
   * Resource 或 plain string 统一转成字符串
   *
   * @param item Resource 或字符串
   * @returns 字符串
   */
  public static getStringByResourceOrString(item: Resource | string): string {
    if (typeof item === 'string') {
      return item;
    }
    return ResourceUtil.getStringByResource(item);
  }

  /**
   * 通过资源名称获取字符串
   *
   * @param name 资源名称
   * @param context 可选 UIAbility 上下文
   * @returns 字符串
   */
  public static getStringByName(name: string, context?: common.UIAbilityContext): string {
    let result = '';
    try {
      if (!context) {
        result = ResourceUtil.getContext().resourceManager.getStringByNameSync(name);
      } else {
        result = context.resourceManager.getStringByNameSync(name);
      }
    } catch (err) {
      HiLog.e(TAG, `getStringByName error: ${String(err)}`);
    }
    return result;
  }

  /**
   * 将 Resource 转成复数字符串（支持额外格式化参数）
   *
   * @param resource 字符串资源
   * @param num 数量
   * @param args 额外格式化参数
   * @returns 复数字符串
   */
  public static getPluralStringValue(resource: Resource, num: number, ...args: (string | number)[]): string {
    try {
      const resourceManager = ResourceUtil.getContext().resourceManager;
      if (args.length === 0) {
        return resourceManager.getIntPluralStringValueSync(resource.id, num);
      }
      if (args.length === 1) {
        return resourceManager.getIntPluralStringValueSync(resource.id, num, args[0]);
      }
      if (args.length === 2) {
        return resourceManager.getIntPluralStringValueSync(resource.id, num, args[0], args[1]);
      }
      if (args.length === 3) {
        return resourceManager.getIntPluralStringValueSync(resource.id, num, args[0], args[1], args[2]);
      }
      HiLog.w(TAG, `getPluralStringValue unsupported args length=${args.length}`);
      return resourceManager.getIntPluralStringValueSync(resource.id, num);
    } catch (error) {
      const err = error as BusinessError;
      HiLog.e(TAG, `getPluralStringValue fail code=${err.code} message=${err.message}`);
    }
    return '';
  }
}
