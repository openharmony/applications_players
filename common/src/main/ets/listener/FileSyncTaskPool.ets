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


import { taskpool } from '@kit.ArkTS';
import fs from '@ohos.file.fs';
import { FileChangeType, FileChangeEventInfo, WatchEventFlags } from './FileChangeEvent';

export interface SyncTaskResult {
  filePath: string;
  success: boolean;
  error?: string;
  fileInfo?: SyncFileInfo;
}

export interface SyncFileInfo {
  fileName: string;
  path: string;
  uri: string;
  size: number;
  mtime: number;
  duration: number;
  isDirectory: boolean;
  extension: string;
}

@Concurrent
function getFileInfoTask(filePath: string): SyncFileInfo | null {
  try {
    const stat = fs.statSync(filePath);
    const fileName = filePath.substring(filePath.lastIndexOf('/') + 1);
    const extension = fileName.lastIndexOf('.') !== -1 ?
      fileName.substring(fileName.lastIndexOf('.')) : '';

    // 关键修复：如果 filePath 已经是 file:// URI 格式（如 file://media/Photo/...），
    // 不再重复拼接 file:// 前缀，避免产生 file://file://media/... 的错误 URI
    const uri = filePath.startsWith('file://') ? filePath : `file://${filePath}`;

    return {
      fileName: fileName,
      path: filePath,
      uri: uri,
      size: stat.size,
      mtime: stat.mtime,
      duration: 0,
      isDirectory: stat.isDirectory(),
      extension: extension.toLowerCase()
    };
  } catch (error) {
    return null;
  }
}

@Concurrent
function checkFileExistsTask(filePath: string): boolean {
  try {
    return fs.accessSync(filePath);
  } catch (error) {
    return false;
  }
}

@Concurrent
function batchCheckFilesTask(filePaths: string[]): Map<string, boolean> {
  const results = new Map<string, boolean>();
  for (const path of filePaths) {
    try {
      results.set(path, fs.accessSync(path));
    } catch (error) {
      results.set(path, false);
    }
  }
  return results;
}

export class FileSyncTaskPool {
  private static readonly MAX_CONCURRENT_TASKS = 4;

  static async getFileInfo(filePath: string): Promise<SyncFileInfo | null> {
    try {
      const task = new taskpool.Task(getFileInfoTask, filePath);
      const result = await taskpool.execute(task) as SyncFileInfo | null;
      return result;
    } catch (error) {
      return null;
    }
  }

  static async checkFileExists(filePath: string): Promise<boolean> {
    try {
      const task = new taskpool.Task(checkFileExistsTask, filePath);
      const result = await taskpool.execute(task) as boolean;
      return result;
    } catch (error) {
      return false;
    }
  }

  static async batchCheckFiles(filePaths: string[]): Promise<Map<string, boolean>> {
    if (filePaths.length === 0) {
      return new Map<string, boolean>();
    }

    const MAX_CONCURRENT_TASKS = 4;

    try {
      const batchSize = Math.ceil(filePaths.length / MAX_CONCURRENT_TASKS);
      const tasks: taskpool.Task[] = [];

      for (let i = 0; i < MAX_CONCURRENT_TASKS && i * batchSize < filePaths.length; i++) {
        const batch = filePaths.slice(i * batchSize, (i + 1) * batchSize);
        if (batch.length > 0) {
          tasks.push(new taskpool.Task(batchCheckFilesTask, batch));
        }
      }

      const results = await Promise.all(
        tasks.map(task => taskpool.execute(task) as Promise<Map<string, boolean>>)
      );

      const combinedResults = new Map<string, boolean>();
      for (const resultMap of results) {
        resultMap.forEach((value, key) => {
          combinedResults.set(key, value);
        });
      }

      return combinedResults;
    } catch (error) {
      const results = new Map<string, boolean>();
      for (const path of filePaths) {
        results.set(path, false);
      }
      return results;
    }
  }

  static async batchGetFileInfo(filePaths: string[]): Promise<SyncFileInfo[]> {
    if (filePaths.length === 0) {
      return [];
    }

    const taskGroup = new taskpool.TaskGroup();
    for (const path of filePaths) {
      taskGroup.addTask(new taskpool.Task(getFileInfoTask, path));
    }

    try {
      const results = await taskpool.execute(taskGroup) as SyncFileInfo[];
      const validResults: SyncFileInfo[] = [];
      for (const result of results) {
        if (result !== null) {
          validResults.push(result);
        }
      }
      return validResults;
    } catch (error) {
      const fallbackResults: SyncFileInfo[] = [];
      for (const path of filePaths) {
        const info = await FileSyncTaskPool.getFileInfo(path);
        if (info) {
          fallbackResults.push(info);
        }
      }
      return fallbackResults;
    }
  }
}

export { getFileInfoTask, checkFileExistsTask, batchCheckFilesTask };
