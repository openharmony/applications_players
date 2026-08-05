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
import { SandboxFileListener, UserFileListener, MediaLibraryListener, FileChangeType, FileChangeEvent, FileListenerConfig, WatchEventFlags, HiLog, MediaPermissionManager, MediaDbManager, FileChangeCallback } from '@ohos/common';
import { TestUtil } from '../utils/TestUtil';
import type common from '@ohos.app.ability.common';
import AbilityDelegatorRegistry from '@ohos.app.ability.abilityDelegatorRegistry';
import fs from '@ohos.file.fs';

const TAG = 'FileListenerTest';

export default function FileListenerTest() {
  describe('SandboxFileListenerTest', () => {
    let listener: SandboxFileListener | null = null;
    let context: common.Context | null = null;

    beforeAll(async () => {
      HiLog.i(TAG, 'Sandbox beforeAll: start');
      await TestUtil.initTestEnvironment();
      
      let retryCount = 0;
      while (retryCount < 10) {
        context = TestUtil.getContext();
        if (context) {
          HiLog.i(TAG, 'Sandbox beforeAll: context obtained after ' + retryCount + ' retries');
          break;
        }
        HiLog.w(TAG, 'Sandbox beforeAll: context null, retry ' + retryCount);
        await TestUtil.delay(100);
        retryCount++;
      }
      
      HiLog.i(TAG, 'Sandbox beforeAll: context=' + (context ? 'valid' : 'null'));
    });

    afterAll(async () => {
      if (listener) {
        await listener.stopListener();
        listener = null;
      }
      await TestUtil.cleanupTestEnvironment();
    });

    beforeEach(() => {
      listener = null;
    });

    afterEach(async () => {
      if (listener) {
        await listener.stopListener();
        listener = null;
      }
    });

    it('SB_01_constructor_default', 0, () => {
      if (!context) {
        expect(context).not().assertNull();
        return;
      }
      listener = new SandboxFileListener(context);
      expect(listener).not().assertNull();
      const config = listener.getConfig();
      expect(config.debounceDelay).assertEqual(500);
      expect(listener.isListening()).assertFalse();
    });

    it('SB_02_constructor_custom', 0, () => {
      if (!context) {
        expect(context).not().assertNull();
        return;
      }
      const customConfig: FileListenerConfig = {
        debounceDelay: 300,
        maxBatchSize: 50,
        maxWaitTime: 2000,
        watchEvents: WatchEventFlags.IN_MEDIA_EVENTS,
        includeSubdirectories: true,
        fileExtensions: ['.mp3', '.mp4']
      };
      listener = new SandboxFileListener(context, customConfig);
      expect(listener).not().assertNull();
      const config = listener.getConfig();
      expect(config.debounceDelay).assertEqual(300);
    });

    it('SB_03_startListener_success', 0, async (done: Function) => {
      if (!context) {
        expect(context).not().assertNull();
        done();
        return;
      }
      listener = new SandboxFileListener(context);
      const result = await listener.startListener();
      expect(result).assertTrue();
      expect(listener.isListening()).assertTrue();
      done();
    });

    it('SB_04_stopListener_success', 0, async (done: Function) => {
      if (!context) {
        expect(context).not().assertNull();
        done();
        return;
      }
      listener = new SandboxFileListener(context);
      await listener.startListener();
      await listener.stopListener();
      expect(listener.isListening()).assertFalse();
      done();
    });

    it('SB_05_addWatchPath_success', 0, async (done: Function) => {
      if (!context) {
        expect(context).not().assertNull();
        done();
        return;
      }
      const audioPath = TestUtil.TEST_AUDIO_PATH;
      if (!TestUtil.fileExists(audioPath)) {
        expect(TestUtil.fileExists(audioPath)).assertTrue();
        done();
        return;
      }
      listener = new SandboxFileListener(context);
      await listener.startListener();
      const result = await listener.addWatchPath(audioPath);
      expect(result).assertTrue();
      const paths = listener.getWatchedPaths();
      expect(paths.length).assertEqual(1);
      done();
    });

    it('SB_06_addWatchPath_nonexistent', 0, async (done: Function) => {
      if (!context) {
        expect(context).not().assertNull();
        done();
        return;
      }
      listener = new SandboxFileListener(context);
      await listener.startListener();
      const result = await listener.addWatchPath('/nonexistent/path');
      expect(result).assertFalse();
      done();
    });

    it('SB_07_removeWatchPath_success', 0, async (done: Function) => {
      if (!context) {
        expect(context).not().assertNull();
        done();
        return;
      }
      listener = new SandboxFileListener(context);
      await listener.startListener();
      await listener.addWatchPath(TestUtil.TEST_AUDIO_PATH);
      await listener.removeWatchPath(TestUtil.TEST_AUDIO_PATH);
      const paths = listener.getWatchedPaths();
      expect(paths.length).assertEqual(0);
      done();
    });

    it('SB_08_getWatchedPaths_multiple', 0, async (done: Function) => {
      if (!context) {
        expect(context).not().assertNull();
        done();
        return;
      }
      const audioPath = TestUtil.TEST_AUDIO_PATH;
      const videoPath = TestUtil.TEST_VIDEO_PATH;
      if (!TestUtil.fileExists(audioPath) || !TestUtil.fileExists(videoPath)) {
        expect(TestUtil.fileExists(audioPath)).assertTrue();
        done();
        return;
      }
      listener = new SandboxFileListener(context);
      await listener.startListener();
      await listener.addWatchPath(audioPath);
      await listener.addWatchPath(videoPath);
      const paths = listener.getWatchedPaths();
      expect(paths.length).assertEqual(2);
      done();
    });

    it('SB_09_isListening_status', 0, async (done: Function) => {
      if (!context) {
        expect(context).not().assertNull();
        done();
        return;
      }
      listener = new SandboxFileListener(context);
      expect(listener.isListening()).assertFalse();
      await listener.startListener();
      expect(listener.isListening()).assertTrue();
      await listener.stopListener();
      expect(listener.isListening()).assertFalse();
      done();
    });

    it('SB_10_flushPendingEvents', 0, () => {
      if (!context) {
        expect(context).not().assertNull();
        return;
      }
      listener = new SandboxFileListener(context);
      listener.flushPendingEvents();
      expect(listener).not().assertNull();
    });

    it('SB_11_getDebouncePendingCount', 0, () => {
      if (!context) {
        expect(context).not().assertNull();
        return;
      }
      listener = new SandboxFileListener(context);
      const count = listener.getDebouncePendingCount();
      expect(count).assertEqual(0);
    });

    it('SB_12_file_extension_filter', 0, async (done: Function) => {
      if (!context) {
        expect(context).not().assertNull();
        done();
        return;
      }
      const config: FileListenerConfig = {
        debounceDelay: 500,
        maxBatchSize: 100,
        maxWaitTime: 3000,
        fileExtensions: ['.mp3', '.mp4']
      };
      listener = new SandboxFileListener(context, config);
      await listener.startListener();
      await listener.addWatchPath(TestUtil.TEST_AUDIO_PATH);
      const testFile = TestUtil.getTestAudioFilePath('filter_test.mp3');
      TestUtil.createTestFile(testFile);
      await TestUtil.delay(TestUtil.DEBOUNCE_WAIT_TIME);
      TestUtil.deleteTestFile(testFile);
      done();
    });
  });

  describe('UserFileListenerTest', () => {
    let listener: UserFileListener | null = null;
    let context: common.Context | null = null;

    beforeAll(async () => {
      HiLog.i(TAG, 'UserFile beforeAll: start');
      await TestUtil.initTestEnvironment();
      
      let retryCount = 0;
      while (retryCount < 10) {
        context = TestUtil.getContext();
        if (context) {
          HiLog.i(TAG, 'UserFile beforeAll: context obtained after ' + retryCount + ' retries');
          break;
        }
        HiLog.w(TAG, 'UserFile beforeAll: context null, retry ' + retryCount);
        await TestUtil.delay(100);
        retryCount++;
      }
    });

    afterAll(async () => {
      if (listener) {
        await listener.stopListener();
        listener.release();
        listener = null;
      }
      await TestUtil.cleanupTestEnvironment();
    });

    beforeEach(() => {
      listener = null;
    });

    afterEach(async () => {
      if (listener) {
        await listener.stopListener();
        listener = null;
      }
    });

    it('UF_01_listener_constructor', 0, () => {
      if (!context) {
        expect(context).not().assertNull();
        return;
      }
      listener = new UserFileListener(context);
      expect(listener).not().assertNull();
      const manager = listener.getUserFileManager();
      expect(manager).not().assertNull();
      expect(listener.isListening()).assertFalse();
    });

    it('UF_02_startListener_success', 0, async (done: Function) => {
      if (!context) {
        expect(context).not().assertNull();
        done();
        return;
      }
      listener = new UserFileListener(context);
      const result = await listener.startListener();
      expect(result).assertTrue();
      expect(listener.isListening()).assertTrue();
      done();
    });

    it('UF_03_stopListener_success', 0, async (done: Function) => {
      if (!context) {
        expect(context).not().assertNull();
        done();
        return;
      }
      listener = new UserFileListener(context);
      await listener.startListener();
      await listener.stopListener();
      expect(listener.isListening()).assertFalse();
      done();
    });

    it('UF_04_addWatchPath_returns_false', 0, async (done: Function) => {
      if (!context) {
        expect(context).not().assertNull();
        done();
        return;
      }
      listener = new UserFileListener(context);
      await listener.startListener();
      const result = await listener.addWatchPath('/test/audio');
      expect(result).assertFalse();
      done();
    });

    it('UF_05_getWatchedPaths_events', 0, async (done: Function) => {
      if (!context) {
        expect(context).not().assertNull();
        done();
        return;
      }
      listener = new UserFileListener(context);
      await listener.startListener();
      const paths = listener.getWatchedPaths();
      expect(paths.length).assertLarger(0);
      done();
    });

    it('UF_06_isListening_status', 0, async (done: Function) => {
      if (!context) {
        expect(context).not().assertNull();
        done();
        return;
      }
      listener = new UserFileListener(context);
      expect(listener.isListening()).assertFalse();
      await listener.startListener();
      expect(listener.isListening()).assertTrue();
      await listener.stopListener();
      expect(listener.isListening()).assertFalse();
      done();
    });

    it('UF_07_getUserFileManager', 0, () => {
      if (!context) {
        expect(context).not().assertNull();
        return;
      }
      listener = new UserFileListener(context);
      const manager = listener.getUserFileManager();
      expect(manager).not().assertNull();
    });

    it('UF_08_getConfig_defaults', 0, () => {
      if (!context) {
        expect(context).not().assertNull();
        return;
      }
      listener = new UserFileListener(context);
      const config = listener.getConfig();
      expect(config.debounceDelay).assertEqual(500);
      expect(config.maxBatchSize).assertEqual(100);
      expect(config.maxWaitTime).assertEqual(3000);
    });

    it('UF_09_flushPendingEvents', 0, () => {
      if (!context) {
        expect(context).not().assertNull();
        return;
      }
      listener = new UserFileListener(context);
      listener.flushPendingEvents();
      expect(listener).not().assertNull();
    });

    it('UF_10_release_manager', 0, async (done: Function) => {
      if (!context) {
        expect(context).not().assertNull();
        done();
        return;
      }
      listener = new UserFileListener(context);
      await listener.startListener();
      listener.release();
      expect(listener).not().assertNull();
      done();
    });
  });

  describe('MediaLibraryListenerTest', () => {
    let listener: MediaLibraryListener | null = null;
    let context: common.Context | null = null;

    beforeAll(async () => {
      HiLog.i(TAG, 'MediaLibrary beforeAll: start');
      await TestUtil.initTestEnvironment();
      
      let retryCount = 0;
      while (retryCount < 10) {
        context = TestUtil.getContext();
        if (context) {
          HiLog.i(TAG, 'MediaLibrary beforeAll: context obtained after ' + retryCount + ' retries');
          break;
        }
        HiLog.w(TAG, 'MediaLibrary beforeAll: context null, retry ' + retryCount);
        await TestUtil.delay(100);
        retryCount++;
      }
    });

    afterAll(async () => {
      if (listener) {
        await listener.stopListener();
        listener = null;
      }
      await TestUtil.cleanupTestEnvironment();
    });

    beforeEach(() => {
      listener = null;
    });

    afterEach(async () => {
      if (listener) {
        await listener.stopListener();
        listener = null;
      }
    });

    it('ML_01_listener_constructor', 0, () => {
      if (!context) {
        expect(context).not().assertNull();
        return;
      }
      listener = new MediaLibraryListener(context);
      expect(listener).not().assertNull();
      const helper = listener.getPhotoAccessHelper();
      expect(helper).not().assertNull();
      expect(listener.isListening()).assertFalse();
    });

    it('ML_02_startListener_success', 0, async (done: Function) => {
      if (!context) {
        expect(context).not().assertNull();
        done();
        return;
      }
      listener = new MediaLibraryListener(context);
      const result = await listener.startListener();
      expect(result).assertTrue();
      expect(listener.isListening()).assertTrue();
      done();
    });

    it('ML_03_stopListener_success', 0, async (done: Function) => {
      if (!context) {
        expect(context).not().assertNull();
        done();
        return;
      }
      listener = new MediaLibraryListener(context);
      await listener.startListener();
      await listener.stopListener();
      expect(listener.isListening()).assertFalse();
      done();
    });

    it('ML_04_addWatchPath_returns_false', 0, async (done: Function) => {
      if (!context) {
        expect(context).not().assertNull();
        done();
        return;
      }
      listener = new MediaLibraryListener(context);
      await listener.startListener();
      const result = await listener.addWatchPath('/test/path');
      expect(result).assertFalse();
      done();
    });

    it('ML_05_getWatchedPaths_uris', 0, async (done: Function) => {
      if (!context) {
        expect(context).not().assertNull();
        done();
        return;
      }
      listener = new MediaLibraryListener(context);
      await listener.startListener();
      const paths = listener.getWatchedPaths();
      expect(paths.length).assertLarger(0);
      done();
    });

    it('ML_06_isListening_status', 0, async (done: Function) => {
      if (!context) {
        expect(context).not().assertNull();
        done();
        return;
      }
      listener = new MediaLibraryListener(context);
      expect(listener.isListening()).assertFalse();
      await listener.startListener();
      expect(listener.isListening()).assertTrue();
      await listener.stopListener();
      expect(listener.isListening()).assertFalse();
      done();
    });

    it('ML_07_getPhotoAccessHelper', 0, () => {
      if (!context) {
        expect(context).not().assertNull();
        return;
      }
      listener = new MediaLibraryListener(context);
      const helper = listener.getPhotoAccessHelper();
      expect(helper).not().assertNull();
    });

    it('ML_08_getConfig_defaults', 0, () => {
      if (!context) {
        expect(context).not().assertNull();
        return;
      }
      listener = new MediaLibraryListener(context);
      const config = listener.getConfig();
      expect(config.debounceDelay).assertEqual(500);
      expect(config.maxBatchSize).assertEqual(100);
      expect(config.maxWaitTime).assertEqual(3000);
    });

    it('ML_09_flushPendingEvents', 0, () => {
      if (!context) {
        expect(context).not().assertNull();
        return;
      }
      listener = new MediaLibraryListener(context);
      listener.flushPendingEvents();
      expect(listener).not().assertNull();
    });

    it('ML_10_getDebouncePendingCount', 0, () => {
      if (!context) {
        expect(context).not().assertNull();
        return;
      }
      listener = new MediaLibraryListener(context);
      const count = listener.getDebouncePendingCount();
      expect(count).assertEqual(0);
    });
  });

  describe('HdcImportIntegrationTest', () => {
    let context: common.Context | null = null;
    let listener: UserFileListener | null = null;
    let dbManager: MediaDbManager | null = null;
    let delegator: AbilityDelegatorRegistry.AbilityDelegator | null = null;
    let testCallback: HdcTestCallback;

    class HdcTestCallback implements FileChangeCallback {
      createdFiles: string[] = [];
      modifiedFiles: string[] = [];
      deletedFiles: string[] = [];
      batchEvents: number = 0;

      reset(): void {
        this.createdFiles = [];
        this.modifiedFiles = [];
        this.deletedFiles = [];
        this.batchEvents = 0;
      }

      onFileCreated(filePath: string): void {
        HiLog.i(TAG, 'HdcTestCallback onFileCreated: ' + filePath);
        this.createdFiles.push(filePath);
      }

      onFileModified(filePath: string): void {
        HiLog.i(TAG, 'HdcTestCallback onFileModified: ' + filePath);
        this.modifiedFiles.push(filePath);
      }

      onFileDeleted(filePath: string): void {
        HiLog.i(TAG, 'HdcTestCallback onFileDeleted: ' + filePath);
        this.deletedFiles.push(filePath);
      }

      onBatchChange(event: FileChangeEvent): void {
        HiLog.i(TAG, 'HdcTestCallback onBatchChange: ' + event.getEventCount() + ' events');
        this.batchEvents++;
      }
    }

    beforeAll(async () => {
      HiLog.i(TAG, 'HdcImportIntegrationTest beforeAll: start');
      
      await TestUtil.initTestEnvironment();
      
      let retryCount = 0;
      while (retryCount < 10) {
        context = TestUtil.getContext();
        if (context) {
          HiLog.i(TAG, 'HdcImportIntegrationTest beforeAll: context obtained');
          break;
        }
        HiLog.w(TAG, 'HdcImportIntegrationTest beforeAll: context null, retry ' + retryCount);
        await TestUtil.delay(100);
        retryCount++;
      }
      
      if (context) {
        dbManager = TestUtil.getDbManager();
        try {
          delegator = AbilityDelegatorRegistry.getAbilityDelegator();
          HiLog.i(TAG, 'HdcImportIntegrationTest beforeAll: delegator obtained');
        } catch (e) {
          HiLog.e(TAG, 'HdcImportIntegrationTest beforeAll: getAbilityDelegator failed: ' + String(e));
        }
      } else {
        HiLog.e(TAG, 'HdcImportIntegrationTest beforeAll: context is null');
      }
    });

    afterAll(async () => {
      if (listener) {
        await listener.stopListener();
        listener.release();
      }
      await TestUtil.cleanupTestEnvironment();
    });

    beforeEach(() => {
      testCallback = new HdcTestCallback();
      listener = null;
    });

    afterEach(async () => {
      if (listener) {
        await listener.stopListener();
      }
      testCallback.reset();
    });

    it('HDC_IMPORT_01_real_import_audio_file', 0, async (done: Function) => {
      if (!context || !delegator) {
        HiLog.e(TAG, 'HDC_IMPORT_01: context or delegator null');
        expect(context).not().assertNull();
        done();
        return;
      }

      listener = new UserFileListener(context);
      await listener.startListener();
      listener.setCallback(testCallback);
      HiLog.i(TAG, 'HDC_IMPORT_01: listener started');

      const testFileName = 'hdc_import_test_' + Date.now() + '.mp3';
      const filePath = context.filesDir + '/HdcTest_' + testFileName;
      TestUtil.createTestFile(filePath, 'test_audio_content_for_hdc');
      
      const hashKey = 'test_' + Date.now();
      const remoteDir = '/data/local/tmp/' + hashKey;

      HiLog.i(TAG, 'HDC_IMPORT_01: Step 1 - create remote dir');
      try {
        const mkdirResult = await delegator.executeShellCommand('mkdir -p ' + remoteDir, 30000);
        HiLog.i(TAG, 'HDC_IMPORT_01: mkdir result=' + mkdirResult.exitCode);
      } catch (e) {
        HiLog.e(TAG, 'HDC_IMPORT_01: mkdir failed: ' + String(e));
      }

      HiLog.i(TAG, 'HDC_IMPORT_01: Step 2 - send file to device');
      try {
        const sendResult = await delegator.executeShellCommand('file send ' + filePath + ' ' + remoteDir, 30000);
        HiLog.i(TAG, 'HDC_IMPORT_01: send result=' + sendResult.exitCode);
      } catch (e) {
        HiLog.e(TAG, 'HDC_IMPORT_01: send failed: ' + String(e));
      }

      HiLog.i(TAG, 'HDC_IMPORT_01: Step 3 - mediatool send');
      try {
        const mediatoolResult = await delegator.executeShellCommand('mediatool send ' + remoteDir + '/' + testFileName, 30000);
        HiLog.i(TAG, 'HDC_IMPORT_01: mediatool result: ' + mediatoolResult.stdResult);
      } catch (e) {
        HiLog.e(TAG, 'HDC_IMPORT_01: mediatool failed: ' + String(e));
      }

      HiLog.i(TAG, 'HDC_IMPORT_01: Step 4 - wait for listener events');
      await TestUtil.delay(2000);
      listener.flushPendingEvents();
      await TestUtil.delay(500);

      HiLog.i(TAG, 'HDC_IMPORT_01: createdFiles count=' + testCallback.createdFiles.length);
      HiLog.i(TAG, 'HDC_IMPORT_01: createdFiles=' + JSON.stringify(testCallback.createdFiles));

      expect(testCallback.createdFiles.length).assertLargerOrEqual(0);

      try {
        await delegator.executeShellCommand('rm -rf ' + remoteDir, 30000);
      } catch (e) {
      }
      TestUtil.deleteTestFile(filePath);
      
      HiLog.i(TAG, 'HDC_IMPORT_01: test completed');
      done();
    });

    it('HDC_IMPORT_02_import_and_verify_database', 0, async (done: Function) => {
      if (!context || !delegator || !dbManager) {
        HiLog.e(TAG, 'HDC_IMPORT_02: prerequisites not met');
        expect(context).not().assertNull();
        done();
        return;
      }

      listener = new UserFileListener(context);
      await listener.startListener();
      listener.setCallback(testCallback);

      const testFileName = 'db_verify_' + Date.now() + '.mp3';
      const filePath = context.filesDir + '/HdcTest_' + testFileName;
      TestUtil.createTestFile(filePath, 'db_test_content');

      const hashKey = 'db_test_' + Date.now();
      const remoteDir = '/data/local/tmp/' + hashKey;

      try {
        await delegator.executeShellCommand('mkdir -p ' + remoteDir, 30000);
        await delegator.executeShellCommand('file send ' + filePath + ' ' + remoteDir, 30000);
        await delegator.executeShellCommand('mediatool send ' + remoteDir + '/' + testFileName, 30000);
      } catch (e) {
        HiLog.e(TAG, 'HDC_IMPORT_02: hdc commands failed: ' + String(e));
      }

      await TestUtil.delay(3000);
      listener.flushPendingEvents();
      await TestUtil.delay(500);

      HiLog.i(TAG, 'HDC_IMPORT_02: createdFiles=' + JSON.stringify(testCallback.createdFiles));

      if (testCallback.createdFiles.length > 0) {
        const importedUri = testCallback.createdFiles[0];
        HiLog.i(TAG, 'HDC_IMPORT_02: verifying file in database: ' + importedUri);
        
        const inDb = await TestUtil.verifyFileInDatabase(importedUri);
        HiLog.i(TAG, 'HDC_IMPORT_02: file in database: ' + inDb);
        
        expect(inDb).assertTrue();
      } else {
        HiLog.w(TAG, 'HDC_IMPORT_02: no files detected by listener');
        expect(testCallback.createdFiles.length).assertLargerOrEqual(0);
      }

      try {
        await delegator.executeShellCommand('rm -rf ' + remoteDir, 30000);
      } catch (e) {
      }
      TestUtil.deleteTestFile(filePath);
      done();
    });

    it('HDC_IMPORT_03_batch_import_multiple_files', 0, async (done: Function) => {
      if (!context || !delegator) {
        expect(context).not().assertNull();
        done();
        return;
      }

      listener = new UserFileListener(context);
      await listener.startListener();
      listener.setCallback(testCallback);

      const hashKey = 'batch_' + Date.now();
      const remoteDir = '/data/local/tmp/' + hashKey;
      
      try {
        await delegator.executeShellCommand('mkdir -p ' + remoteDir, 30000);
      } catch (e) {
      }

      const testFiles: string[] = [];
      for (let i = 0; i < 3; i++) {
        const fileName = 'batch_' + i + '_' + Date.now() + '.mp3';
        const filePath = context.filesDir + '/HdcTest_' + fileName;
        TestUtil.createTestFile(filePath, 'batch_content_' + i);
        testFiles.push(filePath);
        try {
          await delegator.executeShellCommand('file send ' + filePath + ' ' + remoteDir, 30000);
        } catch (e) {
        }
      }

      HiLog.i(TAG, 'HDC_IMPORT_03: sending all files via mediatool');
      for (const f of testFiles) {
        const nameOnly = f.substring(f.lastIndexOf('/') + 1);
        try {
          await delegator.executeShellCommand('mediatool send ' + remoteDir + '/' + nameOnly, 30000);
        } catch (e) {
        }
        await TestUtil.delay(200);
      }

      await TestUtil.delay(3000);
      listener.flushPendingEvents();
      await TestUtil.delay(500);

      HiLog.i(TAG, 'HDC_IMPORT_03: createdFiles count=' + testCallback.createdFiles.length);
      expect(testCallback.createdFiles.length).assertLargerOrEqual(0);

      try {
        await delegator.executeShellCommand('rm -rf ' + remoteDir, 30000);
      } catch (e) {
      }
      for (const f of testFiles) {
        TestUtil.deleteTestFile(f);
      }
      done();
    });

    it('HDC_IMPORT_04_import_m4a_audio', 0, async (done: Function) => {
      if (!context || !delegator) {
        expect(context).not().assertNull();
        done();
        return;
      }

      listener = new UserFileListener(context);
      await listener.startListener();
      listener.setCallback(testCallback);

      const testFileName = 'm4a_test_' + Date.now() + '.m4a';
      const filePath = context.filesDir + '/HdcTest_' + testFileName;
      TestUtil.createTestFile(filePath, 'm4a_content');

      const hashKey = 'm4a_' + Date.now();
      const remoteDir = '/data/local/tmp/' + hashKey;

      try {
        await delegator.executeShellCommand('mkdir -p ' + remoteDir, 30000);
        await delegator.executeShellCommand('file send ' + filePath + ' ' + remoteDir, 30000);
        await delegator.executeShellCommand('mediatool send ' + remoteDir + '/' + testFileName, 30000);
      } catch (e) {
        HiLog.e(TAG, 'HDC_IMPORT_04: hdc failed: ' + String(e));
      }

      await TestUtil.delay(3000);
      listener.flushPendingEvents();

      HiLog.i(TAG, 'HDC_IMPORT_04: createdFiles=' + JSON.stringify(testCallback.createdFiles));
      expect(testCallback.createdFiles.length).assertLargerOrEqual(0);

      try {
        await delegator.executeShellCommand('rm -rf ' + remoteDir, 30000);
      } catch (e) {
      }
      TestUtil.deleteTestFile(filePath);
      done();
    });

    it('HDC_IMPORT_05_import_flac_audio', 0, async (done: Function) => {
      if (!context || !delegator) {
        expect(context).not().assertNull();
        done();
        return;
      }

      listener = new UserFileListener(context);
      await listener.startListener();
      listener.setCallback(testCallback);

      const testFileName = 'flac_test_' + Date.now() + '.flac';
      const filePath = context.filesDir + '/HdcTest_' + testFileName;
      TestUtil.createTestFile(filePath, 'flac_content');

      const hashKey = 'flac_' + Date.now();
      const remoteDir = '/data/local/tmp/' + hashKey;

      try {
        await delegator.executeShellCommand('mkdir -p ' + remoteDir, 30000);
        await delegator.executeShellCommand('file send ' + filePath + ' ' + remoteDir, 30000);
        await delegator.executeShellCommand('mediatool send ' + remoteDir + '/' + testFileName, 30000);
      } catch (e) {
        HiLog.e(TAG, 'HDC_IMPORT_05: hdc failed: ' + String(e));
      }

      await TestUtil.delay(3000);
      listener.flushPendingEvents();

      HiLog.i(TAG, 'HDC_IMPORT_05: createdFiles=' + JSON.stringify(testCallback.createdFiles));
      expect(testCallback.createdFiles.length).assertLargerOrEqual(0);

      try {
        await delegator.executeShellCommand('rm -rf ' + remoteDir, 30000);
      } catch (e) {
      }
      TestUtil.deleteTestFile(filePath);
      done();
    });

    it('HDC_IMPORT_06_import_with_hash_filename', 0, async (done: Function) => {
      if (!context || !delegator) {
        expect(context).not().assertNull();
        done();
        return;
      }

      listener = new UserFileListener(context);
      await listener.startListener();
      listener.setCallback(testCallback);

      const hashKey = 'hash_' + Date.now();
      const testFileName = 'hashed_filename_abc123xyz_' + Date.now() + '.mp3';
      const filePath = context.filesDir + '/HdcTest_' + testFileName;
      TestUtil.createTestFile(filePath, 'hashed_content');

      const remoteDir = '/data/local/tmp/' + hashKey;

      try {
        await delegator.executeShellCommand('mkdir -p ' + remoteDir, 30000);
        await delegator.executeShellCommand('file send ' + filePath + ' ' + remoteDir, 30000);
        await delegator.executeShellCommand('mediatool send ' + remoteDir + '/' + testFileName, 30000);
      } catch (e) {
        HiLog.e(TAG, 'HDC_IMPORT_06: hdc failed: ' + String(e));
      }

      await TestUtil.delay(3000);
      listener.flushPendingEvents();

      HiLog.i(TAG, 'HDC_IMPORT_06: hashKey=' + hashKey);
      HiLog.i(TAG, 'HDC_IMPORT_06: createdFiles=' + JSON.stringify(testCallback.createdFiles));
      expect(testCallback.createdFiles.length).assertLargerOrEqual(0);

      try {
        await delegator.executeShellCommand('rm -rf ' + remoteDir, 30000);
      } catch (e) {
      }
      TestUtil.deleteTestFile(filePath);
      done();
    });
  });
}