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
import { FileInfo } from '../utils/FileOperateInfo';
import type common from '@ohos.app.ability.common';
import preferences from '@ohos.data.preferences';

const TAG = 'ScanStateManager';

const PREFERENCES_NAME = 'scan_state';
const KEY_LAST_FULL_SCAN_TIME = 'last_full_scan_time';
const KEY_LAST_INCREMENTAL_SCAN_TIME = 'last_incremental_scan_time';

/**
 * 扫描状态管理器
 * 用于管理扫描状态，实现增量扫描
 */
export class ScanStateManager {
  private static instance: ScanStateManager | undefined;
  private context: common.Context;
  private lastScanTime: number = 0;
  private scannedFiles: Map<string, FileInfo> = new Map();
  private pendingFiles: Set<string> = new Set();
  private isScanning: boolean = false;
  private preferencesStore: preferences.Preferences | null = null;
  private initialized: boolean = false;

  private constructor(context: common.Context) {
    this.context = context;
  }

  /**
   * 获取单例实例
   */
  public static getInstance(context: common.Context): ScanStateManager {
    if (!ScanStateManager.instance) {
      ScanStateManager.instance = new ScanStateManager(context);
    }
    return ScanStateManager.instance;
  }

  /**
   * 初始化 preferences 存储
   * @returns 是否初始化成功
   */
  public async init(): Promise<boolean> {
    if (this.initialized) {
      return true;
    }

    try {
      HiLog.i(TAG, 'Initializing scan state manager');
      this.preferencesStore = await preferences.getPreferences(this.context, PREFERENCES_NAME);
      this.initialized = true;
      HiLog.i(TAG, 'Scan state manager initialized successfully');
      return true;
    } catch (error) {
      HiLog.e(TAG, `Scan state manager initialization failed: ${error}`);
      return false;
    }
  }

  /**
   * 获取上次扫描时间
   */
  public getLastScanTime(): number {
    return this.lastScanTime;
  }

  /**
   * 设置上次扫描时间
   */
  public setLastScanTime(time: number): void {
    this.lastScanTime = time;
    HiLog.i(TAG, `Set last scan time: ${time}`);
  }

  /**
   * 获取上次全量扫描时间（从 preferences）
   * @returns 上次全量扫描时间戳（毫秒），默认返回 0
   */
  public async getLastFullScanTime(): Promise<number> {
    if (!this.preferencesStore) {
      HiLog.e(TAG, 'preferences not initialized');
      return 0;
    }

    try {
      const lastFullScanTime = await this.preferencesStore.get(KEY_LAST_FULL_SCAN_TIME, 0) as number;
      HiLog.i(TAG, `Get last full scan time: ${lastFullScanTime}`);
      return lastFullScanTime;
    } catch (error) {
      HiLog.e(TAG, `Failed to get last full scan time: ${error}`);
      return 0;
    }
  }

  /**
   * 设置上次全量扫描时间（保存到 preferences）
   * @param time 全量扫描时间戳（毫秒）
   * @returns 是否设置成功
   */
  public async setLastFullScanTime(time: number): Promise<boolean> {
    if (!this.preferencesStore) {
      HiLog.e(TAG, 'preferences not initialized');
      return false;
    }

    try {
      await this.preferencesStore.put(KEY_LAST_FULL_SCAN_TIME, time);
      await this.preferencesStore.flush();
      HiLog.i(TAG, `Set last full scan time: ${time}`);
      return true;
    } catch (error) {
      HiLog.e(TAG, `Failed to set last full scan time: ${error}`);
      return false;
    }
  }

  /**
   * 获取上次增量扫描时间（从 preferences）
   * @returns 上次增量扫描时间戳（毫秒），默认返回 0
   */
  public async getLastIncrementalScanTime(): Promise<number> {
    if (!this.preferencesStore) {
      HiLog.e(TAG, 'preferences not initialized');
      return 0;
    }

    try {
      const lastIncrementalScanTime = await this.preferencesStore.get(KEY_LAST_INCREMENTAL_SCAN_TIME, 0) as number;
      HiLog.i(TAG, `Get last incremental scan time: ${lastIncrementalScanTime}`);
      return lastIncrementalScanTime;
    } catch (error) {
      HiLog.e(TAG, `Failed to get last incremental scan time: ${error}`);
      return 0;
    }
  }

  /**
   * 设置上次增量扫描时间（保存到 preferences）
   * @param time 增量扫描时间戳（毫秒）
   * @returns 是否设置成功
   */
  public async setLastIncrementalScanTime(time: number): Promise<boolean> {
    if (!this.preferencesStore) {
      HiLog.e(TAG, 'preferences not initialized');
      return false;
    }

    try {
      await this.preferencesStore.put(KEY_LAST_INCREMENTAL_SCAN_TIME, time);
      await this.preferencesStore.flush();
      HiLog.i(TAG, `Set last incremental scan time: ${time}`);
      return true;
    } catch (error) {
      HiLog.e(TAG, `Failed to set last incremental scan time: ${error}`);
      return false;
    }
  }

  /**
   * 添加已扫描文件
   */
  public addScannedFile(fileInfo: FileInfo): void {
    if (!fileInfo || !fileInfo.uri) {
      return;
    }
    this.scannedFiles.set(fileInfo.uri, fileInfo);
    HiLog.i(TAG, `Added scanned file: ${fileInfo.uri}`);
  }

  /**
   * 批量添加已扫描文件
   */
  public addScannedFiles(files: FileInfo[]): void {
    if (!files || files.length === 0) {
      return;
    }
    for (const file of files) {
      this.addScannedFile(file);
    }
    HiLog.i(TAG, `Batch added scanned files: ${files.length}`);
  }

  /**
   * 移除已扫描文件
   */
  public removeScannedFile(uri: string): void {
    if (!uri) {
      return;
    }
    this.scannedFiles.delete(uri);
    HiLog.i(TAG, `Removed scanned file: ${uri}`);
  }

  /**
   * 获取已扫描文件
   */
  public getScannedFile(uri: string): FileInfo | undefined {
    return this.scannedFiles.get(uri);
  }

  /**
   * 获取所有已扫描文件
   */
  public getAllScannedFiles(): FileInfo[] {
    return Array.from(this.scannedFiles.values());
  }

  /**
   * 检查文件是否已扫描
   */
  public isFileScanned(uri: string): boolean {
    return this.scannedFiles.has(uri);
  }

  /**
   * 添加待扫描文件
   */
  public addPendingFile(uri: string): void {
    if (!uri) {
      return;
    }
    this.pendingFiles.add(uri);
    HiLog.i(TAG, `Added pending file: ${uri}`);
  }

  /**
   * 批量添加待扫描文件
   */
  public addPendingFiles(uris: string[]): void {
    if (!uris || uris.length === 0) {
      return;
    }
    for (const uri of uris) {
      this.addPendingFile(uri);
    }
    HiLog.i(TAG, `Batch added pending files: ${uris.length}`);
  }

  /**
   * 移除待扫描文件
   */
  public removePendingFile(uri: string): void {
    if (!uri) {
      return;
    }
    this.pendingFiles.delete(uri);
    HiLog.i(TAG, `Removed pending file: ${uri}`);
  }

  /**
   * 获取所有待扫描文件
   */
  public getAllPendingFiles(): string[] {
    return Array.from(this.pendingFiles.values());
  }

  /**
   * 检查文件是否待扫描
   */
  public isFilePending(uri: string): boolean {
    return this.pendingFiles.has(uri);
  }

  /**
   * 获取待扫描文件数量
   */
  public getPendingFileCount(): number {
    return this.pendingFiles.size;
  }

  /**
   * 获取已扫描文件数量
   */
  public getScannedFileCount(): number {
    return this.scannedFiles.size;
  }

  /**
   * 清空待扫描文件
   */
  public clearPendingFiles(): void {
    this.pendingFiles.clear();
    HiLog.i(TAG, 'Cleared pending files');
  }

  /**
   * 清空已扫描文件
   */
  public clearScannedFiles(): void {
    this.scannedFiles.clear();
    HiLog.i(TAG, 'Cleared scanned files');
  }

  /**
   * 清空所有状态
   */
  public clearAll(): void {
    this.clearPendingFiles();
    this.clearScannedFiles();
    this.lastScanTime = 0;
    this.isScanning = false;
    HiLog.i(TAG, 'Cleared all scan states');
  }

  /**
   * 设置扫描状态
   */
  public setScanning(scanning: boolean): void {
    this.isScanning = scanning;
    HiLog.i(TAG, `Set scanning state: ${scanning}`);
  }

  /**
   * 检查是否正在扫描
   */
  public isScanningInProgress(): boolean {
    return this.isScanning;
  }

  /**
   * 获取扫描统计信息
   */
  public getScanStatistics(): ScanStatistics {
    return {
      totalFiles: this.scannedFiles.size + this.pendingFiles.size,
      scannedFiles: this.scannedFiles.size,
      pendingFiles: this.pendingFiles.size,
      lastScanTime: this.lastScanTime,
      isScanning: this.isScanning
    };
  }

/**
   * 释放资源
   */
  public release(): void {
    this.clearAll();
    ScanStateManager.instance = undefined;
    HiLog.i(TAG, 'Released ScanStateManager resources');
  }
}

/**
 * 扫描统计信息
 */
export interface ScanStatistics {
  totalFiles: number;
  scannedFiles: number;
  pendingFiles: number;
  lastScanTime: number;
  isScanning: boolean;
}
