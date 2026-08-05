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


import userFileManager from '@ohos.filemanagement.userFileManager';
import { HiLog } from '../../utils/HiLog';
import { FileChangeType, FileChangeEvent, FileChangeEventInfo } from '../FileChangeEvent';
import { DebounceHandler, DebounceCallback } from '../DebounceHandler';
import { FileChangeCallback, IFileListener, FileListenerConfig } from '../IFileChangeListener';
import type common from '@ohos.app.ability.common';

const TAG = 'UserFileListener';

const DEFAULT_AUDIO_URI = 'file://media/Audio';
const DEFAULT_PHOTO_URI = 'file://media/Photo';
const DEFAULT_ALBUM_URI = 'file://media/PhotoAlbum';

export type UserFileChangeEvent = 'deviceChange' | 'albumChange' | 'imageChange' | 'audioChange' | 'videoChange' | 'remoteFileChange';

export class UserFileListener implements IFileListener {
  private context: common.Context;
  private userFileMgr: userFileManager.UserFileManager | null = null;
  private debounceHandler: DebounceHandler;
  private callback: FileChangeCallback | null = null;
  private isRunning: boolean = false;
  private config: FileListenerConfig;
  private registeredEvents: Set<UserFileChangeEvent> = new Set();
  private uriChangeCallback: ((changeData: userFileManager.ChangeData) => void) | null = null;
  private eventCallbacks: Map<UserFileChangeEvent, () => void> = new Map();

  constructor(context: common.Context, config?: FileListenerConfig) {
    this.context = context;
    this.config = {
      debounceDelay: config?.debounceDelay ?? 500,
      maxBatchSize: config?.maxBatchSize ?? 100,
      maxWaitTime: config?.maxWaitTime ?? 3000,
      watchEvents: config?.watchEvents,
      includeSubdirectories: config?.includeSubdirectories ?? true,
      fileExtensions: config?.fileExtensions
    };

    this.debounceHandler = new DebounceHandler(
      this.config.debounceDelay,
      this.config.maxBatchSize,
      this.config.maxWaitTime
    );

    this.initUserFileManager();

    class DebounceCallbackImpl extends DebounceCallback {
      private listener: UserFileListener;
      
      constructor(listener: UserFileListener) {
        super();
        this.listener = listener;
      }
      
      onEvent(event: FileChangeEvent): void {
        this.listener.handleBatchEvent(event);
      }
    }

    this.debounceHandler.setCallback(new DebounceCallbackImpl(this));
    HiLog.i(TAG, 'UserFileListener created');
  }

  private initUserFileManager(): void {
    try {
      this.userFileMgr = userFileManager.getUserFileMgr(this.context);
      HiLog.i(TAG, 'UserFileManager initialized');
    } catch (error) {
      HiLog.e(TAG, `Failed to init UserFileManager: ${error}`);
    }
  }

  async startListener(): Promise<boolean> {
    if (this.isRunning) {
      HiLog.w(TAG, 'Listener already running');
      return true;
    }

    if (!this.userFileMgr) {
      HiLog.e(TAG, 'UserFileManager not initialized');
      return false;
    }

    HiLog.i(TAG, 'Starting user file listener');

    this.uriChangeCallback = (changeData: userFileManager.ChangeData) => {
      this.handleUserFileChange(changeData);
    };

    try {
      this.userFileMgr.on(
        DEFAULT_AUDIO_URI,
        true,
        this.uriChangeCallback
      );
      this.registeredEvents.add('audioChange');

      this.userFileMgr.on(
        DEFAULT_PHOTO_URI,
        true,
        this.uriChangeCallback
      );
      this.registeredEvents.add('videoChange');

      this.userFileMgr.on(
        DEFAULT_ALBUM_URI,
        true,
        this.uriChangeCallback
      );
      this.registeredEvents.add('albumChange');

      const audioEventCallback = () => {
        this.handleEventChange('audioChange');
      };
      this.userFileMgr.on('audioChange', audioEventCallback);
      this.eventCallbacks.set('audioChange', audioEventCallback);

      const videoEventCallback = () => {
        this.handleEventChange('videoChange');
      };
      this.userFileMgr.on('videoChange', videoEventCallback);
      this.eventCallbacks.set('videoChange', videoEventCallback);

      this.isRunning = true;
      HiLog.i(TAG, 'User file listener started successfully');
      return true;
    } catch (error) {
      HiLog.e(TAG, `Failed to register change listener: ${error}`);
      return false;
    }
  }

  async stopListener(): Promise<void> {
    if (!this.isRunning || !this.userFileMgr) {
      return;
    }

    HiLog.i(TAG, 'Stopping user file listener');

    this.debounceHandler.cancel();

    try {
      if (this.uriChangeCallback) {
        this.userFileMgr.off(
          DEFAULT_AUDIO_URI,
          this.uriChangeCallback
        );
        this.userFileMgr.off(
          DEFAULT_PHOTO_URI,
          this.uriChangeCallback
        );
        this.userFileMgr.off(
          DEFAULT_ALBUM_URI,
          this.uriChangeCallback
        );
      }

      const mgr = this.userFileMgr;
      if (mgr) {
        this.eventCallbacks.forEach((callback: () => void, event: UserFileChangeEvent) => {
          mgr.off(event, callback);
        });
      }
      this.eventCallbacks.clear();
      this.registeredEvents.clear();
    } catch (error) {
      HiLog.e(TAG, `Failed to unregister change listener: ${error}`);
    }

    this.isRunning = false;
    HiLog.i(TAG, 'User file listener stopped');
  }

  async addWatchPath(path: string): Promise<boolean> {
    HiLog.w(TAG, `UserFileListener does not support path-based watching: ${path}`);
    return false;
  }

  async removeWatchPath(path: string): Promise<void> {
    HiLog.w(TAG, `UserFileListener does not support path-based watching: ${path}`);
  }

  getWatchedPaths(): string[] {
    return Array.from(this.registeredEvents);
  }

  isListening(): boolean {
    return this.isRunning;
  }

  setCallback(callback: FileChangeCallback): void {
    this.callback = callback;
  }

  private handleEventChange(event: UserFileChangeEvent): void {
    if (!this.isRunning) {
      return;
    }

    HiLog.i(TAG, `Event change detected: ${event}`);

    const changeType = this.mapEventToChangeType(event);

    const eventInfo: FileChangeEventInfo = {
      filePath: event,
      changeType: changeType,
      timestamp: Date.now(),
      directoryPath: '',
      fileName: ''
    };

    this.debounceHandler.addEvent(eventInfo);
  }

  private handleUserFileChange(changeData: userFileManager.ChangeData): void {
    if (!this.isRunning) {
      return;
    }

    const notifyType = changeData.type;
    const uris = changeData.uris || [];
    const subUris = changeData.subUris;

    HiLog.i(TAG, `User file change detected: type=${notifyType}, uris=${uris.length}`);

    const changeType = this.mapNotifyTypeToChangeType(notifyType);

    for (const uri of uris) {
      const eventInfo: FileChangeEventInfo = {
        filePath: uri,
        changeType: changeType,
        timestamp: Date.now(),
        directoryPath: '',
        fileName: ''
      };
      this.debounceHandler.addEvent(eventInfo);
    }

    if (subUris && subUris.length > 0) {
      const assetChangeType = notifyType === userFileManager.NotifyType.NOTIFY_ALBUM_ADD_ASSET ?
        FileChangeType.CREATED : FileChangeType.DELETED;

      for (const uri of subUris) {
        const eventInfo: FileChangeEventInfo = {
          filePath: uri,
          changeType: assetChangeType,
          timestamp: Date.now(),
          directoryPath: '',
          fileName: ''
        };
        this.debounceHandler.addEvent(eventInfo);
      }
    }
  }

  private mapEventToChangeType(event: UserFileChangeEvent): FileChangeType {
    switch (event) {
      case 'audioChange':
        return FileChangeType.MODIFIED;
      case 'videoChange':
        return FileChangeType.MODIFIED;
      case 'imageChange':
        return FileChangeType.MODIFIED;
      case 'albumChange':
        return FileChangeType.MODIFIED;
      case 'deviceChange':
        return FileChangeType.MOVED_IN;
      case 'remoteFileChange':
        return FileChangeType.MODIFIED;
      default:
        return FileChangeType.MODIFIED;
    }
  }

  private mapNotifyTypeToChangeType(notifyType: userFileManager.NotifyType): FileChangeType {
    switch (notifyType) {
      case userFileManager.NotifyType.NOTIFY_ADD:
        return FileChangeType.CREATED;
      case userFileManager.NotifyType.NOTIFY_UPDATE:
        return FileChangeType.MODIFIED;
      case userFileManager.NotifyType.NOTIFY_REMOVE:
        return FileChangeType.DELETED;
      case userFileManager.NotifyType.NOTIFY_ALBUM_ADD_ASSET:
        return FileChangeType.MOVED_IN;
      case userFileManager.NotifyType.NOTIFY_ALBUM_REMOVE_ASSET:
        return FileChangeType.MOVED_OUT;
      default:
        return FileChangeType.MODIFIED;
    }
  }

  private handleBatchEvent(event: FileChangeEvent): void {
    if (!this.callback || !event.hasEvents()) {
      return;
    }

    HiLog.i(TAG, `Processing batch user file event: ${event.getEventCount()} events`);

    if (this.callback.onBatchChange) {
      this.callback.onBatchChange(event);
    }

    this.processIndividualEvents(event);
  }

  private processIndividualEvents(event: FileChangeEvent): void {
    if (!this.callback) {
      return;
    }

    const createdEvents = event.getEventsByType(FileChangeType.CREATED);
    const modifiedEvents = event.getEventsByType(FileChangeType.MODIFIED);
    const deletedEvents = event.getEventsByType(FileChangeType.DELETED);
    const movedInEvents = event.getEventsByType(FileChangeType.MOVED_IN);
    const movedOutEvents = event.getEventsByType(FileChangeType.MOVED_OUT);

    for (const evt of deletedEvents) {
      if (this.callback.onFileDeleted) {
        this.callback.onFileDeleted(evt.filePath);
      }
    }

    for (const evt of movedOutEvents) {
      if (this.callback.onFileMovedOut) {
        this.callback.onFileMovedOut(evt.filePath);
      }
    }

    for (const evt of createdEvents) {
      if (this.callback.onFileCreated) {
        this.callback.onFileCreated(evt.filePath);
      }
    }

    for (const evt of movedInEvents) {
      if (this.callback.onFileMovedIn) {
        this.callback.onFileMovedIn(evt.filePath);
      }
    }

    for (const evt of modifiedEvents) {
      if (this.callback.onFileModified) {
        this.callback.onFileModified(evt.filePath);
      }
    }
  }

  getUserFileManager(): userFileManager.UserFileManager | null {
    return this.userFileMgr;
  }

  getConfig(): FileListenerConfig {
    return this.config;
  }

  getDebouncePendingCount(): number {
    return this.debounceHandler.getPendingCount();
  }

  flushPendingEvents(): void {
    this.debounceHandler.flush();
  }

  release(): void {
    if (this.userFileMgr) {
      this.userFileMgr.release();
    }
  }
}
