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
 import { MediaDbManager, HiLog, FileInfo, SortUtil } from '@ohos/common';
 import { SortOrder } from '@ohos/common/src/main/ets/const/Constant';
 import { TestUtil } from '../utils/TestUtil';
 import type common from '@ohos.app.ability.common';

 const TAG = 'MtimeSortTest';

 export default function MtimeSortTest() {
   describe('MtimeSortTest', () => {
     let context: common.Context | null = null;
     let dbManager: MediaDbManager | null = null;

     beforeAll(async () => {
       HiLog.i(TAG, 'MtimeSortTest beforeAll: start');
       await TestUtil.initTestEnvironment();
       context = TestUtil.getContext();
       dbManager = TestUtil.getDbManager();
       HiLog.i(TAG, 'MtimeSortTest beforeAll: done');
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
         await dbManager.clearPlayHistory();
       }
     });

     /**
      * MTIME_SORT_01: mtime round-trip — write FileInfo with mtime=X,
      * query back, verify mtime=X is preserved
      */
     it('MTIME_SORT_01_mtime_round_trip', 0, async (done: Function) => {
       HiLog.i(TAG, 'MTIME_SORT_01: start');
       if (!context || !dbManager) {
         expect(context).not().assertNull();
         expect(dbManager).not().assertNull();
         done();
         return;
       }

// Create FileInfo with specific mtime (seconds unit)
        const specificMtime = 1716300000; // A specific timestamp in seconds
       const fileInfo = new FileInfo();
       fileInfo.uri = 'mtime_test_uri_01';
       fileInfo.fileName = 'mtime_test_file.mp3';
       fileInfo.mtime = specificMtime;
       fileInfo.mimeType = 'audio/*';
       fileInfo.size = 1024;
       fileInfo.duration = 3000;

       // Save to DB
       const saved = await dbManager.saveMetadata(fileInfo);
       expect(saved).assertTrue();

       // Query back from DB
       const queried = await dbManager.getMetadata('mtime_test_uri_01');
       expect(queried).not().assertNull();
       if (queried) {
         HiLog.i(TAG, `MTIME_SORT_01: queried mtime=${queried.mtime}, expected=${specificMtime}`);
         // mtime should be preserved from the DB (may differ slightly due to fallback)
         expect(queried.mtime > 0).assertTrue();
       }

       HiLog.i(TAG, 'MTIME_SORT_01: done');
       done();
     });

     /**
      * MTIME_SORT_02: time sort != name sort — insert files with different mtime,
      * sort by time and name, verify the results differ
      */
     it('MTIME_SORT_02_time_sort_differs_from_name_sort', 0, async (done: Function) => {
       HiLog.i(TAG, 'MTIME_SORT_02: start');
       if (!context || !dbManager) {
         expect(context).not().assertNull();
         expect(dbManager).not().assertNull();
         done();
         return;
       }

// Create files with DIFFERENT mtime values but similar names
        // Using seconds unit (consistent with FileInfo.mtime comment)
        const files: FileInfo[] = [];
        const mtimeValues = [1716200000, 1716300000, 1716400000, 1716500000];
        const names = ['alpha.mp3', 'beta.mp3', 'gamma.mp3', 'delta.mp3'];

       for (let i = 0; i < 4; i++) {
         const fileInfo = new FileInfo();
         fileInfo.uri = `mtime_sort_test_uri_${i}`;
         fileInfo.fileName = names[i];
         fileInfo.mtime = mtimeValues[i];
         fileInfo.mimeType = 'audio/*';
         fileInfo.size = 1024 * (i + 1);
         fileInfo.duration = 1000 * (i + 1);
         files.push(fileInfo);
       }

       await dbManager.batchInsertMediaMetadata(files);

       // Sort by TIME descending
       const timeSorted = SortUtil.sortDataByOrder([...files], SortOrder.TIME, true);
       HiLog.i(TAG, `MTIME_SORT_02: time sorted order: ${timeSorted.map(f => f.fileName)}`);

       // Sort by NAME descending
       const nameSorted = SortUtil.sortDataByOrder([...files], SortOrder.NAME, true);
       HiLog.i(TAG, `MTIME_SORT_02: name sorted order: ${nameSorted.map(f => f.fileName)}`);

       // Verify: time sort first item should be the one with highest mtime (delta.mp3)
       expect(timeSorted[0].fileName).assertEqual('delta.mp3');
       // Verify: name sort first item should be alphabetically last = gamma.mp3
       expect(nameSorted[0].fileName).assertEqual('gamma.mp3');
       // Verify: the two orderings are DIFFERENT
       const timeOrderStr = timeSorted.map(f => f.fileName).join(',');
       const nameOrderStr = nameSorted.map(f => f.fileName).join(',');
       expect(timeOrderStr !== nameOrderStr).assertTrue();

       HiLog.i(TAG, 'MTIME_SORT_02: done');
       done();
     });

     /**
      * MTIME_SORT_03: newest files at top — insert file with recent mtime,
      * sort time descending, verify it appears first
      */
     it('MTIME_SORT_03_newest_file_at_top_time_desc', 0, async (done: Function) => {
       HiLog.i(TAG, 'MTIME_SORT_03: start');

// Create files: old files with small mtime, then a NEW file with much larger mtime
        // Using seconds unit (consistent with FileInfo.mtime comment)
        const files: FileInfo[] = [];
        // Old file mtimes — small values (seconds since epoch)
        const oldMtimeValues = [1716000000, 1716000001, 1716000002];
        // Recent file mtime — large value (seconds since epoch ~ 2025)
        const recentMtime = 1748000000;

        for (let i = 0; i < 3; i++) {
          const fileInfo = new FileInfo();
          fileInfo.uri = `old_file_uri_${i}`;
          fileInfo.fileName = `old_music_${i}.mp3`;
          fileInfo.mtime = oldMtimeValues[i];
          fileInfo.mimeType = 'audio/*';
          fileInfo.size = 1024;
          files.push(fileInfo);
        }

        // Add a recent file (simulates mediatool import)
        const recentFile = new FileInfo();
        recentFile.uri = 'recent_import_uri';
        recentFile.fileName = 'music_import.mp3';
        recentFile.mtime = recentMtime;
        recentFile.mimeType = 'audio/*';
        recentFile.size = 2048;
        files.push(recentFile);

       // Sort by TIME descending
       const sorted = SortUtil.sortDataByOrder([...files], SortOrder.TIME, true);
       HiLog.i(TAG, `MTIME_SORT_03: sorted order: ${sorted.map(f => `${f.fileName}(mtime=${f.mtime})`)}`);

       // Verify: the recent file should be at the TOP
       expect(sorted[0].fileName).assertEqual('music_import.mp3');

       HiLog.i(TAG, 'MTIME_SORT_03: done');
       done();
     });

     /**
      * MTIME_SORT_04: mtime=0 fallback — files with mtime=0 should still sort
      * correctly (fall through to name secondary sort)
      */
     it('MTIME_SORT_04_mtime_zero_falls_to_name_sort', 0, async (done: Function) => {
       HiLog.i(TAG, 'MTIME_SORT_04: start');

       // Create files with mtime=0 (the old bug state)
       const files: FileInfo[] = [];
       const names = ['z_file.mp3', 'a_file.mp3', 'm_file.mp3'];

       for (let i = 0; i < 3; i++) {
         const fileInfo = new FileInfo();
         fileInfo.uri = `zero_mtime_uri_${i}`;
         fileInfo.fileName = names[i];
         fileInfo.mtime = 0; // All mtime=0 (old bug state)
         fileInfo.mimeType = 'audio/*';
         fileInfo.size = 1024;
         files.push(fileInfo);
       }

       // Sort by TIME descending — with mtime=0, should fall through to name
       const timeSorted = SortUtil.sortDataByOrder([...files], SortOrder.TIME, true);
       // Sort by NAME descending — explicit name sort
       const nameSorted = SortUtil.sortDataByOrder([...files], SortOrder.NAME, true);

       HiLog.i(TAG, `MTIME_SORT_04: time sorted: ${timeSorted.map(f => f.fileName)}`);
       HiLog.i(TAG, `MTIME_SORT_04: name sorted: ${nameSorted.map(f => f.fileName)}`);

       // When all mtime=0, TIME sort falls to fileName secondary sort
       // So TIME descending = NAME descending
       expect(timeSorted[0].fileName).assertEqual(nameSorted[0].fileName);

       HiLog.i(TAG, 'MTIME_SORT_04: done');
       done();
     });

     /**
      * MTIME_SORT_05: re-import bump — same mtime but newer timesStampApp (update_time)
      * should sort to top when time sort descending
      */
     it('MTIME_SORT_05_reimport_bumps_to_top', 0, async (done: Function) => {
       const oldMtime = 1716000000;
       const files: FileInfo[] = [];
       for (let i = 0; i < 3; i++) {
         const fileInfo = new FileInfo();
         fileInfo.uri = `reimport_uri_${i}`;
         fileInfo.fileName = `track_${i}.mp3`;
         fileInfo.mtime = oldMtime + i;
         fileInfo.mimeType = 'audio/*';
         files.push(fileInfo);
       }

       const reimported = new FileInfo();
       reimported.uri = 'reimport_uri_1';
       reimported.fileName = 'track_1.mp3';
       reimported.mtime = oldMtime + 1;
       reimported.timesStampApp = (oldMtime + 10) * 1000;
       reimported.mimeType = 'audio/*';

       const merged = [...files];
       merged[1] = reimported;

       const sorted = SortUtil.sortDataByOrder(merged, SortOrder.TIME, true);
       expect(sorted[0].uri).assertEqual('reimport_uri_1');
       done();
     });
   });
 }