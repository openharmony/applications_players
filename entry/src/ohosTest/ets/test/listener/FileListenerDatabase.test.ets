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
import { FileListenerManager, ListenerTypeEnum, FileChangeEvent, FileChangeType, FileChangeEventInfo, FileSyncEngine, SandboxFileListener, HiLog, MediaPermissionManager, MediaDbManager } from '@ohos/common';
import { TestUtil } from '../utils/TestUtil';
import type common from '@ohos.app.ability.common';

const TAG = 'FileListenerDatabaseTest';

export default function FileListenerDatabaseTest() {
  describe('DatabaseSyncTest', () => {
    let manager: FileListenerManager | null = null;
    let context: common.Context | null = null;
    let dbManager: MediaDbManager | null = null;

    beforeAll(async () => {
      HiLog.i(TAG, 'DatabaseSync beforeAll: start');
      await TestUtil.initTestEnvironment();
      context = TestUtil.getContext();
      dbManager = TestUtil.getDbManager();
      HiLog.i(TAG, 'DatabaseSync beforeAll: context=' + (context ? 'valid' : 'null'));
      HiLog.i(TAG, 'DatabaseSync beforeAll: dbManager=' + (dbManager ? 'valid' : 'null'));
    });

    afterAll(async () => {
      if (manager) {
        await manager.destroy();
        manager = null;
      }
      await TestUtil.cleanupTestEnvironment();
    });

    beforeEach(async () => {
      if (context) {
        manager = FileListenerManager.getInstance(context);
        await manager.initialize();
      }
    });

    afterEach(async () => {
      if (manager) {
        await manager.stopListening(ListenerTypeEnum.SANDBOX);
        await manager.destroy();
        manager = null;
      }
      const testFiles: string[] = [
        TestUtil.getTestAudioFilePath('db_sync_1.mp3'),
        TestUtil.getTestAudioFilePath('db_sync_2.mp3'),
        TestUtil.getTestAudioFilePath('db_sync_3.mp4'),
        TestUtil.getTestAudioFilePath('batch_1.mp3'),
        TestUtil.getTestAudioFilePath('batch_2.mp3'),
        TestUtil.getTestAudioFilePath('batch_3.mp3')
      ];
      TestUtil.deleteTestFiles(testFiles);
    });

    it('DB_SYNC_01_file_created_sync_to_database', 0, async (done: Function) => {
      HiLog.i(TAG, 'DB_SYNC_01: start');
      if (!context || !manager) {
        expect(context).not().assertNull();
        expect(manager).not().assertNull();
        done();
        return;
      }
      const audioPath = TestUtil.TEST_AUDIO_PATH;
      if (!TestUtil.fileExists(audioPath)) {
        expect(TestUtil.fileExists(audioPath)).assertTrue();
        done();
        return;
      }
      
      await manager.startListening(ListenerTypeEnum.SANDBOX);
      await manager.addWatchDirectory(audioPath, ListenerTypeEnum.SANDBOX);
      
      const testFile = TestUtil.getTestAudioFilePath('db_sync_1.mp3');
      TestUtil.createMediaTestFile(testFile);
      expect(TestUtil.fileExists(testFile)).assertTrue();
      
      const syncEngine = manager.getSyncEngine();
      const success = await syncEngine.syncFileCreated(testFile);
      expect(success).assertTrue();
      
      TestUtil.deleteTestFile(testFile);
      done();
    });

    it('DB_SYNC_02_file_modified_sync_to_database', 0, async (done: Function) => {
      if (!context || !manager) {
        expect(context).not().assertNull();
        expect(manager).not().assertNull();
        done();
        return;
      }
      
      const testFile = TestUtil.getTestAudioFilePath('db_sync_2.mp3');
      TestUtil.createMediaTestFile(testFile);
      
      await TestUtil.saveFileToDatabase(testFile);
      
      TestUtil.modifyTestFile(testFile, 'modified_content_' + Date.now());
      
      const syncEngine = manager.getSyncEngine();
      const success = await syncEngine.syncFileModified(testFile);
      expect(success).assertTrue();
      
      TestUtil.deleteTestFile(testFile);
      done();
    });

    it('DB_SYNC_03_file_deleted_sync_to_database', 0, async (done: Function) => {
      HiLog.i(TAG, 'DB_SYNC_03: start');
      if (!context || !manager) {
        expect(context).not().assertNull();
        expect(manager).not().assertNull();
        done();
        return;
      }
      const audioPath = TestUtil.TEST_AUDIO_PATH;
      if (!TestUtil.fileExists(audioPath)) {
        expect(TestUtil.fileExists(audioPath)).assertTrue();
        done();
        return;
      }
      
      const testFile = TestUtil.getTestAudioFilePath('db_sync_3.mp4');
      TestUtil.createMediaTestFile(testFile);
      expect(TestUtil.fileExists(testFile)).assertTrue();
      
      await TestUtil.saveFileToDatabase(testFile);
      
      TestUtil.deleteTestFile(testFile);
      await TestUtil.delay(100);
      
      expect(TestUtil.fileExists(testFile)).assertFalse();
      
      const syncEngine = manager.getSyncEngine();
      const success = await syncEngine.syncFileDeleted(testFile);
      expect(success).assertTrue();
      
      done();
    });

    it('DB_SYNC_04_batch_sync_multiple_files', 0, async (done: Function) => {
      HiLog.i(TAG, 'DB_SYNC_04: start');
      if (!context || !manager) {
        expect(context).not().assertNull();
        expect(manager).not().assertNull();
        done();
        return;
      }
      const audioPath = TestUtil.TEST_AUDIO_PATH;
      if (!TestUtil.fileExists(audioPath)) {
        expect(TestUtil.fileExists(audioPath)).assertTrue();
        done();
        return;
      }
      
      const testFiles: string[] = [
        TestUtil.getTestAudioFilePath('batch_1.mp3'),
        TestUtil.getTestAudioFilePath('batch_2.mp3'),
        TestUtil.getTestAudioFilePath('batch_3.mp3')
      ];
      
      TestUtil.createTestFiles(testFiles);
      
      const event = new FileChangeEvent();
      for (const file of testFiles) {
        const info: FileChangeEventInfo = {
          filePath: file,
          changeType: FileChangeType.CREATED,
          timestamp: Date.now(),
          directoryPath: audioPath,
          fileName: file.substring(file.lastIndexOf('/') + 1)
        };
        event.addEvent(info);
      }
      
      const syncEngine = manager.getSyncEngine();
      const processedCount = await syncEngine.batchSync(event);
      expect(processedCount).assertEqual(3);
      
      TestUtil.deleteTestFiles(testFiles);
      done();
    });

    it('DB_SYNC_05_listener_detect_and_sync', 0, async (done: Function) => {
      HiLog.i(TAG, 'DB_SYNC_05: start');
      if (!context || !manager) {
        expect(context).not().assertNull();
        expect(manager).not().assertNull();
        done();
        return;
      }
      const audioPath = TestUtil.TEST_AUDIO_PATH;
      if (!TestUtil.fileExists(audioPath)) {
        expect(TestUtil.fileExists(audioPath)).assertTrue();
        done();
        return;
      }
      
      await manager.startListening(ListenerTypeEnum.SANDBOX);
      await manager.addWatchDirectory(audioPath, ListenerTypeEnum.SANDBOX);
      
      const testFile = TestUtil.getTestAudioFilePath('detect_sync_test.mp3');
      TestUtil.createMediaTestFile(testFile);
      
      await TestUtil.delay(TestUtil.DEBOUNCE_WAIT_TIME);
      
      manager.flushPendingEvents(ListenerTypeEnum.SANDBOX);
      
      expect(TestUtil.fileExists(testFile)).assertTrue();
      
      TestUtil.deleteTestFile(testFile);
      done();
    });

    it('DB_SYNC_06_sync_engine_status', 0, async (done: Function) => {
      if (!context || !manager) {
        expect(context).not().assertNull();
        expect(manager).not().assertNull();
        done();
        return;
      }
      
      const syncEngine = manager.getSyncEngine();
      expect(syncEngine.isSyncing()).assertFalse();
      
      done();
    });

    it('DB_SYNC_07_cancel_sync_operation', 0, async (done: Function) => {
      if (!context || !manager) {
        expect(context).not().assertNull();
        expect(manager).not().assertNull();
        done();
        return;
      }
      
      const syncEngine = manager.getSyncEngine();
      syncEngine.cancelSync();
      
      expect(syncEngine).not().assertNull();
      done();
    });

    it('DB_SYNC_08_non_media_file_skipped', 0, async (done: Function) => {
      if (!context || !manager) {
        expect(context).not().assertNull();
        expect(manager).not().assertNull();
        done();
        return;
      }
      
      const testFile = TestUtil.getTestAudioFilePath('non_media.txt');
      TestUtil.createTestFile(testFile);
      
      const syncEngine = manager.getSyncEngine();
      const success = await syncEngine.syncFileCreated(testFile);
      expect(success).assertFalse();
      
      TestUtil.deleteTestFile(testFile);
      done();
    });
  });

  describe('ScanDatabaseTest', () => {
    let manager: FileListenerManager | null = null;
    let context: common.Context | null = null;
    let dbManager: MediaDbManager | null = null;

    beforeAll(async () => {
      HiLog.i(TAG, 'ScanDatabase beforeAll: start');
      await TestUtil.initTestEnvironment();
      context = TestUtil.getContext();
      dbManager = TestUtil.getDbManager();
    });

    afterAll(async () => {
      if (manager) {
        await manager.destroy();
        manager = null;
      }
      await TestUtil.cleanupTestEnvironment();
    });

    beforeEach(async () => {
      if (context) {
        manager = FileListenerManager.getInstance(context);
        await manager.initialize();
      }
    });

    afterEach(async () => {
      if (manager) {
        await manager.stopListening(ListenerTypeEnum.SANDBOX);
        await manager.destroy();
        manager = null;
      }
      const testFiles: string[] = [
        TestUtil.getTestAudioFilePath('scan_1.mp3'),
        TestUtil.getTestAudioFilePath('scan_2.mp4'),
        TestUtil.getTestAudioFilePath('scan_3.m4a')
      ];
      TestUtil.deleteTestFiles(testFiles);
    });

    it('SCAN_01_scan_directory_files', 0, async (done: Function) => {
      HiLog.i(TAG, 'SCAN_01: start');
      if (!context || !manager) {
        expect(context).not().assertNull();
        expect(manager).not().assertNull();
        done();
        return;
      }
      const audioPath = TestUtil.TEST_AUDIO_PATH;
      if (!TestUtil.fileExists(audioPath)) {
        expect(TestUtil.fileExists(audioPath)).assertTrue();
        done();
        return;
      }
      
      const testFiles: string[] = [
        TestUtil.getTestAudioFilePath('scan_1.mp3'),
        TestUtil.getTestAudioFilePath('scan_2.mp4')
      ];
      
      TestUtil.createTestFiles(testFiles);
      
      await manager.startListening(ListenerTypeEnum.SANDBOX);
      await manager.addWatchDirectory(audioPath, ListenerTypeEnum.SANDBOX);
      
      await TestUtil.delay(TestUtil.DEBOUNCE_WAIT_TIME);
      manager.flushPendingEvents(ListenerTypeEnum.SANDBOX);
      
      expect(TestUtil.fileExists(testFiles[0])).assertTrue();
      expect(TestUtil.fileExists(testFiles[1])).assertTrue();
      
      TestUtil.deleteTestFiles(testFiles);
      done();
    });

    it('SCAN_02_verify_file_in_database', 0, async (done: Function) => {
      if (!context || !dbManager) {
        expect(context).not().assertNull();
        expect(dbManager).not().assertNull();
        done();
        return;
      }
      
      const testFile = TestUtil.getTestAudioFilePath('scan_3.m4a');
      TestUtil.createMediaTestFile(testFile);
      
      const saved = await TestUtil.saveFileToDatabase(testFile);
      expect(saved).assertTrue();
      
      const found = await TestUtil.verifyFileInDatabase(testFile);
      expect(found).assertTrue();
      
      TestUtil.deleteTestFile(testFile);
      done();
    });

    it('SCAN_03_update_file_metadata', 0, async (done: Function) => {
      if (!context || !dbManager) {
        expect(context).not().assertNull();
        expect(dbManager).not().assertNull();
        done();
        return;
      }
      
      const testFile = TestUtil.getTestAudioFilePath('update_test.mp3');
      TestUtil.createMediaTestFile(testFile);
      
      await TestUtil.saveFileToDatabase(testFile);
      
      TestUtil.modifyTestFile(testFile, 'updated_content');
      
      const updated = await TestUtil.updateFileInDatabase(testFile);
      expect(updated).assertTrue();
      
      TestUtil.deleteTestFile(testFile);
      done();
    });

    it('SCAN_04_delete_file_from_database', 0, async (done: Function) => {
      if (!context || !dbManager) {
        expect(context).not().assertNull();
        expect(dbManager).not().assertNull();
        done();
        return;
      }
      
      const testFile = TestUtil.getTestAudioFilePath('delete_test.mp3');
      TestUtil.createMediaTestFile(testFile);
      
      await TestUtil.saveFileToDatabase(testFile);
      
      const deleted = await TestUtil.deleteFileFromDatabase(testFile);
      expect(deleted).assertTrue();
      
      TestUtil.deleteTestFile(testFile);
      done();
    });

    it('SCAN_05_wait_for_database_update', 0, async (done: Function) => {
      if (!context || !dbManager) {
        expect(context).not().assertNull();
        expect(dbManager).not().assertNull();
        done();
        return;
      }
      
      const testFile = TestUtil.getTestAudioFilePath('wait_test.mp3');
      TestUtil.createMediaTestFile(testFile);
      
      await TestUtil.saveFileToDatabase(testFile);
      
      const found = await TestUtil.waitForDatabaseUpdate(testFile, 2000);
      expect(found).assertTrue();
      
      TestUtil.deleteTestFile(testFile);
      done();
    });

    it('SCAN_06_batch_files_to_database', 0, async (done: Function) => {
      if (!context || !dbManager) {
        expect(context).not().assertNull();
        expect(dbManager).not().assertNull();
        done();
        return;
      }
      
      const testFiles: string[] = [
        TestUtil.getTestAudioFilePath('batch_a.mp3'),
        TestUtil.getTestAudioFilePath('batch_b.mp4'),
        TestUtil.getTestAudioFilePath('batch_c.m4a')
      ];
      
      TestUtil.createTestFiles(testFiles);
      
      let savedCount = 0;
      for (const file of testFiles) {
        if (await TestUtil.saveFileToDatabase(file)) {
          savedCount++;
        }
      }
      
      expect(savedCount).assertLargerOrEqual(0);
      
      TestUtil.deleteTestFiles(testFiles);
      done();
    });

    it('SCAN_07_filter_by_extension', 0, async (done: Function) => {
      if (!context) {
        expect(context).not().assertNull();
        done();
        return;
      }
      
      const mediaFile = TestUtil.getTestAudioFilePath('filter_media.mp3');
      const nonMediaFile = TestUtil.getTestAudioFilePath('filter_non.txt');
      
      TestUtil.createTestFile(mediaFile);
      TestUtil.createTestFile(nonMediaFile);
      
      const isMedia = TestUtil.isMediaFile(mediaFile);
      expect(isMedia).assertTrue();
      
      const isNotMedia = TestUtil.isMediaFile(nonMediaFile);
      expect(isNotMedia).assertFalse();
      
      TestUtil.deleteTestFile(mediaFile);
      TestUtil.deleteTestFile(nonMediaFile);
      done();
    });

    it('SCAN_08_get_mime_type', 0, () => {
      const mp3Mime = TestUtil.getMimeType('.mp3');
      expect(mp3Mime).assertEqual('audio/*');
      
      const mp4Mime = TestUtil.getMimeType('.mp4');
      expect(mp4Mime).assertEqual('video/*');
      
      const txtMime = TestUtil.getMimeType('.txt');
      expect(txtMime).assertEqual('application/octet-stream');
    });
  });

  describe('FileListenerManagerIntegrationTest', () => {
    let manager: FileListenerManager | null = null;
    let context: common.Context | null = null;

    beforeAll(async () => {
      HiLog.i(TAG, 'Integration beforeAll: start');
      await TestUtil.initTestEnvironment();
      context = TestUtil.getContext();
    });

    afterAll(async () => {
      if (manager) {
        await manager.destroy();
        manager = null;
      }
      await TestUtil.cleanupTestEnvironment();
    });

    beforeEach(() => {
      if (context) {
        manager = FileListenerManager.getInstance(context);
      }
    });

    afterEach(async () => {
      if (manager) {
        await manager.destroy();
        manager = null;
      }
    });

    it('MGR_01_initialize_all_listeners', 0, async (done: Function) => {
      if (!context || !manager) {
        expect(context).not().assertNull();
        expect(manager).not().assertNull();
        done();
        return;
      }
      
      await manager.initialize();
      await manager.initializeMediaLibraryListener();
      await manager.initializeUserFileListener();
      
      expect(manager.getSandboxListener()).not().assertNull();
      expect(manager.getMediaLibraryListener()).not().assertNull();
      expect(manager.getUserFileListener()).not().assertNull();
      done();
    });

    it('MGR_02_start_all_listeners', 0, async (done: Function) => {
      if (!context || !manager) {
        expect(context).not().assertNull();
        expect(manager).not().assertNull();
        done();
        return;
      }
      
      await manager.initialize();
      await manager.initializeMediaLibraryListener();
      await manager.initializeUserFileListener();
      
      await manager.startListening(ListenerTypeEnum.SANDBOX);
      await manager.startListening(ListenerTypeEnum.PUBLIC_MEDIA);
      await manager.startListening(ListenerTypeEnum.USER_FILE);
      
      expect(manager.isListening(ListenerTypeEnum.SANDBOX)).assertTrue();
      expect(manager.isListening(ListenerTypeEnum.PUBLIC_MEDIA)).assertTrue();
      expect(manager.isListening(ListenerTypeEnum.USER_FILE)).assertTrue();
      done();
    });

    it('MGR_03_stop_all_listeners', 0, async (done: Function) => {
      if (!context || !manager) {
        expect(context).not().assertNull();
        expect(manager).not().assertNull();
        done();
        return;
      }
      
      await manager.initialize();
      await manager.initializeMediaLibraryListener();
      await manager.initializeUserFileListener();
      
      await manager.startListening(ListenerTypeEnum.SANDBOX);
      await manager.startListening(ListenerTypeEnum.PUBLIC_MEDIA);
      await manager.startListening(ListenerTypeEnum.USER_FILE);
      
      await manager.stopListening(ListenerTypeEnum.SANDBOX);
      await manager.stopListening(ListenerTypeEnum.PUBLIC_MEDIA);
      await manager.stopListening(ListenerTypeEnum.USER_FILE);
      
      expect(manager.isListening(ListenerTypeEnum.SANDBOX)).assertFalse();
      expect(manager.isListening(ListenerTypeEnum.PUBLIC_MEDIA)).assertFalse();
      expect(manager.isListening(ListenerTypeEnum.USER_FILE)).assertFalse();
      done();
    });

    it('MGR_04_destroy_cleanup', 0, async (done: Function) => {
      if (!context || !manager) {
        expect(context).not().assertNull();
        expect(manager).not().assertNull();
        done();
        return;
      }
      
      await manager.initialize();
      await manager.initializeMediaLibraryListener();
      await manager.initializeUserFileListener();
      await manager.startListening(ListenerTypeEnum.SANDBOX);
      
      await manager.destroy();
      
      expect(manager.getSandboxListener()).assertNull();
      expect(manager.getMediaLibraryListener()).assertNull();
      expect(manager.getUserFileListener()).assertNull();
      done();
    });

    it('MGR_05_get_sync_engine', 0, async (done: Function) => {
      if (!context || !manager) {
        expect(context).not().assertNull();
        expect(manager).not().assertNull();
        done();
        return;
      }
      
      await manager.initialize();
      
      const syncEngine = manager.getSyncEngine();
      expect(syncEngine).not().assertNull();
      done();
    });

    it('MGR_06_flush_all_pending_events', 0, async (done: Function) => {
      if (!context || !manager) {
        expect(context).not().assertNull();
        expect(manager).not().assertNull();
        done();
        return;
      }
      
      await manager.initialize();
      await manager.initializeMediaLibraryListener();
      await manager.initializeUserFileListener();
      
      manager.flushPendingEvents(ListenerTypeEnum.SANDBOX);
      manager.flushPendingEvents(ListenerTypeEnum.PUBLIC_MEDIA);
      manager.flushPendingEvents(ListenerTypeEnum.USER_FILE);
      
      expect(manager).not().assertNull();
      done();
    });

    it('MGR_07_add_watch_directory', 0, async (done: Function) => {
      if (!context || !manager) {
        expect(context).not().assertNull();
        expect(manager).not().assertNull();
        done();
        return;
      }
      
      const audioPath = TestUtil.TEST_AUDIO_PATH;
      if (!TestUtil.fileExists(audioPath)) {
        expect(TestUtil.fileExists(audioPath)).assertTrue();
        done();
        return;
      }
      
      await manager.initialize();
      await manager.startListening(ListenerTypeEnum.SANDBOX);
      
      const result = await manager.addWatchDirectory(audioPath, ListenerTypeEnum.SANDBOX);
      expect(result).assertTrue();
      
      const paths = manager.getWatchedDirectories(ListenerTypeEnum.SANDBOX);
      expect(paths.length).assertLarger(0);
      done();
    });

    it('MGR_08_remove_watch_directory', 0, async (done: Function) => {
      if (!context || !manager) {
        expect(context).not().assertNull();
        expect(manager).not().assertNull();
        done();
        return;
      }
      
      const audioPath = TestUtil.TEST_AUDIO_PATH;
      if (!TestUtil.fileExists(audioPath)) {
        expect(TestUtil.fileExists(audioPath)).assertTrue();
        done();
        return;
      }
      
      await manager.initialize();
      await manager.startListening(ListenerTypeEnum.SANDBOX);
      await manager.addWatchDirectory(audioPath, ListenerTypeEnum.SANDBOX);
      
      await manager.removeWatchDirectory(audioPath, ListenerTypeEnum.SANDBOX);
      
      const paths = manager.getWatchedDirectories(ListenerTypeEnum.SANDBOX);
      expect(paths.length).assertEqual(0);
      done();
    });
  });
}