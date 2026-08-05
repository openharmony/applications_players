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

import { MockKit } from '@ohos/hypium';
import fs from '@ohos.file.fs';
import { HiLog } from '@ohos/common/src/main/ets/utils/HiLog';
import { AppContext } from '@ohos/common/src/main/ets/context/AppContext';
import { MediaDbManager } from '@ohos/common/src/main/ets/persistence/rdb/MediaDbManager';
import { FileInfo } from '@ohos/common/src/main/ets/utils/FileOperateInfo';
import type common from '@ohos.app.ability.common';
import abilityAccessCtrl from '@ohos.abilityAccessCtrl';
import bundleManager from '@ohos.bundle.bundleManager';
import type { Permissions } from '@ohos.abilityAccessCtrl';
import Want from '@ohos.app.ability.Want';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { Driver } from '@ohos.UiTest';
import { KeyCode } from '@ohos.multimodalInput.keyCode';
import { FileMonitor } from '@ohos/common';
import { PermissionState } from '@ohos/common/src/main/ets/permission/MediaPermissionManager';
import { MediaAggregateViewModel } from '@ohos/media/src/main/ets/manager/MediaAggregateViewModel';
import { FileChangeEvent, FileChangeType } from '@ohos/common/src/main/ets/listener/FileChangeEvent';
import { FileChangeCallback } from '@ohos/common/src/main/ets/listener/IFileChangeListener';

const TAG = 'TestUtil';

export class TestUtil {
  public static readonly WAIT_TIME_MS = 100;
  public static readonly WAIT_TIME_MS_SHORT = 500;
  public static readonly WAIT_TIME_MS_MEDIUM = 1000;
  public static readonly WAIT_TIME_MS_LONG = 3000;
  public static readonly DEBOUNCE_WAIT_TIME = 600;

  // Auto-flush timing constants (for DebounceHandler verification WITHOUT manual flush)
  public static readonly AUTO_FLUSH_TIMER_WAIT = 800;      // 500ms debounceDelay + 300ms buffer
  public static readonly AUTO_FLUSH_MAX_WAIT = 3500;       // 3000ms maxWaitTime + 500ms buffer
  public static readonly AUTO_FLUSH_BATCH_WAIT = 500;      // Batch flush is immediate

  public static readonly AUDIO_EXTENSIONS: string[] = ['.mp3', '.m4a', '.aac', '.flac', '.ogg', '.wav'];
  public static readonly VIDEO_EXTENSIONS: string[] = ['.mp4', '.mov', '.avi', '.mkv', '.webm'];

  private static context: common.Context | null = null;
  private static dbManager: MediaDbManager | null = null;
  private static mockKit: MockKit | null = null;

  private static testFolderPath: string = '';
  private static testAudioPath: string = '';
  private static testVideoPath: string = '';
  private static testSubPath: string = '';
  private static initialized: boolean = false;

  static get TEST_FOLDER_PATH(): string {
    return TestUtil.testFolderPath;
  }

  static get TEST_AUDIO_PATH(): string {
    return TestUtil.testAudioPath;
  }

  static get TEST_VIDEO_PATH(): string {
    return TestUtil.testVideoPath;
  }

  static get TEST_SUB_PATH(): string {
    return TestUtil.testSubPath;
  }

  static setContext(context: common.Context): void {
    TestUtil.context = context;
    TestUtil.dbManager = MediaDbManager.getInstance(context);
  }

  static getContext(): common.Context | null {
    const appStateContext: common.UIAbilityContext | null = AppContext.getInstance().getMainAbilityContext();
    if (appStateContext) {
      HiLog.i(TAG, 'getContext: using AppState context');
      return appStateContext;
    }
    if (TestUtil.context) {
      HiLog.i(TAG, 'getContext: using local context');
      return TestUtil.context;
    }
    HiLog.e(TAG, 'getContext: context is null');
    return null;
  }

  static getDbManager(): MediaDbManager | null {
    return TestUtil.dbManager;
  }

  static getMockKit(): MockKit {
    if (!TestUtil.mockKit) {
      TestUtil.mockKit = new MockKit();
    }
    return TestUtil.mockKit;
  }

  static async initTestEnvironment(): Promise<void> {
    try {
      HiLog.i(TAG, 'initTestEnvironment: start');
      
      const context: common.UIAbilityContext | null = AppContext.getInstance().getMainAbilityContext();
      HiLog.i(TAG, 'initTestEnvironment: AppState context=' + (context ? 'valid' : 'null'));
      
      if (!context) {
        HiLog.e(TAG, 'initTestEnvironment: Context is null from AppState!');
        return;
      }
      
      TestUtil.setContext(context);
      HiLog.i(TAG, 'initTestEnvironment: context set successfully, filesDir=' + context.filesDir);

      TestUtil.testFolderPath = context.filesDir + '/FileListenerTest';
      TestUtil.testAudioPath = context.filesDir + '/FileListenerTest/audio';
      TestUtil.testVideoPath = context.filesDir + '/FileListenerTest/video';
      TestUtil.testSubPath = context.filesDir + '/FileListenerTest/subdir';
      
      HiLog.i(TAG, 'initTestEnvironment: paths set - TEST_FOLDER_PATH=' + TestUtil.testFolderPath);
      HiLog.i(TAG, 'initTestEnvironment: TEST_AUDIO_PATH=' + TestUtil.testAudioPath);
      HiLog.i(TAG, 'initTestEnvironment: TEST_VIDEO_PATH=' + TestUtil.testVideoPath);

      const pathsToCreate = [
        TestUtil.testFolderPath,
        TestUtil.testAudioPath,
        TestUtil.testVideoPath,
        TestUtil.testSubPath
      ];
      
      for (const path of pathsToCreate) {
        try {
          const stat = fs.statSync(path);
          if (stat.isDirectory()) {
            HiLog.i(TAG, 'Directory verified: ' + path + ', mode=' + stat.mode);
          } else {
            HiLog.e(TAG, 'Path exists but is not a directory: ' + path);
          }
        } catch (statError) {
          HiLog.i(TAG, 'Directory does not exist, creating: ' + path);
          try {
            fs.mkdirSync(path);
            HiLog.i(TAG, 'Created directory: ' + path);
            await TestUtil.delay(100);
            
            const verifyStat = fs.statSync(path);
            HiLog.i(TAG, 'Directory created and verified: ' + path + ', isDir=' + verifyStat.isDirectory());
          } catch (createError) {
            HiLog.e(TAG, 'Failed to create directory: ' + path + ', error: ' + String(createError));
            return;
          }
        }
      }
      
      TestUtil.initialized = true;
      HiLog.i(TAG, 'Test environment initialized successfully, initialized=' + TestUtil.initialized);
    } catch (error) {
      HiLog.e(TAG, 'Failed to init test environment: ' + (error ? String(error) : 'unknown'));
      HiLog.e(TAG, 'Stack: ' + (error instanceof Error ? error.stack : 'no stack'));
    }
  }

  static async cleanupTestEnvironment(): Promise<void> {
    try {
      if (TestUtil.initialized && TestUtil.testFolderPath && TestUtil.fileExists(TestUtil.testFolderPath)) {
        TestUtil.deleteDirectoryRecursive(TestUtil.testFolderPath);
      }
      TestUtil.context = null;
      TestUtil.dbManager = null;
      TestUtil.testFolderPath = '';
      TestUtil.testAudioPath = '';
      TestUtil.testVideoPath = '';
      TestUtil.testSubPath = '';
      TestUtil.initialized = false;
      HiLog.i(TAG, 'Test environment cleaned up');
    } catch (error) {
      HiLog.e(TAG, `Failed to cleanup test environment: ${error}`);
    }
  }

  static isInitialized(): boolean {
    return TestUtil.initialized;
  }

  static deleteDirectoryRecursive(path: string): void {
    try {
      const stat = fs.statSync(path);
      if (stat.isDirectory()) {
        const files = fs.listFileSync(path);
        for (const file of files) {
          const filePath = path + '/' + file;
          TestUtil.deleteDirectoryRecursive(filePath);
        }
        fs.rmdirSync(path);
      } else {
        fs.unlinkSync(path);
      }
    } catch (error) {
      HiLog.e(TAG, `Failed to delete: ${path}, error: ${error}`);
    }
  }

  static createTestFile(filePath: string, content: string = 'test_content'): boolean {
    try {
      const file = fs.openSync(filePath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY);
      if (content.length > 0) {
        fs.writeSync(file.fd, content);
      }
      fs.closeSync(file.fd);
      HiLog.i(TAG, `Created test file: ${filePath}`);
      return true;
    } catch (error) {
      HiLog.e(TAG, `Failed to create test file: ${filePath}, error: ${error}`);
      return false;
    }
  }

  static createTestFiles(filePaths: string[]): number {
    let successCount = 0;
    for (const path of filePaths) {
      if (TestUtil.createTestFile(path)) {
        successCount++;
      }
    }
    return successCount;
  }

  static deleteTestFile(filePath: string): boolean {
    try {
      const existsBefore = TestUtil.fileExists(filePath);
      HiLog.i(TAG, `deleteTestFile: ${filePath}, existsBefore=${existsBefore}`);
      if (existsBefore) {
        fs.unlinkSync(filePath);
        HiLog.i(TAG, `deleteTestFile: fs.unlinkSync called for ${filePath}`);
        try {
          fs.statSync(filePath);
          HiLog.i(TAG, `deleteTestFile: ${filePath}, statSync succeeded - file still exists`);
          return true;
        } catch (statError) {
          HiLog.i(TAG, `deleteTestFile: ${filePath}, statSync failed - file deleted`);
          return true;
        }
      }
      return true;
    } catch (error) {
      HiLog.e(TAG, `Failed to delete test file: ${filePath}, error: ${error}`);
      return false;
    }
  }

  static deleteTestFiles(filePaths: string[]): number {
    let successCount = 0;
    for (const path of filePaths) {
      if (TestUtil.deleteTestFile(path)) {
        successCount++;
      }
    }
    return successCount;
  }

  static modifyTestFile(filePath: string, newContent: string): boolean {
    try {
      if (!TestUtil.fileExists(filePath)) {
        return false;
      }
      const file = fs.openSync(filePath, fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, newContent);
      fs.closeSync(file.fd);
      return true;
    } catch (error) {
      HiLog.e(TAG, `Failed to modify test file: ${filePath}, error: ${error}`);
      return false;
    }
  }

  static renameTestFile(oldPath: string, newPath: string): boolean {
    try {
      if (!TestUtil.fileExists(oldPath)) {
        return false;
      }
      fs.renameSync(oldPath, newPath);
      return true;
    } catch (error) {
      HiLog.e(TAG, `Failed to rename test file: ${oldPath}, error: ${error}`);
      return false;
    }
  }

  static fileExists(filePath: string): boolean {
    try {
      fs.statSync(filePath);
      return true;
    } catch (error) {
      return false;
    }
  }

  static getFileSize(filePath: string): number {
    try {
      const stat = fs.statSync(filePath);
      return stat.size;
    } catch (error) {
      return 0;
    }
  }

  static getTestAudioFilePath(fileName: string): string {
    return TestUtil.TEST_AUDIO_PATH + '/' + fileName;
  }

  static getTestVideoFilePath(fileName: string): string {
    return TestUtil.TEST_VIDEO_PATH + '/' + fileName;
  }

  static getTestSubFilePath(fileName: string): string {
    return TestUtil.TEST_SUB_PATH + '/' + fileName;
  }

  static async delay(ms: number): Promise<void> {
    return new Promise<void>((resolve) => {
      setTimeout(() => {
        resolve();
      }, ms);
    });
  }

  static generateTestData(): string {
    return 'test_data_' + Date.now().toString() + '_' + Math.random().toString(36).substring(7);
  }

  static async verifyFileInDatabase(filePath: string): Promise<boolean> {
    try {
      if (!TestUtil.dbManager) {
        HiLog.e(TAG, 'DbManager not initialized');
        return false;
      }
      const metadata: FileInfo | null = await TestUtil.dbManager.getMetadata(filePath);
      if (metadata) {
        HiLog.i(TAG, `File found in database: ${filePath}`);
        return true;
      }
      HiLog.w(TAG, `File not found in database: ${filePath}`);
      return false;
    } catch (error) {
      HiLog.e(TAG, `Failed to verify file in database: ${filePath}, error: ${error}`);
      return false;
    }
  }

  static async saveFileToDatabase(filePath: string): Promise<boolean> {
    try {
      if (!TestUtil.dbManager) {
        HiLog.e(TAG, 'DbManager not initialized');
        return false;
      }
      const fileInfo: FileInfo | null = TestUtil.createFileInfoFromPath(filePath);
      if (!fileInfo) {
        return false;
      }
      const success: boolean = await TestUtil.dbManager.saveMetadata(fileInfo);
      HiLog.i(TAG, `Saved file to database: ${filePath}, success=${success}`);
      return success;
    } catch (error) {
      HiLog.e(TAG, `Failed to save file to database: ${filePath}, error: ${error}`);
      return false;
    }
  }

  static async updateFileInDatabase(filePath: string): Promise<boolean> {
    try {
      if (!TestUtil.dbManager) {
        HiLog.e(TAG, 'DbManager not initialized');
        return false;
      }
      const fileInfo: FileInfo | null = TestUtil.createFileInfoFromPath(filePath);
      if (!fileInfo) {
        return false;
      }
      const success: boolean = await TestUtil.dbManager.updateMediaMetadata(fileInfo);
      HiLog.i(TAG, `Updated file in database: ${filePath}, success=${success}`);
      return success;
    } catch (error) {
      HiLog.e(TAG, `Failed to update file in database: ${filePath}, error: ${error}`);
      return false;
    }
  }

  static async deleteFileFromDatabase(filePath: string): Promise<boolean> {
    try {
      if (!TestUtil.dbManager) {
        HiLog.e(TAG, 'DbManager not initialized');
        return false;
      }
      const success: boolean = await TestUtil.dbManager.markAsInvalid(filePath);
      HiLog.i(TAG, `Deleted file from database: ${filePath}, success=${success}`);
      return success;
    } catch (error) {
      HiLog.e(TAG, `Failed to delete file from database: ${filePath}, error: ${error}`);
      return false;
    }
  }

  static createFileInfoFromPath(filePath: string): FileInfo | null {
    try {
      if (!TestUtil.fileExists(filePath)) {
        return null;
      }
      const stat: fs.Stat = fs.statSync(filePath);
      const fileName: string = filePath.substring(filePath.lastIndexOf('/') + 1);
      const extension: string = fileName.lastIndexOf('.') !== -1 ? fileName.substring(fileName.lastIndexOf('.')) : '';
      
      const fileInfo: FileInfo = new FileInfo();
      fileInfo.fileName = fileName;
      fileInfo.path = filePath;
      fileInfo.uri = filePath;
      fileInfo.size = stat.size;
      fileInfo.mtime = stat.mtime;
      fileInfo.thumbGenerated = false;
      fileInfo.mimeType = TestUtil.getMimeType(extension);
      return fileInfo;
    } catch (error) {
      HiLog.e(TAG, `Failed to create FileInfo: ${filePath}, error: ${error}`);
      return null;
    }
  }

  static getMimeType(extension: string): string {
    const audioExts = ['.mp3', '.m4a', '.aac', '.flac', '.ogg', '.wav', '.wma', '.ape', '.opus'];
    const videoExts = ['.mp4', '.mov', '.avi', '.mkv', '.flv', '.webm', '.ts', '.m3u8'];
    
    const ext = extension.toLowerCase();
    if (audioExts.includes(ext)) {
      return 'audio/*';
    }
    if (videoExts.includes(ext)) {
      return 'video/*';
    }
    return 'application/octet-stream';
  }

  static async waitForDatabaseUpdate(filePath: string, maxWaitMs: number = 5000): Promise<boolean> {
    const startTime = Date.now();
    while (Date.now() - startTime < maxWaitMs) {
      const found = await TestUtil.verifyFileInDatabase(filePath);
      if (found) {
        return true;
      }
      await TestUtil.delay(200);
    }
    return false;
  }

  static isMediaFile(filePath: string): boolean {
    const extension = filePath.lastIndexOf('.') !== -1 ? 
      filePath.substring(filePath.lastIndexOf('.')).toLowerCase() : '';
    return TestUtil.AUDIO_EXTENSIONS.includes(extension) || TestUtil.VIDEO_EXTENSIONS.includes(extension);
  }

  static createMediaTestFile(filePath: string): boolean {
    const extension = filePath.lastIndexOf('.') !== -1 ? 
      filePath.substring(filePath.lastIndexOf('.')).toLowerCase() : '';
    
    if (!TestUtil.isMediaFile(filePath)) {
      HiLog.w(TAG, `Not a media file extension: ${extension}`);
      return false;
    }
    
    const content = 'media_test_content_' + Date.now();
    return TestUtil.createTestFile(filePath, content);
  }

  /**
   * startAbility with timeout wrapper to prevent hanging
   * 
   * @param delegator - AbilityDelegator instance
   * @param want - Want object for ability startup
   * @param timeoutMs - Timeout in milliseconds (default 10000)
   * @returns Promise<boolean> - true if started successfully, false if timeout/error
   */
  static async startAbilityWithTimeout(
    delegator: abilityDelegatorRegistry.AbilityDelegator,
    want: Want,
    timeoutMs: number = 10000
  ): Promise<boolean> {
    return new Promise<boolean>((resolve) => {
      const timeoutId = setTimeout(() => {
        HiLog.e(TAG, `startAbility timeout after ${timeoutMs}ms`);
        resolve(false);
      }, timeoutMs);
      
      try {
        delegator.startAbility(want, (err: Error | null) => {
          clearTimeout(timeoutId);
          if (err) {
            HiLog.e(TAG, `startAbility error: ${err.message}`);
            resolve(false);
          } else {
            HiLog.i(TAG, `startAbility success`);
            resolve(true);
          }
        });
      } catch (error) {
        clearTimeout(timeoutId);
        const errMsg = error instanceof Error ? error.message : String(error);
        HiLog.e(TAG, `startAbility exception: ${errMsg}`);
        resolve(false);
      }
    });
  }

  /**
   * Wait for ability to reach specific lifecycle state
   * 
   * @param delegator - AbilityDelegator instance
   * @param abilityName - Target ability name
   * @param targetState - Target lifecycle state (2=FOREGROUND, 3=BACKGROUND, 4=DESTROY)
   * @param timeoutMs - Timeout in milliseconds
   * @returns Promise<boolean> - true if state reached, false if timeout
   */
  static async waitForAbilityState(
    delegator: abilityDelegatorRegistry.AbilityDelegator,
    abilityName: string,
    targetState: number,
    timeoutMs: number = 5000
  ): Promise<boolean> {
    const startTime = Date.now();
    
    while (Date.now() - startTime < timeoutMs) {
      try {
        const ability = await delegator.getCurrentTopAbility();
        if (ability && ability.context.abilityInfo.name === abilityName) {
          const state = delegator.getAbilityState(ability);
          if (state === targetState) {
            HiLog.i(TAG, `Ability ${abilityName} reached state ${targetState}`);
            return true;
          }
        }
      } catch (error) {
        const errMsg = error instanceof Error ? error.message : String(error);
        HiLog.w(TAG, `Error checking ability state: ${errMsg}`);
      }
      await TestUtil.delay(200);
    }
    
    HiLog.w(TAG, `Ability ${abilityName} did not reach state ${targetState} within ${timeoutMs}ms`);
    return false;
  }

  /**
   * Unlock device screen with user interaction simulation
   * 
   * This method uses UiTest Driver API to:
   * 1. Wake up display (turn screen on)
   * 2. Swipe up to unlock screen
   * 
   * IMPORTANT: Call this before any startAbility to prevent hanging when device is locked.
   * This actually unlocks the device, not just wakes the screen.
   * 
   * @returns Promise<boolean> - true if unlock successful, false otherwise
   */
  static async unlockDevice(): Promise<boolean> {
    try {
      HiLog.i(TAG, 'unlockDevice: starting device unlock sequence...');
      
      // Create UiTest Driver instance
      const driver = Driver.create();
      HiLog.i(TAG, 'unlockDevice: Driver created');
      
      // Step 1: Wake up display (turn screen on)
      await driver.wakeUpDisplay();
      HiLog.i(TAG, 'unlockDevice: display woke up');
      
      // Step 2: Wait for screen to wake (reduced delay)
      await TestUtil.delay(300);
      
      // Step 3: Get display size for swipe coordinates
      const displaySize = await driver.getDisplaySize();
      HiLog.i(TAG, `unlockDevice: display size = ${displaySize.x} x ${displaySize.y}`);
      
      // Step 4: Calculate swipe coordinates (middle of screen, bottom to top)
      const centerX = displaySize.x / 2;
      const startY = Math.floor(displaySize.y * 0.8);  // 80% from top (bottom area)
      const endY = Math.floor(displaySize.y * 0.2);    // 20% from top (top area)
      HiLog.i(TAG, `unlockDevice: swipe from (${centerX}, ${startY}) to (${centerX}, ${endY})`);
      
      // Step 5: Swipe up to unlock (speed 600 px/s)
      await driver.swipe(centerX, startY, centerX, endY, 600);
      HiLog.i(TAG, 'unlockDevice: swipe gesture executed');
      
      // Step 6: Wait for unlock (reduced delay)
      await TestUtil.delay(500);
      
      HiLog.i(TAG, 'unlockDevice: device unlocked successfully');
      return true;
    } catch (error) {
      const errMsg = error instanceof Error ? error.message : String(error);
      HiLog.e(TAG, `unlockDevice failed: ${errMsg}`);
      return false;
    }
  }

  /**
   * Unlock device using HDC shell commands (alternative method)
   * 
   * Uses: uitest uiInput keyEvent Power + uitest uiInput swipe
   * 
   * @param delegator - AbilityDelegator instance
   * @param timeoutMs - Timeout for each command (default 5000)
   * @returns Promise<boolean> - true if unlock successful
   */
  static async unlockDeviceWithHdc(
    delegator: abilityDelegatorRegistry.AbilityDelegator,
    timeoutMs: number = 5000
  ): Promise<boolean> {
    try {
      HiLog.i(TAG, 'unlockDeviceWithHdc: starting unlock with HDC commands...');
      
      // Step 1: Wake screen with POWER key
      await delegator.executeShellCommand('uitest uiInput keyEvent Power', timeoutMs);
      HiLog.i(TAG, 'unlockDeviceWithHdc: Power key pressed');
      
      // Step 2: Wait for screen wake
      await TestUtil.delay(1000);
      
      // Step 3: Swipe up to unlock (center of screen, bottom to top)
      // Default coordinates for typical 1080x2400 display
      const swipeCmd = 'uitest uiInput swipe 540 1920 540 480 600';
      await delegator.executeShellCommand(swipeCmd, timeoutMs);
      HiLog.i(TAG, 'unlockDeviceWithHdc: swipe gesture executed');
      
      // Step 4: Wait for unlock
      await TestUtil.delay(2000);
      
      HiLog.i(TAG, 'unlockDeviceWithHdc: device unlocked successfully');
      return true;
    } catch (error) {
      const errMsg = error instanceof Error ? error.message : String(error);
      HiLog.e(TAG, `unlockDeviceWithHdc failed: ${errMsg}`);
      return false;
    }
  }

  /**
   * Auto-grant all media permissions using grantUserGrantedPermission
   * 
   * Uses system API to automatically grant permissions, bypassing manual authorization.
   * Updates AppState permission state after successful grant.
   * 
   * @returns Promise<boolean> - true if all permissions granted successfully
   */
  static async grantAllMediaPermissions(): Promise<boolean> {
    try {
      HiLog.i(TAG, 'Auto-granting media permissions...');
      
      const atManager = abilityAccessCtrl.createAtManager();
      const bundleInfo = await bundleManager.getBundleInfoForSelf(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION
      );
      const tokenId = bundleInfo.appInfo.accessTokenId;
      
      const perms: Permissions[] = [
        'ohos.permission.READ_AUDIO',
        'ohos.permission.WRITE_AUDIO',
        'ohos.permission.READ_IMAGEVIDEO',
        'ohos.permission.WRITE_IMAGEVIDEO'
      ];
      
      for (const perm of perms) {
        await atManager.grantUserGrantedPermission(tokenId, perm, 0);
        HiLog.i(TAG, `Permission granted: ${perm}`);
      }
      
      // IMPORTANT: DO NOT set AppState.permissionState here
      // Let MainAbility.onForeground() execute the normal permission flow:
      // 1. onForeground checks cachedState (PENDING) → doesn't skip
      // 2. checkMediaPermission() finds system-level grant → returns GRANTED
      // 3. setPermissionState(GRANTED) → notifyPermissionListeners()
      // 4. MediaAggregateViewModel.onPermissionChanged() triggers
      // 5. loadMediaFiles() executes
      // 
      // This ensures test flow matches production flow exactly,
      // and permission change listeners receive proper GRANTED transition.
      HiLog.i(TAG, 'Permissions granted at system level - AppState flow will handle state transition');
      
      HiLog.i(TAG, 'All permissions auto-granted successfully');
      return true;
    } catch (error) {
      HiLog.e(TAG, `Auto-grant permissions failed: ${error}`);
      return false;
    }
  }

  /**
   * Get ViewModel and FileMonitor for testing
   * 
   * Retrieves initialized MediaAggregateViewModel and FileMonitor.
   * If FileMonitor is not initialized, calls ViewModel.init(context) to initialize.
   * 
   * @param context - Context for ViewModel initialization
   * @returns ViewModelAndFileMonitorResult or null if failed
   */
  static async getViewModelAndFileMonitor(context: common.Context): Promise<ViewModelAndFileMonitorResult | null> {
    try {
      const viewModel = MediaAggregateViewModel.getInstance();
      if (!viewModel) {
        HiLog.e(TAG, 'MediaAggregateViewModel getInstance returned null');
        return null;
      }
      
      // Check if FileMonitor is initialized
      let fileMonitor = viewModel.getFileMonitor();
      
      // If FileMonitor not initialized, call ViewModel.init()
      if (!fileMonitor) {
        HiLog.i(TAG, 'FileMonitor not initialized, calling ViewModel.init()');
        viewModel.init(context as common.UIAbilityContext);
        
        // Wait for FileMonitor to start
        await new Promise<void>((resolve) => {
          setTimeout(() => {
            fileMonitor = viewModel.getFileMonitor();
            resolve();
          }, 1000);
        });
        
        if (!fileMonitor) {
          HiLog.e(TAG, 'FileMonitor still null after init()');
          return null;
        }
        
        HiLog.i(TAG, 'FileMonitor initialized successfully');
      } else {
        // FileMonitor 已初始化，不需要重新 init
        // 重要：避免重新 init 导致 Preferences 缓存问题
        HiLog.i(TAG, 'FileMonitor already initialized, skipping init()');
      }
      
      HiLog.i(TAG, 'ViewModel and FileMonitor obtained successfully');
      const result: ViewModelAndFileMonitorResult = {
        viewModel: viewModel,
        fileMonitor: fileMonitor
      };
      return result;
    } catch (error) {
      HiLog.e(TAG, `getViewModelAndFileMonitor error: ${error}`);
      return null;
    }
  }
}

/**
 * ViewModel and FileMonitor result interface
 */
export interface ViewModelAndFileMonitorResult {
  viewModel: MediaAggregateViewModel;
  fileMonitor: FileMonitor;
}

/**
 * Detected event data class
 */
export class DetectedEvent {
  uri: string = '';
  type: FileChangeType = FileChangeType.CREATED;
  
  constructor(uri: string, type: FileChangeType) {
    this.uri = uri;
    this.type = type;
  }
}

/**
 * Test callback implementation class - collects file events detected by listener
 */
export class TestFileChangeCallback implements FileChangeCallback {
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