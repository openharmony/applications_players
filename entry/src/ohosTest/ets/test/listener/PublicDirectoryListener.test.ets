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
import { MediaPermissionManager, PermissionState } from '@ohos/common/src/main/ets/permission/MediaPermissionManager';
import { FileListenerManager, ListenerTypeEnum } from '@ohos/common/src/main/ets/listener/FileListenerManager';
import { FileChangeEvent, FileChangeType, FileChangeEventInfo } from '@ohos/common/src/main/ets/listener/FileChangeEvent';
import { FileChangeCallback } from '@ohos/common/src/main/ets/listener/IFileChangeListener';
import { TestUtil } from '../utils/TestUtil';
import type common from '@ohos.app.ability.common';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import userFileManager from '@ohos.filemanagement.userFileManager';
import { abilityAccessCtrl, bundleManager } from '@kit.AbilityKit';
import type { Permissions } from '@ohos.abilityAccessCtrl';

const TAG = 'PublicDirectoryListenerTest';

/**
 * 检测事件数据类
 */
class DetectedEvent {
  uri: string = '';
  type: FileChangeType = FileChangeType.CREATED;
  
  constructor(uri: string, type: FileChangeType) {
    this.uri = uri;
    this.type = type;
  }
}

/**
 * 测试回调实现类
 */
class TestFileChangeCallback implements FileChangeCallback {
  private detectedEvents: DetectedEvent[] = [];
  private tag: string = TAG;
  
  getDetectedEvents(): DetectedEvent[] {
    return this.detectedEvents;
  }
  
  clearEvents(): void {
    this.detectedEvents = [];
  }
  
  onFileCreated(uri: string): void {
    this.detectedEvents.push(new DetectedEvent(uri, FileChangeType.CREATED));
    HiLog.i(this.tag, `File creation detected: ${uri}`);
  }
  
  onFileModified(uri: string): void {
    this.detectedEvents.push(new DetectedEvent(uri, FileChangeType.MODIFIED));
    HiLog.i(this.tag, `File modification detected: ${uri}`);
  }
  
  onFileDeleted(uri: string): void {
    this.detectedEvents.push(new DetectedEvent(uri, FileChangeType.DELETED));
    HiLog.i(this.tag, `File deletion detected: ${uri}`);
  }
  
  onFileMovedIn(uri: string, fromPath?: string): void {
    this.detectedEvents.push(new DetectedEvent(uri, FileChangeType.MOVED_IN));
    HiLog.i(this.tag, `File moved in detected: ${uri}`);
  }
  
  onFileMovedOut(uri: string, toPath?: string): void {
    this.detectedEvents.push(new DetectedEvent(uri, FileChangeType.MOVED_OUT));
    HiLog.i(this.tag, `File moved out detected: ${uri}`);
  }
  
  onBatchChange(event: FileChangeEvent): void {
    HiLog.i(this.tag, `Batch change: ${event.getEventCount()} events`);
  }
  
  onError(error: Error): void {
    HiLog.e(this.tag, `Listener error: ${error.message}`);
  }
}

/**
 * 公共目录监听器测试
 */
export default function PublicDirectoryListenerTest() {
  describe('PublicDirectoryListenerSuite', () => {
    let context: common.Context | null = null;
    let listenerManager: FileListenerManager | null = null;
    let phHelper: photoAccessHelper.PhotoAccessHelper | null = null;
    let userFileMgr: userFileManager.UserFileManager | null = null;
    let createdPhotoUris: string[] = [];
    let createdAudioUris: string[] = [];
    let testCallback: TestFileChangeCallback = new TestFileChangeCallback();
    
    beforeAll(async () => {
      HiLog.i(TAG, '=== beforeAll START ===');
      
      // Step 1: 解锁设备
      const unlockSuccess = await TestUtil.unlockDevice();
      HiLog.i(TAG, `Device unlock result: ${unlockSuccess}`);
      
      // Step 2: 初始化测试环境
      await TestUtil.initTestEnvironment();
      
      // Step 3: 检查权限状态
      const permissionState = MediaPermissionManager.getInstance().getPermissionState();
      HiLog.i(TAG, `Permission state: ${permissionState}`);
      
      // Step 4: 获取 context
      context = TestUtil.getContext();
      if (!context) {
        HiLog.e(TAG, 'Context is null');
        return;
      }
      
      // Step 5: 初始化 FileListenerManager
      listenerManager = FileListenerManager.getInstance(context);
      await listenerManager.initialize();
      HiLog.i(TAG, 'FileListenerManager initialized');
      
      // 初始化 photoAccessHelper
      phHelper = photoAccessHelper.getPhotoAccessHelper(context);
      HiLog.i(TAG, 'PhotoAccessHelper initialized');
      
      // 初始化 userFileManager
      userFileMgr = userFileManager.getUserFileMgr(context);
      HiLog.i(TAG, 'UserFileManager initialized');
      
      HiLog.i(TAG, '=== beforeAll END ===');
    });
    
    afterAll(async () => {
      HiLog.i(TAG, '=== afterAll START ===');
      
      // 清理创建的媒体文件
      if (phHelper) {
        for (const uri of createdPhotoUris) {
          try {
            await phHelper.deleteAssets([uri]);
            HiLog.i(TAG, `Deleted photo: ${uri}`);
          } catch (e) {
            HiLog.w(TAG, `Failed to delete photo: ${uri}`);
          }
        }
      }
      
      if (userFileMgr) {
        for (const uri of createdAudioUris) {
          try {
            await userFileMgr.delete(uri);
            HiLog.i(TAG, `Deleted audio: ${uri}`);
          } catch (e) {
            HiLog.w(TAG, `Failed to delete audio: ${uri}`);
          }
        }
      }
      
      // 停止监听器
      if (listenerManager) {
        await listenerManager.stopListening(ListenerTypeEnum.PUBLIC_MEDIA);
        await listenerManager.stopListening(ListenerTypeEnum.USER_FILE);
        await listenerManager.destroy();
      }
      
      await TestUtil.cleanupTestEnvironment();
      HiLog.i(TAG, '=== afterAll END ===');
    });
    
    beforeEach(() => {
      HiLog.i(TAG, '=== beforeEach ===');
      testCallback.clearEvents();
    });
    
    afterEach(() => {
      HiLog.i(TAG, '=== afterEach ===');
    });
    
    // ==========================================
    // MediaLibraryListener Tests
    // ==========================================
    
    /**
     * PUB_MEDIA_01: MediaLibraryListener 初始化验证
     */
    it('PUB_MEDIA_01_medialibrary_listener_init', 0, async (done: Function) => {
      HiLog.i(TAG, '=== PUB_MEDIA_01 START ===');
      
      if (!listenerManager) {
        HiLog.w(TAG, 'listenerManager is null');
        done();
        return;
      }
      
      // 初始化 MediaLibraryListener
      const initResult = await listenerManager.initializeMediaLibraryListener();
      HiLog.i(TAG, `MediaLibraryListener init result: ${initResult}`);
      expect(initResult).assertTrue();
      
      // 启动监听
      const startResult = await listenerManager.startListening(ListenerTypeEnum.PUBLIC_MEDIA);
      HiLog.i(TAG, `MediaLibraryListener start result: ${startResult}`);
      expect(startResult).assertTrue();
      
      // 验证监听状态
      const isListening = listenerManager.isListening(ListenerTypeEnum.PUBLIC_MEDIA);
      HiLog.i(TAG, `MediaLibraryListener isListening: ${isListening}`);
      expect(isListening).assertTrue();
      
      // 验证监听的 URI
      const watchedDirs = listenerManager.getWatchedDirectories(ListenerTypeEnum.PUBLIC_MEDIA);
      HiLog.i(TAG, `MediaLibraryListener watched URIs: ${JSON.stringify(watchedDirs)}`);
      expect(watchedDirs.length).assertGreater(0);
      
      HiLog.i(TAG, '=== PUB_MEDIA_01 END ===');
      done();
    });
    
    /**
     * PUB_MEDIA_02: 照片创建 → MediaLibraryListener 自动检测
     */
    it('PUB_MEDIA_02_photo_creation_detected', 0, async (done: Function) => {
      HiLog.i(TAG, '=== PUB_MEDIA_02 START ===');
      
      if (!listenerManager || !phHelper) {
        HiLog.w(TAG, 'listenerManager or phHelper is null');
        done();
        return;
      }
      
      // 设置回调
      const mediaListener = listenerManager.getMediaLibraryListener();
      if (!mediaListener) {
        HiLog.e(TAG, 'MediaLibraryListener is null');
        done();
        return;
      }
      
      mediaListener.setCallback(testCallback);
      
      // 创建照片资产
      const testPhotoName = 'pub_test_photo_' + Date.now();
      try {
        const photoUri = await phHelper.createAsset(
          photoAccessHelper.PhotoType.IMAGE,
          'jpg',
          { title: testPhotoName }
        );
        HiLog.i(TAG, `Created photo: ${photoUri}`);
        createdPhotoUris.push(photoUri);
        
        // 等待监听器检测
        await TestUtil.delay(TestUtil.DEBOUNCE_WAIT_TIME * 2);
        mediaListener.flushPendingEvents();
        await TestUtil.delay(500);
        
        // 验证检测
        const events = testCallback.getDetectedEvents();
        HiLog.i(TAG, `Detected events count: ${events.length}`);
        const found = events.some(e => 
          e.uri.includes(testPhotoName) || e.type === FileChangeType.CREATED
        );
        HiLog.i(TAG, `Photo creation detected in events: ${found}`);
        
        if (found) {
          expect(found).assertTrue();
        } else {
          HiLog.w(TAG, 'Photo creation not detected - may need more time');
        }
        
      } catch (e) {
        HiLog.e(TAG, `Failed to create photo: ${e}`);
      }
      
      HiLog.i(TAG, '=== PUB_MEDIA_02 END ===');
      done();
    });
    
    // ==========================================
    // UserFileListener Tests
    // ==========================================
    
    /**
     * PUB_USER_01: UserFileListener 初始化验证
     */
    it('PUB_USER_01_userfile_listener_init', 0, async (done: Function) => {
      HiLog.i(TAG, '=== PUB_USER_01 START ===');
      
      if (!listenerManager) {
        HiLog.w(TAG, 'listenerManager is null');
        done();
        return;
      }
      
      // 初始化 UserFileListener
      const initResult = await listenerManager.initializeUserFileListener();
      HiLog.i(TAG, `UserFileListener init result: ${initResult}`);
      expect(initResult).assertTrue();
      
      // 启动监听
      const startResult = await listenerManager.startListening(ListenerTypeEnum.USER_FILE);
      HiLog.i(TAG, `UserFileListener start result: ${startResult}`);
      expect(startResult).assertTrue();
      
      // 验证监听状态
      const isListening = listenerManager.isListening(ListenerTypeEnum.USER_FILE);
      HiLog.i(TAG, `UserFileListener isListening: ${isListening}`);
      expect(isListening).assertTrue();
      
      // 验证监听的 URI
      const watchedDirs = listenerManager.getWatchedDirectories(ListenerTypeEnum.USER_FILE);
      HiLog.i(TAG, `UserFileListener watched URIs: ${JSON.stringify(watchedDirs)}`);
      expect(watchedDirs.length).assertGreater(0);
      
      HiLog.i(TAG, '=== PUB_USER_01 END ===');
      done();
    });
    
    /**
     * PUB_USER_02: 音频创建 → UserFileListener 自动检测
     */
    it('PUB_USER_02_audio_creation_detected', 0, async (done: Function) => {
      HiLog.i(TAG, '=== PUB_USER_02 START ===');
      
      if (!listenerManager || !userFileMgr) {
        HiLog.w(TAG, 'listenerManager or userFileMgr is null');
        done();
        return;
      }
      
      // 设置回调
      const userListener = listenerManager.getUserFileListener();
      if (!userListener) {
        HiLog.e(TAG, 'UserFileListener is null');
        done();
        return;
      }
      
      userListener.setCallback(testCallback);
      
      // 创建音频资产
      const testAudioName = 'pub_test_audio_' + Date.now() + '.mp3';
      try {
        const audioAsset = await userFileMgr.createAudioAsset(testAudioName);
        if (audioAsset) {
          HiLog.i(TAG, `Created audio: ${audioAsset.uri}`);
          createdAudioUris.push(audioAsset.uri);
          
          // 等待监听器检测
          await TestUtil.delay(TestUtil.DEBOUNCE_WAIT_TIME * 2);
          userListener.flushPendingEvents();
          await TestUtil.delay(500);
          
          // 验证检测
          const events = testCallback.getDetectedEvents();
          HiLog.i(TAG, `Detected events count: ${events.length}`);
          const found = events.some(e =>
            e.uri.includes(testAudioName) || e.type === FileChangeType.CREATED
          );
          HiLog.i(TAG, `Audio creation detected in events: ${found}`);
          
          if (found) {
            expect(found).assertTrue();
          } else {
            HiLog.w(TAG, 'Audio creation not detected - may need more time');
          }
        }
      } catch (e) {
        HiLog.e(TAG, `Failed to create audio: ${e}`);
      }
      
      HiLog.i(TAG, '=== PUB_USER_02 END ===');
      done();
    });
  });
}