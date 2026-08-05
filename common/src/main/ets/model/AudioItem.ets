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

export interface AudioInfo {
  title: string;
  artist: string;
  album: string;
  duration: number;
  albumArtUrl: string;
  genre?: string;
  trackNumber?: number;
  year?: number;
}

export interface VideoInfo {
  duration: number;
  width: number;
  height: number;
  thumbnailUrl: string;
  bitrate?: number;
  frameRate?: number;
  codec?: string;
}

export class AudioItem {
  id: string;
  uri: string;
  fileName: string;
  size: number;
  mtime: number;
  ctime: number;
  mimeType: string;
  isFolder: boolean;
  isCollected: boolean;
  fileInfo: FileInfo;
  audioInfo: AudioInfo;

  constructor() {
    this.id = '';
    this.uri = '';
    this.fileName = '';
    this.size = 0;
    this.mtime = 0;
    this.ctime = 0;
    this.mimeType = '';
    this.isFolder = false;
    this.isCollected = false;
    this.fileInfo = new FileInfo();
    this.audioInfo = {
      title: '',
      artist: '未知艺术家',
      album: '未知专辑',
      duration: 0,
      albumArtUrl: ''
    };
  }

  static fromFileInfo(fileInfo: FileInfo): AudioItem {
    const audioItem = new AudioItem();
    audioItem.id = fileInfo.uri;
    audioItem.uri = fileInfo.uri;
    audioItem.fileName = fileInfo.fileName;
    audioItem.size = fileInfo.size;
    audioItem.mtime = fileInfo.mtime;
    audioItem.mimeType = fileInfo.mimeType;
    audioItem.isFolder = fileInfo.isFolder;
    audioItem.fileInfo = fileInfo;
    audioItem.audioInfo = {
      title: fileInfo.fileName,
      artist: '未知艺术家',
      album: '未知专辑',
      duration: fileInfo.duration || 0,
      albumArtUrl: ''
    };
    audioItem.isCollected = false;
    return audioItem;
  }

  static fromEntityFileInfo(entityInfo: EntityFileInfo): AudioItem {
    const audioItem = new AudioItem();
    audioItem.id = entityInfo.uri;
    audioItem.uri = entityInfo.uri;
    audioItem.fileName = entityInfo.fileName;
    audioItem.size = entityInfo.fileSize;
    audioItem.mtime = entityInfo.updateTime;
    audioItem.mimeType = entityInfo.mimeType;
    audioItem.isFolder = false;
    audioItem.fileInfo = new FileInfo();
    audioItem.fileInfo.uri = entityInfo.uri;
    audioItem.fileInfo.fileName = entityInfo.fileName;
    audioItem.fileInfo.size = entityInfo.fileSize;
    audioItem.fileInfo.mtime = entityInfo.updateTime;
    audioItem.fileInfo.mimeType = entityInfo.mimeType;
    audioItem.fileInfo.duration = entityInfo.duration;
    audioItem.fileInfo.thumbUri = entityInfo.thumbUri;
    audioItem.fileInfo.coverUri = entityInfo.coverUri;
    audioItem.audioInfo = {
      title: entityInfo.fileName,
      artist: '未知艺术家',
      album: '未知专辑',
      duration: entityInfo.duration || 0,
      albumArtUrl: entityInfo.coverUri || ''
    };
    audioItem.isCollected = false;
    return audioItem;
  }

  static createDefault(title: string, uri: string): AudioItem {
    const audioItem = new AudioItem();
    audioItem.id = uri;
    audioItem.uri = uri;
    audioItem.fileName = title;
    audioItem.title = title;
    audioItem.size = 0;
    audioItem.mtime = Date.now();
    audioItem.ctime = Date.now();
    audioItem.mimeType = 'audio/mpeg';
    audioItem.isFolder = false;
    audioItem.fileInfo = FileInfo.fromFileUri(uri);
    audioItem.audioInfo = {
      title: title,
      artist: '未知艺术家',
      album: '未知专辑',
      duration: 0,
      albumArtUrl: ''
    };
    audioItem.isCollected = false;
    return audioItem;
  }

  get title(): string {
    return this.audioInfo.title;
  }

  set title(value: string) {
    this.audioInfo.title = value;
  }

  get artist(): string {
    return this.audioInfo.artist;
  }

  set artist(value: string) {
    this.audioInfo.artist = value;
  }

  get album(): string {
    return this.audioInfo.album;
  }

  set album(value: string) {
    this.audioInfo.album = value;
  }

  get duration(): number {
    return this.audioInfo.duration;
  }

  set duration(value: number) {
    this.audioInfo.duration = value;
  }

  get albumArtUrl(): string {
    return this.audioInfo.albumArtUrl;
  }

  set albumArtUrl(value: string) {
    this.audioInfo.albumArtUrl = value;
  }
}
