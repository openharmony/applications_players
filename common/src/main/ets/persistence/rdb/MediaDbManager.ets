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

import { Rdb } from './Rdb';
import { FileInfo } from '../../utils/FileOperateInfo';
import { FileUtil } from '../../utils/FileUtil';
import { HiLog } from '../../utils/HiLog';
import { StringUtil } from '../../utils/StringUtil';
import { SupportedMediaFormats } from '../../constants/media/SupportedMediaFormats';
import relationalStore from '@ohos.data.relationalStore';
import type common from '@ohos.app.ability.common';

const TAG = 'MediaDbManager';

/** 播放列表数据库记录 */
export interface PlaylistRecord {
  id: number;
  name: string;
  createTime: number;
  itemCount: number;
  position: number;
}

const MEDIA_DB_CONFIG: relationalStore.StoreConfig = {
  name: 'media.db',
  securityLevel: relationalStore.SecurityLevel.S1
};

const PLAY_HISTORY_TABLE_SQL = `
  CREATE TABLE IF NOT EXISTS play_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    uri TEXT NOT NULL,
    file_name TEXT NOT NULL,
    media_type INTEGER,
    play_time INTEGER,
    duration INTEGER,
    play_progress INTEGER,
    play_count INTEGER DEFAULT 0,
    last_play_time INTEGER
  )
`;

const MEDIA_METADATA_TABLE_SQL = `
  CREATE TABLE IF NOT EXISTS media_metadata (
    uri TEXT PRIMARY KEY,
    title TEXT,
    artist TEXT,
    album TEXT,
    duration INTEGER,
    bitrate INTEGER,
    codec TEXT,
    cover_image TEXT,
    update_time INTEGER,
    mtime INTEGER DEFAULT 0,
    ctime INTEGER DEFAULT 0,
    file_size INTEGER,
    file_path TEXT,
    media_type INTEGER,
    is_valid INTEGER DEFAULT 1
  )
`;

const PLAYLIST_TABLE_SQL = `
  CREATE TABLE IF NOT EXISTS playlist (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    create_time INTEGER,
    play_mode INTEGER DEFAULT 0,
    position INTEGER DEFAULT 0
  )
`;

const PLAYLIST_ITEM_TABLE_SQL = `
  CREATE TABLE IF NOT EXISTS playlist_item (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    playlist_id INTEGER,
    uri TEXT NOT NULL,
    position INTEGER,
    FOREIGN KEY (playlist_id) REFERENCES playlist(id) ON DELETE CASCADE
  )
`;

export class MediaDbManager {
  private static instance: MediaDbManager;
  private playHistoryTable: Rdb;
  private mediaMetadataTable: Rdb;
  private playlistTable: Rdb;
  private playlistItemTable: Rdb;
  private context: common.Context;
  private initialized: boolean = false;

  private constructor(context: common.Context) {
    this.context = context;
    this.playHistoryTable = new Rdb('play_history', PLAY_HISTORY_TABLE_SQL, []);
    this.mediaMetadataTable = new Rdb('media_metadata', MEDIA_METADATA_TABLE_SQL, []);
    this.playlistTable = new Rdb('playlist', PLAYLIST_TABLE_SQL, []);
    this.playlistItemTable = new Rdb('playlist_item', PLAYLIST_ITEM_TABLE_SQL, []);
  }

  static getInstance(context: common.Context): MediaDbManager {
    if (!MediaDbManager.instance) {
      MediaDbManager.instance = new MediaDbManager(context);
    }
    return MediaDbManager.instance;
  }

  async init(): Promise<boolean> {
    if (this.initialized) {
      return true;
    }

    try {
      HiLog.i(TAG, 'Initializing media database');

      const success1 = await this.playHistoryTable.getRdbStore(MEDIA_DB_CONFIG);
      const success2 = await this.mediaMetadataTable.getRdbStore(MEDIA_DB_CONFIG);
      const success3 = await this.playlistTable.getRdbStore(MEDIA_DB_CONFIG);
      const success4 = await this.playlistItemTable.getRdbStore(MEDIA_DB_CONFIG);

      if (success1 && success2 && success3 && success4) {
        await this.createIndexes();
        this.initialized = true;
        HiLog.i(TAG, 'Media database initialized successfully');
        return true;
      }

      HiLog.e(TAG, 'Media database initialization failed');
      return false;
    } catch (error) {
      HiLog.e(TAG, `Media database initialization exception: ${error}`);
      return false;
    }
  }

  private async createIndexes(): Promise<void> {
    try {
      HiLog.i(TAG, 'Creating database indexes');

      const rdbStore = this.playHistoryTable.getRdbStoreSync();
      if (rdbStore) {
        // Create indexes for play_history table
        await rdbStore.executeSql(
          'CREATE INDEX IF NOT EXISTS idx_play_history_last_play_time ON play_history(last_play_time DESC)'
        );
        await rdbStore.executeSql(
          'CREATE INDEX IF NOT EXISTS idx_play_history_uri ON play_history(uri)'
        );

        // Create indexes for media_metadata table
        await rdbStore.executeSql(
          'CREATE INDEX IF NOT EXISTS idx_media_metadata_type_valid_time ON media_metadata(media_type, is_valid, update_time DESC)'
        );
        await rdbStore.executeSql(
          'CREATE INDEX IF NOT EXISTS idx_media_metadata_valid ON media_metadata(is_valid)'
        );

        // Create indexes for playlist_item table
        await rdbStore.executeSql(
          'CREATE INDEX IF NOT EXISTS idx_playlist_item_playlist_position ON playlist_item(playlist_id, position)'
        );

        // Schema migration: add mtime column for existing databases
        // ALTER TABLE ADD COLUMN fails if column already exists, so catch and continue
        try {
          await rdbStore.executeSql(
            'ALTER TABLE media_metadata ADD COLUMN mtime INTEGER DEFAULT 0'
          );
          HiLog.i(TAG, 'mtime column migration: new column added');
        } catch (migrationError) {
          // Column already exists — expected for databases created with new schema
          HiLog.i(TAG, `mtime column migration: column exists or migration error: ${migrationError}`);
        }

        try {
          await rdbStore.executeSql(
            'ALTER TABLE media_metadata ADD COLUMN ctime INTEGER DEFAULT 0'
          );
          HiLog.i(TAG, 'ctime column migration: new column added');
        } catch (migrationError) {
          HiLog.i(TAG, `ctime column migration: column exists or migration error: ${migrationError}`);
        }

        // Schema migration: add playlist.position for custom sort order
        try {
          await rdbStore.executeSql(
            'ALTER TABLE playlist ADD COLUMN position INTEGER DEFAULT 0'
          );
          HiLog.i(TAG, 'playlist position column migration: new column added');
          await this.backfillPlaylistPositions();
        } catch (playlistPositionError) {
          HiLog.i(TAG, `playlist position column migration: column exists or migration error: ${playlistPositionError}`);
        }

        HiLog.i(TAG, 'Database indexes created successfully');
      }
    } catch (error) {
      HiLog.e(TAG, `Failed to create database indexes: ${error}`);
    }
  }

  getRdbStore(): relationalStore.RdbStore | undefined {
    return this.playHistoryTable.getRdbStoreSync();
  }

  async savePlayHistory(fileInfo: FileInfo, progress: number = 0): Promise<boolean> {
    try {
      const values: relationalStore.ValuesBucket = {
        uri: fileInfo.uri,
        file_name: fileInfo.fileName,
        media_type: this.getMediaType(fileInfo),
        play_time: Date.now(),
        duration: fileInfo.duration,
        play_progress: progress,
        last_play_time: Date.now()
      };

      await this.playHistoryTable.insertData(values);
      HiLog.i(TAG, `Saved play history: ${fileInfo.fileName}`);
      return true;
    } catch (error) {
      HiLog.e(TAG, `Failed to save play history: ${error}`);
      return false;
    }
  }

  async getPlayHistory(limit: number = 50): Promise<FileInfo[]> {
    try {
      const resultSet = await this.playHistoryTable.queryData(
        new relationalStore.RdbPredicates('play_history')
          .orderByDesc('last_play_time')
          .limitAs(limit)
      );

      if (!resultSet) {
        return [];
      }

      const files: FileInfo[] = [];
      while (resultSet.goToNextRow()) {
        const fileInfo = new FileInfo();
        const uriIndex = resultSet.getColumnIndex('uri');
        const fileNameIndex = resultSet.getColumnIndex('file_name');
        const durationIndex = resultSet.getColumnIndex('duration');
        const lastPlayTimeIndex = resultSet.getColumnIndex('last_play_time');

        fileInfo.uri = resultSet.getString(uriIndex);
        fileInfo.fileName = resultSet.getString(fileNameIndex);
        fileInfo.duration = resultSet.getLong(durationIndex);
        fileInfo.recentTime = resultSet.getLong(lastPlayTimeIndex);
        files.push(fileInfo);
      }

      HiLog.i(TAG, `Fetched play history, ${files.length} records`);
      return files;
    } catch (error) {
      HiLog.e(TAG, `Failed to fetch play history: ${error}`);
      return [];
    }
  }

  async saveMetadata(fileInfo: FileInfo): Promise<boolean> {
    try {
      FileUtil.applyCanonicalMediaIdentity(fileInfo);
      const now = Date.now();
      const values: relationalStore.ValuesBucket = {
        uri: fileInfo.uri,
        title: fileInfo.fileName,
        artist: fileInfo.appSourceName || '',
        album: '',
        duration: fileInfo.duration,
        bitrate: 0,
        codec: '',
        cover_image: fileInfo.coverUri || fileInfo.thumbUri || '',
        update_time: now,
        mtime: fileInfo.mtime,
        ctime: fileInfo.ctime,
        file_size: fileInfo.size,
        file_path: fileInfo.path || fileInfo.uri,
        media_type: this.getMediaType(fileInfo),
        is_valid: 1
      };

      await this.mediaMetadataTable.insertData(values);
      fileInfo.timesStampApp = now;
      fileInfo.thumbnailModifiledMs = now;
      HiLog.i(TAG, `Saved metadata: ${fileInfo.fileName}, mtime: ${fileInfo.mtime}`);
      return true;
    } catch (error) {
      HiLog.e(TAG, `Failed to save metadata: ${error}`);
      return false;
    }
  }

  async getMetadata(uri: string): Promise<FileInfo | null> {
    return await this.queryMediaMetadataByUri(uri);
  }

  async createPlaylist(name: string): Promise<number> {
    try {
      const position = await this.getNextPlaylistPosition();
      const values: relationalStore.ValuesBucket = {
        name: name,
        create_time: Date.now(),
        play_mode: 0,
        position: position
      };

      const rowId = await this.playlistTable.insertData(values);
      HiLog.i(TAG, `Created playlist: ${name}, id: ${rowId}, position: ${position}`);
      return rowId;
    } catch (error) {
      HiLog.e(TAG, `Failed to create playlist: ${error}`);
      return -1;
    }
  }

  async addToPlaylist(playlistId: number, uri: string, position: number): Promise<boolean> {
    try {
      const values: relationalStore.ValuesBucket = {
        playlist_id: playlistId,
        uri: uri,
        position: position
      };

      await this.playlistItemTable.insertData(values);
      HiLog.i(TAG, `Added to playlist: playlistId=${playlistId}, uri=${uri}`);
      return true;
    } catch (error) {
      HiLog.e(TAG, `Failed to add to playlist: ${error}`);
      return false;
    }
  }

  async getPlaylistItems(playlistId: number): Promise<string[]> {
    try {
      const resultSet = await this.playlistItemTable.queryData(
        new relationalStore.RdbPredicates('playlist_item')
          .equalTo('playlist_id', playlistId)
          .orderByAsc('position')
      );

      if (!resultSet) {
        return [];
      }

      const uris: string[] = [];
      while (resultSet.goToNextRow()) {
        const uriIndex = resultSet.getColumnIndex('uri');
        uris.push(resultSet.getString(uriIndex));
      }

      HiLog.i(TAG, `Fetched playlist items, ${uris.length} files`);
      return uris;
    } catch (error) {
      HiLog.e(TAG, `Failed to fetch playlist items: ${error}`);
      return [];
    }
  }

  /**
   * 批量查询各歌单首曲 URI（按 position 升序、id 升序取第一条）
   *
   * @returns playlistId → 首曲 uri
   */
  async getPlaylistFirstTrackUriMap(playlistIds: number[]): Promise<Map<number, string>> {
    const map = new Map<number, string>();
    if (playlistIds.length === 0) {
      return map;
    }
    try {
      for (let i = 0; i < playlistIds.length; i++) {
        const playlistId = playlistIds[i];
        const uris = await this.getPlaylistItems(playlistId);
        if (uris.length > 0) {
          map.set(playlistId, uris[0]);
        }
      }
      HiLog.i(TAG, `getPlaylistFirstTrackUriMap count=${map.size}`);
      return map;
    } catch (error) {
      HiLog.e(TAG, `getPlaylistFirstTrackUriMap failed: ${error}`);
      return map;
    }
  }

  /**
   * 查询全部播放列表及曲目数量
   *
   * @returns 播放列表记录数组
   */
  async getAllPlaylists(): Promise<PlaylistRecord[]> {
    try {
      const rdbStore = this.playlistTable.getRdbStoreSync();
      if (!rdbStore) {
        return [];
      }
      const sql = `SELECT p.id, p.name, p.create_time, p.position, COUNT(pi.id) AS item_count
        FROM playlist p
        LEFT JOIN playlist_item pi ON p.id = pi.playlist_id
        GROUP BY p.id
        ORDER BY p.position ASC, p.id ASC`;
      const resultSet = await rdbStore.querySql(sql);
      if (!resultSet) {
        return [];
      }
      const records: PlaylistRecord[] = [];
      while (resultSet.goToNextRow()) {
        records.push({
          id: resultSet.getLong(resultSet.getColumnIndex('id')),
          name: resultSet.getString(resultSet.getColumnIndex('name')),
          createTime: resultSet.getLong(resultSet.getColumnIndex('create_time')),
          itemCount: resultSet.getLong(resultSet.getColumnIndex('item_count')),
          position: resultSet.getLong(resultSet.getColumnIndex('position'))
        });
      }
      resultSet.close();
      HiLog.i(TAG, `Queried playlists: ${records.length}, by position ascending`);
      return records;
    } catch (error) {
      HiLog.e(TAG, `Failed to query playlists: ${error}`);
      return [];
    }
  }

  /**
   * 重命名播放列表
   *
   * @param playlistId 列表 ID
   * @param name 新名称
   * @returns 是否成功
   */
  async renamePlaylist(playlistId: number, name: string): Promise<boolean> {
    try {
      await this.playlistTable.updateData(
        { name: name } as relationalStore.ValuesBucket,
        new relationalStore.RdbPredicates('playlist').equalTo('id', playlistId)
      );
      HiLog.i(TAG, `Renamed playlist id=${playlistId} name=${name}`);
      return true;
    } catch (error) {
      HiLog.e(TAG, `Failed to rename playlist: ${error}`);
      return false;
    }
  }

  /**
   * 删除播放列表及其全部曲目
   *
   * @param playlistId 列表 ID
   * @returns 是否成功
   */
  async deletePlaylist(playlistId: number): Promise<boolean> {
    try {
      await this.playlistItemTable.deleteData(
        new relationalStore.RdbPredicates('playlist_item').equalTo('playlist_id', playlistId)
      );
      await this.playlistTable.deleteData(
        new relationalStore.RdbPredicates('playlist').equalTo('id', playlistId)
      );
      HiLog.i(TAG, `Deleted playlist id=${playlistId}`);
      return true;
    } catch (error) {
      HiLog.e(TAG, `Failed to delete playlist: ${error}`);
      return false;
    }
  }

  /**
   * 从播放列表移除指定曲目
   *
   * @param playlistId 列表 ID
   * @param uris 曲目 URI 列表
   * @returns 是否成功
   */
  async removePlaylistItems(playlistId: number, uris: string[]): Promise<boolean> {
    if (uris.length === 0) {
      return true;
    }
    try {
      for (const uri of uris) {
        await this.playlistItemTable.deleteData(
          new relationalStore.RdbPredicates('playlist_item')
            .equalTo('playlist_id', playlistId)
            .equalTo('uri', uri)
        );
      }
      HiLog.i(TAG, `Removed playlist items playlistId=${playlistId} count=${uris.length}`);
      return true;
    } catch (error) {
      HiLog.e(TAG, `Failed to remove playlist items: ${error}`);
      return false;
    }
  }

  /**
   * 判断 URI 是否已在播放列表中
   *
   * @param playlistId 列表 ID
   * @param uri 媒体 URI
   * @returns 是否已存在
   */
  async isUriInPlaylist(playlistId: number, uri: string): Promise<boolean> {
    try {
      const resultSet = await this.playlistItemTable.queryData(
        new relationalStore.RdbPredicates('playlist_item')
          .equalTo('playlist_id', playlistId)
          .equalTo('uri', uri)
      );
      if (!resultSet) {
        return false;
      }
      const exists = resultSet.goToFirstRow();
      resultSet.close();
      return exists;
    } catch (error) {
      HiLog.e(TAG, `Failed to check playlist item existence: ${error}`);
      return false;
    }
  }

  /**
   * 获取播放列表下一首曲目的 position 序号
   *
   * @param playlistId 列表 ID
   * @returns 新曲目 position
   */
  async getNextPlaylistItemPosition(playlistId: number): Promise<number> {
    try {
      const uris = await this.getPlaylistItems(playlistId);
      return uris.length;
    } catch (error) {
      HiLog.e(TAG, `Failed to get playlist position: ${error}`);
      return 0;
    }
  }

  /**
   * 按新顺序批量更新播放列表 position
   *
   * @param playlistIds 排序后的播放列表 ID 列表
   * @returns 是否成功
   */
  async updatePlaylistPositions(playlistIds: number[]): Promise<boolean> {
    if (playlistIds.length === 0) {
      return true;
    }
    try {
      for (let index = 0; index < playlistIds.length; index++) {
        const playlistId = playlistIds[index];
        await this.playlistTable.updateData(
          { position: index } as relationalStore.ValuesBucket,
          new relationalStore.RdbPredicates('playlist').equalTo('id', playlistId)
        );
        HiLog.i(TAG, `playlist position id=${playlistId} index=${index}`);
      }
      const preview = playlistIds.map((id: number, index: number) => `${index}:${id}`).join('>');
      HiLog.i(TAG, `Updated playlist grid order count=${playlistIds.length} order=${preview}`);
      return true;
    } catch (error) {
      HiLog.e(TAG, `Failed to update playlist grid order: ${error}`);
      return false;
    }
  }

  /**
   * 获取下一个播放列表 position（新建列表追加在末尾）
   *
   * @returns 新列表 position
   */
  async getNextPlaylistPosition(): Promise<number> {
    try {
      const rdbStore = this.playlistTable.getRdbStoreSync();
      if (!rdbStore) {
        return 0;
      }
      const resultSet = await rdbStore.querySql('SELECT COALESCE(MAX(position), -1) AS max_position FROM playlist');
      if (!resultSet || !resultSet.goToFirstRow()) {
        return 0;
      }
      const maxPosition = resultSet.getLong(resultSet.getColumnIndex('max_position'));
      resultSet.close();
      return maxPosition + 1;
    } catch (error) {
      HiLog.e(TAG, `Failed to get playlist position: ${error}`);
      return 0;
    }
  }

  /**
   * 迁移后为存量播放列表按 id 升序回填 position
   */
  private async backfillPlaylistPositions(): Promise<void> {
    try {
      const rdbStore = this.playlistTable.getRdbStoreSync();
      if (!rdbStore) {
        return;
      }
      const resultSet = await rdbStore.querySql('SELECT id FROM playlist ORDER BY id ASC');
      if (!resultSet) {
        return;
      }
      let index = 0;
      while (resultSet.goToNextRow()) {
        const playlistId = resultSet.getLong(resultSet.getColumnIndex('id'));
        await this.playlistTable.updateData(
          { position: index } as relationalStore.ValuesBucket,
          new relationalStore.RdbPredicates('playlist').equalTo('id', playlistId)
        );
        index++;
      }
      resultSet.close();
      HiLog.i(TAG, `Backfilled playlist position count=${index}`);
    } catch (error) {
      HiLog.e(TAG, `Failed to backfill playlist position: ${error}`);
    }
  }

  /**
   * 按新顺序批量更新播放列表曲目 position
   *
   * @param playlistId 列表 ID
   * @param uris 排序后的 URI 列表
   * @returns 是否成功
   */
  async updatePlaylistItemPositions(playlistId: number, uris: string[]): Promise<boolean> {
    if (uris.length === 0) {
      return true;
    }
    try {
      for (let index = 0; index < uris.length; index++) {
        const fileName = uris[index].substring(uris[index].lastIndexOf('/') + 1);
        await this.playlistItemTable.updateData(
          { position: index } as relationalStore.ValuesBucket,
          new relationalStore.RdbPredicates('playlist_item')
            .equalTo('playlist_id', playlistId)
            .equalTo('uri', uris[index])
        );
        HiLog.i(TAG, `playlistItem position playlistId=${playlistId} index=${index} fileName=${fileName}`);
      }
      const preview = uris.map((uri: string, index: number) => `${index}:${uri.substring(uri.lastIndexOf('/') + 1)}`).join('>');
      HiLog.i(TAG, `Updated playlist order playlistId=${playlistId} count=${uris.length} order=${preview}`);
      return true;
    } catch (error) {
      HiLog.e(TAG, `Failed to update playlist order: ${error}`);
      return false;
    }
  }

  async deletePlayHistory(uri: string): Promise<boolean> {
    try {
      await this.playHistoryTable.deleteData(
        new relationalStore.RdbPredicates('play_history')
          .equalTo('uri', uri)
      );
      HiLog.i(TAG, `Deleted play history: ${uri}`);
      return true;
    } catch (error) {
      HiLog.e(TAG, `Failed to delete play history: ${error}`);
      return false;
    }
  }

  async clearPlayHistory(): Promise<boolean> {
    try {
      await this.playHistoryTable.deleteData(
        new relationalStore.RdbPredicates('play_history')
      );
      HiLog.i(TAG, 'Cleared play history');
      return true;
    } catch (error) {
      HiLog.e(TAG, `Failed to clear play history: ${error}`);
      return false;
    }
  }

  private getMediaType(fileInfo: FileInfo): number {
    if (fileInfo.mimeType?.startsWith('audio')) {
      return 1;
    } else if (fileInfo.mimeType?.startsWith('video')) {
      return 2;
    }
    // mimeType 不能识别时（如 application/ogg），按扩展名兜底
    if (SupportedMediaFormats.isSupportedAudio(fileInfo.fileName)) {
      return 1;
    } else if (SupportedMediaFormats.isSupportedVideo(fileInfo.fileName)) {
      return 2;
    }
    return 0;
  }

  /**
   * 导入 upsert：uri 不存在则插入，已存在则更新 update_time / mtime 等字段。
   *
   * @returns 成功处理的记录数
   */
  async upsertMediaMetadata(fileInfoList: FileInfo[]): Promise<number> {
    if (!fileInfoList || fileInfoList.length === 0) {
      return 0;
    }

    let processed = 0;
    try {
      for (let i = 0; i < fileInfoList.length; i++) {
        const fileInfo = fileInfoList[i];
        FileUtil.applyCanonicalMediaIdentity(fileInfo);
        const existing = await this.findExistingMediaMetadata(fileInfo);
        let success = false;
        if (existing) {
          fileInfo.uri = existing.uri;
          success = await this.updateMediaMetadata(fileInfo);
        } else {
          success = await this.saveMetadata(fileInfo);
        }
        if (success) {
          processed++;
        }
      }
      HiLog.i(TAG, `Import upsert completed: ${processed}/${fileInfoList.length}`);
      return processed;
    } catch (error) {
      HiLog.e(TAG, `Import upsert failed: ${error}`);
      return processed;
    }
  }

  async batchInsertMediaMetadata(fileInfoList: FileInfo[]): Promise<boolean> {
    if (!fileInfoList || fileInfoList.length === 0) {
      return true;
    }
    
    try {
      const valuesList: relationalStore.ValuesBucket[] = [];
      for (let i = 0; i < fileInfoList.length; i++) {
        const fileInfo = fileInfoList[i];
        FileUtil.applyCanonicalMediaIdentity(fileInfo);
        const values: relationalStore.ValuesBucket = {
          uri: fileInfo.uri,
          title: fileInfo.fileName,
          artist: fileInfo.appSourceName || '',
          album: '',
          duration: fileInfo.duration,
          bitrate: 0,
          codec: '',
          cover_image: fileInfo.coverUri || fileInfo.thumbUri || '',
          update_time: Date.now(),
          mtime: fileInfo.mtime,
          ctime: fileInfo.ctime,
          file_size: fileInfo.size,
          file_path: fileInfo.path || fileInfo.uri,
          media_type: this.getMediaType(fileInfo),
          is_valid: 1
        };
        valuesList.push(values);
      }
      
      await this.mediaMetadataTable.batchInsertData(valuesList);
      HiLog.i(TAG, `Batch saved metadata: ${fileInfoList.length} files`);
      return true;
    } catch (error) {
      HiLog.e(TAG, `Failed to batch save metadata: ${error}`);
      return false;
    }
  }

  async queryMediaMetadata(mediaType?: number): Promise<FileInfo[]> {
    try {
      let predicates = new relationalStore.RdbPredicates('media_metadata');
      
      if (mediaType !== undefined) {
        predicates = predicates.equalTo('media_type', mediaType);
      }
      
      predicates = predicates.equalTo('is_valid', 1).orderByDesc('update_time');
      
      const resultSet = await this.mediaMetadataTable.queryData(predicates);
      
      if (!resultSet) {
        return [];
      }
      
      const files: FileInfo[] = [];
      
      while (resultSet.goToNextRow()) {
        const fileInfo = new FileInfo();
        fileInfo.uri = resultSet.getString(resultSet.getColumnIndex('uri'));
        fileInfo.fileName = resultSet.getString(resultSet.getColumnIndex('title'));
        fileInfo.duration = resultSet.getLong(resultSet.getColumnIndex('duration'));
        const coverImage = resultSet.getString(resultSet.getColumnIndex('cover_image'));
        fileInfo.coverUri = coverImage;
        fileInfo.thumbUri = coverImage;
        fileInfo.size = resultSet.getLong(resultSet.getColumnIndex('file_size'));
        const filePath = resultSet.getString(resultSet.getColumnIndex('file_path'));
        fileInfo.path = filePath;
        fileInfo.timesStampApp = resultSet.getLong(resultSet.getColumnIndex('update_time'));
        fileInfo.thumbnailModifiledMs = resultSet.getLong(resultSet.getColumnIndex('update_time'));
        const mtimeVal = resultSet.getLong(resultSet.getColumnIndex('mtime'));
        fileInfo.mtime = mtimeVal;
        const ctimeIndex = resultSet.getColumnIndex('ctime');
        fileInfo.ctime = ctimeIndex >= 0 ? resultSet.getLong(ctimeIndex) : mtimeVal;

        // 根据 media_type 推断 mimeType（数据库无 mimeType 字段）
        const mediaType = resultSet.getLong(resultSet.getColumnIndex('media_type'));
        if (mediaType === 1) {
          fileInfo.mimeType = 'audio/*';
        } else if (mediaType === 2) {
          fileInfo.mimeType = 'video/*';
        } else if (SupportedMediaFormats.isSupportedAudio(fileInfo.fileName)) {
          fileInfo.mimeType = 'audio/*';
        } else if (SupportedMediaFormats.isSupportedVideo(fileInfo.fileName)) {
          fileInfo.mimeType = 'video/*';
        }

        files.push(fileInfo);
      }

      const zeroDurationCount = files.filter((f: FileInfo) => f.duration <= 0).length;
      HiLog.i(TAG, `Queried media metadata: ${files.length} files, duration<=0: ${zeroDurationCount}`);
      return files;
    } catch (error) {
      HiLog.e(TAG, `Failed to query media metadata: ${error?.message}`);
      return [];
    }
  }

  async queryMediaMetadataByUri(uri: string): Promise<FileInfo | null> {
    try {
      const normalizedUri = FileUtil.normalizeMediaUri(uri);
      const candidates: string[] = [];
      if (!StringUtil.isEmpty(normalizedUri)) {
        candidates.push(normalizedUri);
      }
      if (!StringUtil.isEmpty(uri) && uri !== normalizedUri) {
        candidates.push(uri);
      }

      for (let i = 0; i < candidates.length; i++) {
        const found = await this.queryMediaMetadataRowByUri(candidates[i]);
        if (found) {
          return found;
        }
      }

      const filePath = FileUtil.getPathFromUri(normalizedUri);
      if (!StringUtil.isEmpty(filePath)) {
        const foundByPath = await this.queryMediaMetadataByFilePath(filePath);
        if (foundByPath) {
          return foundByPath;
        }
      }

      // path 解析失败时，部分历史记录 file_path 可能直接存 uri
      if (!StringUtil.isEmpty(normalizedUri)) {
        const foundByStoredUri = await this.queryMediaMetadataByFilePath(normalizedUri);
        if (foundByStoredUri) {
          return foundByStoredUri;
        }
      }

      return null;
    } catch (error) {
      HiLog.e(TAG, `Failed to query media metadata: ${error}`);
      return null;
    }
  }

  private async findExistingMediaMetadata(fileInfo: FileInfo): Promise<FileInfo | null> {
    let existing = await this.queryMediaMetadataByUri(fileInfo.uri);
    if (existing) {
      return existing;
    }
    const itemPath = fileInfo.path ?? '';
    if (!StringUtil.isEmpty(itemPath)) {
      existing = await this.queryMediaMetadataByFilePath(itemPath);
      if (existing) {
        return existing;
      }
    }
    const resolvedPath = FileUtil.getPathFromUri(fileInfo.uri);
    if (!StringUtil.isEmpty(resolvedPath) && resolvedPath !== itemPath) {
      return await this.queryMediaMetadataByFilePath(resolvedPath);
    }
    return null;
  }

  private async queryMediaMetadataRowByUri(uri: string): Promise<FileInfo | null> {
    const resultSet = await this.mediaMetadataTable.queryData(
      new relationalStore.RdbPredicates('media_metadata')
        .equalTo('uri', uri)
        .equalTo('is_valid', 1)
    );

    if (!resultSet) {
      return null;
    }
    try {
      if (resultSet.goToFirstRow()) {
        return this.mapMediaMetadataRow(resultSet, uri);
      }
      return null;
    } finally {
      resultSet.close();
    }
  }

  private async queryMediaMetadataByFilePath(filePath: string): Promise<FileInfo | null> {
    const resultSet = await this.mediaMetadataTable.queryData(
      new relationalStore.RdbPredicates('media_metadata')
        .equalTo('file_path', filePath)
        .equalTo('is_valid', 1)
    );

    if (!resultSet) {
      return null;
    }
    try {
      if (resultSet.goToFirstRow()) {
        const storedUri = resultSet.getString(resultSet.getColumnIndex('uri'));
        return this.mapMediaMetadataRow(resultSet, storedUri);
      }
      return null;
    } finally {
      resultSet.close();
    }
  }

  private mapMediaMetadataRow(resultSet: relationalStore.ResultSet, uri: string): FileInfo {
    const fileInfo = new FileInfo();
    fileInfo.uri = uri;
    fileInfo.fileName = resultSet.getString(resultSet.getColumnIndex('title'));
    fileInfo.duration = resultSet.getLong(resultSet.getColumnIndex('duration'));
    const coverImage = resultSet.getString(resultSet.getColumnIndex('cover_image'));
    fileInfo.coverUri = coverImage;
    fileInfo.thumbUri = coverImage;
    fileInfo.size = resultSet.getLong(resultSet.getColumnIndex('file_size'));
    const filePath = resultSet.getString(resultSet.getColumnIndex('file_path'));
    fileInfo.path = filePath;
    fileInfo.timesStampApp = resultSet.getLong(resultSet.getColumnIndex('update_time'));
    fileInfo.thumbnailModifiledMs = resultSet.getLong(resultSet.getColumnIndex('update_time'));
    fileInfo.mtime = resultSet.getLong(resultSet.getColumnIndex('mtime'));
    const ctimeIndex = resultSet.getColumnIndex('ctime');
    fileInfo.ctime = ctimeIndex >= 0 ? resultSet.getLong(ctimeIndex) : fileInfo.mtime;
    return fileInfo;
  }

  async markAsInvalid(uri: string): Promise<boolean> {
    try {
      const values: relationalStore.ValuesBucket = {
        is_valid: 0,
        update_time: Date.now()
      };

      await this.mediaMetadataTable.updateData(
        values,
        new relationalStore.RdbPredicates('media_metadata').equalTo('uri', uri)
      );

      HiLog.i(TAG, `Marked as invalid: ${uri}`);
      return true;
    } catch (error) {
      HiLog.e(TAG, `Failed to mark as invalid: ${error}`);
      return false;
    }
  }

  /**
   * 批量软删除：将多个 URI 标记为无效（is_valid=0），不删除本地源文件。
   * 软删后 queryMediaMetadata（仅查 is_valid=1）不再返回这些项。
   *
   * @param uris 待软删的媒体 URI 列表
   * @returns 是否成功
   */
  async batchMarkAsInvalid(uris: string[]): Promise<boolean> {
    if (uris.length === 0) {
      return true;
    }
    try {
      const values: relationalStore.ValuesBucket = {
        is_valid: 0,
        update_time: Date.now()
      };

      await this.mediaMetadataTable.updateData(
        values,
        new relationalStore.RdbPredicates('media_metadata').in('uri', uris)
      );

      HiLog.i(TAG, `Batch mark as invalid completed, count=${uris.length}`);
      return true;
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      HiLog.e(TAG, `Batch mark as invalid failed: ${message}`);
      return false;
    }
  }

  async updateMediaMetadata(fileInfo: FileInfo): Promise<boolean> {
    try {
      const storedUri = fileInfo.uri;
      FileUtil.applyCanonicalMediaIdentity(fileInfo);
      fileInfo.uri = storedUri;
      const now = Date.now();
      const values: relationalStore.ValuesBucket = {
        title: fileInfo.fileName,
        artist: '',
        album: '',
        duration: fileInfo.duration,
        cover_image: fileInfo.thumbUri || '',
        file_size: fileInfo.size,
        update_time: now,
        mtime: fileInfo.mtime,
        ctime: fileInfo.ctime,
        is_valid: 1
      };

      await this.mediaMetadataTable.updateData(
        values,
        new relationalStore.RdbPredicates('media_metadata').equalTo('uri', fileInfo.uri)
      );

      fileInfo.timesStampApp = now;
      fileInfo.thumbnailModifiledMs = now;
      HiLog.i(TAG, `Updated metadata: ${fileInfo.fileName}`);
      return true;
    } catch (error) {
      HiLog.e(TAG, `Failed to update metadata: ${error}`);
      return false;
    }
  }

  /**
   * 查询增量变更的媒体文件
   * 查询条件：update_time > lastScanTime OR is_valid = 0
   * @param lastScanTime 上次扫描时间戳（毫秒）
   * @param mediaType 媒体类型（可选，1=音频，2=视频，不指定则查询所有）
   * @returns 变更的文件列表
   */
  async queryIncrementalChanges(lastScanTime: number, mediaType?: number): Promise<FileInfo[]> {
    try {
      const rdbStore = this.mediaMetadataTable.getRdbStoreSync();
      if (!rdbStore) {
        HiLog.e(TAG, 'queryIncrementalChanges: rdbStore is null');
        return [];
      }

      // 构建查询 SQL
      let sql = `SELECT * FROM media_metadata WHERE (update_time > ${lastScanTime} OR is_valid = 0)`;
      
      if (mediaType !== undefined) {
        sql += ` AND media_type = ${mediaType}`;
      }
      
      sql += ` ORDER BY update_time DESC`;

      HiLog.i(TAG, `queryIncrementalChanges: SQL=${sql}`);

      const resultSet = await rdbStore.querySql(sql);
      
      if (!resultSet) {
        return [];
      }

      const files: FileInfo[] = [];
      
      while (resultSet.goToNextRow()) {
        const fileInfo = new FileInfo();
        fileInfo.uri = resultSet.getString(resultSet.getColumnIndex('uri'));
        fileInfo.fileName = resultSet.getString(resultSet.getColumnIndex('title'));
        fileInfo.duration = resultSet.getLong(resultSet.getColumnIndex('duration'));
        const coverImage = resultSet.getString(resultSet.getColumnIndex('cover_image'));
        fileInfo.coverUri = coverImage;
        fileInfo.thumbUri = coverImage;
        fileInfo.size = resultSet.getLong(resultSet.getColumnIndex('file_size'));
        const filePath = resultSet.getString(resultSet.getColumnIndex('file_path'));
        fileInfo.path = filePath;
        fileInfo.timesStampApp = resultSet.getLong(resultSet.getColumnIndex('update_time'));
        fileInfo.thumbnailModifiledMs = resultSet.getLong(resultSet.getColumnIndex('update_time'));
        fileInfo.mtime = resultSet.getLong(resultSet.getColumnIndex('mtime'));
        const ctimeIndex = resultSet.getColumnIndex('ctime');
        fileInfo.ctime = ctimeIndex >= 0 ? resultSet.getLong(ctimeIndex) : fileInfo.mtime;

        // 标记是否为无效文件（已删除）
        const isValid = resultSet.getLong(resultSet.getColumnIndex('is_valid'));
        fileInfo.thumbGenerated = isValid === 0; // 使用 thumbGenerated 标记是否已删除

        // 根据 media_type 推断 mimeType（数据库无 mimeType 字段）
        const mediaType = resultSet.getLong(resultSet.getColumnIndex('media_type'));
        if (mediaType === 1) {
          fileInfo.mimeType = 'audio/*';
        } else if (mediaType === 2) {
          fileInfo.mimeType = 'video/*';
        } else if (SupportedMediaFormats.isSupportedAudio(fileInfo.fileName)) {
          fileInfo.mimeType = 'audio/*';
        } else if (SupportedMediaFormats.isSupportedVideo(fileInfo.fileName)) {
          fileInfo.mimeType = 'video/*';
        }
        
        files.push(fileInfo);
      }

      resultSet.close();

      HiLog.i(TAG, `queryIncrementalChanges: found ${files.length} changed files`);
      return files;
    } catch (error) {
      HiLog.e(TAG, `queryIncrementalChanges failed: ${error}`);
      return [];
    }
  }
}
