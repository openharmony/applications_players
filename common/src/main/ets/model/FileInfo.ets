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

import { FileStatus } from '../constants/preview/PreviewConstants';
import BaseFileInfo from './BaseFileInfo';
import fileuri from '@ohos.file.fileuri';
import { FileInfo as FileOperateFileInfo } from '../utils/FileOperateInfo';

@Observed
export default class FileInfo extends BaseFileInfo {
  @Track public fileSize: number;
  @Track public updateTime: number;
  @Track public createTime: number;
  @Track public fileItems: number;
  @Track public fileStatus: FileStatus;
  @Track public location: number;
  @Track public filePath: string;

  @Track public thumbUri: string = '';
  @Track public coverUri: string = '';
  @Track public thumbGenerated: boolean = false;
  @Track public duration: number = 0;
  @Track public timesStampApp: number = 0;
  @Track public thumbnailModifiledMs: number = 0;
  @Track public picWidth: number = 0;
  @Track public picHeight: number = 0;
  @Track public mediaPath: string = '';

  constructor(fileName: string, uri: string, mimeType: string, fileSize?: number, updateTime?: number,
    fileItems?: number, fileStatus?: FileStatus, location?: number, filePath?: string, createTime?: number) {
    super(fileName, uri, mimeType);
    this.fileSize = fileSize ?? 0;
    this.updateTime = updateTime ?? 0;
    this.createTime = createTime ?? 0;
    this.fileItems = fileItems ?? 0;
    this.fileStatus = fileStatus ?? FileStatus.UN_EXIST;
    this.location = location ?? 0;
    this.filePath = filePath ?? new fileuri.FileUri(uri).path;
  }

  public setDirectoryInfo(fileSize?: number) {
    this.fileSize = fileSize ?? 0;
  }

  public static getDefaultFileInfo(baseFileInfo: BaseFileInfo) {
    return new FileInfo(baseFileInfo.fileName, baseFileInfo.uri, baseFileInfo.mimeType);
  }

  public static fromFileOperateFileInfo(fileOperateInfo: FileOperateFileInfo): FileInfo {
    const info = new FileInfo(
      fileOperateInfo.fileName,
      fileOperateInfo.uri,
      fileOperateInfo.mimeType,
      fileOperateInfo.size,
      fileOperateInfo.mtime,
      fileOperateInfo.subFileCount,
      FileStatus.IS_FILE,
      fileOperateInfo.locationType,
      fileOperateInfo.path ?? '',
      fileOperateInfo.ctime
    );

    info.thumbUri = fileOperateInfo.thumbUri ?? '';
    info.coverUri = fileOperateInfo.coverUri ?? '';
    info.thumbGenerated = fileOperateInfo.thumbGenerated ?? false;
    info.duration = fileOperateInfo.duration ?? 0;
    info.timesStampApp = fileOperateInfo.timesStampApp ?? 0;
    info.thumbnailModifiledMs = fileOperateInfo.thumbnailModifiledMs ?? 0;
    info.picWidth = fileOperateInfo.picWidth ?? 0;
    info.picHeight = fileOperateInfo.picHeight ?? 0;
    info.mediaPath = fileOperateInfo.path ?? '';

    return info;
  }

  public updateThumbnailData(fileOperateInfo: FileOperateFileInfo): void {
    this.thumbUri = fileOperateInfo.thumbUri ?? '';
    this.coverUri = fileOperateInfo.coverUri ?? '';
    this.thumbGenerated = fileOperateInfo.thumbGenerated ?? false;
    this.duration = fileOperateInfo.duration ?? 0;
  }
}
