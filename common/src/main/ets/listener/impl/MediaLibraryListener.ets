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


import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { HiLog } from '../../utils/HiLog';
import { FileChangeType, FileChangeEvent, FileChangeEventInfo } from '../FileChangeEvent';
import { DebounceHandler, DebounceCallback } from '../DebounceHandler';
import { FileChangeCallback, IFileListener, FileListenerConfig } from '../IFileChangeListener';
import { FileSyncTaskPool } from '../FileSyncTaskPool';
import type common from '@ohos.app.ability.common';

const TAG = 'MediaLibraryListener';

export class MediaLibraryListener implements IFileListener {
  private context: common.Context;
  private phAccessHelper: photoAccessHelper.PhotoAccessHelper | null = null;
  private debounceHandler: DebounceHandler;
  private callback: FileChangeCallback | null = null;
  private isRunning: boolean = false;
  private config: FileListenerConfig;
  private changeCallback: ((changeData: photoAccessHelper.ChangeData) => void) | null = null;
  private registeredUris: Set<string> = new Set();

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

    this.initPhotoAccessHelper();

    class DebounceCallbackImpl extends DebounceCallback {
      private listener: MediaLibraryListener;
      
      constructor(listener: MediaLibraryListener) {
        super();
        this.listener = listener;
      }
      
      onEvent(event: FileChangeEvent): void {
        this.listener.handleBatchEvent(event);
      }
    }

    this.debounceHandler.setCallback(new DebounceCallbackImpl(this));
    HiLog.i(TAG, 'MediaLibraryListener created');
  }

  private initPhotoAccessHelper(): void {
    try {
      this.phAccessHelper = photoAccessHelper.getPhotoAccessHelper(this.context);
      HiLog.i(TAG, 'PhotoAccessHelper initialized');
    } catch (error) {
      HiLog.e(TAG, `Failed to init PhotoAccessHelper: ${error}`);
    }
  }

  async startListener(): Promise<boolean> {
    if (this.isRunning) {
      HiLog.w(TAG, 'Listener already running');
      return true;
    }

    if (!this.phAccessHelper) {
      HiLog.e(TAG, 'PhotoAccessHelper not initialized');
      return false;
    }

    HiLog.i(TAG, 'Starting public media listener');

    this.changeCallback = (changeData: photoAccessHelper.ChangeData) => {
      this.handleMediaChange(changeData);
    };

    try {
      this.phAccessHelper.registerChange(
        photoAccessHelper.DefaultChangeUri.DEFAULT_PHOTO_URI,
        true,
        this.changeCallback
      );
      this.registeredUris.add(photoAccessHelper.DefaultChangeUri.DEFAULT_PHOTO_URI);

      this.phAccessHelper.registerChange(
        photoAccessHelper.DefaultChangeUri.DEFAULT_ALBUM_URI,
        true,
        this.changeCallback
      );
      this.registeredUris.add(photoAccessHelper.DefaultChangeUri.DEFAULT_ALBUM_URI);

      this.isRunning = true;
      HiLog.i(TAG, 'Public media listener started successfully');
      return true;
    } catch (error) {
      HiLog.e(TAG, `Failed to register change listener: ${error}`);
      return false;
    }
  }

  async stopListener(): Promise<void> {
    if (!this.isRunning || !this.phAccessHelper) {
      return;
    }

    HiLog.i(TAG, 'Stopping public media listener');

    this.debounceHandler.cancel();

    try {
      for (const uri of this.registeredUris) {
        this.phAccessHelper.unRegisterChange(uri);
      }
      this.registeredUris.clear();
    } catch (error) {
      HiLog.e(TAG, `Failed to unregister change listener: ${error}`);
    }

    this.isRunning = false;
    HiLog.i(TAG, 'Public media listener stopped');
  }

  async addWatchPath(path: string): Promise<boolean> {
    HiLog.w(TAG, `MediaLibraryListener does not support path-based watching: ${path}`);
    return false;
  }

  async removeWatchPath(path: string): Promise<void> {
    HiLog.w(TAG, `MediaLibraryListener does not support path-based watching: ${path}`);
  }

  getWatchedPaths(): string[] {
    return Array.from(this.registeredUris);
  }

  isListening(): boolean {
    return this.isRunning;
  }

  setCallback(callback: FileChangeCallback): void {
    this.callback = callback;
  }

  private handleMediaChange(changeData: photoAccessHelper.ChangeData): void {
    if (!this.isRunning) {
      return;
    }

    const notifyType = changeData.type;
    const uris = changeData.uris || [];
    const extraUris = changeData.extraUris;

    HiLog.i(TAG, `Media change detected: type=${notifyType}, uris=${uris.length}`);

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

    if (extraUris && extraUris.length > 0) {
      const assetChangeType = notifyType === photoAccessHelper.NotifyType.NOTIFY_ALBUM_ADD_ASSET ?
        FileChangeType.CREATED : FileChangeType.DELETED;

      for (const uri of extraUris) {
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

  private mapNotifyTypeToChangeType(notifyType: number): FileChangeType {
    switch (notifyType) {
      case photoAccessHelper.NotifyType.NOTIFY_ADD:
        return FileChangeType.CREATED;
      case photoAccessHelper.NotifyType.NOTIFY_UPDATE:
        return FileChangeType.MODIFIED;
      case photoAccessHelper.NotifyType.NOTIFY_REMOVE:
        return FileChangeType.DELETED;
      case photoAccessHelper.NotifyType.NOTIFY_ALBUM_ADD_ASSET:
        return FileChangeType.MOVED_IN;
      case photoAccessHelper.NotifyType.NOTIFY_ALBUM_REMOVE_ASSET:
        return FileChangeType.MOVED_OUT;
      default:
        return FileChangeType.MODIFIED;
    }
  }

  private handleBatchEvent(event: FileChangeEvent): void {
    if (!this.callback || !event.hasEvents()) {
      return;
    }

    HiLog.i(TAG, `Processing batch media event: ${event.getEventCount()} events`);

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

  getPhotoAccessHelper(): photoAccessHelper.PhotoAccessHelper | null {
    return this.phAccessHelper;
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
}
