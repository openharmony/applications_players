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


import fs from '@ohos.file.fs';
import type { Watcher, WatchEvent } from '@ohos.file.fs';
import { HiLog } from '../../utils/HiLog';
import { FileChangeType, FileChangeEvent, FileChangeEventInfo, WatchEventFlags } from '../FileChangeEvent';
import { DebounceHandler, DebounceCallback } from '../DebounceHandler';
import { FileChangeCallback, IFileListener, FileListenerConfig } from '../IFileChangeListener';
import { FileSyncTaskPool } from '../FileSyncTaskPool';
import type common from '@ohos.app.ability.common';

const TAG = 'SandboxFileListener';

export class SandboxFileListener implements IFileListener {
  private context: common.Context;
  private watchers: Map<string, fs.Watcher> = new Map();
  private watchedPaths: Set<string> = new Set();
  private debounceHandler: DebounceHandler;
  private callback: FileChangeCallback | null = null;
  private isRunning: boolean = false;
  private config: FileListenerConfig;
  private retryCount: number = 0;
  private readonly MAX_RETRY: number = 3;
  private retryTimer: number | null = null;
  private fileExtensions: Set<string> = new Set();
  private paused: boolean = false;

  constructor(context: common.Context, config?: FileListenerConfig) {
    this.context = context;
    this.config = {
      debounceDelay: config?.debounceDelay ?? 500,
      maxBatchSize: config?.maxBatchSize ?? 100,
      maxWaitTime: config?.maxWaitTime ?? 3000,
      watchEvents: config?.watchEvents ?? WatchEventFlags.IN_MEDIA_EVENTS,
      includeSubdirectories: config?.includeSubdirectories ?? false,
      fileExtensions: config?.fileExtensions ?? []
    };

    this.debounceHandler = new DebounceHandler(
      this.config.debounceDelay,
      this.config.maxBatchSize,
      this.config.maxWaitTime
    );

    if (this.config.fileExtensions && this.config.fileExtensions.length > 0) {
      for (const ext of this.config.fileExtensions) {
        this.fileExtensions.add(ext.toLowerCase());
      }
    }

    class DebounceCallbackImpl extends DebounceCallback {
      private listener: SandboxFileListener;
      
      constructor(listener: SandboxFileListener) {
        super();
        this.listener = listener;
      }
      
      onEvent(event: FileChangeEvent): void {
        this.listener.handleBatchEvent(event);
      }
    }

    this.debounceHandler.setCallback(new DebounceCallbackImpl(this));

    HiLog.i(TAG, 'SandboxFileListener created');
  }

  async startListener(): Promise<boolean> {
    if (this.isRunning) {
      HiLog.w(TAG, 'Listener already running');
      return true;
    }

    HiLog.i(TAG, 'Starting listener');
    this.isRunning = true;
    return true;
  }

  async stopListener(): Promise<void> {
    if (!this.isRunning) {
      return;
    }

    HiLog.i(TAG, 'Stopping listener');

    if (this.retryTimer !== null) {
      clearTimeout(this.retryTimer);
      this.retryTimer = null;
    }

    this.debounceHandler.cancel();
    await this.removeAllWatchers();
    this.isRunning = false;
    HiLog.i(TAG, 'Listener stopped');
  }

  async addWatchPath(path: string): Promise<boolean> {
    if (!this.isRunning) {
      HiLog.w(TAG, 'Listener not running, cannot add watch path');
      return false;
    }

    if (this.watchedPaths.has(path)) {
      HiLog.w(TAG, `Path already watched: ${path}`);
      return true;
    }

    try {
      fs.accessSync(path);
      HiLog.i(TAG, `Path access check passed: ${path}`);
    } catch (error) {
      HiLog.e(TAG, `Path does not exist (accessSync): ${path}, error: ${error}`);
      return false;
    }

    try {
      const stat = fs.statSync(path);
      HiLog.i(TAG, `Path stat check passed: ${path}, isDir=${stat.isDirectory()}, mode=${stat.mode}`);
      if (!stat.isDirectory()) {
        HiLog.e(TAG, `Path is not a directory: ${path}`);
        return false;
      }

      HiLog.i(TAG, `Creating watcher for path: ${path}, events=${this.config.watchEvents!}`);
      const watcher = fs.createWatcher(path, this.config.watchEvents!, (watchEvent: WatchEvent) => {
        this.handleWatchEvent(path, watchEvent);
      });

      watcher.start();
      this.watchers.set(path, watcher);
      this.watchedPaths.add(path);

      HiLog.i(TAG, `Added watch path: ${path}`);
      return true;
    } catch (error) {
      HiLog.e(TAG, `Failed in statSync/createWatcher for path: ${path}, error: ${error}`);
      return this.handleWatchError(path, error as Error);
    }
  }

  async removeWatchPath(path: string): Promise<void> {
    const watcher = this.watchers.get(path);
    if (watcher) {
      try {
        watcher.stop();
        this.watchers.delete(path);
        this.watchedPaths.delete(path);
        HiLog.i(TAG, `Removed watch path: ${path}`);
      } catch (error) {
        HiLog.e(TAG, `Failed to remove watch path: ${path}, error: ${error}`);
      }
    }
  }

  getWatchedPaths(): string[] {
    return Array.from(this.watchedPaths);
  }

  isListening(): boolean {
    return this.isRunning && !this.paused;
  }

  setCallback(callback: FileChangeCallback): void {
    this.callback = callback;
  }

  pause(): void {
    this.paused = true;
    this.debounceHandler.cancel();
    HiLog.i(TAG, 'Listener paused');
  }

  resume(): void {
    if (this.paused) {
      this.paused = false;
      HiLog.i(TAG, 'Listener resumed');
    }
  }

  private handleWatchEvent(dirPath: string, watchEvent: WatchEvent): void {
    if (this.paused) {
      return;
    }

    const filePath = watchEvent.fileName;
    if (!filePath) {
      return;
    }

    const fileName = filePath.substring(filePath.lastIndexOf('/') + 1);
    if (this.fileExtensions.size > 0) {
      const ext = fileName.lastIndexOf('.') !== -1 ?
        fileName.substring(fileName.lastIndexOf('.')).toLowerCase() : '';
      if (!this.fileExtensions.has(ext)) {
        return;
      }
    }

    const changeType = this.mapWatchEventToChangeType(watchEvent.event);
    if (changeType === null) {
      return;
    }

    const eventInfo: FileChangeEventInfo = {
      filePath: filePath,
      changeType: changeType,
      timestamp: Date.now(),
      cookie: watchEvent.cookie,
      directoryPath: dirPath,
      fileName: fileName
    };

    HiLog.d(TAG, `File event: ${filePath}, type: ${changeType}`);
    this.debounceHandler.addEvent(eventInfo);
  }

  private mapWatchEventToChangeType(eventFlags: number): FileChangeType | null {
    if (eventFlags & WatchEventFlags.IN_CREATE) {
      return FileChangeType.CREATED;
    }
    if (eventFlags & WatchEventFlags.IN_DELETE) {
      return FileChangeType.DELETED;
    }
    if (eventFlags & WatchEventFlags.IN_MODIFY) {
      return FileChangeType.MODIFIED;
    }
    if (eventFlags & WatchEventFlags.IN_MOVED_TO) {
      return FileChangeType.MOVED_IN;
    }
    if (eventFlags & WatchEventFlags.IN_MOVED_FROM) {
      return FileChangeType.MOVED_OUT;
    }
    if (eventFlags & WatchEventFlags.IN_ATTRIB) {
      return FileChangeType.ATTR_CHANGED;
    }
    if (eventFlags & WatchEventFlags.IN_CLOSE_WRITE) {
      return FileChangeType.CLOSED_WRITE;
    }
    return null;
  }

  private handleBatchEvent(event: FileChangeEvent): void {
    if (!this.callback || !event.hasEvents()) {
      return;
    }

    HiLog.i(TAG, `Processing batch event: ${event.getEventCount()} events`);

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

  private handleWatchError(path: string, error: Error): boolean {
    HiLog.e(TAG, `Watch error for ${path}: ${error.message}`);

    if (this.retryCount < this.MAX_RETRY) {
      this.retryCount++;
      HiLog.i(TAG, `Retrying watch for ${path}, attempt ${this.retryCount}`);

      this.retryTimer = setTimeout(() => {
        this.addWatchPath(path);
      }, 1000 * this.retryCount);

      return false;
    }

    this.retryCount = 0;

    if (this.callback && this.callback.onError) {
      this.callback.onError(error);
    }

    return false;
  }

  private async removeAllWatchers(): Promise<void> {
    const paths = Array.from(this.watchers.keys());
    for (const path of paths) {
      await this.removeWatchPath(path);
    }
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
