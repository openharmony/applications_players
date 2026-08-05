/*
 * Copyright (c) 2026. All rights reserved.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * You may not use this file except in compliance with the License.
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

import { describe, expect, it, beforeAll, afterAll, beforeEach, afterEach } from '@ohos/hypium';
import { MediaDbManager, HiLog, FileInfo, FileUtil } from '@ohos/common';
import { TestUtil } from '../utils/TestUtil';
import type common from '@ohos.app.ability.common';

const TAG = 'MediaImportUriTest';
const TEST_BASE = 'file://docs/storage/Users/currentUser/Documents/import_uri_test';
const ENCODED_URI = `${TEST_BASE}/%E6%B4%9B%E5%A4%A9%E4%BE%9Dyousa%20-%20%E4%B8%89%E6%9C%88%E9%9B%A8.aac`;
const EXPECTED_FILE_NAME = '洛天依yousa - 三月雨.aac';

export default function MediaImportUriTest() {
  describe('MediaImportUriTest', () => {
    let context: common.Context | null = null;
    let dbManager: MediaDbManager | null = null;
    let canonicalUri: string = '';

    beforeAll(async () => {
      HiLog.i(TAG, 'MediaImportUriTest beforeAll: start');
      await TestUtil.initTestEnvironment();
      context = TestUtil.getContext();
      dbManager = TestUtil.getDbManager();
      canonicalUri = FileUtil.normalizeMediaUri(ENCODED_URI);
    });

    afterAll(async () => {
      await TestUtil.cleanupTestEnvironment();
    });

    beforeEach(async () => {
      if (context && dbManager) {
        await dbManager.init();
      }
    });

    afterEach(async () => {
      if (dbManager) {
        await dbManager.markAsInvalid(canonicalUri);
        await dbManager.markAsInvalid(ENCODED_URI);
      }
    });

    it('IMPORT_URI_01_normalize_encoded_uri', 0, async (done: Function) => {
      const normalized = FileUtil.normalizeMediaUri(ENCODED_URI);
      expect(normalized).assertEqual(canonicalUri);
      expect(FileUtil.normalizeMediaUri(normalized)).assertEqual(canonicalUri);
      const fileName = FileUtil.getFileNameFromUri(normalized);
      expect(fileName).assertEqual(EXPECTED_FILE_NAME);
      done();
    });

    it('IMPORT_URI_02_upsert_encoded_matches_decoded_record', 0, async (done: Function) => {
      if (!context || !dbManager) {
        expect(context).not().assertNull();
        expect(dbManager).not().assertNull();
        done();
        return;
      }

      const original = new FileInfo();
      original.uri = canonicalUri;
      original.fileName = EXPECTED_FILE_NAME;
      original.path = FileUtil.getPathFromUri(canonicalUri);
      original.mtime = 3609;
      original.mimeType = 'audio/*';
      original.size = 11121334;

      const saved = await dbManager.saveMetadata(original);
      expect(saved).assertTrue();

      const reimport = new FileInfo();
      reimport.uri = ENCODED_URI;
      reimport.fileName = '%E6%B4%9B%E5%A4%A9%E4%BE%9Dyousa%20-%20%E4%B8%89%E6%9C%88%E9%9B%A8.aac';
      reimport.path = FileUtil.getPathFromUri(ENCODED_URI);
      reimport.mtime = 3609;
      reimport.mimeType = 'audio/*';
      reimport.size = 11121334;

      const processed = await dbManager.upsertMediaMetadata([reimport]);
      expect(processed).assertEqual(1);

      const foundByEncoded = await dbManager.queryMediaMetadataByUri(ENCODED_URI);
      expect(foundByEncoded).not().assertNull();
      expect(foundByEncoded?.fileName).assertEqual(EXPECTED_FILE_NAME);

      const foundByCanonical = await dbManager.queryMediaMetadataByUri(canonicalUri);
      expect(foundByCanonical).not().assertNull();
      expect(foundByCanonical?.uri).assertEqual(canonicalUri);
      done();
    });
  });
}
