/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import { promptAction } from '@kit.ArkUI';
import { MediaSourceAccessState } from '@ohos/common';

/**
 * 按源文件预检结果弹出准确 Toast，避免一律「源文件已被删除」
 *
 * @param state 存在性 / 打开失败归因
 */
export function showMediaSourceFailureToast(state: MediaSourceAccessState): void {
  let message: Resource;
  if (state === MediaSourceAccessState.MISSING) {
    message = $r('app.string.source_file_missing');
  } else if (state === MediaSourceAccessState.EXISTS) {
    message = $r('app.string.source_file_open_failed');
  } else {
    message = $r('app.string.source_file_unavailable');
  }
  promptAction.showToast({ message: message, duration: 3000 });
}
