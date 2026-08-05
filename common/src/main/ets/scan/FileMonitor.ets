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


import commonEventManager from '@ohos.commonEventManager';
import { HiLog } from '../utils/HiLog';
import type common from '@ohos.app.ability.common';
import { FileListenerManager, ListenerTypeEnum } from '../listener/FileListenerManager';
import { FileChangeEvent } from '../listener/FileChangeEvent';
import { FileSyncCallback } from '../listener/IFileChangeListener';

const TAG = 'FileMonitor';

export enum ChangeType {
  CREATED = 'created',
  MODIFIED = 'modified',
  DELETED = 'deleted'
}

export interface MonitorCallback {
  onDeviceMounted?(volumeUuid: string): void;
  onDeviceUnmounted?(volumeUuid: string): void;
  onDeviceRemoved?(volumeUuid: string): void;
  onFileChanged?(filePath: string, type: ChangeType): void;
  onBatchFileChanged?(event: FileChangeEvent): void;
  onSyncComplete?(processedCount: number): void;
}

export class FileMonitor {
  private context: common.Context;
  private subscriber?: commonEventManager.CommonEventSubscriber;
  private monitorCallback?: MonitorCallback;
  private isSubscribed: boolean = false;
  private listenerManager: FileListenerManager;
  private isInitialized: boolean = false;

  constructor(context: common.Context) {
    this.context = context;
    this.listenerManager = FileListenerManager.getInstance(context);
  }

  async startMonitor(callback: MonitorCallback): Promise<void> {
    if (this.isSubscribed && this.isInitialized) {
      HiLog.w(TAG, 'File monitor already started, skipping');
      return;
    }

    this.monitorCallback = callback;

    try {
      await this.initDeviceEventListener();
      await this.initFileChangeListener();
      this.isSubscribed = true;
      HiLog.i(TAG, 'File monitor started');
    } catch (error) {
      HiLog.e(TAG, `Failed to start monitor: ${error}`);
    }
  }

  private async initDeviceEventListener(): Promise<void> {
    const subscriber = await commonEventManager.createSubscriber({
      events: [
        commonEventManager.Support.COMMON_EVENT_VOLUME_MOUNTED,
        commonEventManager.Support.COMMON_EVENT_VOLUME_UNMOUNTED,
        commonEventManager.Support.COMMON_EVENT_VOLUME_REMOVED,
        commonEventManager.Support.COMMON_EVENT_VOLUME_BAD_REMOVAL
      ]
    });

    commonEventManager.subscribe(subscriber, (error, data) => {
      if (error) {
        HiLog.e(TAG, `Monitor event error: ${error}`);
        return;
      }

      this.handleDeviceEvent(data);
    });

    this.subscriber = subscriber;
  }

  private async initFileChangeListener(): Promise<void> {
    // Use unified initialization from FileListenerManager
    const success = await this.listenerManager.initializeAllListeners();
    if (!success) {
      HiLog.e(TAG, 'Failed to initialize file listener');
      return;
    }

    // Set sync callback wrapper for external notification
    class SyncCallbackWrapper implements FileSyncCallback {
      private monitor: FileMonitor;

      constructor(monitor: FileMonitor) {
        this.monitor = monitor;
      }

      onSyncComplete(count: number): void {
        if (this.monitor.monitorCallback && this.monitor.monitorCallback.onSyncComplete) {
          this.monitor.monitorCallback.onSyncComplete(count);
        }
      }
    }

    this.listenerManager.getSyncEngine().setSyncCallback(new SyncCallbackWrapper(this));

    // Start all listeners using unified method
    await this.listenerManager.startAllListeners();
    this.isInitialized = true;
    HiLog.i(TAG, 'File change monitoring started (including public directory listeners)');
  }

  private handleDeviceEvent(data: commonEventManager.CommonEventData): void {
    const event = data.event;
    const volumeUuid = this.extractVolumeUuid(data);

    HiLog.i(TAG, `Device event: ${event}, uuid: ${volumeUuid}`);

    switch (event) {
      case commonEventManager.Support.COMMON_EVENT_VOLUME_MOUNTED:
        if (this.monitorCallback && this.monitorCallback.onDeviceMounted) {
          this.monitorCallback.onDeviceMounted(volumeUuid);
        }
        break;

      case commonEventManager.Support.COMMON_EVENT_VOLUME_UNMOUNTED:
        this.listenerManager.cancelSync();
        if (this.monitorCallback && this.monitorCallback.onDeviceUnmounted) {
          this.monitorCallback.onDeviceUnmounted(volumeUuid);
        }
        break;

      case commonEventManager.Support.COMMON_EVENT_VOLUME_REMOVED:
      case commonEventManager.Support.COMMON_EVENT_VOLUME_BAD_REMOVAL:
        this.listenerManager.cancelSync();
        if (this.monitorCallback && this.monitorCallback.onDeviceRemoved) {
          this.monitorCallback.onDeviceRemoved(volumeUuid);
        }
        break;
    }
  }

  private extractVolumeUuid(data: commonEventManager.CommonEventData): string {
    if (data.parameters && data.parameters.fsUuid) {
      return data.parameters.fsUuid as string;
    }
    return '';
  }

  async addWatchDirectory(dirPath: string): Promise<boolean> {
    if (!this.isInitialized) {
      HiLog.w(TAG, 'File monitor not initialized');
      return false;
    }

    return await this.listenerManager.addWatchDirectory(dirPath, ListenerTypeEnum.SANDBOX);
  }

  async removeWatchDirectory(dirPath: string): Promise<void> {
    if (!this.isInitialized) {
      return;
    }

    await this.listenerManager.removeWatchDirectory(dirPath, ListenerTypeEnum.SANDBOX);
  }

  getWatchedDirectories(): string[] {
    if (!this.isInitialized) {
      return [];
    }

    return this.listenerManager.getWatchedDirectories(ListenerTypeEnum.SANDBOX);
  }

  async stopMonitor(): Promise<void> {
    if (!this.isSubscribed) {
      HiLog.w(TAG, 'File monitor not started');
      return;
    }

    try {
      if (this.subscriber) {
        await commonEventManager.unsubscribe(this.subscriber);
        this.subscriber = undefined;
      }

      // Stop all listener types
      await this.listenerManager.stopListening(ListenerTypeEnum.SANDBOX);
      await this.listenerManager.stopListening(ListenerTypeEnum.PUBLIC_MEDIA);
      await this.listenerManager.stopListening(ListenerTypeEnum.USER_FILE);
      this.isSubscribed = false;
      this.isInitialized = false;

      HiLog.i(TAG, 'File monitor stopped (including public directory listeners)');
    } catch (error) {
      HiLog.e(TAG, `Failed to stop monitor: ${error}`);
    }
  }

  isMonitoring(): boolean {
    return this.isSubscribed && this.listenerManager.isListening(ListenerTypeEnum.SANDBOX);
  }

  cancelSync(): void {
    this.listenerManager.cancelSync();
  }

  flushPendingEvents(): void {
    // Flush pending events for all listener types
    this.listenerManager.flushPendingEvents(ListenerTypeEnum.SANDBOX);
    this.listenerManager.flushPendingEvents(ListenerTypeEnum.PUBLIC_MEDIA);
    this.listenerManager.flushPendingEvents(ListenerTypeEnum.USER_FILE);
  }

  getListenerManager(): FileListenerManager {
    return this.listenerManager;
  }

  async destroy(): Promise<void> {
    await this.stopMonitor();
    await this.listenerManager.destroy();
  }
}
