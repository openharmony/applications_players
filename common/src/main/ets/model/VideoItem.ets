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

import { FileInfo } from '../utils/FileOperateInfo';
import EntityFileInfo from '../model/FileInfo';

export interface VideoInfo {
  duration: number;
  width: number;
  height: number;
  thumbnailUrl: string;
  bitrate?: number;
  frameRate?: number;
  codec?: string;
}

export class VideoItem {
  id: string;
  uri: string;
  fileName: string;
  size: number;
  mtime: number;
  ctime: number;
  mimeType: string;
  isFolder: boolean;
  fileInfo: FileInfo;
  videoInfo: VideoInfo;
  isPlaying: boolean;

  constructor() {
    this.id = '';
    this.uri = '';
    this.fileName = '';
    this.size = 0;
    this.mtime = 0;
    this.ctime = 0;
    this.mimeType = '';
    this.isFolder = false;
    this.isPlaying = false;
    this.fileInfo = new FileInfo();
    this.videoInfo = {
      duration: 0,
      width: 0,
      height: 0,
      thumbnailUrl: ''
    };
  }

  static fromFileInfo(fileInfo: FileInfo): VideoItem {
    const videoItem = new VideoItem();
    videoItem.id = fileInfo.uri;
    videoItem.uri = fileInfo.uri;
    videoItem.fileName = fileInfo.fileName;
    videoItem.size = fileInfo.size;
    videoItem.mtime = fileInfo.mtime;
    videoItem.mimeType = fileInfo.mimeType;
    videoItem.isFolder = fileInfo.isFolder;
    videoItem.fileInfo = fileInfo;
    videoItem.videoInfo = {
      duration: fileInfo.duration || 0,
      width: 0,
      height: 0,
      thumbnailUrl: ''
    };
    return videoItem;
  }

  static fromEntityFileInfo(entityInfo: EntityFileInfo): VideoItem {
    const videoItem = new VideoItem();
    videoItem.id = entityInfo.uri;
    videoItem.uri = entityInfo.uri;
    videoItem.fileName = entityInfo.fileName;
    videoItem.size = entityInfo.fileSize;
    videoItem.mtime = entityInfo.updateTime;
    videoItem.mimeType = entityInfo.mimeType;
    videoItem.isFolder = false;
    videoItem.fileInfo = new FileInfo();
    videoItem.fileInfo.uri = entityInfo.uri;
    videoItem.fileInfo.fileName = entityInfo.fileName;
    videoItem.fileInfo.size = entityInfo.fileSize;
    videoItem.fileInfo.mtime = entityInfo.updateTime;
    videoItem.fileInfo.mimeType = entityInfo.mimeType;
    videoItem.fileInfo.duration = entityInfo.duration;
    videoItem.fileInfo.thumbUri = entityInfo.thumbUri;
    videoItem.videoInfo = {
      duration: entityInfo.duration || 0,
      width: entityInfo.picWidth || 0,
      height: entityInfo.picHeight || 0,
      thumbnailUrl: entityInfo.thumbUri || ''
    };
    return videoItem;
  }

  static createDefault(title: string, uri: string): VideoItem {
    const videoItem = new VideoItem();
    videoItem.id = uri;
    videoItem.uri = uri;
    videoItem.fileName = title;
    videoItem.size = 0;
    videoItem.mtime = Date.now();
    videoItem.ctime = Date.now();
    videoItem.mimeType = 'video/mp4';
    videoItem.isFolder = false;
    let fileInfo = FileInfo.fromFileUri(uri);
    videoItem.fileInfo = fileInfo;
    videoItem.videoInfo = {
      duration: 0,
      width: 0,
      height: 0,
      thumbnailUrl: ''
    };
    return videoItem;
  }

  get title(): string {
    return this.fileName;
  }

  set title(value: string) {
    this.fileName = value;
  }

  get duration(): number {
    return this.videoInfo.duration;
  }

  set duration(value: number) {
    this.videoInfo.duration = value;
  }

  get width(): number {
    return this.videoInfo.width;
  }

  set width(value: number) {
    this.videoInfo.width = value;
  }

  get height(): number {
    return this.videoInfo.height;
  }

  set height(value: number) {
    this.videoInfo.height = value;
  }

  get thumbnailUrl(): string {
    return this.videoInfo.thumbnailUrl;
  }

  set thumbnailUrl(value: string) {
    this.videoInfo.thumbnailUrl = value;
  }

  get filePath(): string {
    return this.uri;
  }
}
