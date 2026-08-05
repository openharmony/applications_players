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


import { HiLog } from '../utils/HiLog';
import { SandboxFileListener } from './impl/SandboxFileListener';
import { MediaLibraryListener } from './impl/MediaLibraryListener';
import { UserFileListener } from './impl/UserFileListener';
import { FileSyncEngine } from './FileSyncEngine';
import { FileChangeCallback, IFileListener, FileListenerConfig, FileSyncCallback } from './IFileChangeListener';
import { FileChangeEvent } from './FileChangeEvent';
import { IncrementalSyncManager } from '../scan/IncrementalSyncManager';
import { SupportedMediaFormats } from '../constants/media/SupportedMediaFormats';
import type common from '@ohos.app.ability.common';

const TAG = 'FileListenerManager';

/**
 * Shared callback implementation for all listener types.
 * Eliminates duplicate inner class definitions across initialize methods.
 */
class SharedListenerCallback implements FileChangeCallback {
  private syncEngine: FileSyncEngine;
  private incrementalSyncManager: IncrementalSyncManager;
  private errorTag: string;

  constructor(syncEngine: FileSyncEngine, incrementalSyncManager: IncrementalSyncManager, errorTag: string) {
    this.syncEngine = syncEngine;
    this.incrementalSyncManager = incrementalSyncManager;
    this.errorTag = errorTag;
  }

  public onBatchChange(event: FileChangeEvent): void {
    this.syncEngine.batchSync(event);
    this.incrementalSyncManager.handleFileChangeEvent(event);
  }

  public onFileCreated(filePath: string): void {
    this.syncEngine.syncFileCreated(filePath);
  }

  public onFileModified(filePath: string): void {
    this.syncEngine.syncFileModified(filePath);
  }

  public onFileDeleted(filePath: string): void {
    this.syncEngine.syncFileDeleted(filePath);
  }

  public onFileMovedIn(filePath: string): void {
    this.syncEngine.syncFileCreated(filePath);
  }

  public onFileMovedOut(filePath: string): void {
    this.syncEngine.syncFileDeleted(filePath);
  }

  public onError(error: Error): void {
    HiLog.e(this.errorTag, `Listener error: ${error.message}`);
  }
}

export interface ListenerType {
  SANDBOX: number;
  PUBLIC_MEDIA: number;
  USER_FILE: number;
}

export const ListenerTypeEnum: ListenerType = {
  SANDBOX: 0,
  PUBLIC_MEDIA: 1,
  USER_FILE: 2
};

export class FileListenerManager {
  private static instance: FileListenerManager | null = null;
  private context: common.Context;
  private sandboxListener: SandboxFileListener | null = null;
  private mediaLibraryListener: MediaLibraryListener | null = null;
  private userFileListener: UserFileListener | null = null;
  private syncEngine: FileSyncEngine;
  private incrementalSyncManager: IncrementalSyncManager;
  private listeners: Map<number, IFileListener> = new Map();
  private isInitialized: boolean = false;
  private isMediaLibraryInitialized: boolean = false;
  private isUserFileInitialized: boolean = false;

  private constructor(context: common.Context) {
    this.context = context;
    this.syncEngine = new FileSyncEngine(context);
    this.incrementalSyncManager = IncrementalSyncManager.getInstance(context);
    HiLog.i(TAG, 'FileListenerManager created');
  }

  public static getInstance(context: common.Context): FileListenerManager {
    if (!FileListenerManager.instance) {
      FileListenerManager.instance = new FileListenerManager(context);
    }
    return FileListenerManager.instance;
  }

  public async initialize(): Promise<boolean> {
    if (this.isInitialized) {
      return true;
    }

    HiLog.i(TAG, 'Initializing FileListenerManager');

    const mediaExtensions = SupportedMediaFormats.getAllSuffixes();

    const config: FileListenerConfig = {
      debounceDelay: 500,
      maxBatchSize: 100,
      maxWaitTime: 3000,
      watchEvents: 0x2 | 0x100 | 0x200 | 0x80 | 0x40 | 0x8,
      includeSubdirectories: true,
      fileExtensions: mediaExtensions
    };

    this.sandboxListener = new SandboxFileListener(this.context, config);

    // SyncCallback still defined inline as it's only used once
    class SyncCallbackImpl implements FileSyncCallback {
      private tag: string = TAG;
      onSyncStart(): void {
        HiLog.i(this.tag, 'Sync started');
      }
      onSyncComplete(count: number): void {
        HiLog.i(this.tag, `Sync completed: ${count} files processed`);
      }
      onSyncError(error: Error): void {
        HiLog.e(this.tag, `Sync error: ${error.message}`);
      }
      onFileProcessed(path: string, success: boolean): void {
        if (!success) {
          HiLog.w(this.tag, `File sync failed: ${path}`);
        }
      }
    }

    const syncCallback = new SyncCallbackImpl();
    this.syncEngine.setSyncCallback(syncCallback);

    // Use shared callback class
    const listenerCallback = new SharedListenerCallback(this.syncEngine, this.incrementalSyncManager, TAG);
    this.sandboxListener.setCallback(listenerCallback);
    this.listeners.set(ListenerTypeEnum.SANDBOX, this.sandboxListener);

    this.isInitialized = true;
    HiLog.i(TAG, 'FileListenerManager initialized');
    return true;
  }

  /**
   * Unified initialization for all listener types.
   * This method initializes SandboxFileListener, MediaLibraryListener, and UserFileListener
   * in a single call, providing a consistent entry point for FileMonitor.
   * 
   * @returns true if all listeners initialized successfully
   */
  public async initializeAllListeners(): Promise<boolean> {
    HiLog.i(TAG, 'Initializing all listeners');

    // Initialize SandboxFileListener
    const sandboxInit = await this.initialize();
    if (!sandboxInit) {
      HiLog.e(TAG, 'Failed to initialize SandboxFileListener');
      return false;
    }

    // Initialize MediaLibraryListener (for Photos/Videos detection)
    const mediaLibInit = await this.initializeMediaLibraryListener();
    if (!mediaLibInit) {
      HiLog.e(TAG, 'Failed to initialize MediaLibraryListener');
      // Continue with other listeners even if one fails
    }

    // Initialize UserFileListener (for Audio files detection)
    const userFileInit = await this.initializeUserFileListener();
    if (!userFileInit) {
      HiLog.e(TAG, 'Failed to initialize UserFileListener');
      // Continue with other listeners even if one fails
    }

    HiLog.i(TAG, 'All listeners initialized');
    return true;
  }

  /**
   * Start all initialized listeners.
   * This method starts all listeners that have been successfully initialized.
   * 
   * @returns true if all listeners started successfully
   */
  public async startAllListeners(): Promise<boolean> {
    HiLog.i(TAG, 'Starting all listeners');

    let allStarted = true;

    // Start SandboxFileListener if initialized
    if (this.isInitialized) {
      const started = await this.startListening(ListenerTypeEnum.SANDBOX);
      if (!started) {
        HiLog.e(TAG, 'Failed to start SandboxFileListener');
        allStarted = false;
      }
    }

    // Start MediaLibraryListener if initialized
    if (this.isMediaLibraryInitialized) {
      const started = await this.startListening(ListenerTypeEnum.PUBLIC_MEDIA);
      if (!started) {
        HiLog.e(TAG, 'Failed to start MediaLibraryListener');
        allStarted = false;
      }
    }

    // Start UserFileListener if initialized
    if (this.isUserFileInitialized) {
      const started = await this.startListening(ListenerTypeEnum.USER_FILE);
      if (!started) {
        HiLog.e(TAG, 'Failed to start UserFileListener');
        allStarted = false;
      }
    }

    HiLog.i(TAG, 'All listeners started');
    return allStarted;
  }

  public async startListening(type: number = ListenerTypeEnum.SANDBOX): Promise<boolean> {
    const listener = this.listeners.get(type);
    if (listener) {
      return await listener.startListener();
    }
    HiLog.e(TAG, `Listener type ${type} not found`);
    return false;
  }

  public async stopListening(type: number = ListenerTypeEnum.SANDBOX): Promise<void> {
    const listener = this.listeners.get(type);
    if (listener) {
      await listener.stopListener();
    }
  }

  public async addWatchDirectory(path: string, type: number = ListenerTypeEnum.SANDBOX): Promise<boolean> {
    const listener = this.listeners.get(type);
    if (listener) {
      return await listener.addWatchPath(path);
    }
    return false;
  }

  public async removeWatchDirectory(path: string, type: number = ListenerTypeEnum.SANDBOX): Promise<void> {
    const listener = this.listeners.get(type);
    if (listener) {
      await listener.removeWatchPath(path);
    }
  }

  public getWatchedDirectories(type: number = ListenerTypeEnum.SANDBOX): string[] {
    const listener = this.listeners.get(type);
    if (listener) {
      return listener.getWatchedPaths();
    }
    return [];
  }

  public isListening(type: number = ListenerTypeEnum.SANDBOX): boolean {
    const listener = this.listeners.get(type);
    if (listener) {
      return listener.isListening();
    }
    return false;
  }

  public getSandboxListener(): SandboxFileListener | null {
    return this.sandboxListener;
  }

  public getMediaLibraryListener(): MediaLibraryListener | null {
    return this.mediaLibraryListener;
  }

  public getUserFileListener(): UserFileListener | null {
    return this.userFileListener;
  }

  public getSyncEngine(): FileSyncEngine {
    return this.syncEngine;
  }

  public getIncrementalSyncManager(): IncrementalSyncManager {
    return this.incrementalSyncManager;
  }

  public async initializeMediaLibraryListener(): Promise<boolean> {
    if (this.isMediaLibraryInitialized) {
      return true;
    }

    HiLog.i(TAG, 'Initializing MediaLibraryListener');

    this.mediaLibraryListener = new MediaLibraryListener(this.context);

    // Use shared callback class
    const mediaLibraryCallback = new SharedListenerCallback(
      this.syncEngine,
      this.incrementalSyncManager,
      'MediaLibraryListener'
    );
    this.mediaLibraryListener.setCallback(mediaLibraryCallback);
    this.listeners.set(ListenerTypeEnum.PUBLIC_MEDIA, this.mediaLibraryListener);

    this.isMediaLibraryInitialized = true;
    HiLog.i(TAG, 'MediaLibraryListener initialized');
    return true;
  }

  public async initializeUserFileListener(): Promise<boolean> {
    if (this.isUserFileInitialized) {
      return true;
    }

    HiLog.i(TAG, 'Initializing UserFileListener');

    this.userFileListener = new UserFileListener(this.context);

    // Use shared callback class
    const userFileCallback = new SharedListenerCallback(
      this.syncEngine,
      this.incrementalSyncManager,
      'UserFileListener'
    );
    this.userFileListener.setCallback(userFileCallback);
    this.listeners.set(ListenerTypeEnum.USER_FILE, this.userFileListener);

    this.isUserFileInitialized = true;
    HiLog.i(TAG, 'UserFileListener initialized');
    return true;
  }

  public cancelSync(): void {
    this.syncEngine.cancelSync();
  }

  public flushPendingEvents(type: number = ListenerTypeEnum.SANDBOX): void {
    if (type === ListenerTypeEnum.SANDBOX && this.sandboxListener) {
      this.sandboxListener.flushPendingEvents();
    } else if (type === ListenerTypeEnum.PUBLIC_MEDIA && this.mediaLibraryListener) {
      this.mediaLibraryListener.flushPendingEvents();
    } else if (type === ListenerTypeEnum.USER_FILE && this.userFileListener) {
      this.userFileListener.flushPendingEvents();
    }
  }

  public registerListener(type: number, listener: IFileListener): void {
    this.listeners.set(type, listener);
    HiLog.i(TAG, `Registered listener type ${type}`);
  }

  public unregisterListener(type: number): void {
    this.listeners.delete(type);
    HiLog.i(TAG, `Unregistered listener type ${type}`);
  }

  public async destroy(): Promise<void> {
    HiLog.i(TAG, 'Destroying FileListenerManager');

    for (const listener of this.listeners.values()) {
      await listener.stopListener();
    }

    this.listeners.clear();
    this.sandboxListener = null;
    this.mediaLibraryListener = null;
    this.userFileListener = null;
    this.incrementalSyncManager.release();
    FileListenerManager.instance = null;
    this.isInitialized = false;
    this.isMediaLibraryInitialized = false;
    this.isUserFileInitialized = false;

    HiLog.i(TAG, 'FileListenerManager destroyed');
  }
}
