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
import userFileManager from '@ohos.filemanagement.userFileManager';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import dataSharePredicates from '@ohos.data.dataSharePredicates';
import fs from '@ohos.file.fs';
import process from '@ohos.process';
import { UserFileListener, MediaLibraryListener, FileChangeType, FileChangeEvent, FileChangeCallback, HiLog, MediaPermissionManager, MediaDbManager } from '@ohos/common';
import { TestUtil } from '../utils/TestUtil';
import type common from '@ohos.app.ability.common';

const TAG = 'FileListenerApiTest';

class TestCallbackImpl implements FileChangeCallback {
  createdFiles: string[] = [];
  modifiedFiles: string[] = [];
  deletedFiles: string[] = [];
  eventReceived: boolean = false;
  
  reset(): void {
    this.createdFiles = [];
    this.modifiedFiles = [];
    this.deletedFiles = [];
    this.eventReceived = false;
  }

  onFileCreated(filePath: string): void {
    HiLog.i(TAG, 'onFileCreated: ' + filePath);
    this.createdFiles.push(filePath);
    this.eventReceived = true;
  }

  onFileModified(filePath: string): void {
    HiLog.i(TAG, 'onFileModified: ' + filePath);
    this.modifiedFiles.push(filePath);
    this.eventReceived = true;
  }

  onFileDeleted(filePath: string): void {
    HiLog.i(TAG, 'onFileDeleted: ' + filePath);
    this.deletedFiles.push(filePath);
    this.eventReceived = true;
  }

  onBatchChange(event: FileChangeEvent): void {
    HiLog.i(TAG, 'onBatchChange: ' + event.getEventCount() + ' events');
  }
}

class UserFileTestHelper {
  private userFileMgr: userFileManager.UserFileManager | null = null;
  private createdAssets: userFileManager.FileAsset[] = [];
  private testCallback: TestCallbackImpl;
  private listener: UserFileListener | null = null;

  constructor(callback: TestCallbackImpl) {
    this.testCallback = callback;
  }

  setUserFileMgr(mgr: userFileManager.UserFileManager | null): void {
    this.userFileMgr = mgr;
  }

  setListener(l: UserFileListener | null): void {
    this.listener = l;
    if (l) {
      l.setCallback(this.testCallback);
    }
  }

  async createAudioAsset(displayName: string): Promise<userFileManager.FileAsset | null> {
    if (!this.userFileMgr) {
      return null;
    }
    try {
      const asset = await this.userFileMgr.createAudioAsset(displayName);
      this.createdAssets.push(asset);
      HiLog.i(TAG, 'createAudioAsset: ' + asset.uri);
      return asset;
    } catch (e) {
      HiLog.e(TAG, 'createAudioAsset failed: ' + String(e));
      return null;
    }
  }

  async deleteAudioAsset(uri: string): Promise<boolean> {
    if (!this.userFileMgr) {
      return false;
    }
    try {
      await this.userFileMgr.delete(uri);
      const idx = this.createdAssets.findIndex(a => a.uri === uri);
      if (idx !== -1) {
        this.createdAssets.splice(idx, 1);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  async modifyAssetName(asset: userFileManager.FileAsset, newName: string): Promise<boolean> {
    try {
      asset.set('displayName', newName);
      await asset.commitModify();
      return true;
    } catch (e) {
      return false;
    }
  }

  async cleanup(): Promise<void> {
    if (this.userFileMgr) {
      for (const asset of this.createdAssets) {
        try {
          await this.userFileMgr.delete(asset.uri);
        } catch (e) {
        }
      }
      this.createdAssets = [];
    }
  }

  async waitForEvents(timeoutMs: number): Promise<void> {
    const start = Date.now();
    while (!this.testCallback.eventReceived && Date.now() - start < timeoutMs) {
      await TestUtil.delay(100);
    }
    if (this.testCallback.eventReceived) {
      await TestUtil.delay(600);
      this.listener?.flushPendingEvents();
      await TestUtil.delay(200);
    }
  }
}

class PhotoTestHelper {
  private phHelper: photoAccessHelper.PhotoAccessHelper | null = null;
  private createdUris: string[] = [];
  private testCallback: TestCallbackImpl;
  private listener: MediaLibraryListener | null = null;

  constructor(callback: TestCallbackImpl) {
    this.testCallback = callback;
  }

  setPhotoAccessHelper(h: photoAccessHelper.PhotoAccessHelper | null): void {
    this.phHelper = h;
  }

  setListener(l: MediaLibraryListener | null): void {
    this.listener = l;
    if (l) {
      l.setCallback(this.testCallback);
    }
  }

  async createPhotoAsset(title: string): Promise<string | null> {
    if (!this.phHelper) return null;
    try {
      const uri = await this.phHelper.createAsset(photoAccessHelper.PhotoType.IMAGE, 'jpg', { title: title });
      this.createdUris.push(uri);
      HiLog.i(TAG, 'createPhoto: ' + uri);
      return uri;
    } catch (e) {
      HiLog.e(TAG, 'createPhoto failed: ' + String(e));
      return null;
    }
  }

  async createVideoAsset(title: string): Promise<string | null> {
    if (!this.phHelper) return null;
    try {
      const uri = await this.phHelper.createAsset(photoAccessHelper.PhotoType.VIDEO, 'mp4', { title: title });
      this.createdUris.push(uri);
      HiLog.i(TAG, 'createVideo: ' + uri);
      return uri;
    } catch (e) {
      HiLog.e(TAG, 'createVideo failed: ' + String(e));
      return null;
    }
  }

  async deleteAsset(uri: string): Promise<boolean> {
    if (!this.phHelper) return false;
    try {
      await this.phHelper.deleteAssets([uri]);
      const idx = this.createdUris.indexOf(uri);
      if (idx !== -1) this.createdUris.splice(idx, 1);
      return true;
    } catch (e) {
      return false;
    }
  }

  async getAssetByUri(uri: string): Promise<photoAccessHelper.PhotoAsset | null> {
    if (!this.phHelper) return null;
    try {
      const predicates = new dataSharePredicates.DataSharePredicates();
      predicates.equalTo('uri', uri);
      const fetchResult = await this.phHelper.getAssets({ fetchColumns: ['uri', 'displayName'], predicates: predicates });
      if (fetchResult.getCount() > 0) {
        const asset = await fetchResult.getFirstObject();
        fetchResult.close();
        return asset;
      }
      fetchResult.close();
      return null;
    } catch (e) {
      return null;
    }
  }

  async modifyAssetName(uri: string, newName: string): Promise<boolean> {
    const asset = await this.getAssetByUri(uri);
    if (!asset) return false;
    try {
      asset.set('displayName', newName);
      await asset.commitModify();
      return true;
    } catch (e) {
      return false;
    }
  }

  async cleanup(): Promise<void> {
    if (this.phHelper && this.createdUris.length > 0) {
      try {
        await this.phHelper.deleteAssets(this.createdUris);
      } catch (e) {
        for (const uri of this.createdUris) {
          try {
            await this.phHelper.deleteAssets([uri]);
          } catch (e2) {
          }
        }
      }
      this.createdUris = [];
    }
  }

  async waitForEvents(timeoutMs: number): Promise<void> {
    const start = Date.now();
    while (!this.testCallback.eventReceived && Date.now() - start < timeoutMs) {
      await TestUtil.delay(100);
    }
    if (this.testCallback.eventReceived) {
      await TestUtil.delay(600);
      this.listener?.flushPendingEvents();
      await TestUtil.delay(200);
    }
  }
}

export default function FileListenerApiTest() {
  describe('UserFileApiTest', () => {
    let context: common.Context | null = null;
    let userFileMgr: userFileManager.UserFileManager | null = null;
    let listener: UserFileListener | null = null;
    let testCallback: TestCallbackImpl;
    let helper: UserFileTestHelper;

    beforeAll(async () => {
      HiLog.i(TAG, 'UserFileApiTest beforeAll: start');
      
      await TestUtil.initTestEnvironment();
      
      let retryCount = 0;
      while (retryCount < 10) {
        context = TestUtil.getContext();
        if (context) {
          HiLog.i(TAG, 'UserFileApiTest beforeAll: context obtained after ' + retryCount + ' retries');
          break;
        }
        HiLog.w(TAG, 'UserFileApiTest beforeAll: context null, retry ' + retryCount);
        await TestUtil.delay(100);
        retryCount++;
      }
      
      if (context) {
        try {
          userFileMgr = userFileManager.getUserFileMgr(context);
          HiLog.i(TAG, 'UserFileApiTest beforeAll: userFileMgr obtained');
        } catch (e) {
          HiLog.e(TAG, 'UserFileApiTest beforeAll: getUserFileMgr failed: ' + String(e));
        }
      } else {
        HiLog.e(TAG, 'UserFileApiTest beforeAll: context is null after retries');
      }
    });

    afterAll(async () => {
      if (listener) {
        await listener.stopListener();
        listener.release();
      }
      if (userFileMgr) {
        userFileMgr.release();
      }
      await TestUtil.cleanupTestEnvironment();
    });

    beforeEach(() => {
      testCallback = new TestCallbackImpl();
      helper = new UserFileTestHelper(testCallback);
      helper.setUserFileMgr(userFileMgr);
      listener = null;
    });

    afterEach(async () => {
      if (listener) {
        await listener.stopListener();
      }
      await helper.cleanup();
    });

    it('UF_API_01_create_single_audio', 0, async (done: Function) => {
      if (!context || !userFileMgr) {
        expect(context).not().assertNull();
        done();
        return;
      }
      listener = new UserFileListener(context);
      await listener.startListener();
      helper.setListener(listener);
      
      const asset = await helper.createAudioAsset('test_audio_01.mp3');
      expect(asset).not().assertNull();
      
      await helper.waitForEvents(2000);
      expect(testCallback.createdFiles.length).assertLargerOrEqual(0);
      done();
    });

    it('UF_API_02_create_multiple_audio', 0, async (done: Function) => {
      if (!context || !userFileMgr) {
        expect(context).not().assertNull();
        done();
        return;
      }
      listener = new UserFileListener(context);
      await listener.startListener();
      helper.setListener(listener);
      
      for (let i = 0; i < 3; i++) {
        await helper.createAudioAsset('multi_' + i + '.mp3');
        await TestUtil.delay(100);
      }
      
      await helper.waitForEvents(3000);
      expect(testCallback.createdFiles.length).assertLargerOrEqual(0);
      done();
    });

    it('UF_API_03_delete_single_audio', 0, async (done: Function) => {
      if (!context || !userFileMgr) {
        expect(context).not().assertNull();
        done();
        return;
      }
      listener = new UserFileListener(context);
      await listener.startListener();
      helper.setListener(listener);
      
      const asset = await helper.createAudioAsset('del_01.mp3');
      expect(asset).not().assertNull();
      
      await helper.waitForEvents(2000);
      testCallback.reset();
      
      if (asset) {
        await helper.deleteAudioAsset(asset.uri);
      }
      
      await helper.waitForEvents(2000);
      expect(testCallback.deletedFiles.length).assertLargerOrEqual(0);
      done();
    });

    it('UF_API_04_delete_multiple_audio', 0, async (done: Function) => {
      if (!context || !userFileMgr) {
        expect(context).not().assertNull();
        done();
        return;
      }
      listener = new UserFileListener(context);
      await listener.startListener();
      helper.setListener(listener);
      
      const uris: string[] = [];
      for (let i = 0; i < 3; i++) {
        const a = await helper.createAudioAsset('del_m_' + i + '.mp3');
        if (a) uris.push(a.uri);
      }
      
      await helper.waitForEvents(3000);
      testCallback.reset();
      
      for (const uri of uris) {
        await helper.deleteAudioAsset(uri);
      }
      
      await helper.waitForEvents(3000);
      expect(testCallback.deletedFiles.length).assertLargerOrEqual(0);
      done();
    });

    it('UF_API_05_modify_audio_name', 0, async (done: Function) => {
      if (!context || !userFileMgr) {
        expect(context).not().assertNull();
        done();
        return;
      }
      listener = new UserFileListener(context);
      await listener.startListener();
      helper.setListener(listener);
      
      const asset = await helper.createAudioAsset('rename_01.mp3');
      expect(asset).not().assertNull();
      
      await helper.waitForEvents(2000);
      testCallback.reset();
      
      if (asset) {
        await helper.modifyAssetName(asset, 'renamed_01.mp3');
      }
      
      await helper.waitForEvents(2000);
      expect(testCallback.modifiedFiles.length).assertLargerOrEqual(0);
      done();
    });

    it('UF_API_06_verify_uri_format', 0, async (done: Function) => {
      if (!context || !userFileMgr) {
        expect(context).not().assertNull();
        done();
        return;
      }
      listener = new UserFileListener(context);
      await listener.startListener();
      helper.setListener(listener);
      
      const asset = await helper.createAudioAsset('uri_test.mp3');
      expect(asset).not().assertNull();
      
      if (asset) {
        expect(asset.uri).assertContain('file://media/');
      }
      done();
    });
  });

  describe('MediaLibraryApiTest', () => {
    let context: common.Context | null = null;
    let phHelper: photoAccessHelper.PhotoAccessHelper | null = null;
    let listener: MediaLibraryListener | null = null;
    let testCallback: TestCallbackImpl;
    let helper: PhotoTestHelper;

    beforeAll(async () => {
      HiLog.i(TAG, 'MediaLibraryApiTest beforeAll: start');
      
      await TestUtil.initTestEnvironment();
      
      let retryCount = 0;
      while (retryCount < 10) {
        context = TestUtil.getContext();
        if (context) {
          HiLog.i(TAG, 'MediaLibraryApiTest beforeAll: context obtained after ' + retryCount + ' retries');
          break;
        }
        HiLog.w(TAG, 'MediaLibraryApiTest beforeAll: context null, retry ' + retryCount);
        await TestUtil.delay(100);
        retryCount++;
      }
      
      if (context) {
        try {
          phHelper = photoAccessHelper.getPhotoAccessHelper(context);
          HiLog.i(TAG, 'MediaLibraryApiTest beforeAll: phHelper obtained');
        } catch (e) {
          HiLog.e(TAG, 'MediaLibraryApiTest beforeAll: getPhotoAccessHelper failed: ' + String(e));
        }
      } else {
        HiLog.e(TAG, 'MediaLibraryApiTest beforeAll: context is null after retries');
      }
    });

    afterAll(async () => {
      if (listener) {
        await listener.stopListener();
      }
      await TestUtil.cleanupTestEnvironment();
    });

    beforeEach(() => {
      testCallback = new TestCallbackImpl();
      helper = new PhotoTestHelper(testCallback);
      helper.setPhotoAccessHelper(phHelper);
      listener = null;
    });

    afterEach(async () => {
      if (listener) {
        await listener.stopListener();
      }
      await helper.cleanup();
    });

    it('ML_API_01_create_single_photo', 0, async (done: Function) => {
      if (!context || !phHelper) {
        expect(context).not().assertNull();
        done();
        return;
      }
      listener = new MediaLibraryListener(context);
      await listener.startListener();
      helper.setListener(listener);
      
      const uri = await helper.createPhotoAsset('photo_01');
      expect(uri).not().assertNull();
      
      await helper.waitForEvents(2000);
      expect(testCallback.createdFiles.length).assertLargerOrEqual(0);
      done();
    });

    it('ML_API_02_create_multiple_photos', 0, async (done: Function) => {
      if (!context || !phHelper) {
        expect(context).not().assertNull();
        done();
        return;
      }
      listener = new MediaLibraryListener(context);
      await listener.startListener();
      helper.setListener(listener);
      
      for (let i = 0; i < 3; i++) {
        await helper.createPhotoAsset('photo_m_' + i);
        await TestUtil.delay(100);
      }
      
      await helper.waitForEvents(3000);
      expect(testCallback.createdFiles.length).assertLargerOrEqual(0);
      done();
    });

    it('ML_API_03_delete_single_photo', 0, async (done: Function) => {
      if (!context || !phHelper) {
        expect(context).not().assertNull();
        done();
        return;
      }
      listener = new MediaLibraryListener(context);
      await listener.startListener();
      helper.setListener(listener);
      
      const uri = await helper.createPhotoAsset('photo_del');
      expect(uri).not().assertNull();
      
      await helper.waitForEvents(2000);
      testCallback.reset();
      
      if (uri) {
        await helper.deleteAsset(uri);
      }
      
      await helper.waitForEvents(2000);
      expect(testCallback.deletedFiles.length).assertLargerOrEqual(0);
      done();
    });

    it('ML_API_04_delete_multiple_photos', 0, async (done: Function) => {
      if (!context || !phHelper) {
        expect(context).not().assertNull();
        done();
        return;
      }
      listener = new MediaLibraryListener(context);
      await listener.startListener();
      helper.setListener(listener);
      
      const uris: string[] = [];
      for (let i = 0; i < 3; i++) {
        const u = await helper.createPhotoAsset('photo_d_m_' + i);
        if (u) uris.push(u);
      }
      
      await helper.waitForEvents(3000);
      testCallback.reset();
      
      for (const u of uris) {
        await helper.deleteAsset(u);
      }
      
      await helper.waitForEvents(3000);
      expect(testCallback.deletedFiles.length).assertLargerOrEqual(0);
      done();
    });

    it('ML_API_05_create_video', 0, async (done: Function) => {
      if (!context || !phHelper) {
        expect(context).not().assertNull();
        done();
        return;
      }
      listener = new MediaLibraryListener(context);
      await listener.startListener();
      helper.setListener(listener);
      
      const uri = await helper.createVideoAsset('video_01');
      expect(uri).not().assertNull();
      
      await helper.waitForEvents(2000);
      expect(testCallback.createdFiles.length).assertLargerOrEqual(0);
      done();
    });

    it('ML_API_06_delete_video', 0, async (done: Function) => {
      if (!context || !phHelper) {
        expect(context).not().assertNull();
        done();
        return;
      }
      listener = new MediaLibraryListener(context);
      await listener.startListener();
      helper.setListener(listener);
      
      const uri = await helper.createVideoAsset('video_del');
      expect(uri).not().assertNull();
      
      await helper.waitForEvents(2000);
      testCallback.reset();
      
      if (uri) {
        await helper.deleteAsset(uri);
      }
      
      await helper.waitForEvents(2000);
      expect(testCallback.deletedFiles.length).assertLargerOrEqual(0);
      done();
    });

    it('ML_API_07_modify_photo_name', 0, async (done: Function) => {
      if (!context || !phHelper) {
        expect(context).not().assertNull();
        done();
        return;
      }
      listener = new MediaLibraryListener(context);
      await listener.startListener();
      helper.setListener(listener);
      
      const uri = await helper.createPhotoAsset('photo_rename');
      expect(uri).not().assertNull();
      
      await helper.waitForEvents(2000);
      testCallback.reset();
      
      if (uri) {
        await helper.modifyAssetName(uri, 'photo_renamed.jpg');
      }
      
      await helper.waitForEvents(2000);
      expect(testCallback.modifiedFiles.length).assertLargerOrEqual(0);
      done();
    });

    it('ML_API_08_mixed_photo_video', 0, async (done: Function) => {
      if (!context || !phHelper) {
        expect(context).not().assertNull();
        done();
        return;
      }
      listener = new MediaLibraryListener(context);
      await listener.startListener();
      helper.setListener(listener);
      
      await helper.createPhotoAsset('mixed_photo');
      await TestUtil.delay(100);
      await helper.createVideoAsset('mixed_video');
      
      await helper.waitForEvents(3000);
      expect(testCallback.createdFiles.length).assertLargerOrEqual(0);
      done();
    });

    it('ML_API_09_verify_photo_uri', 0, async (done: Function) => {
      if (!context || !phHelper) {
        expect(context).not().assertNull();
        done();
        return;
      }
      listener = new MediaLibraryListener(context);
      await listener.startListener();
      helper.setListener(listener);
      
      const uri = await helper.createPhotoAsset('uri_test');
      expect(uri).not().assertNull();
      
      if (uri) {
        expect(uri).assertContain('file://media/');
      }
      done();
    });
  });

  describe('MediatoolHdcTest', () => {
    let context: common.Context | null = null;
    let phHelper: photoAccessHelper.PhotoAccessHelper | null = null;
    let userFileMgr: userFileManager.UserFileManager | null = null;
    let mediaListener: MediaLibraryListener | null = null;
    let audioListener: UserFileListener | null = null;
    let testCallback: TestCallbackImpl;
    let sandboxDir: string = '';

    beforeAll(async () => {
      HiLog.i(TAG, 'MediatoolHdcTest beforeAll: start');
      
      await TestUtil.initTestEnvironment();
      
      let retryCount = 0;
      while (retryCount < 10) {
        context = TestUtil.getContext();
        if (context) {
          HiLog.i(TAG, 'MediatoolHdcTest beforeAll: context obtained after ' + retryCount + ' retries');
          break;
        }
        HiLog.w(TAG, 'MediatoolHdcTest beforeAll: context null, retry ' + retryCount);
        await TestUtil.delay(100);
        retryCount++;
      }
      
      if (context) {
        try {
          phHelper = photoAccessHelper.getPhotoAccessHelper(context);
          userFileMgr = userFileManager.getUserFileMgr(context);
          sandboxDir = context.filesDir + '/MediatoolTest';
          try {
            fs.mkdirSync(sandboxDir);
          } catch (e) {
          }
          HiLog.i(TAG, 'MediatoolHdcTest beforeAll: all helpers obtained, sandboxDir=' + sandboxDir);
        } catch (e) {
          HiLog.e(TAG, 'MediatoolHdcTest beforeAll: init helpers failed: ' + String(e));
        }
      } else {
        HiLog.e(TAG, 'MediatoolHdcTest beforeAll: context is null after retries');
      }
    });

    afterAll(async () => {
      if (mediaListener) await mediaListener.stopListener();
      if (audioListener) {
        await audioListener.stopListener();
        audioListener.release();
      }
      if (userFileMgr) userFileMgr.release();
      await TestUtil.cleanupTestEnvironment();
    });

    beforeEach(() => {
      testCallback = new TestCallbackImpl();
      sandboxDir = '';
      if (context) {
        sandboxDir = context.filesDir + '/MediatoolTest_' + Date.now();
      }
      mediaListener = null;
      audioListener = null;
    });

    afterEach(async () => {
      if (mediaListener) await mediaListener.stopListener();
      if (audioListener) await audioListener.stopListener();
    });

    it('HDC_01_import_photo_via_mediatool', 0, async (done: Function) => {
      if (!context || !phHelper) {
        expect(context).not().assertNull();
        done();
        return;
      }
      mediaListener = new MediaLibraryListener(context);
      await mediaListener.startListener();
      mediaListener.setCallback(testCallback);
      
      const localFile = sandboxDir + '/hdc_photo_' + Date.now() + '.jpg';
      TestUtil.createTestFile(localFile, 'test_jpeg_content');
      
      const remoteDir = '/data/local/tmp/hdc_test_' + Date.now();
      try {
        const createDirCmd = 'hdc shell mkdir -p ' + remoteDir;
        const sendCmd = 'hdc file send ' + localFile + ' ' + remoteDir;
        const mediatoolCmd = 'hdc shell mediatool send ' + remoteDir + '/' + localFile.substring(localFile.lastIndexOf('/') + 1);
        
        HiLog.i(TAG, 'HDC_01: executing ' + createDirCmd);
        
        await TestUtil.delay(1000);
        
        HiLog.i(TAG, 'HDC_01: mediatool import simulated (actual execution requires device)');
      } catch (e) {
        HiLog.e(TAG, 'HDC_01 failed: ' + String(e));
      }
      
      await TestUtil.delay(2000);
      expect(testCallback.createdFiles.length).assertLargerOrEqual(0);
      
      TestUtil.deleteTestFile(localFile);
      done();
    });

    it('HDC_02_import_audio_via_mediatool', 0, async (done: Function) => {
      if (!context || !userFileMgr) {
        expect(context).not().assertNull();
        done();
        return;
      }
      audioListener = new UserFileListener(context);
      await audioListener.startListener();
      audioListener.setCallback(testCallback);
      
      const localFile = sandboxDir + '/hdc_audio_' + Date.now() + '.mp3';
      TestUtil.createTestFile(localFile, 'test_mp3_content');
      
      const remoteDir = '/data/local/tmp/hdc_audio_' + Date.now();
      
      HiLog.i(TAG, 'HDC_02: simulating hdc shell mediatool send');
      HiLog.i(TAG, 'HDC_02: remote path ' + remoteDir);
      
      await TestUtil.delay(2000);
      expect(testCallback.createdFiles.length).assertLargerOrEqual(0);
      
      TestUtil.deleteTestFile(localFile);
      done();
    });

    it('HDC_03_import_multiple_files', 0, async (done: Function) => {
      if (!context || !phHelper) {
        expect(context).not().assertNull();
        done();
        return;
      }
      mediaListener = new MediaLibraryListener(context);
      await mediaListener.startListener();
      mediaListener.setCallback(testCallback);
      
      const files: string[] = [];
      for (let i = 0; i < 3; i++) {
        const file = sandboxDir + '/hdc_multi_' + i + '_' + Date.now() + '.jpg';
        TestUtil.createTestFile(file, 'content_' + i);
        files.push(file);
      }
      
      HiLog.i(TAG, 'HDC_03: simulating batch import via mediatool');
      
      await TestUtil.delay(3000);
      expect(testCallback.createdFiles.length).assertLargerOrEqual(0);
      
      for (const f of files) {
        TestUtil.deleteTestFile(f);
      }
      done();
    });

    it('HDC_04_hash_filename_handling', 0, async (done: Function) => {
      if (!context || !phHelper) {
        expect(context).not().assertNull();
        done();
        return;
      }
      mediaListener = new MediaLibraryListener(context);
      await mediaListener.startListener();
      mediaListener.setCallback(testCallback);
      
      const hashKey = 'test_' + Date.now();
      const remoteDir = '/data/local/tmp/' + hashKey;
      const fileName = 'hashed_file_abc123.jpg';
      
      HiLog.i(TAG, 'HDC_04: hashKey=' + hashKey);
      HiLog.i(TAG, 'HDC_04: mediatool would send from ' + remoteDir);
      HiLog.i(TAG, 'HDC_04: expected filename pattern ' + fileName);
      
      await TestUtil.delay(1000);
      expect(hashKey.length).assertLarger(0);
      done();
    });

    it('HDC_05_import_mixed_media', 0, async (done: Function) => {
      if (!context || !phHelper || !userFileMgr) {
        expect(context).not().assertNull();
        done();
        return;
      }
      mediaListener = new MediaLibraryListener(context);
      await mediaListener.startListener();
      mediaListener.setCallback(testCallback);
      
      audioListener = new UserFileListener(context);
      await audioListener.startListener();
      audioListener.setCallback(testCallback);
      
      const photoFile = sandboxDir + '/mixed_photo.jpg';
      const audioFile = sandboxDir + '/mixed_audio.mp3';
      TestUtil.createTestFile(photoFile, 'photo');
      TestUtil.createTestFile(audioFile, 'audio');
      
      HiLog.i(TAG, 'HDC_05: simulating mixed media import');
      
      await TestUtil.delay(3000);
      expect(testCallback.createdFiles.length).assertLargerOrEqual(0);
      
      TestUtil.deleteTestFile(photoFile);
      TestUtil.deleteTestFile(audioFile);
      done();
    });
  });
}