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


export enum FileChangeType {
  CREATED = 0x100,
  MODIFIED = 0x2,
  DELETED = 0x200,
  MOVED_IN = 0x80,
  MOVED_OUT = 0x40,
  ATTR_CHANGED = 0x4,
  CLOSED_WRITE = 0x8
}

export interface FileChangeEventInfo {
  filePath: string;
  changeType: FileChangeType;
  timestamp: number;
  cookie?: number;
  directoryPath?: string;
  fileName?: string;
}

export class FileChangeEvent {
  private events: FileChangeEventInfo[] = [];
  private timestamp: number = Date.now();

  public addEvent(info: FileChangeEventInfo): void {
    this.events.push(info);
    this.timestamp = Date.now();
  }

  public getEvents(): FileChangeEventInfo[] {
    return this.events;
  }

  public getTimestamp(): number {
    return this.timestamp;
  }

  public clear(): void {
    this.events = [];
  }

  public hasEvents(): boolean {
    return this.events.length > 0;
  }

  public getEventCount(): number {
    return this.events.length;
  }

  public mergeEvents(other: FileChangeEvent): void {
    const otherEvents = other.getEvents();
    for (const event of otherEvents) {
      this.events.push(event);
    }
  }

  public getUniquePaths(): string[] {
    const paths = new Set<string>();
    for (const event of this.events) {
      paths.add(event.filePath);
    }
    return Array.from(paths);
  }

  public getEventsByType(type: FileChangeType): FileChangeEventInfo[] {
    return this.events.filter(e => e.changeType === type);
  }
}

export class WatchEventFlags {
  public static readonly IN_ACCESS: number = 0x1;
  public static readonly IN_MODIFY: number = 0x2;
  public static readonly IN_ATTRIB: number = 0x4;
  public static readonly IN_CLOSE_WRITE: number = 0x8;
  public static readonly IN_CLOSE_NOWRITE: number = 0x10;
  public static readonly IN_OPEN: number = 0x20;
  public static readonly IN_MOVED_FROM: number = 0x40;
  public static readonly IN_MOVED_TO: number = 0x80;
  public static readonly IN_CREATE: number = 0x100;
  public static readonly IN_DELETE: number = 0x200;
  public static readonly IN_DELETE_SELF: number = 0x400;
  public static readonly IN_MOVE_SELF: number = 0x800;
  public static readonly IN_ALL_EVENTS: number = 0xfff;
  public static readonly IN_MEDIA_EVENTS: number = 0x2 | 0x100 | 0x200 | 0x80 | 0x40 | 0x8;
}
