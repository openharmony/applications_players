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


/** 跨层传递单次起播续播进度（prepared 后 seek，消费即清空） */
export class PlaybackResumeContext {
  private static pendingStartMs: number = 0;
  private static pendingStartPaused: boolean = false;

  public static setPendingStartMs(startMs: number): void {
    PlaybackResumeContext.pendingStartMs = startMs > 0 ? startMs : 0;
  }

  /** 冷启动恢复迷你条：prepared 后 seek 但不自动 play */
  public static setPendingStartPaused(paused: boolean): void {
    PlaybackResumeContext.pendingStartPaused = paused;
  }

  public static consumePendingStartMs(): number {
    const ms = PlaybackResumeContext.pendingStartMs;
    PlaybackResumeContext.pendingStartMs = 0;
    return ms;
  }

  public static consumePendingStartPaused(): boolean {
    const paused = PlaybackResumeContext.pendingStartPaused;
    PlaybackResumeContext.pendingStartPaused = false;
    return paused;
  }
}
