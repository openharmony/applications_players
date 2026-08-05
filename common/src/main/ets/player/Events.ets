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

import FileInfo from '../model/FileInfo';

export class AvPlayerToPlayingEvent {
  public static readonly event: string = 'avPlayerToPlayingEvent';
}

export class RefreshOpenTypeEvent {
  public static readonly event: string = 'refreshOpenTypeEvent';
  public openType: number = 0;
  public fileInfo: FileInfo | null = null;
}

export class AvPlayerToIdleEvent {
  public static readonly event: string = 'avPlayerToIdleEvent';
}

export class RegisterAvSessionCallbackEvent {
  public static readonly event: string = 'registerAvSessionCallbackEvent';
}

export class VideoCoverEvent {
  public static readonly event: string = 'videoCoverEvent';
  public isReady: boolean = false;
}
