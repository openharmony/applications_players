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


import { BasicDataSource } from './BasicDataSource';
import { FileSourceType, LocationType } from '../constants/storage/Constant';
import { FileInfo } from '../utils/FileOperateInfo';
import { ArrayUtil } from '../utils/ArrayUtil';
import { GroupFileInfo } from '../model/GroupFileInfo';
import { HiLog } from '../utils/HiLog';
import { StartModeOptions } from '../constants/system/StartModeOptions';
import { FileUtil } from '../utils/FileUtil';

const TAG = 'FileDataSource';

export class FileDataSource extends BasicDataSource {
  private dataArray: FileInfo[] = [];
  public dataCount: number = 0;
  public watchFlag : WatchFlag = new WatchFlag();
  public dataReceStatus: DataReceStatus = new DataReceStatus();

  public notifySourceDataChange() {
    this.dataArray = this.dataArray;
  }

  public totalCount(): number {
    return this.dataArray.length;
  }

  public getDataArray(): FileInfo[] {
    return this.dataArray;
  }

  public getFileList(): FileInfo[] {
    return this.dataArray.filter((item: FileInfo) => !item.isFolder);
  }

  public getCanChooseCount(): number {
    return this.dataArray.filter((item: FileInfo) => item.isMultiEnable).length;
  }

  public getFileViewList(): FileInfo[] {
    return this.dataArray.filter((item: FileInfo) => (!item.isFolder && item.isMultiEnable));
  }

  public setData(data: FileInfo[]): void {
    this.watchFlag.executeWatch = false;
    this.dataCount = data.length; // 数值相同时不会触发状态监听
    this.watchFlag.executeWatch = true;
    this.dataArray = data.slice(); // 使用新数组赋值会触发状态监听
    this.notifyDataReload();
  }

  public isExistFusionAlbum(): boolean {
    return this.dataArray.some((item: FileInfo) => item.isFusionAlbum === true);
  }

  public getFusionAlbumUri(): string {
    return this.dataArray.find((item: FileInfo) => item.isFusionAlbum === true)?.uri || '';
  }

  public getData(index: number): FileInfo {
    return this.dataArray[index];
  }

  // 来源页全选文件，针对分类后的文件进行过滤
  public selectAllFilterFile(uris: string[]): void {
    this.dataArray.forEach((item: FileInfo) => {
      if (item.isMultiEnable && uris.includes(item.uri)) {
        item.isChecked = true;
      }
    })
  }

  public selectAll(isSelected: boolean): void {
    this.dataArray.forEach((item: FileInfo) => {
      if (item.isMultiEnable) {
        item.isChecked = isSelected;
      }
    })
  }

  public getIndex(uri: string): number {
    return this.dataArray.findIndex((item: FileInfo) => item?.uri === uri);
  }

  public getIndexByDecodeUri(uri: string): number {
    return this.dataArray.findIndex((item: FileInfo) => FileUtil.decodeURIComponent(item?.uri) === uri);
  }

  public getSelectedFileList(): FileInfo[] {
    return this.dataArray.filter((item: FileInfo) => item.isChecked);
  }

  public deSelectedFileList(): FileInfo[] {
    return this.dataArray.map((item : FileInfo): FileInfo => {
      item.isChecked = false;
      return item;
    });
  }

  public replaceData(index: number, data: FileInfo): void {
    this.dataArray.splice(index, 1, data);
    this.notifyDataChange(index);
  }

  public replaceDataSilence(index: number, data: FileInfo): void {
    this.dataArray.splice(index, 1, data);
  }

  public addData(index: number, data: FileInfo): void {
    this.dataArray.splice(index, 0, data);
    this.dataCount = this.dataArray.length;
    this.notifyDataAdd(index);
  }

  public pushData(data: FileInfo): void {
    this.dataArray.push(data);
    this.dataCount = this.dataArray.length;
    this.notifyDataAdd(this.dataArray.length - 1);
  }

  public pushDataArray(dataArray: FileInfo[]): void {
    this.watchFlag.executeWatch = false;
    this.dataCount += dataArray.length; // 数值相同时不会触发状态监听
    this.watchFlag.executeWatch = true;
    this.dataArray = this.dataArray.concat(dataArray); // 使用新数组赋值会触发状态监听
    this.notifyDataAdd(this.dataArray.length - 1);
  }

  public appendData(dataArray: FileInfo[]): void {
    if (dataArray.length === 0) {
      return;
    }
    this.watchFlag.executeWatch = false;
    this.dataCount += dataArray.length;
    this.watchFlag.executeWatch = true;
    this.dataArray = this.dataArray.concat(dataArray);
    this.notifyDataAdd(this.dataArray.length - dataArray.length);
  }

  public deleteData(index: number): void {
    this.dataArray.splice(index, 1);
    this.dataCount = this.dataArray.length;
    this.notifyDataDelete(index);
  }

  public batchDeleteData(fileUriList: string[]): void {
    const deleteUriSet = new Set<string>(fileUriList);
    const remainFiles = this.dataArray.filter((file: FileInfo) => !deleteUriSet.has(file.uri));
    this.setData(remainFiles);
  }

  public batchHashDeleteData(fileUriList: string[]): void {
    const deleteUriSet = new Set<string>(fileUriList);
    let remainFiles = this.dataArray.filter((file: FileInfo) => !deleteUriSet.has(file.uri));
    const countMap = new Map<string, number>();
    remainFiles.forEach((item: FileInfo) => {
      const hash: string = item.fileSuffix;
      countMap.set(hash, (countMap.get(hash) || 0) + 1);
    });
    remainFiles = remainFiles.filter((item: FileInfo) => {
      const duplicateFilesCount = countMap.get(item.fileSuffix);
      return duplicateFilesCount ? duplicateFilesCount > 1 : false;
    })
    this.setData(remainFiles);
  }

  public getLastFileUri(): string {
    if (ArrayUtil.isEmpty(this.dataArray)) {
      return '';
    }
    return this.dataArray[this.dataArray.length - 1].uri;
  }

  public updateItemInfo(uri: string): void {
    const index = this.getIndex(uri);
    if (index === -1) {
      return;
    }
    this.notifyDataChange(index);
  }

  public updateCheckStatus(uri: string, isChecked: boolean): void {
    const index = this.getIndex(uri);
    if (index !== -1) {
      this.dataArray[index].isChecked = isChecked;
    }
  }

  public getAllFolderName(): string[] {
    const folderList = this.dataArray.filter((fileInfo: FileInfo) => fileInfo.isFolder)
    if (ArrayUtil.isEmpty(folderList)) {
      return [];
    }
    return folderList.map((folder: FileInfo) => folder.fileName)
  }

  public freshFileListSource(): void {
    this.setData(this.dataArray)
  }

  public setDataFromGroups(groupFiles: GroupFileInfo[]): void {
    this.watchFlag.executeWatch = false;
    this.dataArray.length = 0; // 清空数组
    groupFiles.forEach((group: GroupFileInfo) => {
      this.dataArray = this.dataArray.concat(group.getFileDataSource().getDataArray());
    });
    this.watchFlag.executeWatch = true;
    this.notifyDataAdd(this.dataArray.length - 1);
    HiLog.i(TAG, `setDataFromGroups length : ${this.dataArray.length}`);
  }

  public getFileInfoCheckStatus(uri: string): boolean {
    let checkStatus: boolean = false;
    const index = this.getIndex(uri);
    if (index !== -1) {
      checkStatus = this.dataArray[index].isChecked;
    }
    return checkStatus;
  }
}

/**
 * 用于避免重复触发@Watch
 */
class WatchFlag {
  public executeWatch: boolean = true;
}

/**
 * 数据接收状态
 */
class DataReceStatus {
  public status: DataStatus = DataStatus.INIT;
}

export enum DataStatus {
  INIT = 0,
  PUSH,
  END
}
