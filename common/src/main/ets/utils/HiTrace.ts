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


import hilog from '@ohos.hilog';
import hiTraceMeter from '@ohos.hiTraceMeter';

const DOMAIN: number = 0x09734;

/**
 * HiTrace 工具类：封装异步 trace 打点逻辑
 */
export class HiTrace {
  private static readonly TRACE_LOG_BEGIN: string = ' begin.';
  private static readonly TRACE_LOG_END: string = ' end.';
  private static readonly TRACE_LOG_SEPARATE: string = '::';
  private static traceTaskMap: Map<string, number> = new Map();

  /**
   * 开始 trace 打点
   * @param tag 组件标识
   * @param methodName trace 名
   * @param level 日志等级
   */
  static begin(tag: string, methodName: string,
    level: hiTraceMeter.HiTraceOutputLevel = hiTraceMeter.HiTraceOutputLevel.INFO): void {
    hilog.info(DOMAIN, tag, methodName + HiTrace.TRACE_LOG_BEGIN);
    const traceName: string = `${tag}${HiTrace.TRACE_LOG_SEPARATE}${methodName}`;
    hiTraceMeter.startAsyncTrace(level, traceName, HiTrace.generateAndSetTaskId(traceName), '');
  }

  /**
   * 结束 trace 打点
   * @param tag 组件标识
   * @param methodName trace 名
   * @param level 日志等级
   */
  static end(tag: string, methodName: string,
    level: hiTraceMeter.HiTraceOutputLevel = hiTraceMeter.HiTraceOutputLevel.INFO): void {
    hilog.info(DOMAIN, tag, methodName + HiTrace.TRACE_LOG_END);
    const traceName: string = `${tag}${HiTrace.TRACE_LOG_SEPARATE}${methodName}`;
    hiTraceMeter.finishAsyncTrace(level, traceName, HiTrace.getAndClearTaskId(traceName));
  }

  /**
   * 开始 trace 打点（可降频）
   * @param tag 组件标识
   * @param methodName trace 名
   * @param isFreq 是否高频，为 true 时降频为 debug
   */
  static beginTraceFreq(tag: string, methodName: string, isFreq: boolean): void {
    if (!isFreq) {
      hilog.info(DOMAIN, tag, methodName + HiTrace.TRACE_LOG_BEGIN);
      hiTraceMeter.startTrace(tag + HiTrace.TRACE_LOG_SEPARATE + methodName, 1);
    }
  }

  /**
   * 结束 trace 打点（可降频）
   * @param tag 组件标识
   * @param methodName trace 名
   * @param isFreq 是否高频
   */
  static endTraceFreq(tag: string, methodName: string, isFreq: boolean): void {
    if (!isFreq) {
      hilog.info(DOMAIN, tag, methodName + HiTrace.TRACE_LOG_END);
      hiTraceMeter.finishTrace(tag + HiTrace.TRACE_LOG_SEPARATE + methodName, 1);
    }
  }

  /**
   * 生成 trace task id 并存储至 map 中
   * @param traceName trace 名
   * @returns task id
   */
  private static generateAndSetTaskId(traceName: string): number {
    try {
      const taskId: number = Date.now();
      HiTrace.traceTaskMap.set(traceName, taskId);
      return taskId;
    } catch (err) {
      hilog.error(DOMAIN, 'HiTrace', `${traceName} generate task fail. ${err?.code}`);
      return 1;
    }
  }

  /**
   * 从 map 中取出 task id 并删除对应 traceName
   * @param traceName trace 名
   * @returns task id
   */
  private static getAndClearTaskId(traceName: string): number {
    if (HiTrace.traceTaskMap.has(traceName)) {
      const taskId: number = HiTrace.traceTaskMap.get(traceName) as number;
      HiTrace.traceTaskMap.delete(traceName);
      return taskId;
    }
    hilog.error(DOMAIN, 'HiTrace', `${traceName} is not trigger begin, but trigger end.`);
    return 1;
  }
}
