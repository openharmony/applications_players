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
import { MediaFileScanner } from '../scan/MediaFileScanner';
import { MediaType } from '../datasource/IMediaDataSource';
import type common from '@ohos.app.ability.common';
import { taskpool } from '@kit.ArkTS';

const TAG = 'ScanTaskPool';
const CHUNK_SIZE = 50;

export enum ScanTaskType {
  SCAN_AUDIO = 'scan_audio',
  SCAN_VIDEO = 'scan_video',
  SCAN_ALL = 'scan_all',
  SCAN_SYSTEM_AUDIO = 'scan_system_audio',
  SCAN_SYSTEM_VIDEO = 'scan_system_video',
  SCAN_SYSTEM_ALL = 'scan_system_all',
  SCAN_PUBLIC_AUDIO = 'scan_public_audio',
  SCAN_PUBLIC_VIDEO = 'scan_public_video',
  SCAN_PUBLIC_ALL = 'scan_public_all'
}

export enum TaskStatus {
  PENDING = 'pending',
  RUNNING = 'running',
  COMPLETED = 'completed',
  FAILED = 'failed',
  CANCELLED = 'cancelled'
}

export interface ScanTask {
  id: string;
  type: ScanTaskType;
  status: TaskStatus;
  progress: number;
  total: number;
  result: FileInfo[];
  error?: Error;
  startTime: number;
  endTime?: number;
  context?: common.Context;
  includeSystem?: boolean;
  includePublic?: boolean;
}

export interface ScanTaskOptions {
  type: ScanTaskType;
  directories?: string[];
  extensions?: string[];
  recursive?: boolean;
  includeSystem?: boolean;
  includePublic?: boolean;
  context?: common.Context;
  taskId?: string;
}

export interface ScanTaskCallback {
  onTaskStart?(task: ScanTask): void;

  onTaskProgress?(task: ScanTask): void;

  onChunkComplete?(task: ScanTask, chunk: FileInfo[], chunkIndex: number, totalChunks: number): void;

  onTaskComplete?(task: ScanTask): void;

  onTaskError?(task: ScanTask): void;

  onTaskCancel?(task: ScanTask): void;
}

export interface TaskStatistics {
  total: number;
  running: number;
  pending: number;
  completed: number;
  failed: number;
  cancelled: number;
}

@Concurrent
async function scanFilesTask(options: ScanTaskOptions): Promise<FileInfo[]> {
  if (!options.context) {
    return [];
  }

  const includeLibrary = options.includeSystem !== false;
  const includePublic = options.includePublic !== false;

  const scanner = new MediaFileScanner(options.context);
  let result: FileInfo[] = [];

  switch (options.type) {
    case 'scan_audio':
    case 'scan_system_audio':
      result = await scanner.scanAudioFiles(includeLibrary, includePublic);
      break;
    case 'scan_video':
    case 'scan_system_video':
      result = await scanner.scanVideoFiles(includeLibrary, includePublic);
      break;
    case 'scan_all':
    case 'scan_system_all':
      result = await scanner.scanAllMediaFiles(includeLibrary, includePublic);
      break;
    default:
      break;
  }

  return result;
}

interface GeneratedTypeLiteralInterface_1 {
  resolve: (task: ScanTask) => void;
  reject: (error: Error) => void;
}

export class ScanTaskPool {
  private static instance: ScanTaskPool;
  private tasks: Map<string, ScanTask> = new Map();
  private runningTasks: Set<string> = new Set();
  private maxConcurrentTasks: number = 8;
  private callback?: ScanTaskCallback;
  private taskQueue: string[] = [];
  // 等待指定扫描任务结束（完成/失败/取消）的 Promise 队列
  private taskWaiters: Map<string, GeneratedTypeLiteralInterface_1[]> = new Map();

  private constructor() {
  }

  public static getInstance(): ScanTaskPool {
    if (!ScanTaskPool.instance) {
      ScanTaskPool.instance = new ScanTaskPool();
    }
    return ScanTaskPool.instance;
  }

  public setCallback(callback: ScanTaskCallback): void {
    this.callback = callback;
  }

  public setMaxConcurrentTasks(max: number): void {
    this.maxConcurrentTasks = Math.max(1, max);
  }

  public async submitTask(options: ScanTaskOptions): Promise<string> {
    const taskId = this.generateTaskId();

    const task: ScanTask = {
      id: taskId,
      type: options.type,
      status: TaskStatus.PENDING,
      progress: 0,
      total: 0,
      result: [],
      startTime: Date.now(),
      context: options.context,
      includeSystem: options.includeSystem,
      includePublic: options.includePublic
    };

    this.tasks.set(taskId, task);
    this.taskQueue.push(taskId);

    HiLog.i(TAG, `Submitted scan task: ${taskId}, type: ${options.type}`);
    this.callback?.onTaskStart?.(task);

    this.processQueue();

    return taskId;
  }

  private async processQueue(): Promise<void> {
    if (this.runningTasks.size >= this.maxConcurrentTasks || this.taskQueue.length === 0) {
      return;
    }

    const taskId = this.taskQueue.shift();
    if (!taskId) {
      return;
    }

    const task = this.tasks.get(taskId);
    if (!task || task.status !== TaskStatus.PENDING) {
      return;
    }

    this.runningTasks.add(taskId);
    task.status = TaskStatus.RUNNING;

    try {
      HiLog.i(TAG, `Executing scan task: ${taskId}`);
      // 阶段1：taskpool 子线程扫描磁盘。扫描过程无逐文件进度，UI 显示 0%。
      this.reportTaskProgress(task, 0, 0);

      const result = await this.executeTask(task);

      // 阶段2：按分块已处理的文件数更新真实进度（processed / total * 100%）
      if (result.length > 0) {
        const totalChunks = Math.ceil(result.length / CHUNK_SIZE);
        HiLog.i(TAG, `Scan task: ${taskId}, total files: ${result.length}, chunks: ${totalChunks}`);

        for (let i = 0; i < totalChunks; i++) {
          const startIndex = i * CHUNK_SIZE;
          const endIndex = Math.min(startIndex + CHUNK_SIZE, result.length);
          const chunk = result.slice(startIndex, endIndex);
          const processedCount = endIndex;

          HiLog.i(TAG, `Scan task: ${taskId}, chunk ${i + 1}/${totalChunks}, processed: ${processedCount}/${result.length}`);
          this.reportTaskProgress(task, processedCount, result.length);
          this.callback?.onChunkComplete?.(task, chunk, i, totalChunks);
        }
      } else {
        // 未发现文件：直接视为 100%，避免 UI 长时间停在 0%
        this.reportTaskProgress(task, 0, 0);
        task.progress = 100;
        this.callback?.onTaskProgress?.(task);
      }

      task.result = result;
      task.status = TaskStatus.COMPLETED;
      task.endTime = Date.now();
      task.progress = 100;
      this.callback?.onTaskProgress?.(task);

      HiLog.i(TAG, `Scan task completed: ${taskId}, files: ${result.length}`);
      this.callback?.onTaskComplete?.(task);
      this.resolveTaskWaiters(task);
    } catch (error) {
      task.status = TaskStatus.FAILED;
      task.error = error as Error;
      task.endTime = Date.now();

      HiLog.e(TAG, `Scan task failed: ${taskId}, error: ${error}`);
      this.callback?.onTaskError?.(task);
      this.resolveTaskWaiters(task);
    } finally {
      this.runningTasks.delete(taskId);
      this.processQueue();
    }
  }

  private async executeTask(task: ScanTask): Promise<FileInfo[]> {
    const includeLibrary = task.includeSystem !== false;
    const includePublic = task.includePublic !== false;
    HiLog.i(TAG, `executeTask ${task.id}: type=${task.type}, includeLibrary=${includeLibrary}, includePublic=${includePublic}`);

    const options: ScanTaskOptions = {
      type: task.type,
      context: task.context,
      includeSystem: task.includeSystem,
      includePublic: task.includePublic
    };

    try {
      const result = await taskpool.execute(scanFilesTask, options);
      return result as FileInfo[];
    } catch (error) {
      HiLog.e(TAG, `Task execution failed: ${task.id}, error: ${error}`);
      throw new Error(`执行任务失败: ${error}`);
    }
  }

  public cancelTask(taskId: string): boolean {
    const task = this.tasks.get(taskId);
    if (!task) {
      HiLog.w(TAG, `Task not found: ${taskId}`);
      return false;
    }

    if (task.status === TaskStatus.RUNNING) {
      task.status = TaskStatus.CANCELLED;
      task.endTime = Date.now();
      this.runningTasks.delete(taskId);

      HiLog.i(TAG, `Cancelled task: ${taskId}`);
      this.callback?.onTaskCancel?.(task);
      this.resolveTaskWaiters(task);
      return true;
    }

    if (task.status === TaskStatus.PENDING) {
      const index = this.taskQueue.indexOf(taskId);
      if (index !== -1) {
        this.taskQueue.splice(index, 1);
      }

      task.status = TaskStatus.CANCELLED;
      task.endTime = Date.now();

      HiLog.i(TAG, `Cancelled pending task: ${taskId}`);
      this.callback?.onTaskCancel?.(task);
      this.resolveTaskWaiters(task);
      return true;
    }

    return false;
  }

  public cancelAllTasks(): void {
    const taskIds = Array.from(this.tasks.keys());

    for (const taskId of taskIds) {
      this.cancelTask(taskId);
    }

    HiLog.i(TAG, `Cancelled all tasks: ${taskIds.length}`);
  }

  public getTask(taskId: string): ScanTask | undefined {
    return this.tasks.get(taskId);
  }

  /**
   * 等待扫描任务结束。
   *
   * loadMediaFiles(forceRefresh) 在 submitTask 后必须 await 此方法，
   * 否则 UI 会在任务刚提交时就误判为「扫描完成」。
   *
   * @param taskId 由 submitTask 返回的任务 ID
   * @returns 已完成任务的 ScanTask；失败/取消时 reject
   */
  public waitForTaskCompletion(taskId: string): Promise<ScanTask> {
    const task = this.tasks.get(taskId);
    if (!task) {
      return Promise.reject(new Error(`扫描任务不存在: ${taskId}`));
    }
    if (task.status === TaskStatus.COMPLETED) {
      return Promise.resolve(task);
    }
    if (task.status === TaskStatus.FAILED || task.status === TaskStatus.CANCELLED) {
      return Promise.reject(task.error ?? new Error(`扫描任务结束: ${task.status}`));
    }

    return new Promise<ScanTask>((resolve, reject) => {
      const waiters = this.taskWaiters.get(taskId) ?? [];
      waiters.push({ resolve: resolve, reject: reject });
      this.taskWaiters.set(taskId, waiters);
    });
  }

  /**
   * 按「已处理文件数 / 总文件数」计算真实进度，并回调 onTaskProgress。
   *
   * 阶段1（taskpool 扫盘）：无逐文件回调，processedCount 保持 0，UI 显示 0%。
   * 阶段2（分块交付结果）：每处理一块 chunk 递增 processedCount。
   *
   * @param task 当前扫描任务
   * @param processedCount 已处理文件数
   * @param totalCount 扫描结果总文件数
   */
  private reportTaskProgress(task: ScanTask, processedCount: number, totalCount: number): void {
    task.total = totalCount;
    if (totalCount <= 0) {
      task.progress = 0;
    } else {
      task.progress = Math.min(100, Math.floor(processedCount * 100 / totalCount));
    }
    this.callback?.onTaskProgress?.(task);
  }

  /**
   * 解析等待指定 taskId 结束的 Promise（完成 resolve，失败/取消 reject）。
   *
   * @param task 已终态的扫描任务
   */
  private resolveTaskWaiters(task: ScanTask): void {
    const waiters = this.taskWaiters.get(task.id);
    if (!waiters || waiters.length === 0) {
      return;
    }
    for (const waiter of waiters) {
      if (task.status === TaskStatus.COMPLETED) {
        waiter.resolve(task);
      } else {
        waiter.reject(task.error ?? new Error(`扫描任务结束: ${task.status}`));
      }
    }
    this.taskWaiters.delete(task.id);
  }

  public getAllTasks(): ScanTask[] {
    return Array.from(this.tasks.values());
  }

  public getRunningTasks(): ScanTask[] {
    return Array.from(this.runningTasks.values())
      .map(id => this.tasks.get(id))
      .filter(task => task !== undefined) as ScanTask[];
  }

  public getPendingTasks(): ScanTask[] {
    return this.taskQueue
      .map(id => this.tasks.get(id))
      .filter(task => task !== undefined) as ScanTask[];
  }

  public getCompletedTasks(): ScanTask[] {
    return Array.from(this.tasks.values())
      .filter(task => task.status === TaskStatus.COMPLETED);
  }

  public getFailedTasks(): ScanTask[] {
    return Array.from(this.tasks.values())
      .filter(task => task.status === TaskStatus.FAILED);
  }

  public clearCompletedTasks(): void {
    const completedTasks = this.getCompletedTasks();

    for (const task of completedTasks) {
      this.tasks.delete(task.id);
    }

    HiLog.i(TAG, `Cleaned completed tasks: ${completedTasks.length}`);
  }

  public clearAllTasks(): void {
    this.cancelAllTasks();
    this.tasks.clear();
    this.taskQueue = [];

    HiLog.i(TAG, 'Cleared all tasks');
  }

  public getTaskCount(): number {
    return this.tasks.size;
  }

  public getRunningTaskCount(): number {
    return this.runningTasks.size;
  }

  public getPendingTaskCount(): number {
    return this.taskQueue.length;
  }

  private generateTaskId(): string {
    return `task_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  public getTaskStatistics(): TaskStatistics {
    const tasks = Array.from(this.tasks.values());
    const stats: TaskStatistics = {
      total: tasks.length,
      running: tasks.filter(t => t.status === TaskStatus.RUNNING).length,
      pending: tasks.filter(t => t.status === TaskStatus.PENDING).length,
      completed: tasks.filter(t => t.status === TaskStatus.COMPLETED).length,
      failed: tasks.filter(t => t.status === TaskStatus.FAILED).length,
      cancelled: tasks.filter(t => t.status === TaskStatus.CANCELLED).length
    };
    return stats;
  }
}
