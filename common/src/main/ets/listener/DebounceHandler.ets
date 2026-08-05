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


import { FileChangeEvent, FileChangeEventInfo } from './FileChangeEvent';

export abstract class DebounceCallback {
  abstract onEvent(events: FileChangeEvent): void;
}

export class DebounceHandler {
  private delay: number;
  private pendingEvent: FileChangeEvent = new FileChangeEvent();
  private timerId: number | null = null;
  private callback: DebounceCallback | null = null;
  private maxBatchSize: number;
  private maxWaitTime: number;
  private startTime: number = 0;

  constructor(delay: number = 500, maxBatchSize: number = 100, maxWaitTime: number = 3000) {
    this.delay = delay;
    this.maxBatchSize = maxBatchSize;
    this.maxWaitTime = maxWaitTime;
  }

  public setCallback(callback: DebounceCallback): void {
    this.callback = callback;
  }

  public addEvent(eventInfo: FileChangeEventInfo): void {
    this.pendingEvent.addEvent(eventInfo);

    if (this.startTime === 0) {
      this.startTime = Date.now();
    }

    if (this.pendingEvent.getEventCount() >= this.maxBatchSize) {
      this.flush();
      return;
    }

    const elapsed = Date.now() - this.startTime;
    if (elapsed >= this.maxWaitTime) {
      this.flush();
      return;
    }

    this.scheduleFlush();
  }

  private scheduleFlush(): void {
    if (this.timerId !== null) {
      clearTimeout(this.timerId);
    }

    this.timerId = setTimeout(() => {
      this.flush();
    }, this.delay);
  }

  public flush(): void {
    if (this.timerId !== null) {
      clearTimeout(this.timerId);
      this.timerId = null;
    }

    if (this.pendingEvent.hasEvents() && this.callback) {
      const eventToProcess = this.pendingEvent;
      this.pendingEvent = new FileChangeEvent();
      this.startTime = 0;
      this.callback.onEvent(eventToProcess);
    }
  }

  public cancel(): void {
    if (this.timerId !== null) {
      clearTimeout(this.timerId);
      this.timerId = null;
    }
    this.pendingEvent.clear();
    this.startTime = 0;
  }

  public getPendingCount(): number {
    return this.pendingEvent.getEventCount();
  }

  isPending(): boolean {
    return this.timerId !== null || this.pendingEvent.hasEvents();
  }
}
