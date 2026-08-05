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
import fs from '@ohos.file.fs';
import { ObjectUtil } from '../utils/ObjectUtil';

const TAG = 'StorageDeviceManager';

export interface StorageDeviceInfo {
  volumeUuid: string;
  displayName: string;
  path: string;
  isMounted: boolean;
  isRemovable: boolean;
  totalCapacity: number;
  availableCapacity: number;
}

export interface StorageDeviceCallback {
  onDeviceMounted?(device: StorageDeviceInfo): void;

  onDeviceUnmounted?(device: StorageDeviceInfo): void;

  onDeviceRemoved?(device: StorageDeviceInfo): void;

  onDeviceChanged?(devices: StorageDeviceInfo[]): void;
}

export class StorageDeviceManager {
  private static instance: StorageDeviceManager;
  private context: common.Context | null = null;
  private subscriber?: commonEventManager.CommonEventSubscriber;
  private devices: Map<string, StorageDeviceInfo> = new Map();
  private callback?: StorageDeviceCallback;
  private isInitialized: boolean = false;

  private constructor() {
  }

  public static getInstance(): StorageDeviceManager {
    if (!StorageDeviceManager.instance) {
      StorageDeviceManager.instance = new StorageDeviceManager();
    }
    return StorageDeviceManager.instance;
  }

  public async init(context: common.Context): Promise<void> {
    if (this.isInitialized) {
      HiLog.w(TAG, 'StorageDeviceManager already initialized');
      return;
    }

    this.context = context;
    await this.refreshDevices();
    await this.startMonitor();

    this.isInitialized = true;
    HiLog.i(TAG, 'StorageDeviceManager initialized');
  }

  private async refreshDevices(): Promise<void> {
    try {
      this.devices.clear();

      const directories = [
        this.context?.filesDir,
        this.context?.cacheDir,
        '/storage/media',
        '/storage/emulated/0'
      ];

      for (const dir of directories) {
        if (!dir) {
          continue;
        }

        try {
          const stat = await fs.stat(dir);
          if (stat.isDirectory()) {
            const deviceInfo: StorageDeviceInfo = {
              volumeUuid: dir,
              displayName: this.getDisplayName(dir),
              path: dir,
              isMounted: true,
              isRemovable: dir.includes('/storage/media'),
              totalCapacity: 0,
              availableCapacity: 0
            };

            this.devices.set(dir, deviceInfo);
          }
        } catch (error) {
          HiLog.d(TAG, `Directory not found or inaccessible: ${dir}`);
        }
      }

      HiLog.i(TAG, `Refreshed storage devices: ${this.devices.size}`);
      this.notifyDeviceChanged();
    } catch (error) {
      HiLog.e(TAG, `Failed to refresh storage devices: ${error}`);
    }
  }

  private getDisplayName(path: string): string {
    if (path.includes('filesDir')) {
      return '应用文件目录';
    } else if (path.includes('cacheDir')) {
      return '应用缓存目录';
    } else if (path.includes('/storage/media')) {
      return '系统媒体目录';
    } else if (path.includes('/storage/emulated/0')) {
      return '内部存储';
    }
    return '未知设备';
  }

  private async startMonitor(): Promise<void> {
    try {
      const subscribeInfo: commonEventManager.CommonEventSubscribeInfo = {
        events: [
          commonEventManager.Support.COMMON_EVENT_VOLUME_MOUNTED,
          commonEventManager.Support.COMMON_EVENT_VOLUME_UNMOUNTED,
          commonEventManager.Support.COMMON_EVENT_VOLUME_REMOVED,
          commonEventManager.Support.COMMON_EVENT_VOLUME_BAD_REMOVAL
        ]
      };

      const subscriber = await commonEventManager.createSubscriber(subscribeInfo);

      commonEventManager.subscribe(subscriber, (error, data) => {
        if (error) {
          HiLog.e(TAG, `Storage device monitor error: ${error}`);
          return;
        }

        this.handleDeviceEvent(data);
      });

      this.subscriber = subscriber;
      HiLog.i(TAG, 'Storage device monitor started');
    } catch (error) {
      HiLog.e(TAG, `Failed to start storage device monitor: ${error}`);
    }
  }

  private async handleDeviceEvent(data: commonEventManager.CommonEventData): Promise<void> {
    const volumeUuid = this.getUuidByParams(data);
    HiLog.i(TAG, 'subscribe : ', volumeUuid + ' ; ' + JSON.stringify(data));

    switch (data.event) {
      case commonEventManager.Support.COMMON_EVENT_VOLUME_MOUNTED:
        HiLog.i(TAG, `Device mounted: ${volumeUuid}`);
        await this.onDeviceMounted(volumeUuid);
        break;

      case commonEventManager.Support.COMMON_EVENT_VOLUME_UNMOUNTED:
        HiLog.i(TAG, `Device unmounted: ${volumeUuid}`);
        await this.onDeviceUnmounted(volumeUuid);
        break;

      case commonEventManager.Support.COMMON_EVENT_VOLUME_REMOVED:
        HiLog.i(TAG, `Device removed: ${volumeUuid}`);
        await this.onDeviceRemoved(volumeUuid);
        break;

      case commonEventManager.Support.COMMON_EVENT_VOLUME_BAD_REMOVAL:
        HiLog.w(TAG, `Device abnormally removed: ${volumeUuid}`);
        await this.onDeviceRemoved(volumeUuid);
        break;

      default:
        HiLog.w(TAG, `Unknown event: ${data.event}`);
        break;
    }
  }

  private getUuidByParams(commonEventData: commonEventManager.CommonEventData): string {
    if (!ObjectUtil.isNullOrUndefined(commonEventData)) {
      let params = commonEventData.parameters;
      if (params) {
        let uuid: object = params.fsUuid;
        if (typeof uuid === 'string') {
          return uuid as string;
        }
      }
    }
    return '';
  }

  private async onDeviceMounted(volumeUuid: string): Promise<void> {
    try {
      const deviceInfo: StorageDeviceInfo = {
        volumeUuid: volumeUuid,
        displayName: this.getDisplayName(volumeUuid),
        path: volumeUuid,
        isMounted: true,
        isRemovable: true,
        totalCapacity: 0,
        availableCapacity: 0
      };

      this.devices.set(volumeUuid, deviceInfo);
      this.callback?.onDeviceMounted?.(deviceInfo);
      this.notifyDeviceChanged();

      HiLog.i(TAG, `Device mount handled: ${volumeUuid}`);
    } catch (error) {
      HiLog.e(TAG, `Failed to handle device mount: ${volumeUuid}, error: ${error}`);
    }
  }

  private async onDeviceUnmounted(volumeUuid: string): Promise<void> {
    try {
      const device = this.devices.get(volumeUuid);
      if (device) {
        device.isMounted = false;
        this.callback?.onDeviceUnmounted?.(device);
        this.notifyDeviceChanged();
      }

      HiLog.i(TAG, `Device unmount handled: ${volumeUuid}`);
    } catch (error) {
      HiLog.e(TAG, `Failed to handle device unmount: ${volumeUuid}, error: ${error}`);
    }
  }

  private async onDeviceRemoved(volumeUuid: string): Promise<void> {
    try {
      const device = this.devices.get(volumeUuid);
      if (device) {
        this.devices.delete(volumeUuid);
        this.callback?.onDeviceRemoved?.(device);
        this.notifyDeviceChanged();
      }

      HiLog.i(TAG, `Device removal handled: ${volumeUuid}`);
    } catch (error) {
      HiLog.e(TAG, `Failed to handle device removal: ${volumeUuid}, error: ${error}`);
    }
  }

  private notifyDeviceChanged(): void {
    const devices = Array.from(this.devices.values());
    this.callback?.onDeviceChanged?.(devices);
  }

  public setCallback(callback: StorageDeviceCallback): void {
    this.callback = callback;
  }

  public getDevices(): StorageDeviceInfo[] {
    return Array.from(this.devices.values());
  }

  public getMountedDevices(): StorageDeviceInfo[] {
    return Array.from(this.devices.values()).filter(device => device.isMounted);
  }

  public getDeviceByPath(path: string): StorageDeviceInfo | undefined {
    return Array.from(this.devices.values()).find(device => path.startsWith(device.path));
  }

  public async stop(): Promise<void> {
    if (this.subscriber) {
      await commonEventManager.unsubscribe(this.subscriber);
      this.subscriber = undefined;
    }

    this.devices.clear();
    this.isInitialized = false;

    HiLog.i(TAG, 'StorageDeviceManager stopped');
  }

  public isReady(): boolean {
    return this.isInitialized;
  }
}
