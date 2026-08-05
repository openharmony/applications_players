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

import { common } from '@kit.AbilityKit';

import { FileMonitor, MonitorCallback } from '@ohos/common/src/main/ets/scan/FileMonitor';
import { ScanProgressDetail, SortType } from '@ohos/common/src/main/ets/datasource/IMediaDataSource';
import FileInfo from '@ohos/common/src/main/ets/model/FileInfo';
import { MediaDataSource, MediaType } from '@ohos/common/src/main/ets/datasource/MediaDataSource';
import { StorageDeviceManager } from '@ohos/common/src/main/ets/scan/StorageDeviceManager';
import { FileInfo as FileOperateFileInfo } from '@ohos/common/src/main/ets/utils/FileOperateInfo';
import { FileUtil } from '@ohos/common/src/main/ets/utils/FileUtil';
import { MediaImportResult } from '@ohos/common/src/main/ets/scan/MediaImportHelper';
import { FileChangeEvent } from '@ohos/common/src/main/ets/listener/FileChangeEvent';
import { MediaFileScanner } from '@ohos/common/src/main/ets/scan/MediaFileScanner';
import { PublicStorageScanner } from '@ohos/common/src/main/ets/scan/PublicStorageScanner';
import { IMediaListAccess } from '@ohos/common/src/main/ets/bridge/IMediaListAccess';
import { MediaPermissionManager, PermissionState } from '@ohos/common/src/main/ets/permission/MediaPermissionManager';
import { AppContext } from '@ohos/common/src/main/ets/context/AppContext';
import { HiLog } from '@ohos/common/src/main/ets/utils/HiLog';
import { MediaSortPreference } from '@ohos/common/src/main/ets/persistence/preferences/MediaSortPreference';

const TAG = 'MediaAggregateViewModel';

export interface ScanProgress {
  current: number;
  total: number;
}

export class MediaAggregateViewModel implements IMediaListAccess {
  private static instance: MediaAggregateViewModel | null = null;
  private uiMediaList: FileInfo[] = [];
  private isLoading: boolean = false;
  private isGridView: boolean = true;
  private selectedMedia: Set<string> = new Set<string>();
  private isSelectionMode: boolean = false;
  private currentMediaType: MediaType = MediaType.UNKNOWN;
  private context: common.UIAbilityContext | null = null;
  private mediaDataSource: MediaDataSource | null = null;
  private storageDeviceManager: StorageDeviceManager;
  private mediaFileScanner: MediaFileScanner | null = null;
  private includeSystemFiles: boolean = true;
  private isInitialized: boolean = false;
  private fileMonitor: FileMonitor | null = null;
  private dataChangeListeners: ((mediaType: MediaType, data: FileInfo[]) => void)[] = [];
  private thumbnailUpdateListeners: ((uri: string, fileInfo: FileInfo) => void)[] = [];
  private scanProgress: ScanProgress = { current: 0, total: 0 };
  private progressListeners: ((current: number, total: number) => void)[] = [];
  private permissionState: PermissionState = PermissionState.PENDING;
  private permissionListenerId: number = 0;
  private currentSortType: SortType = SortType.DATE;
  private isDesc: boolean = true;
  private sortPreference: MediaSortPreference = MediaSortPreference.getInstance();

  private constructor() {
    this.storageDeviceManager = StorageDeviceManager.getInstance();
  }

  public static getInstance(): MediaAggregateViewModel {
    if (!MediaAggregateViewModel.instance) {
      MediaAggregateViewModel.instance = new MediaAggregateViewModel();
    }
    return MediaAggregateViewModel.instance;
  }

  public init(context: common.UIAbilityContext) {
    HiLog.i(TAG, 'Starting MediaAggregateViewModel initialization');

    this.context = context;
    this.mediaDataSource = new MediaDataSource(context, MediaType.UNKNOWN);
    // 初始化阶段抑制空数据通知：MediaDataSource 构造后 dataArray 为空，
    // 若此时 notifyDataChanged 会导致 UI 先闪一下空状态再显示 DB 缓存数据。
    // loadMediaFiles 完成后会清除该标志并统一通知一次。
    this.mediaDataSource.setSuppressDataNotification(true);
    this.mediaFileScanner = new MediaFileScanner(context);

    this.sortPreference.init(context);
    this.currentSortType = this.sortPreference.getSortType();
    this.isDesc = this.sortPreference.getIsDesc();

    // 关键修复：在数据加载前设置 MediaDataSource 的排序偏好
    // 确保 setData() 的自动排序使用正确的偏好，而非默认值 (DATE desc)
    // 避免初始加载先用默认排序再修正导致的视觉闪烁
    this.mediaDataSource.setSortPreference(this.currentSortType, this.isDesc);

    // 立即检查 AppStorage 是否有 want.parameters 覆盖
    this.applySortFromAppStorage();
    HiLog.i(TAG, `Sort preference: ${this.currentSortType}, isDesc: ${this.isDesc}`);

    const permissionMgr = MediaPermissionManager.getInstance();

    this.permissionListenerId = Date.now();
    permissionMgr.addPermissionListener(this.onPermissionChanged.bind(this));

    this.permissionState = permissionMgr.getPermissionState();
    HiLog.i(TAG, `Cached permission state: ${this.permissionState}`);

    permissionMgr.syncPermissionState()
      .then((state) => {
        HiLog.i(TAG, `Permission sync completed state=${state}`);
        this.permissionState = state;
      })
      .catch((error: Error) => {
        HiLog.e(TAG, `Permission sync failed message=${error.message}`);
      });

    if (this.mediaDataSource) {
      this.mediaDataSource.addDataChangeListener((data) => {
        this.uiMediaList = data.map(item => FileInfo.fromFileOperateFileInfo(item));
        this.notifyDataChange(this.currentMediaType, this.uiMediaList);
      });

      this.mediaDataSource.addThumbnailUpdateListener((uri, fileOperateInfo) => {
        this.updateThumbnailInList(uri, fileOperateInfo);
      });
    }

    this.storageDeviceManager.init(context).then(() => {
      HiLog.i(TAG, 'StorageDeviceManager initialization completed');
    }).catch((error: Error) => {
      HiLog.e(TAG, `StorageDeviceManager initialization failed: ${error.message}`);
    });

    // Initialize FileMonitor for automatic file detection → database sync → UI refresh
    try {
      this.fileMonitor = new FileMonitor(context);

      // Define callback class for ArkTS compatibility
      class ViewModelMonitorCallback implements MonitorCallback {
        private viewModel: MediaAggregateViewModel;
        
        constructor(viewModel: MediaAggregateViewModel) {
          this.viewModel = viewModel;
        }
        
        onBatchFileChanged(event: FileChangeEvent): void {
          HiLog.i(TAG, `Batch file change detected, events: ${event.getEventCount()}`);
          // 增量刷新：从 DB 查询新文件并插入到正确位置，避免全量扫描导致列表重排
          // FileSyncEngine 已将新文件保存到 DB，直接查询 DB 即可获取最新数据
          if (this.viewModel.mediaDataSource) {
            this.viewModel.mediaDataSource.incrementalRefresh().catch((err: Error) => {
              HiLog.e(TAG, `Incremental refresh after batch file change failed: ${err.message}`);
            });
          }
        }
        
        onSyncComplete(count: number): void {
          // 增量刷新：从 DB 查询新文件并插入到正确位置
          // mediatool 导入走 userFileManager 路径，不会触发 onBatchFileChanged
          // 所以 onSyncComplete 必须也触发增量刷新
          if (count > 0 && this.viewModel.mediaDataSource) {
            this.viewModel.mediaDataSource.incrementalRefresh().catch((err: Error) => {
              HiLog.e(TAG, `Incremental refresh after file sync failed: ${err.message}`);
            });
          }
        }
      }

      this.fileMonitor.startMonitor(new ViewModelMonitorCallback(this)).then(async () => {
        HiLog.i(TAG, 'FileMonitor started successfully - automatic file detection enabled');
        
        // Add sandbox directories to watch after startMonitor completes
        const sandboxDirs = this.getSandboxDirectories();
        const publicStorageDirs = PublicStorageScanner.resolveAccessibleDirectories();
        const watchDirs = [...sandboxDirs, ...publicStorageDirs];
        HiLog.i(TAG, `Adding ${watchDirs.length} directories to watch (sandbox=${sandboxDirs.length}, ` +
          `publicFs=${publicStorageDirs.length})`);
        
        for (const dir of watchDirs) {
          try {
            const success = await this.fileMonitor!.addWatchDirectory(dir);
            if (success) {
              HiLog.i(TAG, `Watching directory: ${dir}`);
            } else {
              HiLog.w(TAG, `Failed to watch directory: ${dir}`);
            }
          } catch (err) {
            const errMsg = err instanceof Error ? err.message : String(err);
            HiLog.e(TAG, `Error watching directory ${dir}: ${errMsg}`);
          }
        }
      }).catch((err: Error) => {
        HiLog.e(TAG, `Failed to start FileMonitor: ${err.message}`);
      });
    } catch (error) {
      const errMsg = error instanceof Error ? error.message : String(error);
      HiLog.e(TAG, `FileMonitor initialization error: ${errMsg}`);
    }
    this.isInitialized = true;  // 标记初始化完成，使 isReady() 返回 true
    HiLog.i(TAG, 'MediaAggregateViewModel initialization completed');
  }

  private onPermissionChanged(state: PermissionState): void {
    HiLog.i(TAG, `Permission state changed: ${this.permissionState} -> ${state}`);
    const previousState = this.permissionState;
    this.permissionState = state;

    const wasAllowed = previousState === PermissionState.GRANTED || previousState === PermissionState.PARTIAL;
    const isAllowed = state === PermissionState.GRANTED || state === PermissionState.PARTIAL;
    const mediaType: MediaType = this.currentMediaType !== MediaType.UNKNOWN ?
      this.currentMediaType : MediaType.UNKNOWN;

    if (!wasAllowed && isAllowed) {
      HiLog.i(TAG, 'Permission granted, refreshing media list within scope');
      this.loadMediaFiles(mediaType, true);
      return;
    }

    if (wasAllowed && !isAllowed) {
      HiLog.w(TAG, 'System media permission revoked, falling back to sandbox and stopping public directory scan');
      if (this.mediaDataSource) {
        this.mediaDataSource.setMediaReadAccessScope(false, false);
        this.mediaDataSource.setIncludePublicFiles(false);
        this.mediaDataSource.setIncludeSystemFiles(false);
        this.mediaDataSource.clear();
      }
      this.loadMediaFiles(mediaType, true);
      return;
    }

    // PARTIAL ↔ GRANTED：授权范围变化，需强制重载避免沿用未过滤缓存
    if (wasAllowed && isAllowed && previousState !== state) {
      HiLog.i(TAG, 'Media read permission scope changed, forcing reload with new scope');
      this.loadMediaFiles(mediaType, true);
    }
  }

  public getPermissionState(): PermissionState {
    return this.permissionState;
  }

  /**
   * 应用内确认媒体授权并刷新列表（不触发系统权限弹窗）
   *
   * @param mediaType 当前展示的媒体类型
   * @returns 授权后状态
   */
  public async requestPermissionAndReload(mediaType: MediaType): Promise<PermissionState> {
    const permissionMgr = MediaPermissionManager.getInstance();
    const context = AppContext.getInstance().getMainAbilityContext();
    if (!context) {
      HiLog.e(TAG, 'Unable to get context, permission request cancelled');
      return PermissionState.DENIED;
    }
    const state = await permissionMgr.requestSystemMediaPermission(context);
    // 确保读权限缓存与 ATM 一致，供首页提示条立刻隐藏
    await permissionMgr.getMediaReadAccess();
    HiLog.i(TAG, `Permission request result: ${state}`);
    if (state === PermissionState.GRANTED || state === PermissionState.PARTIAL) {
      await this.loadMediaFiles(mediaType, true);
    }
    return state;
  }

  public isReady(): boolean {
    return this.isInitialized && this.context !== null && this.mediaDataSource !== null;
  }

  public addDataChangeListener(listener: (mediaType: MediaType, data: FileInfo[]) => void): void {
    this.dataChangeListeners.push(listener);
    HiLog.i(TAG, `Added data change listener, current count: ${this.dataChangeListeners.length}`);
  }

  public removeDataChangeListener(listener: (mediaType: MediaType, data: FileInfo[]) => void): void {
    const index = this.dataChangeListeners.indexOf(listener);
    if (index !== -1) {
      this.dataChangeListeners.splice(index, 1);
      HiLog.i(TAG, `Removed data change listener, remaining count: ${this.dataChangeListeners.length}`);
    }
  }

  public addThumbnailUpdateListener(listener: (uri: string, fileInfo: FileInfo) => void): void {
    this.thumbnailUpdateListeners.push(listener);
  }

  public removeThumbnailUpdateListener(listener: (uri: string, fileInfo: FileInfo) => void): void {
    const index = this.thumbnailUpdateListeners.indexOf(listener);
    if (index !== -1) {
      this.thumbnailUpdateListeners.splice(index, 1);
    }
  }

  private notifyDataChange(type: MediaType, data: FileInfo[]): void {
    HiLog.i(TAG, `Notifying data change: ${MediaType[type]}, count: ${data.length}`);
    for (const listener of this.dataChangeListeners) {
      try {
        listener(type, data);
      } catch (error) {
        HiLog.e(TAG, `Data change listener execution failed: ${error}`);
      }
    }
  }

  private notifyThumbnailUpdate(uri: string, fileInfo: FileInfo): void {
    for (const listener of this.thumbnailUpdateListeners) {
      try {
        listener(uri, fileInfo);
      } catch (error) {
        HiLog.e(TAG, `Thumbnail update listener execution failed: ${error}`);
      }
    }
  }

  private updateThumbnailInList(uri: string, fileOperateInfo: FileOperateFileInfo): void {
    const index = this.uiMediaList.findIndex(f => f.uri === uri);
    if (index >= 0) {
      this.uiMediaList[index].updateThumbnailData(fileOperateInfo);
      this.notifyThumbnailUpdate(uri, this.uiMediaList[index]);
      HiLog.i(TAG, `Updated UI list thumbnail: ${uri}`);
    }
  }

  /**
   * 即时切换显示媒体类型（不重新扫描，仅内存过滤）
   * 用于 tab 切换场景：数据已加载时，直接过滤切换
   */
  public switchMediaType(mediaType: MediaType): void {
    if (!this.isReady()) {
      HiLog.w(TAG, 'ViewModel not ready for switchMediaType');
      return;
    }

    this.currentMediaType = mediaType;
    HiLog.i(TAG, `Trace[filter/4] switchMediaType mediaType=${MediaType[mediaType]}`);
    if (this.mediaDataSource) {
      this.mediaDataSource.filterByType(mediaType);
      this.uiMediaList = this.mediaDataSource.getFilteredData().map(item => FileInfo.fromFileOperateFileInfo(item));
    }
    this.notifyDataChange(mediaType, this.uiMediaList);
    HiLog.i(TAG, `switchMediaType: ${MediaType[mediaType]}, count: ${this.uiMediaList.length}`);
  }

  public async loadMediaFiles(mediaType: MediaType, forceRefresh: boolean = false) {
    if (!this.isReady()) {
      HiLog.e(TAG, 'ViewModel not ready, cannot load media files');
      return;
    }

    this.currentMediaType = mediaType;

    try {
      this.isLoading = true;
      this.currentMediaType = mediaType;

      const permissionMgr = MediaPermissionManager.getInstance();
      // 每次加载都以系统读权限复核，避免 Preference/缓存态误判后扫描公共目录
      const mediaAccess = await permissionMgr.getMediaReadAccess();
      HiLog.i(TAG,
        `Loading media files: ${MediaType[mediaType]}, permission state: ${this.permissionState}, ` +
        `audio=${mediaAccess.hasAudio}, imageVideo=${mediaAccess.hasImageVideo}, ` +
        `forceRefresh: ${forceRefresh}`);

      if (!mediaAccess.hasAny) {
        if (this.mediaDataSource) {
          this.mediaDataSource.setMediaReadAccessScope(false, false);
          this.mediaDataSource.setIncludePublicFiles(false);
          this.mediaDataSource.setIncludeSystemFiles(false);
          this.mediaDataSource.clear();
        }
        if (this.permissionState === PermissionState.GRANTED ||
          this.permissionState === PermissionState.PARTIAL) {
          this.permissionState = PermissionState.DENIED;
          permissionMgr.setPermissionState(PermissionState.DENIED);
        }
        HiLog.i(TAG, 'No system media read permission, scanning sandbox only');
        await this.loadSandboxFilesOnly(mediaType, true);
        HiLog.i(TAG, `Media files loaded, count: ${this.uiMediaList.length}`);
        return;
      }

      // 有系统权限时，若数据已加载且不强制刷新，可直接切换过滤
      if (!forceRefresh && this.mediaDataSource && this.mediaDataSource.getDataArray().length > 0) {
        this.switchMediaType(mediaType);
        return;
      }

      if (this.mediaDataSource) {
        // 媒体库可按已授权类型扫描；UserFile/PublicStorage 仅双权限时开启
        this.mediaDataSource.setIncludeSystemFiles(true);
        this.mediaDataSource.setMediaReadAccessScope(mediaAccess.hasAudio, mediaAccess.hasImageVideo);
        if (mediaAccess.hasAll) {
          HiLog.i(TAG, 'Both media read permissions granted, scanning sandbox + media library + public file system');
        } else {
          HiLog.i(TAG,
            'Partial media read permission: scanning media library within scope only, PublicStorage/UserFile disabled');
        }
        await this.mediaDataSource.loadMediaFiles(mediaType, forceRefresh);
        this.uiMediaList = this.mediaDataSource.getFilteredData()
          .map(item => FileInfo.fromFileOperateFileInfo(item));
        this.notifyDataChange(this.currentMediaType, this.uiMediaList);
        if (this.permissionState !== PermissionState.GRANTED &&
          this.permissionState !== PermissionState.PARTIAL) {
          this.permissionState = await permissionMgr.syncPermissionState();
        }
      }

      // setData() 已包含自动排序和 notifyDataChanged()
      // 不再需要手动调用 sortBy() 来重新排序和通知 UI
      // 修复前的问题：setData() 不排序，导致增量扫描后数据未排序
      // 修复后：setData() 自动排序 + notifyDataChanged()，覆盖所有数据更新路径
      HiLog.i(TAG, `Media files loaded, count: ${this.uiMediaList.length}`);
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      HiLog.e(TAG, `Failed to load media files: ${errorMessage}`);
      throw new Error(`加载媒体文件失败: ${errorMessage}`);
    } finally {
      this.isLoading = false;
    }
  }

  private async loadSandboxFilesOnly(mediaType: MediaType, forceRefresh: boolean = false): Promise<void> {
    if (!this.context || !this.mediaFileScanner) {
      HiLog.e(TAG, 'context or mediaFileScanner not initialized');
      this.uiMediaList = [];
      this.notifyDataChange(mediaType, this.uiMediaList);
      return;
    }

    try {
      HiLog.i(TAG, `Scanning sandbox only (all types, display filter: ${MediaType[mediaType]})`);

      const sandboxScanner = this.mediaFileScanner.getSandboxFileScanner();
      const directories = this.getSandboxDirectories();

      // 始终扫描全部类型，然后按显示类型过滤
      const audioFiles = await sandboxScanner.scanLocalAudioFiles(directories);
      const videoFiles = await sandboxScanner.scanLocalVideoFiles(directories);
      const allFiles: FileOperateFileInfo[] = [...audioFiles, ...videoFiles];

      const allFileInfo: FileInfo[] = allFiles.map((item: FileOperateFileInfo): FileInfo => FileInfo.fromFileOperateFileInfo(item));

      // 按显示类型过滤
      if (mediaType === MediaType.AUDIO) {
        this.uiMediaList = allFileInfo.filter(f => f.mimeType.startsWith('audio'));
      } else if (mediaType === MediaType.VIDEO) {
        this.uiMediaList = allFileInfo.filter(f => f.mimeType.startsWith('video'));
      } else {
        this.uiMediaList = allFileInfo;
      }
      HiLog.i(TAG, `Sandbox scan complete: ${allFileInfo.length} total files, filtered to ${MediaType[mediaType]}: ${this.uiMediaList.length}`);

      this.notifyDataChange(mediaType, this.uiMediaList);
    } catch (error) {
      HiLog.e(TAG, `Sandbox directory scan failed: ${error}`);
      this.uiMediaList = [];
      this.notifyDataChange(mediaType, this.uiMediaList);
    }
  }

  private getSandboxDirectories(): string[] {
    if (!this.context) {
      return [];
    }
    return [
      this.context.filesDir,
      this.context.cacheDir,
      this.context.filesDir + '/Music',
      this.context.filesDir + '/Videos',
      this.context.filesDir + '/Downloads'
    ];
  }

  public async refresh() {
    if (this.currentMediaType !== MediaType.UNKNOWN) {
      await this.loadMediaFiles(this.currentMediaType);
    }
  }

  public setIncludeSystemFiles(include: boolean) {
    this.includeSystemFiles = include;
    HiLog.i(TAG, `Set include system files: ${include}`);
  }

  public getIncludeSystemFiles(): boolean {
    return this.includeSystemFiles;
  }

  public getMediaList(): FileInfo[] {
    return [...this.uiMediaList];
  }

  public getMediaDataSource(): MediaDataSource | null {
    return this.mediaDataSource;
  }

  /**
   * Picker 导入媒体：upsert DB + 刷新内存列表，不触发全量扫描。
   */
  public async importMediaFromPicker(uris: string[],
    onProgress?: (processed: number, total: number) => void): Promise<MediaImportResult> {
    if (!this.mediaDataSource || uris.length === 0) {
      return new MediaImportResult(0, 0);
    }
    const result = await this.mediaDataSource.importMediaFromUris(uris, onProgress);
    if (result.imported > 0) {
      this.uiMediaList = this.mediaDataSource.getFilteredData()
        .map(item => FileInfo.fromFileOperateFileInfo(item));
      HiLog.i(TAG, `Picker import completed: ${result.imported} files, skipped=${result.skipped}`);
      this.notifyDataChange(this.currentMediaType, this.uiMediaList);
    }
    return result;
  }

  public getCurrentMediaType(): MediaType {
    return this.currentMediaType;
  }

  public getFileMonitor(): FileMonitor | null {
    return this.fileMonitor;
  }

  public getIsLoading(): boolean {
    return this.isLoading;
  }

  public getIsGridView(): boolean {
    return this.isGridView;
  }

  public toggleViewMode() {
    this.isGridView = !this.isGridView;
    HiLog.i(TAG, `Switched to ${this.isGridView ? 'grid' : 'list'} view`);
  }

  public getSelectedMedia(): Set<string> {
    return this.selectedMedia;
  }

  public toggleSelection(mediaId: string) {
    if (this.selectedMedia.has(mediaId)) {
      this.selectedMedia.delete(mediaId);
      HiLog.i(TAG, `Deselected media: ${mediaId}`);
    } else {
      this.selectedMedia.add(mediaId);
      HiLog.i(TAG, `Selected media: ${mediaId}`);
    }
  }

  public clearSelection() {
    this.selectedMedia.clear();
    HiLog.i(TAG, 'Cleared selection');
  }

  public getSelectedCount(): number {
    return this.selectedMedia.size;
  }

  /** 是否处于多选模式 */
  public getIsSelectionMode(): boolean {
    return this.isSelectionMode;
  }

  /**
   * 进入多选模式（通常由长按触发，并选中该项）
   *
   * @param uri 触发长按的媒体 URI，可选
   */
  public enterSelectionMode(uri?: string): void {
    this.isSelectionMode = true;
    if (uri !== undefined && uri.length > 0) {
      this.selectedMedia.add(uri);
    }
    HiLog.i(TAG, `Trace[multi-select] enterSelectionMode uri=${uri ?? ''} count=${this.selectedMedia.size}`);
  }

  /** 退出多选模式并清空选择 */
  public exitSelectionMode(): void {
    this.isSelectionMode = false;
    this.selectedMedia.clear();
    HiLog.i(TAG, 'Trace[multi-select] exitSelectionMode');
  }

  /** 当前选中项 URI 列表 */
  public getSelectedUris(): string[] {
    const uris: string[] = [];
    this.selectedMedia.forEach((uri: string) => uris.push(uri));
    return uris;
  }

  /**
   * 以完整 URI 集合覆盖当前选择（拖动涂选使用）
   *
   * @param uris 目标选中 URI 列表
   */
  public replaceSelection(uris: string[]): void {
    this.selectedMedia.clear();
    for (const uri of uris) {
      this.selectedMedia.add(uri);
    }
    if (this.selectedMedia.size > 0) {
      this.isSelectionMode = true;
    }
  }

  /** 当前展示列表是否已全部选中 */
  public isAllSelected(): boolean {
    if (this.uiMediaList.length === 0) {
      return false;
    }
    return this.uiMediaList.every((item: FileInfo) => this.selectedMedia.has(item.uri));
  }

  /** 全选 / 取消全选：已全选则清空，否则选中当前展示的全部条目 */
  public toggleSelectAll(): void {
    if (this.isAllSelected()) {
      this.clearSelection();
      HiLog.i(TAG, 'Trace[multi-select] toggleSelectAll -> deselect all');
    } else {
      for (const item of this.uiMediaList) {
        this.selectedMedia.add(item.uri);
      }
      HiLog.i(TAG, `Trace[multi-select] toggleSelectAll -> select all count=${this.selectedMedia.size}`);
    }
  }

  /**
   * 删除已选条目：DB 软删除（不删本地源文件）+ 刷新列表，完成后退出多选模式。
   *
   * @returns 实际删除条目数
   */
  public async deleteSelected(): Promise<number> {
    if (!this.mediaDataSource || this.selectedMedia.size === 0) {
      HiLog.w(TAG, 'Trace[multi-select] deleteSelected no selection or data source empty');
      return 0;
    }
    const uris = this.getSelectedUris();
    return await this.deleteByUris(uris, true);
  }

  /**
   * 按 URI 列表软删除（滑动删除单条或多选批量共用）
   *
   * @param uris 待删除 URI
   * @param exitSelection 完成后是否退出多选模式
   * @returns 实际移除条数
   */
  public async deleteByUris(uris: string[], exitSelection: boolean = false): Promise<number> {
    if (!this.mediaDataSource || uris.length === 0) {
      HiLog.w(TAG, 'Trace[delete] deleteByUris no URIs or data source empty');
      return 0;
    }
    HiLog.i(TAG, `Trace[delete] deleteByUris start count=${uris.length}`);
    try {
      const removed = await this.mediaDataSource.softDeleteByUris(uris);
      for (let i = 0; i < uris.length; i++) {
        this.selectedMedia.delete(uris[i]);
      }
      if (exitSelection) {
        this.exitSelectionMode();
      }
      HiLog.i(TAG, `Trace[delete] deleteByUris success removed=${removed}`);
      return removed;
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      HiLog.e(TAG, `Trace[delete] deleteByUris failed message=${message}`);
      return 0;
    }
  }

  public searchMedia(keyword: string): FileInfo[] {
    if (!keyword) {
      return this.uiMediaList;
    }
    const lowerKeyword = keyword.toLowerCase();
    return this.uiMediaList.filter((media: FileInfo): boolean => {
      return media.fileName.toLowerCase().includes(lowerKeyword);
    });
  }

  public getMediaById(id: string): FileInfo | undefined {
    return this.uiMediaList.find((media: FileInfo): boolean => {
      return media.uri === id;
    });
  }

  /**
   * 按 URI 查找媒体（含规范化匹配；优先当前列表，再查全量数据源）
   *
   * @param uri 媒体 URI
   * @returns 匹配的 FileInfo，未找到返回 undefined
   */
  public findMediaByUri(uri: string): FileInfo | undefined {
    if (uri.length === 0) {
      return undefined;
    }
    const normalized = FileUtil.normalizeMediaUri(uri);
    const matchInUi = this.uiMediaList.find((media: FileInfo): boolean => {
      return media.uri === uri || FileUtil.normalizeMediaUri(media.uri) === normalized;
    });
    if (matchInUi !== undefined) {
      return matchInUi;
    }
    const dataSource = this.mediaDataSource;
    if (dataSource === null) {
      return undefined;
    }
    const fromAll: FileOperateFileInfo | undefined = dataSource.getDataArray().find((media: FileOperateFileInfo): boolean => {
      return media.uri === uri || FileUtil.normalizeMediaUri(media.uri) === normalized;
    });
    if (fromAll === undefined) {
      return undefined;
    }
    return FileInfo.fromFileOperateFileInfo(fromAll);
  }

  public getMediaCount(): number {
    return this.uiMediaList.length;
  }

  public sortByTitle(ascending: boolean = true) {
    this.uiMediaList.sort((a: FileInfo, b: FileInfo): number => {
      return ascending ? a.fileName.localeCompare(b.fileName) : b.fileName.localeCompare(a.fileName);
    });
    HiLog.i(TAG, `Sorted by name: ${ascending ? 'ascending' : 'descending'}`);
  }

  public sortByDuration(ascending: boolean = true) {
    this.uiMediaList.sort((a: FileInfo, b: FileInfo): number => {
      return ascending ? a.duration - b.duration : b.duration - a.duration;
    });
    HiLog.i(TAG, `Sorted by duration: ${ascending ? 'ascending' : 'descending'}`);
  }

  public sortBySize(ascending: boolean = true) {
    this.uiMediaList.sort((a: FileInfo, b: FileInfo): number => {
      return ascending ? a.fileSize - b.fileSize : b.fileSize - a.fileSize;
    });
    HiLog.i(TAG, `Sorted by size: ${ascending ? 'ascending' : 'descending'}`);
  }

  public sortByMtime(ascending: boolean = true) {
    this.uiMediaList.sort((a: FileInfo, b: FileInfo): number => {
      return ascending ? a.updateTime - b.updateTime : b.updateTime - a.updateTime;
    });
    HiLog.i(TAG, `Sorted by modification time: ${ascending ? 'ascending' : 'descending'}`);
  }

  public sortBy(sortType: SortType, isDesc: boolean = false) {
    this.currentSortType = sortType;
    this.isDesc = isDesc;
    HiLog.i(TAG, `Trace[sort/3] MediaAggregateViewModel.sortBy sortType=${sortType} isDesc=${isDesc}`);
    this.sortPreference.saveSortPreference(sortType, isDesc);
    
    // 关键修复：调用 MediaDataSource.sortBy() 来刷新 LazyForEach
    // MediaDataSource.sortBy() 会：
    // 1. 排序 filteredArray（实际 UI 显示的数据）
    // 2. 调用 notifyDataReload() 刷新 LazyForEach
    // 3. 调用 notifyDataChanged() 触发 listener 更新 uiMediaList
    if (this.mediaDataSource) {
      this.mediaDataSource.sortBy(sortType, isDesc);
      HiLog.i(TAG, `Sort completed: MediaDataSource.sortBy() called`);
    } else {
      HiLog.e(TAG, 'mediaDataSource is null, cannot sort');
    }
  }

  /**
   * Apply sort settings from AppStorage (set by MainAbility from Want.parameters)
   * Called during initialization to apply sort type from cold startup
   */
  public applySortFromAppStorage(): void {
    // Read sortBy from AppStorage (set by MainAbility from Want.parameters)
    const sortByStr = AppStorage.get<string>('sortBy');
    const sortDesc = AppStorage.get<boolean>('sortDesc');

    if (sortByStr) {
      // Convert string to SortType enum
      const sortType = this.parseSortTypeString(sortByStr);

      if (sortType) {
        HiLog.i(TAG, `Applying sort from AppStorage: sortType=${sortType}, isDesc=${sortDesc}`);
        this.sortBy(sortType, sortDesc ?? false);

        // Clear AppStorage after use (prevent stale values in subsequent launches)
        AppStorage.setOrCreate('sortBy', '');
        AppStorage.setOrCreate('sortDesc', false);
        HiLog.i(TAG, 'sortBy/sortDesc cleared from AppStorage');
      } else {
        HiLog.w(TAG, `Invalid sortBy value from AppStorage: ${sortByStr}`);
      }
    }
  }

  /**
   * Parse sort type string to SortType enum
   */
  private parseSortTypeString(sortTypeStr: string): SortType | null {
    switch (sortTypeStr) {
      case 'name':
        return SortType.NAME;
      case 'date':
        return SortType.DATE;
      case 'size':
        return SortType.SIZE;
      case 'duration':
        return SortType.DURATION;
      default:
        return null;
    }
  }

  public getCurrentSortType(): SortType {
    return this.currentSortType;
  }

  public getIsDesc(): boolean {
    return this.isDesc;
  }

  public isScanning(): boolean {
    return this.mediaDataSource?.isScanning() || false;
  }

  /**
   * 获取当前扫描进度百分比，供 DefaultIndexPage 轮询刷新 Progress。
   *
   * @returns 0–100，无数据源或未扫描时返回 0
   */
  public getScanProgress(): number {
    return this.mediaDataSource?.getScanProgress() || 0;
  }

  /**
   * 获取扫描进度明细（百分比 + 已处理/总数）
   */
  public getScanProgressDetail(): ScanProgressDetail {
    if (!this.mediaDataSource) {
      return { percent: 0, processed: 0, total: 0 };
    }
    return this.mediaDataSource.getScanProgressDetail();
  }

  public cancelScan(): boolean {
    return this.mediaDataSource?.cancelScan() || false;
  }

  public getChunkProgress(): ScanProgress {
    return this.scanProgress;
  }

  public addProgressListener(listener: (current: number, total: number) => void): void {
    this.progressListeners.push(listener);
  }

  public removeProgressListener(listener: (current: number, total: number) => void): void {
    const index = this.progressListeners.indexOf(listener);
    if (index !== -1) {
      this.progressListeners.splice(index, 1);
    }
  }

  private notifyProgress(current: number, total: number): void {
    for (const listener of this.progressListeners) {
      try {
        listener(current, total);
      } catch (error) {
        HiLog.e(TAG, `Progress listener execution failed: ${error}`);
      }
    }
  }

  /**
   * Release all resources and cleanup listeners
   * Called when Ability is destroyed to prevent memory leaks
   */
  async destroy(): Promise<void> {
    HiLog.i(TAG, 'Destroying MediaAggregateViewModel');

    // Stop and destroy FileMonitor
    if (this.fileMonitor) {
      try {
        await this.fileMonitor.destroy();
        this.fileMonitor = null;
        HiLog.i(TAG, 'FileMonitor destroyed');
      } catch (error) {
        const errMsg = error instanceof Error ? error.message : String(error);
        HiLog.e(TAG, `Failed to destroy FileMonitor: ${errMsg}`);
      }
    }

    // Clear all listener arrays
    this.dataChangeListeners = [];
    this.thumbnailUpdateListeners = [];
    this.progressListeners = [];

    // Reset state
    this.uiMediaList = [];
    this.mediaDataSource = null;
    this.mediaFileScanner = null;
    this.context = null;
    this.isInitialized = false;

    // Reset singleton instance
    MediaAggregateViewModel.instance = null;

    HiLog.i(TAG, 'MediaAggregateViewModel destroyed');
  }
}
