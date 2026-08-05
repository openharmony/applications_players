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

import { describe, expect, it, beforeAll, afterAll, beforeEach, afterEach } from '@ohos/hypium';
import { MediaDbManager, HiLog, FileInfo } from '@ohos/common';
import { TestUtil } from '../utils/TestUtil';
import type common from '@ohos.app.ability.common';
import relationalStore from '@ohos.data.relationalStore';

const TAG = 'MediaDbManagerIndexTest';

export default function MediaDbManagerIndexTest() {
  describe('DatabaseIndexTest', () => {
    let context: common.Context | null = null;
    let dbManager: MediaDbManager | null = null;

    beforeAll(async () => {
      HiLog.i(TAG, 'DatabaseIndex beforeAll: start');
      await TestUtil.initTestEnvironment();
      context = TestUtil.getContext();
      dbManager = TestUtil.getDbManager();
      HiLog.i(TAG, 'DatabaseIndex beforeAll: context=' + (context ? 'valid' : 'null'));
      HiLog.i(TAG, 'DatabaseIndex beforeAll: dbManager=' + (dbManager ? 'valid' : 'null'));
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
      // Cleanup test data
      if (dbManager) {
        await dbManager.clearPlayHistory();
      }
    });

    it('INDEX_01_verify_play_history_indexes_exist', 0, async (done: Function) => {
      HiLog.i(TAG, 'INDEX_01: start');
      if (!context || !dbManager) {
        expect(context).not().assertNull();
        expect(dbManager).not().assertNull();
        done();
        return;
      }

      const rdbStore = dbManager.getRdbStore();
      if (!rdbStore) {
        expect(rdbStore).not().assertNull();
        done();
        return;
      }

      // Check if idx_play_history_last_play_time exists
      const index1Sql = "SELECT name FROM sqlite_master WHERE type='index' AND name='idx_play_history_last_play_time'";
      const resultSet1 = await rdbStore.querySql(index1Sql);
      const hasIndex1 = resultSet1.goToFirstRow();
      resultSet1.close();
      expect(hasIndex1).assertTrue();

      // Check if idx_play_history_uri exists
      const index2Sql = "SELECT name FROM sqlite_master WHERE type='index' AND name='idx_play_history_uri'";
      const resultSet2 = await rdbStore.querySql(index2Sql);
      const hasIndex2 = resultSet2.goToFirstRow();
      resultSet2.close();
      expect(hasIndex2).assertTrue();

      HiLog.i(TAG, 'INDEX_01: indexes verified');
      done();
    });

    it('INDEX_02_verify_media_metadata_indexes_exist', 0, async (done: Function) => {
      HiLog.i(TAG, 'INDEX_02: start');
      if (!context || !dbManager) {
        expect(context).not().assertNull();
        expect(dbManager).not().assertNull();
        done();
        return;
      }

      const rdbStore = dbManager.getRdbStore();
      if (!rdbStore) {
        expect(rdbStore).not().assertNull();
        done();
        return;
      }

      // Check if idx_media_metadata_type_valid_time exists
      const index1Sql = "SELECT name FROM sqlite_master WHERE type='index' AND name='idx_media_metadata_type_valid_time'";
      const resultSet1 = await rdbStore.querySql(index1Sql);
      const hasIndex1 = resultSet1.goToFirstRow();
      resultSet1.close();
      expect(hasIndex1).assertTrue();

      // Check if idx_media_metadata_valid exists
      const index2Sql = "SELECT name FROM sqlite_master WHERE type='index' AND name='idx_media_metadata_valid'";
      const resultSet2 = await rdbStore.querySql(index2Sql);
      const hasIndex2 = resultSet2.goToFirstRow();
      resultSet2.close();
      expect(hasIndex2).assertTrue();

      HiLog.i(TAG, 'INDEX_02: indexes verified');
      done();
    });

    it('INDEX_03_verify_playlist_item_indexes_exist', 0, async (done: Function) => {
      HiLog.i(TAG, 'INDEX_03: start');
      if (!context || !dbManager) {
        expect(context).not().assertNull();
        expect(dbManager).not().assertNull();
        done();
        return;
      }

      const rdbStore = dbManager.getRdbStore();
      if (!rdbStore) {
        expect(rdbStore).not().assertNull();
        done();
        return;
      }

      // Check if idx_playlist_item_playlist_position exists
      const indexSql = "SELECT name FROM sqlite_master WHERE type='index' AND name='idx_playlist_item_playlist_position'";
      const resultSet = await rdbStore.querySql(indexSql);
      const hasIndex = resultSet.goToFirstRow();
      resultSet.close();
      expect(hasIndex).assertTrue();

      HiLog.i(TAG, 'INDEX_03: indexes verified');
      done();
    });

    it('INDEX_04_query_performance_with_indexes', 0, async (done: Function) => {
      HiLog.i(TAG, 'INDEX_04: start');
      if (!context || !dbManager) {
        expect(context).not().assertNull();
        expect(dbManager).not().assertNull();
        done();
        return;
      }

      // Insert test data
      const testFiles: FileInfo[] = [];
      for (let i = 0; i < 100; i++) {
        const fileInfo = new FileInfo();
        fileInfo.uri = `test_uri_${i}`;
        fileInfo.fileName = `test_file_${i}.mp3`;
        fileInfo.duration = 1000 + i;
        fileInfo.mimeType = 'audio/mp3';
        testFiles.push(fileInfo);
      }

      await dbManager.batchInsertMediaMetadata(testFiles);

      // Measure query performance
      const startTime = Date.now();
      const results = await dbManager.queryMediaMetadata(1); // Query audio files
      const endTime = Date.now();
      const queryTime = endTime - startTime;

      HiLog.i(TAG, `INDEX_04: query time ${queryTime}ms, results ${results.length}`);

      // Query should complete in reasonable time (with indexes, should be fast)
      expect(queryTime).assertLess(100); // Should be less than 100ms for 100 records
      expect(results.length).assertLargerOrEqual(0);

      done();
    });

    it('INDEX_05_play_history_query_performance', 0, async (done: Function) => {
      HiLog.i(TAG, 'INDEX_05: start');
      if (!context || !dbManager) {
        expect(context).not().assertNull();
        expect(dbManager).not().assertNull();
        done();
        return;
      }

      // Insert test play history
      for (let i = 0; i < 50; i++) {
        const fileInfo = new FileInfo();
        fileInfo.uri = `history_uri_${i}`;
        fileInfo.fileName = `history_file_${i}.mp3`;
        fileInfo.duration = 1000 + i;
        fileInfo.mimeType = 'audio/mp3';
        await dbManager.savePlayHistory(fileInfo, i * 10);
      }

      // Measure query performance with ORDER BY last_play_time DESC
      const startTime = Date.now();
      const history = await dbManager.getPlayHistory(50);
      const endTime = Date.now();
      const queryTime = endTime - startTime;

      HiLog.i(TAG, `INDEX_05: query time ${queryTime}ms, history ${history.length}`);

      // Query should be fast with index on last_play_time DESC
      expect(queryTime).assertLess(50); // Should be less than 50ms
      expect(history.length).assertLargerOrEqual(0);

      done();
    });

    it('INDEX_06_playlist_items_query_performance', 0, async (done: Function) => {
      HiLog.i(TAG, 'INDEX_06: start');
      if (!context || !dbManager) {
        expect(context).not().assertNull();
        expect(dbManager).not().assertNull();
        done();
        return;
      }

      // Create playlist and add items
      const playlistId = await dbManager.createPlaylist('Test Playlist');
      expect(playlistId).assertLarger(0);

      // Add 100 items to playlist
      for (let i = 0; i < 100; i++) {
        await dbManager.addToPlaylist(playlistId, `playlist_uri_${i}`, i);
      }

      // Measure query performance with ORDER BY position
      const startTime = Date.now();
      const items = await dbManager.getPlaylistItems(playlistId);
      const endTime = Date.now();
      const queryTime = endTime - startTime;

      HiLog.i(TAG, `INDEX_06: query time ${queryTime}ms, items ${items.length}`);

      // Query should be fast with index on (playlist_id, position)
      expect(queryTime).assertLess(50); // Should be less than 50ms
      expect(items.length).assertEqual(100);

      done();
    });
  });
}