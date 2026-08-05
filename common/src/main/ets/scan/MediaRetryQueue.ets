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


import { FileInfo } from '../utils/FileOperateInfo';
import { HiLog } from '../utils/HiLog';
import { retryDuration, retrySize, retryCover } from './RetryHelper';
import type common from '@ohos.app.ability.common';
import { taskpool } from '@kit.ArkTS';

const TAG = 'MediaRetryQueue';

/** 重试类型 */
export enum RetryType {
  DURATION = 'duration',
  SIZE = 'size',
  COVER = 'cover'
}

/** 重试项 */
export interface RetryItem {
  uri: string;
  fileName: string;
  retryType: RetryType;
  fileInfo: FileInfo;
}

/** 重试结果 */
export interface RetryResult {
  uri: string;
  retryType: RetryType;
  success: boolean;
  fileInfo: FileInfo;
}

/** 重试成功回调 */
export type RetrySuccessCallback = (uri: string, retryType: RetryType, fileInfo: FileInfo) => void;

/** 最大重试次数 */
const MAX_RETRY_COUNT = 3;
/** 重试间隔（毫秒） */
const RETRY_DELAYS = [5000, 10000, 30000];

/**
 * TaskPool 子线程重试函数
 * 在子线程中执行封面/时长/大小的重试提取
 * 注意：@Concurrent 函数只能使用 import 的变量或局部变量
 *
 * @param items 待重试项列表
 * @param retryType 重试类型
 * @returns 重试结果列表
 */
@Concurrent
async function retryInWorker(items: RetryItem[], retryType: string): Promise<RetryResult[]> {
  const results: RetryResult[] = [];

  for (const item of items) {
    let success = false;

    try {
      switch (retryType) {
        case 'duration':
          success = await retryDuration(item.fileInfo);
          break;
        case 'size':
          success = await retrySize(item.fileInfo);
          break;
        case 'cover':
          success = await retryCover(item.fileInfo);
          break;
      }
    } catch (error) {
      HiLog.w(`MediaRetryQueue Worker`, `Retry failed: ${item.fileName} error=${error}`);
    }

    const result: RetryResult = {
      uri: item.uri,
      retryType: item.retryType,
      success: success,
      fileInfo: item.fileInfo
    };
    results.push(result);
  }

  return results;
}

/**
 * 失败元数据异步重试队列
 *
 * 职责：
 * 1. 收集扫描阶段失败的元数据提取项（duration、size、cover）
 * 2. 使用 TaskPool 子线程异步重试提取
 * 3. 成功后回调通知主线程更新 DB 和 UI
 */
export class MediaRetryQueue {
  private onSuccess: RetrySuccessCallback | null = null;
  private context: common.Context;

  constructor(context: common.Context) {
    this.context = context;
  }

  /**
   * 设置重试成功回调
   */
  setOnSuccess(callback: RetrySuccessCallback): void {
    this.onSuccess = callback;
  }

  /**
   * 将失败项加入重试队列并启动重试
   *
   * @param items 待重试的文件列表
   * @param retryType 重试类型
   */
  enqueue(items: FileInfo[], retryType: RetryType): void {
    if (items.length === 0) {
      return;
    }

    HiLog.i(TAG, `Enqueued retry: ${items.length} files type=${retryType}`);

    // 构建重试项
    const retryItems: RetryItem[] = [];
    for (const item of items) {
      const retryItem: RetryItem = {
        uri: item.uri,
        fileName: item.fileName,
        retryType: retryType,
        fileInfo: item
      };
      retryItems.push(retryItem);
    }

    // 启动异步重试
    this.startRetry(retryItems, retryType);
  }

  /**
   * 启动异步重试
   * 使用 TaskPool 子线程执行，最多重试 3 次
   */
  private async startRetry(items: RetryItem[], retryType: RetryType): Promise<void> {
    let currentItems = items;
    let attempt = 0;

    while (currentItems.length > 0 && attempt < MAX_RETRY_COUNT) {
      // 等待重试间隔（第一次不等待）
      if (attempt > 0) {
        const delay = RETRY_DELAYS[Math.min(attempt - 1, RETRY_DELAYS.length - 1)];
        HiLog.i(TAG, `Waiting ${delay}ms before retry ${attempt + 1}`);
        await this.delay(delay);
      }

      attempt++;
      HiLog.i(TAG, `Starting retry ${attempt}: ${currentItems.length} files type=${retryType}`);

      try {
        // 使用 TaskPool 子线程执行重试
        const task = new taskpool.Task(retryInWorker, currentItems, retryType);
        const results = await taskpool.execute(task) as RetryResult[];

        // 处理结果
        const failedItems: RetryItem[] = [];
        for (const result of results) {
          if (result.success) {
            HiLog.i(TAG, `Retry succeeded: ${result.uri} type=${retryType} attempt=${attempt}`);
            if (this.onSuccess) {
              this.onSuccess(result.uri, retryType, result.fileInfo);
            }
          } else {
            const failedItem: RetryItem = {
              uri: result.uri,
              fileName: result.fileInfo.fileName,
              retryType: result.retryType,
              fileInfo: result.fileInfo
            };
            failedItems.push(failedItem);
          }
        }

        // 更新待重试列表
        currentItems = failedItems;

        if (currentItems.length > 0) {
          HiLog.w(TAG, `Retry ${attempt} complete: ${currentItems.length} files still failed`);
        }
      } catch (error) {
        HiLog.e(TAG, `TaskPool execution error: ${error}`);
        break;
      }
    }

    // 最终失败的文件
    if (currentItems.length > 0) {
      for (const item of currentItems) {
        HiLog.w(TAG, `Permanent failure: ${item.fileName} type=${retryType} retried ${attempt} times`);
      }
    }
  }

  /**
   * 延迟工具方法
   */
  private delay(ms: number): Promise<void> {
    return new Promise<void>((resolve: () => void) => {
      setTimeout(resolve, ms);
    });
  }
}
