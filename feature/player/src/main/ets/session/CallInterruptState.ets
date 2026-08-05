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

/**
 * 通话占用态（与 AVPlayerController 解耦，避免循环依赖）。
 * 通话未 IDLE 时禁止自动恢复播放，避免听筒路由下 AudioRenderer 卡死。
 */
export class CallInterruptState {
  private static callActive: boolean = false;

  static setCallActive(active: boolean): void {
    CallInterruptState.callActive = active;
  }

  static isCallActive(): boolean {
    return CallInterruptState.callActive;
  }
}
