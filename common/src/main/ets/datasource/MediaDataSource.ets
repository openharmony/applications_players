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


import fs from '@ohos.file.fs';
import { FileDataSource } from './FileDataSource';
import { FileInfo } from '../utils/FileOperateInfo';
import { HiLog } from '../utils/HiLog';
import type common from '@ohos.app.ability.common';
import { ScanTaskPool, ScanTaskType, TaskStatus, ScanTaskCallback, ScanTask } from '../scan/ScanTaskPool';
import { IMediaDataSource, MediaType, SortType, ScanProgressDetail } from './IMediaDataSource';
import { MediaCacheManager } from '../cache/MediaCacheManager';
import { MediaDbManager } from '../persistence/rdb/MediaDbManager';
import { IncrementalSyncManager } from '../scan/IncrementalSyncManager';
import { MediaRetryQueue, RetryType } from '../scan/MediaRetryQueue';
import { SortUtil } from '../utils/SortUtil';
import { SortOrder } from '../constants/storage/Constant';
import { ThumbnailManager } from '../thumbnail/ThumbnailManager';
import { PublicStorageScanner } from '../scan/PublicStorageScanner';
import { MediaImportHelper, MediaImportResult } from '../scan/MediaImportHelper';
import { SupportedMediaFormats } from '../constants/media/SupportedMediaFormats';
import { FileUtil } from '../utils/FileUtil';
import { MediaPlaybackFileOpener } from '../utils/MediaPlaybackFileOpener';

const TAG = 'MediaDataSource';

/**
 * 缩略图数据容器（用于数据合并时保存已有缩略图信息）
 * 使用 @Sendable 确保 ArkTS 兼容
 */
@Sendable
class ThumbnailData {
  thumbUri: string = '';
  coverUri: string = '';
  thumbGenerated: boolean = false;
}

/**
 * 扫描任务回调：将 ScanTaskPool 进度与结果写回 MediaDataSource。
 * UI 层通过 getScanProgress() 轮询 task.progress 刷新进度条。
 */
class MediaScanCallback implements ScanTaskCallback {
  private owner: MediaDataSource;
  private mediaType: MediaType;

  constructor(owner: MediaDataSource, mediaType: MediaType) {
    this.owner = owner;
    this.mediaType = mediaType;
  }

  onTaskStart(task: ScanTask): void {
    this.owner.currentTaskId = task.id;
    HiLog.i(TAG, `Scan task started: ${task.id}`);
  }

  /**
   * 同步 ScanTaskPool 计算的真实进度（processedCount / totalCount * 100）。
   *
   * @param task 当前扫描任务，progress 由 reportTaskProgress 更新
   */
  onTaskProgress(task: ScanTask): void {
    // 写入 owner，供 getScanProgress() 供 UI 轮询
    this.owner.scanProgress = task.progress;
    HiLog.d(TAG, `Scan progress: ${task.progress}%, processed=${task.total > 0 ? Math.floor(task.total * task.progress / 100) : 0}/${task.total}`);
  }

  onChunkComplete(task: ScanTask, chunk: FileInfo[], chunkIndex: number, totalChunks: number): void {
    // 进度已在 onTaskProgress 中更新，此处仅记录分块日志
    HiLog.d(TAG, `Scan chunk complete: ${chunkIndex + 1}/${totalChunks}, chunk=${chunk.length}, total progress=${task.progress}%`);
  }

  /**
   * 扫描全部完成：写入列表、缓存与元数据，并触发缩略图后台生成。
   *
   * @param task 已完成任务，result 为扫描到的 FileInfo 列表
   */
  onTaskComplete(task: ScanTask): void {
    if (task.result && task.result.length > 0) {
      this.owner.setData(task.result);
      // 缓存全部类型数据用 UNKNOWN key
      this.owner.cacheManager.updateCache(MediaType.UNKNOWN, task.result);
      this.owner.dbUpdateMediaMetadata(task.result);

      this.owner.generateThumbnailsBackground(task.result);
    }
    HiLog.i(TAG, `Scan task completed: ${task.id}, files: ${task.result.length}`);
  }

  onTaskError(task: ScanTask): void {
    HiLog.e(TAG, `Scan task failed: ${task.id}, error: ${task.error?.message}`);
  }

  onTaskCancel(task: ScanTask): void {
    HiLog.i(TAG, `Scan task cancelled: ${task.id}`);
  }
}

export class MediaDataSource extends FileDataSource implements IMediaDataSource {
  private filteredArray: FileInfo[] = [];
  private mediaType: MediaType = MediaType.UNKNOWN;
  private scanTaskPool: ScanTaskPool;
  public currentTaskId: string = '';
  private includeSystemFiles: boolean = true;
  private includePublicFiles: boolean = true;
  /** 允许展示/合并公共音频（需 READ_AUDIO） */
  private allowPublicAudio: boolean = false;
  /** 允许展示/合并公共视频（需 READ_IMAGEVIDEO） */
  private allowPublicVideo: boolean = false;
  /**
   * 是否允许 UserFile / PublicStorage 文件系统扫描。
   * 仅当音频+图视频读权限齐全时开启；否则 File Access 会绕过未授权的 READ_*。
   */
  private allowPublicFilesystemScan: boolean = false;
  public cacheManager: MediaCacheManager;
  private dbManager: MediaDbManager;
  private context: common.Context;
  private   incrementalSyncManager: IncrementalSyncManager;
  /** 当前扫描任务进度 0–100，由 MediaScanCallback.onTaskProgress 同步 */
  public scanProgress: number = 0;
  private dataChangeListeners: ((data: FileInfo[]) => void)[] = [];
  private thumbnailUpdateListeners: ((uri: string, fileInfo: FileInfo) => void)[] = [];
  private isGeneratingThumbnails: boolean = false;  // 缩略图生成状态标志
  /**
   * 抑制 setData 期间的 UI 通知：scanMediaFiles 流程中 ScanTaskPool、
   * supplementWithFilesystemScan、removeDeletedFiles 会依次调用 setData，
   * 若每次都通知 UI 会导致列表闪烁。设为 true 时 setData 仅更新内部数据，
   * 不触发 notifyDataChanged / notifyDataReload，流程结束后统一通知一次。
   */
  private suppressDataNotification: boolean = false;

  /**
   * 设置是否抑制 setData 期间的 UI 通知。
   * 由外部调用方（如 MediaAggregateViewModel 初始化阶段）控制，
   * 避免空数据 / 中间状态多次触发 UI 刷新导致闪烁。
   */
  public setSuppressDataNotification(suppress: boolean): void {
    this.suppressDataNotification = suppress;
  }

  // 排序状态：存储当前排序偏好，确保每次 setData() 后自动重新排序
  // 修复：冷启动后切换相同排序类型两次结果不一致的 bug
  // 根因：reloadAfterIncrementalScan 等路径替换数据后未重新排序
  private currentSortType: SortType = SortType.DATE;
  private currentIsDesc: boolean = true;

  /** 失败元数据异步重试队列 */
  private retryQueue: MediaRetryQueue;

  constructor(context: common.Context, mediaType: MediaType = MediaType.UNKNOWN) {
    super();
    this.context = context;
    this.mediaType = mediaType;
    this.scanTaskPool = ScanTaskPool.getInstance();
    this.cacheManager = MediaCacheManager.getInstance();
    this.dbManager = MediaDbManager.getInstance(context);
    // 初始化数据库（确保查询时数据库已准备好）
    this.dbManager.init().then((success: boolean) => {
      HiLog.i(TAG, `Database init: ${success ? 'succeeded' : 'failed'}`);
    }).catch((error: Error) => {
      HiLog.e(TAG, `Database init failed: ${error.message}`);
    });
    this.incrementalSyncManager = IncrementalSyncManager.getInstance(context);

    // 初始化重试队列并设置回调
    this.retryQueue = new MediaRetryQueue(context);
    this.retryQueue.setOnSuccess((uri: string, retryType: RetryType, fileInfo: FileInfo) => {
      this.handleRetrySuccess(uri, retryType, fileInfo);
    });
  }

  setData(data: FileInfo[]): void {
    const scopedData = this.applyPermissionScopeFilter(data);
    if (scopedData.length !== data.length) {
      HiLog.i(TAG, `setData filtered public files by media read permission: ${data.length - scopedData.length}`);
    }
    data = scopedData;
    const supportedData = data.filter((item: FileInfo) =>
      SupportedMediaFormats.isSupportedMedia(item.fileName) &&
      (item.duration > 0 || SupportedMediaFormats.isValidMediaByHeader(item.uri)));
    if (supportedData.length !== data.length) {
      HiLog.i(TAG, `setData filtered unsupported format/pseudo files: ${data.length - supportedData.length}`);
    }
    data = supportedData;
    // 同名文件去重（如 Download/Documents 下各有一份），避免列表与播放队列重复
    data = MediaDataSource.mergeFileResults([], data);
    // 数据合并策略：保留已有缩略图数据，防止被覆盖
    const existingThumbnails = new Map<string, ThumbnailData>();
    
    // 收集当前数据中的缩略图信息（从 dataArray 获取全部数据）
    const currentAllData = this.getDataArray();
    for (const item of currentAllData) {
      if (item.thumbUri || item.coverUri || item.thumbGenerated) {
        const thumbData = new ThumbnailData();
        thumbData.thumbUri = item.thumbUri;
        thumbData.coverUri = item.coverUri;
        thumbData.thumbGenerated = item.thumbGenerated;
        existingThumbnails.set(item.uri, thumbData);
      }
    }
    
    // 合并缩略图数据到新数据
    for (const newItem of data) {
      const existingThumb = existingThumbnails.get(newItem.uri);
      if (existingThumb) {
        // 如果新数据无缩略图但有旧数据有，保留旧的
        if (!newItem.thumbUri && existingThumb.thumbUri) {
          newItem.thumbUri = existingThumb.thumbUri;
        }
        if (!newItem.coverUri && existingThumb.coverUri) {
          newItem.coverUri = existingThumb.coverUri;
        }
        if (!newItem.thumbGenerated && existingThumb.thumbGenerated) {
          newItem.thumbGenerated = existingThumb.thumbGenerated;
        }
        HiLog.d(TAG, `Data merge preserved thumbnail: ${newItem.uri}`);
      }
    }

    // 设计优化：扫描全部类型 + 按显示类型自动过滤
    // dataArray 存储所有类型数据（master array），filteredArray 仅存储当前显示类型
    // tab 切换时调用 filterByType() 即时过滤，无需重新扫描
    // 按当前排序偏好自动排序过滤后的数据
    let displayData: FileInfo[] = this.applyMediaTypeFilter(data);
    let sortedDisplayData: FileInfo[] = displayData;
    if (displayData.length > 0) {
      const sortOrder = this.mapSortTypeToSortOrder(this.currentSortType);
      sortedDisplayData = SortUtil.sortDataByOrder(displayData, sortOrder, this.currentIsDesc, false, false);
    }
    
    // 关键修复：filteredArray 必须在 super.setData() 之前设置
    // super.setData() 会调用 notifyDataReload()，LazyForEach 刷新时读取 filteredArray
    this.filteredArray = sortedDisplayData;
    // super.setData 存储全部数据到 dataArray，供 filterByType 切换时读取
    super.setData(data);
    // suppressDataNotification=true 时跳过 UI 通知，由调用方统一通知
    if (!this.suppressDataNotification) {
      this.notifyDataChanged();
    }
  }

  /**
   * 按当前 mediaType 过滤数据
   * UNKNOWN 显示全部，AUDIO 只显示音频，VIDEO 只显示视频
   */
  private applyMediaTypeFilter(data: FileInfo[]): FileInfo[] {
    if (this.mediaType === MediaType.UNKNOWN) {
      return data.filter((file: FileInfo) => SupportedMediaFormats.isSupportedMedia(file.fileName));
    } else if (this.mediaType === MediaType.AUDIO) {
      return data.filter((file: FileInfo) => SupportedMediaFormats.isSupportedAudio(file.fileName));
    } else if (this.mediaType === MediaType.VIDEO) {
      return data.filter((file: FileInfo) => SupportedMediaFormats.isSupportedVideo(file.fileName));
    }
    return data.slice();
  }

  /**
   * 判断是否为应用沙箱文件（沙箱不受媒体 READ_* 约束）
   */
  private isSandboxFile(file: FileInfo): boolean {
    const uri = file.uri;
    if (uri.indexOf(this.context.filesDir) >= 0) {
      return true;
    }
    if (uri.indexOf('/haps/') >= 0 && uri.indexOf('/files') >= 0) {
      return true;
    }
    return false;
  }

  /**
   * 过滤未授权的公共媒体。沙箱文件始终保留。
   */
  private applyPermissionScopeFilter(data: FileInfo[]): FileInfo[] {
    // 双权限齐全时不做额外裁剪
    if (this.allowPublicAudio && this.allowPublicVideo) {
      return data;
    }
    return data.filter((file: FileInfo) => {
      if (this.isSandboxFile(file)) {
        return true;
      }
      const isAudio = SupportedMediaFormats.isSupportedAudio(file.fileName);
      const isVideo = SupportedMediaFormats.isSupportedVideo(file.fileName);
      if (isAudio) {
        return this.allowPublicAudio;
      }
      if (isVideo) {
        return this.allowPublicVideo;
      }
      return false;
    });
  }

  getData(index: number): FileInfo {
    return this.filteredArray[index];
  }

  totalCount(): number {
    return this.filteredArray.length;
  }

  async loadMediaFiles(mediaType: MediaType, forceRefresh: boolean = false): Promise<void> {
    try {
      HiLog.i(TAG, `Loading media files: ${MediaType[mediaType]}, force refresh: ${forceRefresh}`);

      // mediaType 现为显示过滤类型，扫描始终处理全部类型
      this.mediaType = mediaType;

      // 立即显示内存缓存（如果有）- 使用 UNKNOWN key（包含全部类型数据）
      if (!forceRefresh && this.cacheManager.hasCache(MediaType.UNKNOWN)) {
        const cachedData = this.cacheManager.getFromCache(MediaType.UNKNOWN);
        this.setData(cachedData);
        // 清除初始化阶段的抑制标志，确保本次 setData 通知 UI
        this.suppressDataNotification = false;
        this.notifyDataChanged();
        HiLog.i(TAG, `Loaded all data from memory cache: ${cachedData.length} files, filtered to ${MediaType[mediaType]}: ${this.filteredArray.length}`);
        return;
      }

      // 确保数据库已初始化后再查询
      await this.dbManager.init();

// 关键修复：强制刷新时执行完整扫描
      // 修复根因：forceRefresh=true 仅从本地 DB 查询，无法发现 mediatool 导入的新文件
      // 完整扫描通过 UserFileScanner / MediaLibraryScanner 查询系统媒体数据库，可以发现新文件
      if (forceRefresh) {
        HiLog.i(TAG, `Force refresh: performing full scan (all types) to detect system media database changes`);
        await this.scanMediaFiles(MediaType.UNKNOWN);
        return;
      }

      // 立即显示数据库缓存（不等待扫描）
      // 查询全部类型数据，setData 自动按 mediaType 过滤显示
      const dbData = await this.dbManager.queryMediaMetadata();
      if (dbData.length > 0) {
        // 抑制 DB 缓存 / supplementScan / removeDeleted 多次 setData 导致闪烁
        this.suppressDataNotification = true;
        this.setData(dbData);
        // 缓存全部类型数据，用 UNKNOWN key
        this.cacheManager.updateCache(MediaType.UNKNOWN, dbData);
        HiLog.i(TAG, `Loaded all from database cache: ${dbData.length} files, filtered to ${MediaType[mediaType]}: ${this.filteredArray.length}`);

        if (this.includePublicFiles) {
          await this.supplementWithFilesystemScan(this.getDataArray());
        }

        // 移除源文件已被删除的条目
        await this.removeDeletedFiles(this.getDataArray());

        // 补充流程结束，清除标志并统一通知 UI 一次
        this.suppressDataNotification = false;
        this.notifyDataChanged();

        // 数据库有数据时触发后台异步增量扫描
        this.triggerBackgroundIncrementalScan();
      } else {
        // 数据库无数据，执行全量扫描（首次启动场景）
        HiLog.i(TAG, `No cached data in database, performing full scan (all types)`);
        await this.scanMediaFiles(MediaType.UNKNOWN);
}
    } catch (error) {
      HiLog.e(TAG, `Failed to load media files: ${error}`);
      throw new Error(`加载媒体文件失败: ${error}`);
    }
  }

  async loadAudioFiles(): Promise<void> {
    return this.loadMediaFiles(MediaType.AUDIO, false);
  }

  async loadVideoFiles(): Promise<void> {
    return this.loadMediaFiles(MediaType.VIDEO, false);
  }

  search(keyword: string): void {
    if (!keyword) {
      this.filteredArray = this.getDataArray().slice();
    } else {
      const lowerKeyword = keyword.toLowerCase();
      this.filteredArray = this.getDataArray().filter((file: FileInfo) =>
        file.fileName.toLowerCase().includes(lowerKeyword)
      );
    }
    this.notifyDataReload();
  }

  filterByType(mediaType: MediaType): void {
    // 更新显示过滤类型
    this.mediaType = mediaType;
    
    // 从 dataArray（全部类型数据）中按类型过滤
    const allData = this.getDataArray();
    let filteredData: FileInfo[] = this.applyMediaTypeFilter(allData);
    
    // 按当前排序偏好排序过滤后数据
    const sortOrder = this.mapSortTypeToSortOrder(this.currentSortType);
    this.filteredArray = SortUtil.sortDataByOrder(filteredData, sortOrder, this.currentIsDesc, false, false);
    
    this.notifyDataReload();
    this.notifyDataChanged();
    HiLog.i(TAG, `Trace[filter/4] filterByType mediaType=${MediaType[mediaType]} master=${allData.length} filtered=${this.filteredArray.length}`);
  }

  /**
   * 设置排序偏好（由 ViewModel.init() 调用，确保首次 setData() 使用正确的排序）
   * 必须在任何数据加载之前调用，避免默认排序与保存偏好不一致
   */
  public setSortPreference(sortType: SortType, isDesc: boolean): void {
    this.currentSortType = sortType;
    this.currentIsDesc = isDesc;
    HiLog.i(TAG, `setSortPreference: ${sortType}, isDesc: ${isDesc}`);
  }

  sortBy(sortType: SortType, isDesc: boolean = false): void {
    // 存储排序状态，确保后续 setData() 自动重新排序
    this.currentSortType = sortType;
    this.currentIsDesc = isDesc;
    // 关键修复：使用 SortUtil.sortDataByOrder() 确保排序稳定性
    // SortUtil 提供了 fileName 二级排序作为 fallback，保证相同 key 值时顺序确定性
    const sortOrder = this.mapSortTypeToSortOrder(sortType);
    this.filteredArray = SortUtil.sortDataByOrder(
      this.filteredArray,
      sortOrder,
      isDesc,
      false,  // isRecent (媒体文件不使用)
      false   // isRecentDeletePage (媒体文件不使用)
    );
    // 刷新 LazyForEach UI
    this.notifyDataReload();
    // 同时通知 ViewModel 更新 uiMediaList
    this.notifyDataChanged();
    HiLog.i(TAG, `Trace[sort/3] sortBy sortType=${sortType} order=${sortOrder} isDesc=${isDesc} count=${this.filteredArray.length}`);
  }

  private mapSortTypeToSortOrder(sortType: SortType): string {
    switch (sortType) {
      case SortType.NAME:
        return SortOrder.NAME;
      case SortType.DATE:
        return SortOrder.TIME;
      case SortType.SIZE:
        return SortOrder.SIZE;
      case SortType.DURATION:
        return SortOrder.DURATION;
      default:
        return SortOrder.TIME;
    }
  }

  getFilteredData(): FileInfo[] {
    return this.filteredArray;
  }

  /**
   * 批量软删除：DB 标记 is_valid=0（不删本地源文件）+ 同步内存缓存与双数组并刷新 UI。
   * 软删后重新加载/扫描（仅查 is_valid=1）不会再出现这些项。
   *
   * @param uris 待删除的媒体 URI 列表
   * @returns 实际移除的条目数
   */
  public async softDeleteByUris(uris: string[]): Promise<number> {
    if (uris.length === 0) {
      return 0;
    }
    const removeSet = new Set<string>(uris);
    const remainAll = this.getDataArray().filter((f: FileInfo) => !removeSet.has(f.uri));
    const removedCount = this.getDataArray().length - remainAll.length;
    // DB 软删除（is_valid=0），仅移除展示，不删除本地源文件
    await this.dbManager.batchMarkAsInvalid(uris);
    // 同步内存缓存，避免非强制刷新时从缓存复现已删项
    this.cacheManager.updateCache(MediaType.UNKNOWN, remainAll);
    // 重建 dataArray + filteredArray 并通知 UI（setData 自含过滤/排序/notify）
    this.setData(remainAll);
    HiLog.i(TAG, `softDeleteByUris removed=${removedCount} remain=${remainAll.length}`);
    return removedCount;
  }

  getAudioFiles(): FileInfo[] {
    return this.getDataArray().filter((file: FileInfo) => file.mimeType.startsWith('audio'));
  }

  getVideoFiles(): FileInfo[] {
    return this.getDataArray().filter((file: FileInfo) => file.mimeType.startsWith('video'));
  }

  clear(): void {
    this.setData([]);
    this.filteredArray = [];
  }

  setIncludeSystemFiles(include: boolean): void {
    this.includeSystemFiles = include;
    HiLog.i(TAG, `Set include system files: ${include}`);
  }

  setIncludePublicFiles(include: boolean): void {
    this.includePublicFiles = include;
    HiLog.i(TAG, `Set include public directory files: ${include}`);
  }

  /**
   * 按系统媒体读权限约束公共扫描/展示范围。
   * - 媒体库扫描由 includeSystemFiles 控制，ATM 会按 READ_* 过滤
   * - UserFile/PublicStorage 仅在双读权限齐全时开启，避免 File Access 绕过
   * - DB/缓存展示按已授权类型过滤非沙箱文件
   *
   * @param allowAudio 是否允许公共音频
   * @param allowVideo 是否允许公共视频
   */
  setMediaReadAccessScope(allowAudio: boolean, allowVideo: boolean): void {
    this.allowPublicAudio = allowAudio;
    this.allowPublicVideo = allowVideo;
    this.allowPublicFilesystemScan = allowAudio && allowVideo;
    // 文件系统公共扫描仅双权限时开启；媒体库仍可由 includeSystemFiles 单独开启
    this.includePublicFiles = this.allowPublicFilesystemScan;
    HiLog.i(TAG,
      `setMediaReadAccessScope audio=${allowAudio} video=${allowVideo} ` +
      `filesystemScan=${this.allowPublicFilesystemScan}`);
  }

  async loadSystemAudioFiles(): Promise<void> {
    try {
      HiLog.i(TAG, 'Loading system audio files');
      await this.loadMediaFiles(MediaType.AUDIO, true);
      HiLog.i(TAG, `System audio files loaded`);
    } catch (error) {
      HiLog.e(TAG, `Failed to load system audio files: ${error}`);
      throw new Error(`加载系统音频文件失败: ${error}`);
    }
  }

  async loadSystemVideoFiles(): Promise<void> {
    try {
      HiLog.i(TAG, 'Loading system video files');
      await this.loadMediaFiles(MediaType.VIDEO, true);
      HiLog.i(TAG, `System video files loaded`);
    } catch (error) {
      HiLog.e(TAG, `Failed to load system video files: ${error}`);
      throw new Error(`加载系统视频文件失败: ${error}`);
    }
  }

  async loadAllSystemMediaFiles(): Promise<void> {
    try {
      HiLog.i(TAG, 'Loading all system media files');
      await this.loadMediaFiles(MediaType.UNKNOWN, true);
      HiLog.i(TAG, `All system media files loaded`);
    } catch (error) {
      HiLog.e(TAG, `Failed to load all system media files: ${error}`);
      throw new Error(`加载所有系统媒体文件失败: ${error}`);
    }
  }

  async loadAllMediaFiles(): Promise<void> {
    try {
      HiLog.i(TAG, 'Loading all media files (including system files)');
      await this.loadMediaFiles(MediaType.UNKNOWN, true);
      HiLog.i(TAG, `All media files loaded`);
    } catch (error) {
      HiLog.e(TAG, `Failed to load all media files: ${error}`);
      throw new Error(`加载所有媒体文件失败: ${error}`);
    }
  }

  async loadAudioFilesWithSystem(): Promise<void> {
    try {
      HiLog.i(TAG, 'Loading audio files (including system files)');
      await this.loadMediaFiles(MediaType.AUDIO, true);
      HiLog.i(TAG, `Audio files loaded`);
    } catch (error) {
      HiLog.e(TAG, `Failed to load audio files: ${error}`);
      throw new Error(`加载音频文件失败: ${error}`);
    }
  }

  async loadVideoFilesWithSystem(): Promise<void> {
    try {
      HiLog.i(TAG, 'Loading video files (including system files)');
      await this.loadMediaFiles(MediaType.VIDEO, true);
      HiLog.i(TAG, `Video files loaded`);
    } catch (error) {
      HiLog.e(TAG, `Failed to load video files: ${error}`);
      throw new Error(`加载视频文件失败: ${error}`);
    }
  }

  getCurrentTaskId(): string {
    return this.currentTaskId;
  }

  isScanning(): boolean {
    if (!this.currentTaskId) {
      return false;
    }

    const task = this.scanTaskPool.getTask(this.currentTaskId);
    return task?.status === TaskStatus.RUNNING;
  }

  /**
   * 获取当前扫描任务进度百分比。
   *
   * @returns 0–100；无任务时返回 0，任务对象已清理时回退 scanProgress 缓存值
   */
  getScanProgress(): number {
    return MediaDataSource.resolveScanProgressDetail(this).percent;
  }

  /**
   * 获取扫描进度明细（百分比 + 已处理/总数），供实况通知与进度弹窗使用
   */
  getScanProgressDetail(): ScanProgressDetail {
    return MediaDataSource.resolveScanProgressDetail(this);
  }

  private static resolveScanProgressDetail(owner: MediaDataSource): ScanProgressDetail {
    if (!owner.currentTaskId) {
      return { percent: owner.scanProgress, processed: 0, total: 0 };
    }
    const task = owner.scanTaskPool.getTask(owner.currentTaskId);
    if (task) {
      const total = task.total;
      const percent = task.progress;
      const processed = total > 0 ? Math.min(total, Math.floor(total * percent / 100)) : 0;
      return { percent: percent, processed: processed, total: total };
    }
    return { percent: owner.scanProgress, processed: 0, total: 0 };
  }

  cancelScan(): boolean {
    if (!this.currentTaskId) {
      return false;
    }

    const result = this.scanTaskPool.cancelTask(this.currentTaskId);
    if (result) {
      this.currentTaskId = '';
      HiLog.i(TAG, 'Scan task cancelled');
    }
    return result;
  }

  /** 主线程补充 file://docs 公共目录扫描，与索引结果合并 */
  private async supplementWithFilesystemScan(baseResults: FileInfo[]): Promise<void> {
    if (!this.allowPublicFilesystemScan) {
      HiLog.i(TAG, 'Skipping PublicStorageScanner: missing both READ_AUDIO + READ_IMAGEVIDEO, preventing File Access bypass');
      return;
    }
    try {
      const scanner = new PublicStorageScanner(this.context);
      const scanResult = await scanner.scanAllMediaFiles();
      const fsResults = scanResult.files;
      const durationFailedFiles = scanResult.durationFailedFiles;
      if (fsResults.length === 0) {
        return;
      }

      // 记录合并前各文件的 duration，用于检测哪些文件被补充了 duration
      const baseDurationMap = new Map<string, number>();
      for (const file of baseResults) {
        baseDurationMap.set(file.uri, file.duration);
      }
      // 诊断日志：合并前 DB 数据中 duration=0 的文件数
      const dbZeroDurationCount = baseResults.filter((f: FileInfo) => f.duration <= 0).length;
      HiLog.i(TAG, `Diagnostic: files with duration<=0 in DB data before merge: ${dbZeroDurationCount}/${baseResults.length}`);
      // 诊断日志：文件系统扫描结果的 duration 情况
      const fsZeroDurationCount = fsResults.filter((f: FileInfo) => f.duration <= 0).length;
      HiLog.i(TAG, `Diagnostic: files with duration<=0 in filesystem scan: ${fsZeroDurationCount}/${fsResults.length}`);

      // 收集 duration 提取失败的文件，加入重试队列
      if (durationFailedFiles.length > 0) {
        HiLog.i(TAG, `Duration extraction failed: ${durationFailedFiles.length} files, starting retry queue`);
        this.retryQueue.enqueue(durationFailedFiles, RetryType.DURATION);
      }

      const merged = MediaDataSource.mergeFileResults(baseResults, fsResults);
      HiLog.i(TAG, `Public directory merge: index=${baseResults.length}, filesystem=${fsResults.length}, total=${merged.length}`);
      // 诊断日志：合并后 duration 的变化
      const mergedZeroDurationCount = merged.filter((f: FileInfo) => f.duration <= 0).length;
      HiLog.i(TAG, `Diagnostic: files with duration<=0 after merge: ${mergedZeroDurationCount}/${merged.length}`);

      this.setData(merged);
      this.cacheManager.updateCache(MediaType.UNKNOWN, merged);

      const baseUriSet = new Set<string>();
      const basePathSet = new Set<string>();
      for (const file of baseResults) {
        baseUriSet.add(file.uri);
        const physicalPath = FileUtil.getPathFromUri(file.uri) || file.uri;
        basePathSet.add(physicalPath);
      }
      const newFiles: FileInfo[] = [];
      for (const file of fsResults) {
        if (baseUriSet.has(file.uri)) {
          continue;
        }
        const fsPhysicalPath = FileUtil.getPathFromUri(file.uri) || file.uri;
        if (basePathSet.has(fsPhysicalPath)) {
          continue;
        }
        newFiles.push(file);
      }
      // 修复：将合并后 duration 被补充的已有文件也写回 DB，避免重启后丢失
      const durationUpdatedFiles: FileInfo[] = [];
      for (const file of merged) {
        if (file.duration > 0) {
          const oldDuration = baseDurationMap.get(file.uri) ?? 0;
          if (oldDuration <= 0) {
            durationUpdatedFiles.push(file);
          }
        }
      }
      if (durationUpdatedFiles.length > 0) {
        for (const file of durationUpdatedFiles) {
          await this.dbManager.updateMediaMetadata(file);
        }
        HiLog.i(TAG, `Public directory scan: updated duration for ${durationUpdatedFiles.length} files to DB`);
      }

      if (newFiles.length > 0) {
        await this.dbUpdateMediaMetadata(newFiles);
        this.generateThumbnailsBackground(newFiles);
      }
    } catch (error) {
      HiLog.e(TAG, `Public directory filesystem scan failed: ${error}`);
    }
  }

  private static mergeFileResults(base: FileInfo[], extra: FileInfo[]): FileInfo[] {
    const uriSet = new Set<string>();
    const pathSet = new Set<string>();
    const nameSet = new Set<string>();
    const uriToIndex = new Map<string, number>();
    const merged: FileInfo[] = [];

    // 先将 base 中的文件加入 merged，并建立 uri → index 映射
    for (const file of base) {
      const normUri = FileUtil.normalizeMediaUri(file.uri);
      if (!uriSet.has(normUri)) {
        const physicalPath = FileUtil.getPathFromUri(normUri);
        if ((physicalPath.length > 0 && pathSet.has(physicalPath)) || nameSet.has(file.fileName)) {
          continue;
        }
        FileUtil.applyCanonicalMediaIdentity(file);
        uriSet.add(normUri);
        if (physicalPath.length > 0) {
          pathSet.add(physicalPath);
        }
        nameSet.add(file.fileName);
        uriToIndex.set(normUri, merged.length);
        merged.push(file);
      }
    }

    // 遍历 extra：已存在则补充缺失字段（size/duration），不存在则追加
    for (const file of extra) {
      const normUri = FileUtil.normalizeMediaUri(file.uri);
      const existingIndex = uriToIndex.get(normUri);
      if (existingIndex !== undefined) {
        // 已存在：用文件系统的正确值补充 size / duration（DB 旧记录可能为 0）
        const existing = merged[existingIndex];
        if (existing.size <= 0 && file.size > 0) {
          existing.size = file.size;
        }
        if (existing.duration <= 0 && file.duration > 0) {
          existing.duration = file.duration;
        }
        continue;
      }
      const physicalPath = FileUtil.getPathFromUri(normUri);
      if ((physicalPath.length > 0 && pathSet.has(physicalPath)) || nameSet.has(file.fileName)) {
        continue;
      }
      FileUtil.applyCanonicalMediaIdentity(file);
      uriSet.add(normUri);
      if (physicalPath.length > 0) {
        pathSet.add(physicalPath);
      }
      nameSet.add(file.fileName);
      merged.push(file);
    }
    return merged;
  }

  /**
   * 检查文件是否存在，移除已删除的文件（DB 软删除 + 内存清理）。
   * 扫描完成后调用，确保列表中不包含源文件已被删除的条目。
   * 对 file://media URI 使用 MediaPlaybackFileOpener 真正打开检测，
   * 对 file://docs / 沙箱 URI 使用 fs.accessSync 检查物理文件。
   */
  async removeDeletedFiles(files: FileInfo[]): Promise<number> {
    if (files.length === 0) {
      return 0;
    }
    const deletedUris: string[] = [];
    for (const file of files) {
      try {
        let exists = false;
        if (file.uri.startsWith('file://media/')) {
          // 媒体库 URI：真正打开文件检测
          const opened = await MediaPlaybackFileOpener.openReadOnly(file.uri, file.fileName);
          if (opened) {
            await opened.release();
            exists = true;
          }
        } else {
          // file://docs / 沙箱 URI：fs.accessSync 检查物理文件
          try {
            fs.accessSync(file.uri);
            exists = true;
          } catch (_) {
            const path = FileUtil.getPathFromUri(file.uri);
            if (path.length > 0 && path !== file.uri) {
              fs.accessSync(path);
              exists = true;
            }
          }
        }
        if (!exists) {
          deletedUris.push(file.uri);
          HiLog.w(TAG, `Source file deleted: ${file.fileName} uri=${file.uri}`);
        }
      } catch (error) {
        deletedUris.push(file.uri);
        HiLog.w(TAG, `File check exception treated as deleted: ${file.fileName} error=${error}`);
      }
    }

    if (deletedUris.length === 0) {
      return 0;
    }

    HiLog.i(TAG, `Removed deleted files: ${deletedUris.length}`);
    await this.softDeleteByUris(deletedUris);
    return deletedUris.length;
  }

  /**
   * 提交 ScanTaskPool 扫描任务并阻塞至分块处理完毕。
   * 扫描期间 suppressDataNotification=true，ScanTaskPool / PublicStorageScanner /
   * removeDeletedFiles 各自的 setData 仅更新内部数据，不触发 UI 通知；
   * 全部完成后清除标志并统一 notifyDataChanged() 一次，避免列表闪烁。
   *
   * @param mediaType 扫描类型（映射为 ScanTaskType）
   */
  private async scanMediaFiles(mediaType: MediaType): Promise<void> {
    try {
      HiLog.i(TAG, `Scanning media files: ${MediaType[mediaType]}`);

      // 抑制扫描期间的 UI 通知，避免 ScanTaskPool / supplementScan / removeDeleted 多次 setData 导致闪烁
      this.suppressDataNotification = true;

      const scanTaskType = this.getScanTaskType(mediaType);
      const callback = new MediaScanCallback(this, mediaType);

      this.scanTaskPool.setCallback(callback);

      this.currentTaskId = await this.scanTaskPool.submitTask({
        type: scanTaskType,
        context: this.context,
        includeSystem: this.includeSystemFiles,
        includePublic: this.includePublicFiles
      });

      HiLog.i(TAG, `Scan task submitted: ${this.currentTaskId}`);
      await this.scanTaskPool.waitForTaskCompletion(this.currentTaskId);

      const completedTask = this.scanTaskPool.getTask(this.currentTaskId);
      const indexResults = completedTask?.result ?? [];
      if (this.includePublicFiles) {
        await this.supplementWithFilesystemScan(indexResults);
      }

      // 扫描完成后移除源文件已被删除的条目
      const currentData = this.getDataArray();
      await this.removeDeletedFiles(currentData);

      // 扫描流程结束，清除标志并统一通知 UI 一次
      this.suppressDataNotification = false;
      this.notifyDataChanged();
      this.cacheManager.updateCache(MediaType.UNKNOWN, this.getDataArray());

      HiLog.i(TAG, `Scan task ended: ${this.currentTaskId}, progress=${this.getScanProgress()}%`);
    } catch (error) {
      // 异常时也要清除标志，避免后续 setData 永远不通知
      this.suppressDataNotification = false;
      HiLog.e(TAG, `Failed to scan media files: ${error}`);
      throw new Error(`扫描媒体文件失败: ${error}`);
    }
  }

  private triggerBackgroundIncrementalScan(): void {
    HiLog.i(TAG, `Triggering background incremental scan (all types)`);

    // 设置进度回调
    this.incrementalSyncManager.setProgressCallback((progress: number, total: number) => {
      this.scanProgress = Math.floor((progress / total) * 100);
      HiLog.d(TAG, `Incremental scan progress: ${this.scanProgress}%`);
    });

    // 异步执行增量扫描
    this.incrementalSyncManager.executeBackgroundIncrementalScan()
      .then((success: boolean) => {
        if (success) {
          HiLog.i(TAG, `Background incremental scan completed`);
          // 扫描完成后重新加载全部类型并按当前类型过滤显示
          this.reloadAfterIncrementalScan();
        } else {
          HiLog.w(TAG, `Background incremental scan not executed or failed`);
        }
      })
      .catch((error: Error) => {
        HiLog.e(TAG, `Background incremental scan failed: ${error.message}`);
      });
  }

  private async reloadAfterIncrementalScan(): Promise<void> {
    try {
      HiLog.i(TAG, `Reloading after incremental scan (all types)`);
      
      // 并发控制：如果正在生成缩略图，等待完成后重载
      if (this.isGeneratingThumbnails) {
        HiLog.w(TAG, `Thumbnails being generated, delaying reload`);
        await new Promise<void>(resolve => setTimeout(resolve, 500));
        if (this.isGeneratingThumbnails) {
          HiLog.w(TAG, `Thumbnail generation still in progress, skipping this reload`);
          return;
        }
      }

      // 从数据库重新查询全部类型数据
      const updatedData = await this.dbManager.queryMediaMetadata();

      if (updatedData.length > 0) {
        this.setData(updatedData);  // setData 自动按权限范围 + 类型过滤
        this.cacheManager.updateCache(MediaType.UNKNOWN, this.getDataArray());
        HiLog.i(TAG, `UI updated after incremental scan: DB=${updatedData.length}, after permission filter total=${this.getDataArray().length}, display=${MediaType[this.mediaType]}:${this.filteredArray.length}`);

        // 移除源文件已被删除的条目
        await this.removeDeletedFiles(updatedData);

        // 生成缩略图（仅对无缩略图的文件）
        const itemsWithoutThumbnail = updatedData.filter((item: FileInfo) => ThumbnailManager.needsGeneration(item));
        if (itemsWithoutThumbnail.length > 0) {
          this.generateThumbnailsBackground(itemsWithoutThumbnail);
        }
      }
    } catch (error) {
      HiLog.e(TAG, `Failed to reload after incremental scan: ${error}`);
    }
  }

  /**
   * 增量刷新：从 DB 查询最新数据，对比当前数据确定新增/删除/修改的文件，
   * 对简单新增使用 addIncrementalFiles() 插入到正确位置（避免全量重排），
   * 对复杂变更（删除/修改）回退到 setData() 全量更新
   * 用于 ViewModelMonitorCallback.onBatchFileChanged 替代 loadMediaFiles(forceRefresh=true)
   */
  public async incrementalRefresh(): Promise<void> {
    try {
      HiLog.i(TAG, `Incremental refresh: querying latest data from DB`);

      if (this.isGeneratingThumbnails) {
        HiLog.w(TAG, `Thumbnails being generated, delaying incremental refresh`);
        await new Promise<void>(resolve => setTimeout(resolve, 500));
        if (this.isGeneratingThumbnails) {
          HiLog.w(TAG, `Thumbnail generation still in progress, skipping this incremental refresh`);
          return;
        }
      }

      // 确保数据库已初始化
      await this.dbManager.init();

      // 从数据库查询全部类型数据（mtime 值来自 DB，与初始加载一致）
      const updatedData = await this.dbManager.queryMediaMetadata();

      if (updatedData.length === 0) {
        HiLog.i(TAG, `Incremental refresh: no data in DB, skipping`);
        return;
      }

      // 对比当前 dataArray 与 DB 数据，确定新增/删除/修改的文件
      const currentData = this.getDataArray();
      const currentUriMap = new Map<string, FileInfo>();
      for (const item of currentData) {
        currentUriMap.set(item.uri, item);
      }

      const newFiles: FileInfo[] = [];
      const changedFiles: FileInfo[] = [];
      const deletedUris: string[] = [];

      for (const updatedItem of updatedData) {
        const existing = currentUriMap.get(updatedItem.uri);
        if (!existing) {
          // 新文件不在当前 dataArray 中
          newFiles.push(updatedItem);
        } else if (existing.thumbUri !== updatedItem.thumbUri || existing.coverUri !== updatedItem.coverUri) {
          // 已有文件但缩略图数据有更新
          changedFiles.push(updatedItem);
        }
        // 已有文件且无变化 → 不需要处理
      }

      // 检查删除的文件（在当前数据中但不在 DB 结果中）
      const updatedUriSet = new Set<string>();
      for (const item of updatedData) {
        updatedUriSet.add(item.uri);
      }
      for (const item of currentData) {
        if (!updatedUriSet.has(item.uri)) {
          deletedUris.push(item.uri);
        }
      }

      if (newFiles.length === 0 && changedFiles.length === 0 && deletedUris.length === 0) {
        HiLog.i(TAG, `Incremental refresh: no data changes, skipping UI update`);
        return;
      }

      // 简单新增场景（无删除、无修改）：使用增量插入避免全量重排
      if (deletedUris.length === 0 && changedFiles.length === 0 && newFiles.length <= 5) {
        HiLog.i(TAG, `Incrementally inserting ${newFiles.length} new files, not replacing all data`);

        // 合并缩略图数据：保留已有缩略图
        const existingThumbnails = new Map<string, ThumbnailData>();
        for (const item of currentData) {
          if (item.thumbUri || item.coverUri || item.thumbGenerated) {
            const thumbData = new ThumbnailData();
            thumbData.thumbUri = item.thumbUri;
            thumbData.coverUri = item.coverUri;
            thumbData.thumbGenerated = item.thumbGenerated;
            existingThumbnails.set(item.uri, thumbData);
          }
        }
        for (const newFile of newFiles) {
          const existingThumb = existingThumbnails.get(newFile.uri);
          if (existingThumb) {
            if (!newFile.thumbUri && existingThumb.thumbUri) {
              newFile.thumbUri = existingThumb.thumbUri;
            }
            if (!newFile.coverUri && existingThumb.coverUri) {
              newFile.coverUri = existingThumb.coverUri;
            }
            if (!newFile.thumbGenerated && existingThumb.thumbGenerated) {
              newFile.thumbGenerated = existingThumb.thumbGenerated;
            }
          }
        }

        this.addIncrementalFiles(newFiles);

        // 更新缓存（使用内存去重后的数据，避免把同名副本写回 cache）
        this.cacheManager.updateCache(MediaType.UNKNOWN, this.getDataArray());

        // 生成缩略图（仅对新增的无缩略图文件）
        const itemsWithoutThumbnail = newFiles.filter((item: FileInfo) => ThumbnailManager.needsGeneration(item));
        if (itemsWithoutThumbnail.length > 0) {
          this.generateThumbnailsBackground(itemsWithoutThumbnail);
        }

        HiLog.i(TAG, `Incremental refresh complete: ${newFiles.length} new files`);
        return;
      }

      // 复杂变更场景（有删除或修改）：回退到 setData() 全量更新
      // setData() 会自动排序 + notifyDataReload，但 mtime 值来自 DB（与初始加载一致）
      // 所以现有文件的排序位置应该保持稳定
      HiLog.i(TAG, `Incremental refresh: ${deletedUris.length} deletes + ${changedFiles.length} modifications, falling back to setData()`);
      this.setData(updatedData);
      this.cacheManager.updateCache(MediaType.UNKNOWN, this.getDataArray());

      // 生成缩略图（仅对无缩略图文件）
      const itemsWithoutThumbnail = updatedData.filter((item: FileInfo) => ThumbnailManager.needsGeneration(item));
      if (itemsWithoutThumbnail.length > 0) {
        this.generateThumbnailsBackground(itemsWithoutThumbnail);
      }

      HiLog.i(TAG, `Incremental refresh complete: full update of ${updatedData.length} files`);
    } catch (error) {
      HiLog.e(TAG, `Incremental refresh failed: ${error}`);
    }
  }

  /**
   * 增量插入新文件到 dataArray 和 filteredArray 的正确排序位置
   * 不触发 notifyDataReload()，避免全量重排
   * 使用 notifyDataAdd() 逐个插入新可见项
   */
  private addIncrementalFiles(newFiles: FileInfo[]): void {
    // 1. 添加新文件到 dataArray（master array，包含全部类型）
    // 与 mergeFileResults 一致：规范化 URI / 物理路径 / 同名 去重，防止增量把副本插回
    const dataArray = this.getDataArray();
    const existingUris = new Set<string>();
    const existingPaths = new Set<string>();
    const existingNames = new Set<string>();
    for (let i = 0; i < dataArray.length; i++) {
      const existing = dataArray[i];
      const normUri = FileUtil.normalizeMediaUri(existing.uri);
      existingUris.add(normUri);
      const path = FileUtil.getPathFromUri(normUri);
      if (path.length > 0) {
        existingPaths.add(path);
      }
      existingNames.add(existing.fileName);
    }
    const uniqueNewFiles: FileInfo[] = [];
    for (const newFile of newFiles) {
      const normUri = FileUtil.normalizeMediaUri(newFile.uri);
      const path = FileUtil.getPathFromUri(normUri);
      if (existingUris.has(normUri) ||
        (path.length > 0 && existingPaths.has(path)) ||
        existingNames.has(newFile.fileName)) {
        continue;
      }
      FileUtil.applyCanonicalMediaIdentity(newFile);
      existingUris.add(normUri);
      if (path.length > 0) {
        existingPaths.add(path);
      }
      existingNames.add(newFile.fileName);
      uniqueNewFiles.push(newFile);
      dataArray.push(newFile);
    }
    if (uniqueNewFiles.length === 0) {
      HiLog.i(TAG, `addIncrementalFiles: skipped all as duplicates, count=${newFiles.length}`);
      return;
    }

    // 2. 过滤新文件：只处理匹配当前 mediaType 的文件
    const matchingFiles = this.applyMediaTypeFilter(uniqueNewFiles);
    if (matchingFiles.length === 0) {
      HiLog.i(TAG, `addIncrementalFiles: no new files matching current type ${MediaType[this.mediaType]}`);
      // dataArray 已更新，但 filteredArray 无变化，无需 UI 更新
      // 但需要通知 ViewModel 更新 uiMediaList（因为 dataArray 变了，tab 切换时需要新数据）
      this.notifyDataChanged();
      return;
    }

    // 3. 按当前排序偏好排序新文件
    const sortOrder = this.mapSortTypeToSortOrder(this.currentSortType);
    const sortedNewFiles = SortUtil.sortDataByOrder(matchingFiles, sortOrder, this.currentIsDesc, false, false);

    // 4. 逐个插入到 filteredArray 的正确位置
    // 从后往前插入，避免前面的插入位置影响后面的索引计算
    for (let i = sortedNewFiles.length - 1; i >= 0; i--) {
      const newFile = sortedNewFiles[i];
      const insertIndex = this.findInsertPosition(newFile);
      this.filteredArray.splice(insertIndex, 0, newFile);
      // 使用 notifyDataAdd 通知 LazyForEach 在指定位置插入一个新项
      this.notifyDataAdd(insertIndex);
    }

    // 5. 通知 ViewModel 更新 uiMediaList
    this.notifyDataChanged();

    HiLog.i(TAG, `addIncrementalFiles: ${matchingFiles.length} new files inserted, filteredArray total ${this.filteredArray.length}`);
  }

  /**
   * 查找新文件在 filteredArray 中的正确插入位置
   * 使用与 SortUtil 相同的比较逻辑确保排序一致性
   */
  private findInsertPosition(newFile: FileInfo): number {
    const sortOrder = this.mapSortTypeToSortOrder(this.currentSortType);
    const isDesc = this.currentIsDesc;

    for (let i = 0; i < this.filteredArray.length; i++) {
      const existing = this.filteredArray[i];
      const comparison = this.compareForInsertPosition(existing, newFile, sortOrder, isDesc);
      if (comparison > 0) {
        // existing 应排在 newFile 之后 → 在此位置插入 newFile
        return i;
      }
    }

    // newFile 应排在所有现有项之后
    return this.filteredArray.length;
  }

  /**
   * 比较两个 FileInfo 用于确定插入位置
   * 返回负数表示 a 应排在 b 前面，正数表示 a 应排在 b 后面
   * 使用与 SortUtil 相同的比较逻辑确保排序一致性
   */
  private compareForInsertPosition(a: FileInfo, b: FileInfo, sortOrder: string, isDesc: boolean): number {
    if (sortOrder === SortOrder.TIME) {
      return SortUtil.compareFileByTime(a, b, isDesc, false, false);
    } else if (sortOrder === SortOrder.NAME) {
      return SortUtil.compareStr(isDesc, a.fileName, b.fileName);
    } else if (sortOrder === SortOrder.SIZE) {
      if (b.size !== a.size) {
        return isDesc ? b.size - a.size : a.size - b.size;
      }
      return SortUtil.compareStr(isDesc, a.fileName, b.fileName);
    } else if (sortOrder === SortOrder.DURATION) {
      if (b.duration !== a.duration) {
        return isDesc ? b.duration - a.duration : a.duration - b.duration;
      }
      return SortUtil.compareStr(isDesc, a.fileName, b.fileName);
    }
    return 0;
  }

  addDataChangeListener(listener: (data: FileInfo[]) => void): void {
    this.dataChangeListeners.push(listener);
  }

  removeDataChangeListener(listener: (data: FileInfo[]) => void): void {
    const index = this.dataChangeListeners.indexOf(listener);
    if (index !== -1) {
      this.dataChangeListeners.splice(index, 1);
    }
  }

  addThumbnailUpdateListener(listener: (uri: string, fileInfo: FileInfo) => void): void {
    this.thumbnailUpdateListeners.push(listener);
  }

  removeThumbnailUpdateListener(listener: (uri: string, fileInfo: FileInfo) => void): void {
    const index = this.thumbnailUpdateListeners.indexOf(listener);
    if (index !== -1) {
      this.thumbnailUpdateListeners.splice(index, 1);
    }
  }

  notifyDataChanged(): void {
    const data = this.getMediaItems();
    for (const listener of this.dataChangeListeners) {
      try {
        listener(data);
      } catch (error) {
        HiLog.e(TAG, `Data change listener execution failed: ${error}`);
      }
    }
  }

  private notifyThumbnailUpdated(uri: string, fileInfo: FileInfo): void {
    for (const listener of this.thumbnailUpdateListeners) {
      try {
        listener(uri, fileInfo);
      } catch (error) {
        HiLog.e(TAG, `Thumbnail update listener execution failed: ${error}`);
      }
    }
  }

  private getScanTaskType(mediaType: MediaType): ScanTaskType {
    // 设计优化：始终扫描全部类型，tab 切换只做过滤
    return ScanTaskType.SCAN_ALL;
  }

  async dbUpdateMediaMetadata(items: FileInfo[]): Promise<void> {
    if (items.length === 0) {
      return;
    }

    try {
      await this.dbManager.batchInsertMediaMetadata(items);
      HiLog.i(TAG, `Updated database metadata: ${items.length} files`);
    } catch (error) {
      HiLog.e(TAG, `Failed to update database metadata: ${error}`);
    }
  }

  /**
   * Picker 导入：upsert media_metadata，合并内存列表并刷新 UI（不触发全量扫描）。
   *
   * @param uris DocumentViewPicker 返回的 URI 列表（≤100，来自 Documents 等已授权目录）
   * @param onProgress 可选进度回调 (已处理数, 总数)
   * @returns 成功导入数与跳过的非支持文件数
   */
  async importMediaFromUris(uris: string[],
    onProgress?: (processed: number, total: number) => void): Promise<MediaImportResult> {
    if (!uris || uris.length === 0) {
      return new MediaImportResult(0, 0);
    }

    await this.dbManager.init();
    const parseResult = await MediaImportHelper.parseAndResolvePickerUris(uris);
    const importedFiles = parseResult.files;
    if (importedFiles.length === 0) {
      HiLog.w(TAG, `importMediaFromUris: no valid media URIs, skipped=${parseResult.skippedCount}`);
      return new MediaImportResult(0, parseResult.skippedCount);
    }

    const total = importedFiles.length;
    if (onProgress) {
      onProgress(0, total);
    }
    let processed = 0;
    for (let i = 0; i < importedFiles.length; i++) {
      const singleCount = await this.dbManager.upsertMediaMetadata([importedFiles[i]]);
      processed += singleCount;
      if (onProgress) {
        onProgress(i + 1, total);
      }
    }
    if (processed === 0) {
      return new MediaImportResult(0, parseResult.skippedCount);
    }

    let master = this.getDataArray().slice();
    const importedNormUris = new Set<string>();
    for (let i = 0; i < importedFiles.length; i++) {
      importedNormUris.add(FileUtil.normalizeMediaUri(importedFiles[i].uri));
    }
    master = master.filter((item: FileInfo) => {
      const itemNormUri = FileUtil.normalizeMediaUri(item.uri);
      const itemPath = FileUtil.getPathFromUri(itemNormUri);
      if (!itemPath) {
        return true;
      }
      for (let j = 0; j < importedFiles.length; j++) {
        const importPath = FileUtil.getPathFromUri(FileUtil.normalizeMediaUri(importedFiles[j].uri));
        if (importPath && importPath === itemPath) {
          return importedNormUris.has(itemNormUri);
        }
      }
      return true;
    });

    const uriIndex = new Map<string, number>();
    for (let i = 0; i < master.length; i++) {
      uriIndex.set(FileUtil.normalizeMediaUri(master[i].uri), i);
    }

    const newlyAdded: FileInfo[] = [];
    for (let i = 0; i < importedFiles.length; i++) {
      const incoming = importedFiles[i];
      const lookupUri = FileUtil.normalizeMediaUri(incoming.uri);
      const existingIndex = uriIndex.get(lookupUri);
      if (existingIndex !== undefined) {
        const previous = master[existingIndex];
        incoming.uri = previous.uri;
        incoming.thumbUri = previous.thumbUri ?? incoming.thumbUri;
        incoming.coverUri = previous.coverUri ?? incoming.coverUri;
        incoming.thumbGenerated = previous.thumbGenerated ?? incoming.thumbGenerated;
        incoming.duration = previous.duration > 0 ? previous.duration : incoming.duration;
        master[existingIndex] = incoming;
      } else {
        master.push(incoming);
        uriIndex.set(lookupUri, master.length - 1);
        newlyAdded.push(incoming);
      }
    }

    this.setData(master);
    this.cacheManager.updateCache(MediaType.UNKNOWN, master);
    HiLog.i(TAG, `importMediaFromUris completed: upsert=${processed}, added=${newlyAdded.length}, total=${master.length}`);

    const thumbTargets = importedFiles.filter((item: FileInfo) => ThumbnailManager.needsGeneration(item));
    if (thumbTargets.length > 0) {
      this.generateThumbnailsBackground(thumbTargets);
    }
    return new MediaImportResult(processed, parseResult.skippedCount);
  }

  getMediaItems(): FileInfo[] {
    return this.getFilteredData();
  }

  getMediaItem(index: number): FileInfo | undefined {
    return this.getData(index);
  }

  getMediaItemByUri(uri: string): FileInfo | undefined {
    const index = this.getIndex(uri);
    return index >= 0 ? this.getData(index) : undefined;
  }

  filter(predicate: (item: FileInfo) => boolean): void {
    this.filteredArray = this.getDataArray().filter(predicate);
    this.notifyDataReload();
  }

  clearCache(): void {
    this.cacheManager.clearCache(this.mediaType);
    HiLog.i(TAG, `Cache cleared: ${MediaType[this.mediaType]}`);
  }

  async refreshCache(): Promise<void> {
    await this.loadMediaFiles(this.mediaType, true);
  }

  updateItemThumbnail(uri: string): void {
    const fileInfo = this.getDataArray().find((f: FileInfo) => f.uri === uri);
    if (!fileInfo) {
      return;
    }
    this.notifyThumbnailUpdated(uri, fileInfo);
    HiLog.i(TAG, `Thumbnail updated: ${uri}, uri=${ThumbnailManager.getStoredUri(fileInfo)}`);
  }

  async generateThumbnailsBackground(items: FileInfo[]): Promise<void> {
    const pending = items.filter((item: FileInfo) => ThumbnailManager.needsGeneration(item));
    if (pending.length === 0) {
      HiLog.i(TAG, 'Skipping cover generation: all already have covers');
      return;
    }

    this.isGeneratingThumbnails = true;
    const thumbnailManager = ThumbnailManager.getInstance(this.context);

    try {
      const batchResult = await thumbnailManager.generateBatch(pending);

      // 更新成功的项到 DB 并通知 UI
      for (const item of pending) {
        if (ThumbnailManager.getStoredUri(item).length === 0) {
          continue;
        }
        await this.dbManager.updateMediaMetadata(item);
        this.updateItemThumbnail(item.uri);
      }

      // 收集封面提取失败的文件，使用重试队列在子线程重试
      if (batchResult.failedItems.length > 0) {
        HiLog.i(TAG, `Cover extraction failed: ${batchResult.failedItems.length} files, starting retry queue`);
        this.retryQueue.enqueue(batchResult.failedItems, RetryType.COVER);
      }

      HiLog.i(TAG, `Thumbnail generation complete: ${pending.length - batchResult.failedItems.length}/${items.length} pending files`);
    } finally {
      this.isGeneratingThumbnails = false;
    }
  }

  /**
   * 处理重试成功回调
   * 当重试队列中的某个文件元数据提取成功时，更新 DB 和 UI
   *
   * @param uri 文件 URI
   * @param retryType 重试类型
   * @param fileInfo 文件信息（已更新）
   */
  private handleRetrySuccess(uri: string, retryType: RetryType, fileInfo: FileInfo): void {
    HiLog.i(TAG, `Retry succeeded: ${fileInfo.fileName} type=${retryType}`);

    // 更新 DB
    this.dbManager.updateMediaMetadata(fileInfo).then(() => {
      // 更新内存中的数据
      const dataArray = this.getDataArray();
      const index = dataArray.findIndex((f: FileInfo) => f.uri === uri);
      if (index >= 0) {
        // 合并更新的字段
        if (retryType === RetryType.DURATION && fileInfo.duration > 0) {
          dataArray[index].duration = fileInfo.duration;
        }
        if (retryType === RetryType.SIZE && fileInfo.size > 0) {
          dataArray[index].size = fileInfo.size;
        }
        if (retryType === RetryType.COVER) {
          if (fileInfo.thumbUri) {
            dataArray[index].thumbUri = fileInfo.thumbUri;
          }
          if (fileInfo.coverUri) {
            dataArray[index].coverUri = fileInfo.coverUri;
          }
          dataArray[index].thumbGenerated = fileInfo.thumbGenerated;
        }

        // 更新 filteredArray
        const filteredIndex = this.filteredArray.findIndex((f: FileInfo) => f.uri === uri);
        if (filteredIndex >= 0) {
          this.filteredArray[filteredIndex] = dataArray[index];
        }

        // 通知 UI 更新
        this.notifyDataChanged();
        if (retryType === RetryType.COVER) {
          this.updateItemThumbnail(uri);
        }
      }
    }).catch((error: Error) => {
      HiLog.e(TAG, `Failed to update DB after retry success: ${error.message}`);
    });
  }
}

export { MediaType };
