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


import hilog from '@ohos.hilog';

const DOMAIN: number = 0x09734;
const APP_TAG: string = 'Players';

/**
 * HiLog Util（单例实例）
 *
 * standard :
 * 1. define TAG, recommend class name。
 * 2. msg should be short and valuable.
 * 3. choose appropriate function.
 * 4. the function execute many times can not print.
 * 5. uniqueness.
 */
class HiLogImpl {

  d(tag: string, msg: string, ...args: string[]): void {
    hilog.debug(DOMAIN, APP_TAG, `${tag}: ${msg}`, args);
  }

  i(tag: string, msg: string, ...args: string[]): void {
    hilog.info(DOMAIN, APP_TAG, `${tag}: ${msg}`, args);
  }

  w(tag: string, msg: string, ...args: string[]): void {
    hilog.warn(DOMAIN, APP_TAG, `${tag}: ${msg}`, args);
  }

  e(tag: string, msg: string, ...args: string[]): void {
    hilog.error(DOMAIN, APP_TAG, `${tag}: ${msg}`, args);
  }

  f(tag: string, msg: string, ...args: string[]): void {
    hilog.fatal(DOMAIN, APP_TAG, `${tag}: ${msg}`, args);
  }

}

/** HiLog 单例实例 */
export const HiLog: HiLogImpl = new HiLogImpl();
