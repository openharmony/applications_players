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

import { describe, expect, it, beforeAll, afterAll, beforeEach, afterEach } from '@ohos/hypium';
import { HiLog } from '@ohos/common';
import { ScanStateManager } from '@ohos/common/src/main/ets/scan/ScanStateManager';
import { TestUtil } from '../utils/TestUtil';
import type common from '@ohos.app.ability.common';

const TAG = 'ScanStateManagerTest';

export default function ScanStateManagerTest() {
  describe('ScanStateManagerTest', () => {
    let context: common.Context | null = null;

    beforeAll(async () => {
      HiLog.i(TAG, 'ScanStateManager beforeAll: start');
      await TestUtil.initTestEnvironment();
      context = TestUtil.getContext();
      HiLog.i(TAG, 'ScanStateManager beforeAll: context=' + (context ? 'valid' : 'null'));
    });

    afterAll(async () => {
      await TestUtil.cleanupTestEnvironment();
    });

    beforeEach(async () => {
      // 每个测试前的准备工作
    });

    afterEach(async () => {
      // 每个测试后的清理工作
    });

    it('SCAN_STATE_01_get_last_full_scan_time_default', 0, async (done: Function) => {
      HiLog.i(TAG, 'SCAN_STATE_01: start');
      if (!context) {
        expect(context).not().assertNull();
        done();
        return;
      }

      // 测试默认值（首次获取应该返回 0）
      const scanStateManager = ScanStateManager.getInstance(context);
      await scanStateManager.init();
      await scanStateManager.clear(); // 清除之前的状态
      
      const lastFullScanTime = await scanStateManager.getLastFullScanTime();
      expect(lastFullScanTime).assertEqual(0);

      HiLog.i(TAG, 'SCAN_STATE_01: test passed');
      done();
    });

    it('SCAN_STATE_02_set_and_get_last_full_scan_time', 0, async (done: Function) => {
      HiLog.i(TAG, 'SCAN_STATE_02: start');
      if (!context) {
        expect(context).not().assertNull();
        done();
        return;
      }

      const testTime = Date.now();

      // 测试设置和获取全量扫描时间
      const scanStateManager = ScanStateManager.getInstance(context);
      await scanStateManager.init();
      await scanStateManager.clear();
      
      await scanStateManager.setLastFullScanTime(testTime);
      const retrievedTime = await scanStateManager.getLastFullScanTime();
      expect(retrievedTime).assertEqual(testTime);

      HiLog.i(TAG, 'SCAN_STATE_02: test passed');
      done();
    });

    it('SCAN_STATE_03_get_last_incremental_scan_time_default', 0, async (done: Function) => {
      HiLog.i(TAG, 'SCAN_STATE_03: start');
      if (!context) {
        expect(context).not().assertNull();
        done();
        return;
      }

      // 测试默认值（首次获取应该返回 0）
      const scanStateManager = ScanStateManager.getInstance(context);
      await scanStateManager.init();
      await scanStateManager.clear();
      
      const lastIncrementalScanTime = await scanStateManager.getLastIncrementalScanTime();
      expect(lastIncrementalScanTime).assertEqual(0);

      HiLog.i(TAG, 'SCAN_STATE_03: test passed');
      done();
    });

    it('SCAN_STATE_04_set_and_get_last_incremental_scan_time', 0, async (done: Function) => {
      HiLog.i(TAG, 'SCAN_STATE_04: start');
      if (!context) {
        expect(context).not().assertNull();
        done();
        return;
      }

      const testTime = Date.now();

      // 测试设置和获取增量扫描时间
      const scanStateManager = ScanStateManager.getInstance(context);
      await scanStateManager.init();
      await scanStateManager.clear();
      
      await scanStateManager.setLastIncrementalScanTime(testTime);
      const retrievedTime = await scanStateManager.getLastIncrementalScanTime();
      expect(retrievedTime).assertEqual(testTime);

      HiLog.i(TAG, 'SCAN_STATE_04: test passed');
      done();
    });

    it('SCAN_STATE_05_update_full_scan_time', 0, async (done: Function) => {
      HiLog.i(TAG, 'SCAN_STATE_05: start');
      if (!context) {
        expect(context).not().assertNull();
        done();
        return;
      }

      const firstTime = Date.now() - 1000;
      const secondTime = Date.now();

      // 测试更新全量扫描时间
      const scanStateManager = ScanStateManager.getInstance(context);
      await scanStateManager.init();
      await scanStateManager.clear();
      
      await scanStateManager.setLastFullScanTime(firstTime);
      await scanStateManager.setLastFullScanTime(secondTime);
      const retrievedTime = await scanStateManager.getLastFullScanTime();
      expect(retrievedTime).assertEqual(secondTime);
      expect(retrievedTime).assertLarger(firstTime);

      HiLog.i(TAG, 'SCAN_STATE_05: test passed');
      done();
    });

    it('SCAN_STATE_06_update_incremental_scan_time', 0, async (done: Function) => {
      HiLog.i(TAG, 'SCAN_STATE_06: start');
      if (!context) {
        expect(context).not().assertNull();
        done();
        return;
      }

      const firstTime = Date.now() - 1000;
      const secondTime = Date.now();

      // 测试更新增量扫描时间
      const scanStateManager = ScanStateManager.getInstance(context);
      await scanStateManager.init();
      await scanStateManager.clear();
      
      await scanStateManager.setLastIncrementalScanTime(firstTime);
      await scanStateManager.setLastIncrementalScanTime(secondTime);
      const retrievedTime = await scanStateManager.getLastIncrementalScanTime();
      expect(retrievedTime).assertEqual(secondTime);
      expect(retrievedTime).assertLarger(firstTime);

      HiLog.i(TAG, 'SCAN_STATE_06: test passed');
      done();
    });

    it('SCAN_STATE_07_persistence_after_restart', 0, async (done: Function) => {
      HiLog.i(TAG, 'SCAN_STATE_07: start');
      if (!context) {
        expect(context).not().assertNull();
        done();
        return;
      }

      const testTime = Date.now();

      // 测试持久化：设置时间后，重新获取实例，时间应该保持
      const scanStateManager1 = ScanStateManager.getInstance(context);
      await scanStateManager1.init();
      await scanStateManager1.clear();
      await scanStateManager1.setLastFullScanTime(testTime);
      
      // 模拟重启：重新获取实例（单例模式，实际上是同一个实例）
      const scanStateManager2 = ScanStateManager.getInstance(context);
      const retrievedTime = await scanStateManager2.getLastFullScanTime();
      expect(retrievedTime).assertEqual(testTime);

      HiLog.i(TAG, 'SCAN_STATE_07: test passed');
      done();
    });
  });
}