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

/**
 * Feature 模块访问媒体列表数据的抽象接口。
 * 由 entry 层注入 MediaAggregateViewModel 实例，避免 feature 间横向依赖。
 */
export interface IMediaListAccess {
  getMediaList(): FileInfo[];
  getMediaCount(): number;
  isReady(): boolean;
}
