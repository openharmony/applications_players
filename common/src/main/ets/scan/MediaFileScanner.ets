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


import { HiLog } from '../utils/HiLog';
import { HiTrace } from '../utils/HiTrace';
import { FileInfo } from '../utils/FileOperateInfo';
import { SandboxFileScanner } from './SandboxFileScanner';
import { MediaLibraryScanner } from './MediaLibraryScanner';
import { UserFileScanner } from './UserFileScanner';
import type common from '@ohos.app.ability.common';

const TAG = 'MediaFileScanner';

export class MediaFileScanner {
  private context: common.Context;
  private sandboxFileScanner: SandboxFileScanner;
  private mediaLibraryScanner: MediaLibraryScanner;
  private userFileScanner: UserFileScanner;

  constructor(context: common.Context) {
    HiTrace.begin(TAG, `create MediaFileScanner`)
    this.context = context;
    this.sandboxFileScanner = new SandboxFileScanner(context);
    this.mediaLibraryScanner = new MediaLibraryScanner(context);
    this.userFileScanner = new UserFileScanner(context);
    HiTrace.end(TAG, `create MediaFileScanner`)
  }

  async scanAudioFiles(includeLibrary: boolean = false, includePublic: boolean = true): Promise<FileInfo[]> {
    try {
      HiLog.i(TAG, 'Starting audio file scan');
      
      const tasks: (() => Promise<FileInfo[]>)[] = [];
      
      tasks.push(() => this.sandboxFileScanner.scanLocalAudioFiles(this.getAudioDirectories()));
      
      if (includePublic && this.userFileScanner.isReady()) {
        HiLog.i(TAG, 'Including public directory audio scan');
        tasks.push(() => this.userFileScanner.scanPublicAudioFiles());
      }
      
      const results = await this.parallelScan(tasks);
      const allFiles = this.mergeResults(results);
      
      HiLog.i(TAG, 'Audio file scan complete, ' + allFiles.length + ' files');
      return allFiles;
    } catch (error) {
      HiLog.e(TAG, 'Audio file scan failed: ' + error);
      return [];
    }
  }

  async scanAudioFilesWithChunk(
    includeLibrary: boolean = false,
    includePublic: boolean = true,
    chunkSize: number = 50,
    onChunk: (chunk: FileInfo[], index: number, total: number) => void
  ): Promise<FileInfo[]> {
    try {
      HiLog.i(TAG, 'Starting chunked audio file scan, chunk size: ' + chunkSize);
      
      const tasks: (() => Promise<FileInfo[]>)[] = [];
      
      tasks.push(() => this.sandboxFileScanner.scanLocalAudioFiles(this.getAudioDirectories()));
      
      if (includePublic && this.userFileScanner.isReady()) {
        HiLog.i(TAG, 'Including public directory audio scan');
        tasks.push(() => this.userFileScanner.scanPublicAudioFiles());
      }
      
      const results = await this.parallelScan(tasks);
      const allFiles = this.mergeResults(results);
      
      const totalChunks = Math.ceil(allFiles.length / chunkSize);
      HiLog.i(TAG, `Audio file scan complete, ${allFiles.length} files, ${totalChunks} chunks`);
      
      for (let i = 0; i < allFiles.length; i += chunkSize) {
        const chunk = allFiles.slice(i, i + chunkSize);
        const chunkIndex = Math.floor(i / chunkSize);
        onChunk(chunk, chunkIndex, totalChunks);
        HiLog.i(TAG, `Chunk ${chunkIndex + 1}/${totalChunks} complete, ${chunk.length} files`);
      }
      
      return allFiles;
    } catch (error) {
      HiLog.e(TAG, 'Chunked audio file scan failed: ' + error);
      return [];
    }
  }

  async scanVideoFiles(includeLibrary: boolean = true, includePublic: boolean = true): Promise<FileInfo[]> {
    try {
      HiLog.i(TAG, 'Starting video file scan');
      
      const tasks: (() => Promise<FileInfo[]>)[] = [];
      
      tasks.push(() => this.sandboxFileScanner.scanLocalVideoFiles(this.getVideoDirectories()));
      
      if (includeLibrary && this.mediaLibraryScanner.isReady()) {
        HiLog.i(TAG, 'Including media library video scan');
        tasks.push(() => this.mediaLibraryScanner.scanVideoFiles());
      }
      
      if (includePublic && this.userFileScanner.isReady()) {
        HiLog.i(TAG, 'Including public directory video scan');
        tasks.push(() => this.userFileScanner.scanPublicVideoFiles());
      }
      
      const results = await this.parallelScan(tasks);
      const allFiles = this.mergeResults(results);
      
      HiLog.i(TAG, 'Video file scan complete, ' + allFiles.length + ' files');
      return allFiles;
    } catch (error) {
      HiLog.e(TAG, 'Video file scan failed: ' + error);
      return [];
    }
  }

  async scanVideoFilesWithChunk(
    includeLibrary: boolean = true,
    includePublic: boolean = true,
    chunkSize: number = 50,
    onChunk: (chunk: FileInfo[], index: number, total: number) => void
  ): Promise<FileInfo[]> {
    try {
      HiLog.i(TAG, 'Starting chunked video file scan, chunk size: ' + chunkSize);
      
      const tasks: (() => Promise<FileInfo[]>)[] = [];
      
      tasks.push(() => this.sandboxFileScanner.scanLocalVideoFiles(this.getVideoDirectories()));
      
      if (includeLibrary && this.mediaLibraryScanner.isReady()) {
        HiLog.i(TAG, 'Including media library video scan');
        tasks.push(() => this.mediaLibraryScanner.scanVideoFiles());
      }
      
      if (includePublic && this.userFileScanner.isReady()) {
        HiLog.i(TAG, 'Including public directory video scan');
        tasks.push(() => this.userFileScanner.scanPublicVideoFiles());
      }
      
      const results = await this.parallelScan(tasks);
      const allFiles = this.mergeResults(results);
      
      const totalChunks = Math.ceil(allFiles.length / chunkSize);
      HiLog.i(TAG, `Video file scan complete, ${allFiles.length} files, ${totalChunks} chunks`);
      
      for (let i = 0; i < allFiles.length; i += chunkSize) {
        const chunk = allFiles.slice(i, i + chunkSize);
        const chunkIndex = Math.floor(i / chunkSize);
        onChunk(chunk, chunkIndex, totalChunks);
        HiLog.i(TAG, `Chunk ${chunkIndex + 1}/${totalChunks} complete, ${chunk.length} files`);
      }
      
      return allFiles;
    } catch (error) {
      HiLog.e(TAG, 'Chunked video file scan failed: ' + error);
      return [];
    }
  }

  async scanAllMediaFiles(includeLibrary: boolean = true, includePublic: boolean = true): Promise<FileInfo[]> {
    try {
      HiLog.i(TAG, 'Starting all media file scan');
      
      const tasks: (() => Promise<FileInfo[]>)[] = [];
      
      tasks.push(() => this.sandboxFileScanner.scanLocalAudioFiles(this.getAudioDirectories()));
      tasks.push(() => this.sandboxFileScanner.scanLocalVideoFiles(this.getVideoDirectories()));
      
      if (includeLibrary && this.mediaLibraryScanner.isReady()) {
        HiLog.i(TAG, 'Including media library scan');
        tasks.push(() => this.mediaLibraryScanner.scanAllMediaFiles());
      }
      
      if (includePublic && this.userFileScanner.isReady()) {
        HiLog.i(TAG, 'Including public directory scan');
        tasks.push(() => this.userFileScanner.scanAllPublicMediaFiles());
      }
      
      const results = await this.parallelScan(tasks);
      const allFiles = this.mergeResults(results);
      
      HiLog.i(TAG, 'All media file scan complete, ' + allFiles.length + ' files');
      return allFiles;
    } catch (error) {
      HiLog.e(TAG, 'All media file scan failed: ' + error);
      return [];
    }
  }

  private getAudioDirectories(): string[] {
    return [
      this.context.filesDir,
      this.context.cacheDir,
      this.context.filesDir + '/Music',
      this.context.filesDir + '/Downloads'
    ];
  }

  private getVideoDirectories(): string[] {
    return [
      this.context.filesDir,
      this.context.cacheDir,
      this.context.filesDir + '/Videos',
      this.context.filesDir + '/Downloads'
    ];
  }

  getSandboxFileScanner(): SandboxFileScanner {
    return this.sandboxFileScanner;
  }

  getMediaLibraryScanner(): MediaLibraryScanner {
    return this.mediaLibraryScanner;
  }

  getUserFileScanner(): UserFileScanner {
    return this.userFileScanner;
  }

  private async parallelScan<T>(
    tasks: (() => Promise<T>)[]
  ): Promise<T[]> {
    try {
      const results = await Promise.allSettled(tasks.map(task => task()));
      
      const successfulResults: T[] = [];
      let failedCount = 0;
      
      results.forEach((result, index) => {
        if (result.status === 'fulfilled') {
          successfulResults.push(result.value);
          const fileInfoArray = result.value as FileInfo[];
          HiLog.i(TAG, 'Scan task ' + index + ' succeeded, files: ' + fileInfoArray.length);
        } else {
          failedCount++;
          HiLog.e(TAG, 'Scan task ' + index + '  failed: ' + result.reason);
        }
      });
      
      HiLog.i(TAG, 'Parallel scan complete: ' + (tasks.length - failedCount) + '/' + tasks.length);
      return successfulResults;
    } catch (error) {
      HiLog.e(TAG, 'Parallel scan error: ' + error);
      return [];
    }
  }

  private mergeResults(results: FileInfo[][]): FileInfo[] {
    const uriSet = new Set<string>();
    const mergedFiles: FileInfo[] = [];
    
    for (const files of results) {
      for (const file of files) {
        if (!uriSet.has(file.uri)) {
          uriSet.add(file.uri);
          mergedFiles.push(file);
        }
      }
    }
    
    return mergedFiles;
  }
}
