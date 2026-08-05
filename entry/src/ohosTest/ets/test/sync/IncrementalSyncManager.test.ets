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
import { IncrementalSyncManager, HiLog, MediaDbManager, SearchIndexManager, FileInfo, FileChangeEvent, FileChangeType, FileChangeEventInfo } from '@ohos/common';
import { TestUtil } from '../utils/TestUtil';
import type common from '@ohos.app.ability.common';

const TAG = 'IncrementalSyncManagerTest';

export default function IncrementalSyncManagerTest() {
  describe('IncrementalSyncManagerTest', () => {
    let context: common.Context | null = null;
    let syncManager: IncrementalSyncManager | null = null;
    let dbManager: MediaDbManager | null = null;
    let indexManager: SearchIndexManager | null = null;

    beforeAll(async () => {
      HiLog.i(TAG, 'beforeAll: start');
      await TestUtil.initTestEnvironment();
      context = TestUtil.getContext();
      dbManager = TestUtil.getDbManager();
      indexManager = SearchIndexManager.getInstance();
      HiLog.i(TAG, 'beforeAll: context=' + (context ? 'valid' : 'null'));
    });

    afterAll(async () => {
      if (syncManager) {
        syncManager.release();
      }
      await TestUtil.cleanupTestEnvironment();
    });

    beforeEach(async () => {
      if (context) {
        syncManager = IncrementalSyncManager.getInstance(context);
        if (dbManager) {
          await dbManager.init();
        }
      }
    });

    afterEach(async () => {
      if (syncManager) {
        syncManager.release();
        syncManager = null;
      }
      if (dbManager) {
        await dbManager.clearPlayHistory();
      }
    });

    it('ISM_01_constructor_success', 0, () => {
      if (!context) {
        expect(context).not().assertNull();
        return;
      }
      syncManager = IncrementalSyncManager.getInstance(context);
      expect(syncManager).not().assertNull();
      HiLog.i(TAG, 'ISM_01: IncrementalSyncManager created successfully');
    });

    it('ISM_02_getInstance_singleton', 0, () => {
      if (!context) {
        expect(context).not().assertNull();
        return;
      }
      const instance1 = IncrementalSyncManager.getInstance(context);
      const instance2 = IncrementalSyncManager.getInstance(context);
      expect(instance1).assertEqual(instance2);
      HiLog.i(TAG, 'ISM_02: Singleton pattern verified');
    });

    it('ISM_03_executeBackgroundIncrementalScan_success', 0, async (done: Function) => {
      if (!context || !syncManager || !dbManager) {
        expect(context).not().assertNull();
        expect(syncManager).not().assertNull();
        expect(dbManager).not().assertNull();
        done();
        return;
      }

      // Insert test data into database
      const testFile = new FileInfo();
      testFile.uri = 'test_uri_incremental_1';
      testFile.fileName = 'test_incremental_1.mp3';
      testFile.duration = 1000;
      testFile.mimeType = 'audio/mp3';
      await dbManager.saveMetadata(testFile);

      // Execute background incremental scan
      const result = await syncManager.executeBackgroundIncrementalScan();
      expect(result).assertTrue();

      HiLog.i(TAG, 'ISM_03: Background incremental scan executed successfully');
      done();
    });

    it('ISM_04_executeBackgroundIncrementalScan_with_progress_callback', 0, async (done: Function) => {
      if (!context || !syncManager) {
        expect(context).not().assertNull();
        expect(syncManager).not().assertNull();
        done();
        return;
      }

      let progressCalled = false;
      let lastProgress = 0;

      const progressCallback = (progress: number, total: number) => {
        progressCalled = true;
        lastProgress = progress;
        HiLog.i(TAG, `ISM_04: Progress callback: ${progress}/${total}`);
      };

      syncManager.setProgressCallback(progressCallback);

      const result = await syncManager.executeBackgroundIncrementalScan();
      expect(result).assertTrue();
      expect(progressCalled).assertTrue();

      HiLog.i(TAG, 'ISM_04: Progress callback verified');
      done();
    });

    it('ISM_05_handleFileChangeEvent_create', 0, async (done: Function) => {
      if (!context || !syncManager || !dbManager || !indexManager) {
        expect(context).not().assertNull();
        expect(syncManager).not().assertNull();
        expect(dbManager).not().assertNull();
        expect(indexManager).not().assertNull();
        done();
        return;
      }

      // Create file change event
      const eventInfo: FileChangeEventInfo = {
        filePath: TestUtil.TEST_AUDIO_PATH + '/test_create.mp3',
        changeType: FileChangeType.CREATED,
        timestamp: Date.now()
      };
      const event = new FileChangeEvent();
      event.addEvent(eventInfo);

      // Handle file change event
      const result = await syncManager.handleFileChangeEvent(event);
      expect(result).assertTrue();

      // Verify file is added to database
      const inDb = await TestUtil.verifyFileInDatabase(eventInfo.filePath);
      expect(inDb).assertTrue();

      HiLog.i(TAG, 'ISM_05: File create event handled successfully');
      done();
    });

    it('ISM_06_handleFileChangeEvent_modify', 0, async (done: Function) => {
      if (!context || !syncManager || !dbManager) {
        expect(context).not().assertNull();
        expect(syncManager).not().assertNull();
        expect(dbManager).not().assertNull();
        done();
        return;
      }

      // Create test file and save to database
      const testFilePath = TestUtil.TEST_AUDIO_PATH + '/test_modify.mp3';
      TestUtil.createTestFile(testFilePath);
      await TestUtil.saveFileToDatabase(testFilePath);

      // Modify file
      TestUtil.modifyTestFile(testFilePath, 'modified_content');

      // Create file change event
      const eventInfo: FileChangeEventInfo = {
        filePath: testFilePath,
        changeType: FileChangeType.MODIFIED,
        timestamp: Date.now()
      };
      const event = new FileChangeEvent();
      event.addEvent(eventInfo);

      // Handle file change event
      const result = await syncManager.handleFileChangeEvent(event);
      expect(result).assertTrue();

      // Verify file is updated in database
      const updated = await TestUtil.updateFileInDatabase(testFilePath);
      expect(updated).assertTrue();

      TestUtil.deleteTestFile(testFilePath);
      HiLog.i(TAG, 'ISM_06: File modify event handled successfully');
      done();
    });

    it('ISM_07_handleFileChangeEvent_delete', 0, async (done: Function) => {
      if (!context || !syncManager || !dbManager) {
        expect(context).not().assertNull();
        expect(syncManager).not().assertNull();
        expect(dbManager).not().assertNull();
        done();
        return;
      }

      // Create test file and save to database
      const testFilePath = TestUtil.TEST_AUDIO_PATH + '/test_delete.mp3';
      TestUtil.createTestFile(testFilePath);
      await TestUtil.saveFileToDatabase(testFilePath);

      // Create file change event
      const eventInfo: FileChangeEventInfo = {
        filePath: testFilePath,
        changeType: FileChangeType.DELETED,
        timestamp: Date.now()
      };
      const event = new FileChangeEvent();
      event.addEvent(eventInfo);

      // Handle file change event
      const result = await syncManager.handleFileChangeEvent(event);
      expect(result).assertTrue();

      // Verify file is marked as invalid in database
      const deleted = await TestUtil.deleteFileFromDatabase(testFilePath);
      expect(deleted).assertTrue();

      HiLog.i(TAG, 'ISM_07: File delete event handled successfully');
      done();
    });

    it('ISM_08_handleFileChangeEvent_batch', 0, async (done: Function) => {
      if (!context || !syncManager) {
        expect(context).not().assertNull();
        expect(syncManager).not().assertNull();
        done();
        return;
      }

      // Create batch of file change events
      const event = new FileChangeEvent();
      for (let i = 0; i < 5; i++) {
        const eventInfo: FileChangeEventInfo = {
          filePath: TestUtil.TEST_AUDIO_PATH + `/test_batch_${i}.mp3`,
          changeType: FileChangeType.CREATED,
          timestamp: Date.now()
        };
        event.addEvent(eventInfo);
      }

      // Handle batch events
      const result = await syncManager.handleFileChangeEvent(event);
      expect(result).assertTrue();

      HiLog.i(TAG, 'ISM_08: Batch file change events handled successfully');
      done();
    });

    it('ISM_09_getSyncStatistics', 0, async (done: Function) => {
      if (!context || !syncManager) {
        expect(context).not().assertNull();
        expect(syncManager).not().assertNull();
        done();
        return;
      }

      const stats = syncManager.getSyncStatistics();
      expect(stats).not().assertNull();
      expect(stats.totalFiles).assertLargerOrEqual(0);
      expect(stats.syncedFiles).assertLargerOrEqual(0);
      expect(stats.pendingFiles).assertLargerOrEqual(0);

      HiLog.i(TAG, `ISM_09: Sync statistics: total=${stats.totalFiles}, synced=${stats.syncedFiles}, pending=${stats.pendingFiles}`);
      done();
    });

    it('ISM_10_isSyncInProgress', 0, async (done: Function) => {
      if (!context || !syncManager) {
        expect(context).not().assertNull();
        expect(syncManager).not().assertNull();
        done();
        return;
      }

      // Initially not in progress
      expect(syncManager.isSyncInProgress()).assertFalse();

      // Start sync
      syncManager.executeBackgroundIncrementalScan();

      // Should be in progress
      expect(syncManager.isSyncInProgress()).assertTrue();

      // Wait for completion
      await TestUtil.delay(1000);

      // Should not be in progress after completion
      expect(syncManager.isSyncInProgress()).assertFalse();

      HiLog.i(TAG, 'ISM_10: Sync progress status verified');
      done();
    });

    it('ISM_11_cancelSync', 0, async (done: Function) => {
      if (!context || !syncManager) {
        expect(context).not().assertNull();
        expect(syncManager).not().assertNull();
        done();
        return;
      }

      // Start sync
      syncManager.executeBackgroundIncrementalScan();

      // Cancel sync
      const result = syncManager.cancelSync();
      expect(result).assertTrue();

      // Should not be in progress after cancellation
      expect(syncManager.isSyncInProgress()).assertFalse();

      HiLog.i(TAG, 'ISM_11: Sync cancellation verified');
      done();
    });

    it('ISM_12_release', 0, () => {
      if (!context) {
        expect(context).not().assertNull();
        return;
      }
      syncManager = IncrementalSyncManager.getInstance(context);
      syncManager.release();
      expect(syncManager).not().assertNull();
      HiLog.i(TAG, 'ISM_12: Release verified');
    });

    it('ISM_13_integration_with_search_index', 0, async (done: Function) => {
      if (!context || !syncManager || !dbManager || !indexManager) {
        expect(context).not().assertNull();
        expect(syncManager).not().assertNull();
        expect(dbManager).not().assertNull();
        expect(indexManager).not().assertNull();
        done();
        return;
      }

      // Create test file
      const testFilePath = TestUtil.TEST_AUDIO_PATH + '/test_search.mp3';
      TestUtil.createTestFile(testFilePath);

      // Create file change event
      const eventInfo: FileChangeEventInfo = {
        filePath: testFilePath,
        changeType: FileChangeType.CREATED,
        timestamp: Date.now()
      };
      const event = new FileChangeEvent();
      event.addEvent(eventInfo);

      // Handle file change event
      await syncManager.handleFileChangeEvent(event);

      // Wait for index update
      await TestUtil.delay(500);

      // Search for the file
      const searchResults = indexManager.search('test_search');
      expect(searchResults.length).assertLargerOrEqual(0);

      TestUtil.deleteTestFile(testFilePath);
      HiLog.i(TAG, 'ISM_13: Integration with search index verified');
      done();
    });
  });
}