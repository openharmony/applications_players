/*
 * Copyright (c) 2025. All rights reserved.
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

import { describe } from '@ohos/hypium';
import FileListenerTest from './listener/FileListener.test';
import FileListenerApiTest from './listener/FileListenerApi.test';
import FileListenerDatabaseTest from './listener/FileListenerDatabase.test';
import PublicDirectoryListenerTest from './listener/PublicDirectoryListener.test';

import MediaDbManagerIndexTest from './database/MediaDbManagerIndex.test';
import MtimeSortTest from './database/MtimeSort.test';
import MediaImportUriTest from './database/MediaImportUri.test';
import ScanTaskPoolChunkTest from './scan/ScanTaskPoolChunk.test';
import ThumbnailAsyncTest from './thumbnail/ThumbnailAsync.test';
import StartAbilitySortTest from './startability/StartAbilitySort.test'
import MediaImportProgressTest from './import/MediaImportProgress.test';
import SearchMatchEngineTest from './search/SearchMatchEngineTest';

export default function testsuite() {
  FileListenerTest();
  FileListenerApiTest();
  FileListenerDatabaseTest();
  PublicDirectoryListenerTest();
  MediaDbManagerIndexTest();
  MtimeSortTest();
  MediaImportUriTest();
  ScanTaskPoolChunkTest();
  ThumbnailAsyncTest();
  StartAbilitySortTest();
  MediaImportProgressTest();
  SearchMatchEngineTest();
}