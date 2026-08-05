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
import { HiLog, MediaDbManager, FileInfo } from '@ohos/common';
import { TestUtil } from '../utils/TestUtil';
import type common from '@ohos.app.ability.common';

const TAG = 'MediaDbManagerIncrementalTest';

export default function MediaDbManagerIncrementalTest() {
  describe('MediaDbManagerIncrementalTest', () => {
    let context: common.Context | null = null;
    let dbManager: MediaDbManager | null = null;

    beforeAll(async () => {
      HiLog.i(TAG, 'MediaDbManagerIncremental beforeAll: start');
      await TestUtil.initTestEnvironment();
      context = TestUtil.getContext();
      dbManager = TestUtil.getDbManager();
      HiLog.i(TAG, 'MediaDbManagerIncremental beforeAll: context=' + (context ? 'valid' : 'null'));
      HiLog.i(TAG, 'MediaDbManagerIncremental beforeAll: dbManager=' + (dbManager ? 'valid' : 'null'));
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

    it('INCREMENTAL_01_query_new_files_after_timestamp', 0, async (done: Function) => {
      HiLog.i(TAG, 'INCREMENTAL_01: start');
      if (!context || !dbManager) {
        expect(context).not().assertNull();
        expect(dbManager).not().assertNull();
        done();
        return;
      }

      // 插入旧文件（update_time 在 lastScanTime 之前）
      const oldFileInfo = new FileInfo();
      oldFileInfo.uri = 'old_file_uri';
      oldFileInfo.fileName = 'old_file.mp3';
      oldFileInfo.duration = 1000;
      oldFileInfo.mimeType = 'audio/mp3';
      oldFileInfo.size = 1000;
      await dbManager.saveMetadata(oldFileInfo);

      await TestUtil.delay(100); // 确保时间戳不同
      const lastScanTime = Date.now();
      await TestUtil.delay(100);
      
      // 插入新文件（update_time 在 lastScanTime 之后）
      const newFileInfo = new FileInfo();
      newFileInfo.uri = 'new_file_uri';
      newFileInfo.fileName = 'new_file.mp3';
      newFileInfo.duration = 2000;
      newFileInfo.mimeType = 'audio/mp3';
      newFileInfo.size = 2000;
      await dbManager.saveMetadata(newFileInfo);

      // 查询增量变更
      const changes = await dbManager.queryIncrementalChanges(lastScanTime, 1);
      expect(changes.length).assertEqual(1);
      expect(changes[0].uri).assertEqual('new_file_uri');

      HiLog.i(TAG, 'INCREMENTAL_01: test passed');
      done();
    });

    it('INCREMENTAL_02_query_deleted_files', 0, async (done: Function) => {
      HiLog.i(TAG, 'INCREMENTAL_02: start');
      if (!context || !dbManager) {
        expect(context).not().assertNull();
        expect(dbManager).not().assertNull();
        done();
        return;
      }

      // 插入文件
      const fileInfo = new FileInfo();
      fileInfo.uri = 'deleted_file_uri';
      fileInfo.fileName = 'deleted_file.mp3';
      fileInfo.duration = 1000;
      fileInfo.mimeType = 'audio/mp3';
      fileInfo.size = 1000;
      await dbManager.saveMetadata(fileInfo);

      // 标记为无效（模拟删除）
      await dbManager.markAsInvalid('deleted_file_uri');

      const lastScanTime = Date.now() - 10000;

      // 查询增量变更（应该包含已删除的文件）
      const changes = await dbManager.queryIncrementalChanges(lastScanTime, 1);
      expect(changes.length).assertLargerOrEqual(1);
      const deletedFile = changes.find(f => f.uri === 'deleted_file_uri');
      expect(deletedFile).not().assertNull();

      HiLog.i(TAG, 'INCREMENTAL_02: test passed');
      done();
    });

    it('INCREMENTAL_03_query_modified_files', 0, async (done: Function) => {
      HiLog.i(TAG, 'INCREMENTAL_03: start');
      if (!context || !dbManager) {
        expect(context).not().assertNull();
        expect(dbManager).not().assertNull();
        done();
        return;
      }

      // 插入文件
      const fileInfo = new FileInfo();
      fileInfo.uri = 'modified_file_uri';
      fileInfo.fileName = 'original_name.mp3';
      fileInfo.duration = 1000;
      fileInfo.mimeType = 'audio/mp3';
      fileInfo.size = 1000;
      await dbManager.saveMetadata(fileInfo);

      const lastScanTime = Date.now();
      await TestUtil.delay(100);

      // 更新文件（模拟修改）
      fileInfo.fileName = 'modified_name.mp3';
      fileInfo.duration = 2000;
      fileInfo.size = 2000;
      await dbManager.updateMediaMetadata(fileInfo);

      // 查询增量变更（应该包含修改的文件）
      const changes = await dbManager.queryIncrementalChanges(lastScanTime, 1);
      expect(changes.length).assertLargerOrEqual(1);
      const modifiedFile = changes.find(f => f.uri === 'modified_file_uri');
      expect(modifiedFile).not().assertNull();
      expect(modifiedFile.fileName).assertEqual('modified_name.mp3');

      HiLog.i(TAG, 'INCREMENTAL_03: test passed');
      done();
    });

    it('INCREMENTAL_04_query_by_media_type', 0, async (done: Function) => {
      HiLog.i(TAG, 'INCREMENTAL_04: start');
      if (!context || !dbManager) {
        expect(context).not().assertNull();
        expect(dbManager).not().assertNull();
        done();
        return;
      }

      const lastScanTime = Date.now();
      await TestUtil.delay(100);

      // 插入音频文件
      const audioFileInfo = new FileInfo();
      audioFileInfo.uri = 'audio_file_uri';
      audioFileInfo.fileName = 'audio_file.mp3';
      audioFileInfo.duration = 1000;
      audioFileInfo.mimeType = 'audio/mp3';
      audioFileInfo.size = 1000;
      await dbManager.saveMetadata(audioFileInfo);

      // 插入视频文件
      const videoFileInfo = new FileInfo();
      videoFileInfo.uri = 'video_file_uri';
      videoFileInfo.fileName = 'video_file.mp4';
      videoFileInfo.duration = 2000;
      videoFileInfo.mimeType = 'video/mp4';
      videoFileInfo.size = 2000;
      await dbManager.saveMetadata(videoFileInfo);

      // 查询音频类型的增量变更
      const audioChanges = await dbManager.queryIncrementalChanges(lastScanTime, 1);
      expect(audioChanges.length).assertEqual(1);
      expect(audioChanges[0].uri).assertEqual('audio_file_uri');

      // 查询视频类型的增量变更
      const videoChanges = await dbManager.queryIncrementalChanges(lastScanTime, 2);
      expect(videoChanges.length).assertEqual(1);
      expect(videoChanges[0].uri).assertEqual('video_file_uri');

      HiLog.i(TAG, 'INCREMENTAL_04: test passed');
      done();
    });

    it('INCREMENTAL_05_query_all_types', 0, async (done: Function) => {
      HiLog.i(TAG, 'INCREMENTAL_05: start');
      if (!context || !dbManager) {
        expect(context).not().assertNull();
        expect(dbManager).not().assertNull();
        done();
        return;
      }

      const lastScanTime = Date.now();
      await TestUtil.delay(100);

      // 插入音频文件
      const audioFileInfo = new FileInfo();
      audioFileInfo.uri = 'audio_file_uri_all';
      audioFileInfo.fileName = 'audio_file.mp3';
      audioFileInfo.duration = 1000;
      audioFileInfo.mimeType = 'audio/mp3';
      audioFileInfo.size = 1000;
      await dbManager.saveMetadata(audioFileInfo);

      // 插入视频文件
      const videoFileInfo = new FileInfo();
      videoFileInfo.uri = 'video_file_uri_all';
      videoFileInfo.fileName = 'video_file.mp4';
      videoFileInfo.duration = 2000;
      videoFileInfo.mimeType = 'video/mp4';
      videoFileInfo.size = 2000;
      await dbManager.saveMetadata(videoFileInfo);

      // 查询所有类型的增量变更（不指定 mediaType）
      const allChanges = await dbManager.queryIncrementalChanges(lastScanTime);
      expect(allChanges.length).assertEqual(2);

      HiLog.i(TAG, 'INCREMENTAL_05: test passed');
      done();
    });

    it('INCREMENTAL_06_empty_result_when_no_changes', 0, async (done: Function) => {
      HiLog.i(TAG, 'INCREMENTAL_06: start');
      if (!context || !dbManager) {
        expect(context).not().assertNull();
        expect(dbManager).not().assertNull();
        done();
        return;
      }

      // 插入旧文件
      const fileInfo = new FileInfo();
      fileInfo.uri = 'old_file_uri_no_change';
      fileInfo.fileName = 'old_file.mp3';
      fileInfo.duration = 1000;
      fileInfo.mimeType = 'audio/mp3';
      fileInfo.size = 1000;
      await dbManager.saveMetadata(fileInfo);

      await TestUtil.delay(100);
      const lastScanTime = Date.now();

      // 查询增量变更（应该为空）
      const changes = await dbManager.queryIncrementalChanges(lastScanTime, 1);
      expect(changes.length).assertEqual(0);

      HiLog.i(TAG, 'INCREMENTAL_06: test passed');
      done();
    });
  });
}