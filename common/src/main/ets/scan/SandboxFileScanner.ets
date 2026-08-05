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
import { FileInfo } from '../utils/FileOperateInfo';
import { FileUtil } from '../utils/FileUtil';
import fs from '@ohos.file.fs';
import media from '@ohos.multimedia.media';
import type common from '@ohos.app.ability.common';
import { SupportedMediaFormats } from '../constants/media/SupportedMediaFormats';
import { MediaMetadataResolver } from '../utils/MediaMetadataResolver';

const TAG = 'SandboxFileScanner';

export class SandboxFileScanner {
  private context: common.Context;
  private readonly AUDIO_EXTENSIONS: string[] = SupportedMediaFormats.AUDIO_SUFFIXES.slice();
  private readonly VIDEO_EXTENSIONS: string[] = SupportedMediaFormats.VIDEO_SUFFIXES.slice();

  constructor(context: common.Context) {
    this.context = context;
  }

  async scanLocalAudioFiles(directories: string[], recursive: boolean = true): Promise<FileInfo[]> {
    return this.scanFiles(directories, this.AUDIO_EXTENSIONS, 'audio', recursive);
  }

  async scanLocalVideoFiles(directories: string[], recursive: boolean = true): Promise<FileInfo[]> {
    return this.scanFiles(directories, this.VIDEO_EXTENSIONS, 'video', recursive);
  }

  private async scanFiles(
    directories: string[],
    extensions: string[],
    mediaType: 'audio' | 'video',
    recursive: boolean = true
  ): Promise<FileInfo[]> {
    const allFiles: FileInfo[] = [];

    for (const dir of directories) {
      try {
        const files = await this.scanDirectory(dir, extensions, mediaType, recursive);
        allFiles.push(...files);
      } catch (error) {
        HiLog.e(TAG, `Failed to scan directory: ${dir}, error: ${error}`);
      }
    }

    return allFiles;
  }

  private isDocsUri(path: string): boolean {
    return path.startsWith('file://');
  }

  private listDirectoryEntries(dirPath: string): string[] {
    if (this.isDocsUri(dirPath)) {
      return fs.listFileSync(dirPath, { recursion: false });
    }
    return fs.listFileSync(dirPath);
  }

  private async scanDirectory(
    dirPath: string,
    extensions: string[],
    mediaType: 'audio' | 'video',
    recursive: boolean
  ): Promise<FileInfo[]> {
    const files: FileInfo[] = [];

    try {
      const list = this.listDirectoryEntries(dirPath);

      for (const fileName of list) {
        const fullPath = `${dirPath}/${fileName}`;
        const stat = fs.statSync(fullPath);

        if (stat.isDirectory() && recursive) {
          const subFiles = await this.scanDirectory(fullPath, extensions, mediaType, recursive);
          files.push(...subFiles);
        } else if (stat.isFile()) {
          const ext = this.getFileExtension(fileName).toLowerCase();
          if (extensions.includes(ext)) {
            const fileInfo = await this.createFileInfo(fullPath, fileName, mediaType);
            files.push(fileInfo);
          }
        }
      }
    } catch (error) {
      HiLog.e(TAG, `Failed to scan directory: ${dirPath}, error: ${error}`);
    }

    return files;
  }

  private async createFileInfo(
    filePath: string,
    fileName: string,
    mediaType: 'audio' | 'video'
  ): Promise<FileInfo> {
    const fileInfo: FileInfo = new FileInfo();
    const stat = fs.statSync(filePath);

    fileInfo.fileName = fileName;
    if (this.isDocsUri(filePath)) {
      fileInfo.uri = filePath;
      fileInfo.path = FileUtil.getPathFromUri(filePath);
    } else {
      fileInfo.path = filePath;
      fileInfo.uri = `file://${filePath}`;
    }
    fileInfo.mtime = stat.mtime;
    fileInfo.ctime = stat.ctime;
    fileInfo.size = stat.size;
    fileInfo.mimeType = mediaType === 'audio' ? 'audio/*' : 'video/*';
    fileInfo.thumbGenerated = false;

    await this.extractMetadata(fileInfo, mediaType);

    return fileInfo;
  }

  private async extractMetadata(fileInfo: FileInfo, mediaType: 'audio' | 'video'): Promise<void> {
    try {
      const avMetadataExtractor = await media.createAVMetadataExtractor();
      avMetadataExtractor.setUrlSource(fileInfo.uri);

      const metadata = await avMetadataExtractor.fetchMetadata();

      if (metadata) {
        if (mediaType === 'audio') {
          await this.extractAudioMetadata(fileInfo, metadata);
        } else {
          MediaMetadataResolver.applyAvMetadataToFileInfo(fileInfo, metadata);
        }
      }
    } catch (error) {
      HiLog.e(TAG, `Failed to extract metadata: ${fileInfo.uri}, error: ${error}`);
    }
  }

  private async extractAudioMetadata(fileInfo: FileInfo, metadata: media.AVMetadata): Promise<void> {
    const title = metadata.title?.toString();
    if (title) {
      fileInfo.fileName = title;
    }

    const artist = metadata.artist?.toString();
    if (artist) {
      fileInfo.appSourceName = artist;
    }

    MediaMetadataResolver.applyAvMetadataToFileInfo(fileInfo, metadata);
  }

  private getFileExtension(fileName: string): string {
    const lastDot = fileName.lastIndexOf('.');
    if (lastDot === -1) {
      return '';
    }
    return fileName.substring(lastDot);
  }

  isAudioFile(fileName: string): boolean {
    const ext = this.getFileExtension(fileName).toLowerCase();
    return this.AUDIO_EXTENSIONS.includes(ext);
  }

  isVideoFile(fileName: string): boolean {
    const ext = this.getFileExtension(fileName).toLowerCase();
    return this.VIDEO_EXTENSIONS.includes(ext);
  }
}
