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

import { FileStatus } from '../constants/preview/PreviewConstants';

@Observed
export default class BaseFileInfo {
  @Track public fileName: string;
  @Track public uri: string;
  @Track public mimeType: string;

  constructor(fileName: string, uri: string, mimeType: string) {
    this.fileName = fileName;
    this.uri = uri;
    this.mimeType = mimeType;
  }
}
