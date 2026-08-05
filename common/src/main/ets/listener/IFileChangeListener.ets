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


import { FileChangeEvent } from './FileChangeEvent';
import type common from '@ohos.app.ability.common';

export interface FileChangeCallback {
  onFileCreated?(filePath: string): void;
  onFileModified?(filePath: string): void;
  onFileDeleted?(filePath: string): void;
  onFileMovedIn?(filePath: string, fromPath?: string): void;
  onFileMovedOut?(filePath: string, toPath?: string): void;
  onBatchChange?(event: FileChangeEvent): void;
  onError?(error: Error): void;
}

export interface IFileListener {
  startListener(): Promise<boolean>;
  stopListener(): Promise<void>;
  addWatchPath(path: string): Promise<boolean>;
  removeWatchPath(path: string): Promise<void>;
  getWatchedPaths(): string[];
  isListening(): boolean;
  setCallback(callback: FileChangeCallback): void;
}

export interface FileListenerConfig {
  debounceDelay?: number;
  maxBatchSize?: number;
  maxWaitTime?: number;
  watchEvents?: number;
  includeSubdirectories?: boolean;
  fileExtensions?: string[];
}

export interface FileSyncCallback {
  onSyncStart?(): void;
  onSyncComplete?(processedCount: number): void;
  onSyncError?(error: Error): void;
  onFileProcessed?(filePath: string, success: boolean): void;
}

export interface IFileSyncEngine {
  syncFileCreated(filePath: string): Promise<boolean>;
  syncFileModified(filePath: string): Promise<boolean>;
  syncFileDeleted(filePath: string): Promise<boolean>;
  batchSync(event: FileChangeEvent): Promise<number>;
  setSyncCallback(callback: FileSyncCallback): void;
  cancelSync(): void;
  isSyncing(): boolean;
}
