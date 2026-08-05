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
import { ObjectUtil } from '../utils/ObjectUtil';
import { HiLog } from '../utils/HiLog';
import { Constant, FileSourceUri, LocationType } from '../constants/storage/Constant';
import { ArrayUtil } from '../utils/ArrayUtil';
import fs, { ListFileOptions, ReadOptions, WriteOptions } from '@ohos.file.fs';
import FileUri from '@ohos.file.fileuri';
import { fileUri } from '@kit.CoreFileKit';
import { StringUtil } from '../utils/StringUtil';
import { BusinessError } from '@kit.BasicServicesKit';
import { ERROR_CODE } from '../constants/system/ErrorCode';

enum CompressType {
  ZIP = '.zip',
  Z7 = '.7z',
  RAR = '.rar',
  TAR = '.tar',
  GZ = '.gz',
  GZIP = '.gzip',
}
const TAG = 'FileUtil';

/**
 * File Util
 */
export class FileUtil {
  /**
   * uri 格式开头
   */
  public static readonly URI_START = 'file://';
  public static readonly URI_GALLERY = 'file://media/PhotoAlbum';
  private static readonly FILE_SPLIT: string = '/';
  private static readonly VIDEO_EXTENSIONS: string[] =
    ['.mp4', '.mov', '.avi', '.mkv', '.flv', '.webm', '.ts', '.m4v', '.3gp', '.rm', '.rmvb'];
  private static readonly AUDIO_EXTENSIONS: string[] =
    ['.mp3', '.m4a', '.wav', '.flac', '.aac', '.ogg', '.wma', '.ape', '.opus'];
  private static readonly IMAGE_EXTENSIONS: string[] =
    ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.heic', '.heif'];
  private static readonly MIME_TYPES: Record<string, string> = {
    '.mp4': 'video/mp4',
    '.mov': 'video/quicktime',
    '.avi': 'video/x-msvideo',
    '.mkv': 'video/x-matroska',
    '.flv': 'video/x-flv',
    '.webm': 'video/webm',
    '.ts': 'video/mp2t',
    '.m4v': 'video/mp4',
    '.3gp': 'video/3gpp',
    '.rm': 'video/x-pn-realvideo',
    '.rmvb': 'video/x-pn-realvideo',
    '.mp3': 'audio/mpeg',
    '.m4a': 'audio/mp4',
    '.wav': 'audio/wav',
    '.flac': 'audio/flac',
    '.aac': 'audio/aac',
    '.ogg': 'audio/ogg',
    '.wma': 'audio/x-ms-wma',
    '.ape': 'audio/x-ape',
    '.opus': 'audio/opus',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.png': 'image/png',
    '.gif': 'image/gif',
    '.bmp': 'image/bmp',
    '.webp': 'image/webp',
    '.heic': 'image/heic',
    '.heif': 'image/heif'
  };

  /**
   * FAF 默认根路径
   */
  public static readonly URI_INTERNAL = 'file://docs/storage/Users/currentUser';

  /**
   * 名称超长连接字符
   */
  public static CONNECT_NAME_STR: String = '...';
  /**
   * 展示最长长度
   */
  public static readonly MAX_NAME_LENGTH: number = 12;
  /**
   * 保留长度前后各5个
   */
  public static readonly KEEP_NAME_LENGTH: number = 5;


  public static getFileSuffix(fileName: string): string {
    const suffixIndex: number = fileName.lastIndexOf('.');
    if (suffixIndex >= 0) {
      return fileName.substring(suffixIndex);
    }
    return '';
  }

  public static getFilePrefix(fileName: string): string {
    const suffix: string = FileUtil.getFileSuffix(fileName);
    return fileName.substring(0, fileName.length - suffix.length);
  }

  public static async getFileInfo(uri: string): Promise<FileInfo | null> {
    try {
      const path: string = FileUtil.getPathFromUri(uri);
      const stat: fs.Stat = await fs.stat(path);
      const fileName: string = FileUtil.getFileNameFromUri(uri);
      const fileInfo: FileInfo = new FileInfo();
      
      fileInfo.uri = uri;
      fileInfo.fileName = fileName;
      fileInfo.relativePath = path;
      fileInfo.size = stat.size;
      fileInfo.mtime = stat.mtime;
      fileInfo.ctime = stat.ctime;
      fileInfo.isFolder = stat.isDirectory();
      fileInfo.mimeType = FileUtil.getMimeType(fileName);
      
      return fileInfo;
    } catch (error) {
      HiLog.e(TAG, `Failed to get file info: ${uri} ${error}`);
      return null;
    }
  }



  public static async extractVideoThumbnail(uri: string, timeUs: number = 0): Promise<string | null> {
    return null;
  }

  public static getFileExtension(fileName: string): string {
    const lastDot: number = fileName.lastIndexOf('.');
    if (lastDot === -1) {
      return '';
    }
    return fileName.substring(lastDot).toLowerCase();
  }

  public static getMimeType(fileName: string): string {
    const ext: string = FileUtil.getFileExtension(fileName);
    return FileUtil.MIME_TYPES[ext] || 'application/octet-stream';
  }

  public static isVideoFile(fileName: string): boolean {
    const ext: string = FileUtil.getFileExtension(fileName);
    return FileUtil.VIDEO_EXTENSIONS.includes(ext);
  }

  public static isAudioFile(fileName: string): boolean {
    const ext: string = FileUtil.getFileExtension(fileName);
    return FileUtil.AUDIO_EXTENSIONS.includes(ext);
  }

  public static isImageFile(fileName: string): boolean {
    const ext: string = FileUtil.getFileExtension(fileName);
    return FileUtil.IMAGE_EXTENSIONS.includes(ext);
  }

  public static isMediaFile(fileName: string): boolean {
    return FileUtil.isVideoFile(fileName) ||
    FileUtil.isAudioFile(fileName) ||
    FileUtil.isImageFile(fileName);
  }

  public static async fileExists(uri: string): Promise<boolean> {
    try {
      const path: string = FileUtil.getPathFromUri(uri);
      return await fs.access(path);
    } catch (error) {
      return false;
    }
  }

  public static async getFileSize(uri: string): Promise<number> {
    try {
      const path: string = FileUtil.getPathFromUri(uri);
      const stat: fs.Stat = await fs.stat(path);
      return stat.size;
    } catch (error) {
      HiLog.e(TAG, `Failed to get file size: ${uri} ${error}`);
      return 0;
    }
  }

  public static formatFileSize(bytes: number): string {
    if (bytes < 1024) {
      return `${bytes} B`;
    } else if (bytes < 1024 * 1024) {
      return `${(bytes / 1024).toFixed(2)} KB`;
    } else if (bytes < 1024 * 1024 * 1024) {
      return `${(bytes / (1024 * 1024)).toFixed(2)} MB`;
    } else {
      return `${(bytes / (1024 * 1024 * 1024)).toFixed(2)} GB`;
    }
  }

  public static formatDuration(duration: number): string {
    const hours: number = Math.floor(duration / 3600000);
    const minutes: number = Math.floor((duration % 3600000) / 60000);
    const seconds: number = Math.floor((duration % 60000) / 1000);

    if (hours > 0) {
      return `${hours}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
    } else {
      return `${minutes}:${seconds.toString().padStart(2, '0')}`;
    }
  }

  public static formatTimestamp(timestamp: number): string {
    const date: Date = new Date(timestamp);
    const year: number = date.getFullYear();
    const month: string = (date.getMonth() + 1).toString().padStart(2, '0');
    const day: string = date.getDate().toString().padStart(2, '0');
    const hours: string = date.getHours().toString().padStart(2, '0');
    const minutes: string = date.getMinutes().toString().padStart(2, '0');
    return `${year}-${month}-${day} ${hours}:${minutes}`;
  }

  /**
   * @param uri : file uri
   * @return fileType
   */
  public static getFileTypeFromUri(uri?: string): string {
    if (!uri) {
      HiLog.w(TAG, 'getFileTypeFromUri input string is empty');
      return '';
    }
    let index = uri.lastIndexOf('.');
    if ((!index) || (index <= 0)) {
      return '';
    }
    return uri.slice(index).toLowerCase();
  }

  public static getFileParentPathFromUri(uri?: string): string {
    if (!uri) {
      HiLog.w(TAG, 'getFileParentPathFromUri input string is empty');
      return '';
    }
    let index = uri.lastIndexOf('/');
    if ((!index) || (index <= 0)) {
      return '';
    }
    return uri.slice(0, index);
  }

  /**
   * 获取文件名的前缀、后缀, 如：xx/abc.txt的前缀为abc, 后缀为txt
   * @param uri
   */
  public static getPreFixAndSuffixByUri(uri: string): string[] {
    let result: string[] = ['', ''];
    if (StringUtil.isEmpty(uri)) {
      HiLog.w(TAG, 'getPrefixAndSuffix, params are err');
      return result;
    }
    let tempName: string = uri;
    let index = uri.lastIndexOf('/');
    if (index !== -1) {
      tempName = uri.substring(index + 1);
    }

    index = tempName.lastIndexOf('.');
    if (index === -1) {
      HiLog.w(TAG, 'getPrefixAndSuffix, fileName has no suffix');
      result[0] = tempName;
      return result;
    }
    result[0] = tempName.substring(0, index);
    result[1] = tempName.substring(index + 1);
    HiLog.i(TAG, `getPrefixAndSuffix, suffix ${result[1]}`, 'prefix = ' + result[0]);
    return result;

  }

  /**
   * 获取文件名的前缀、后缀, 如：abc.txt的前缀为abc, 后缀为.txt
   * @param fileName 文件名
   */
  public static getPrefixAndSuffix(fileName: string): string[] {
    let result: string[] = ['', ''];
    if (StringUtil.isEmpty(fileName)) {
      HiLog.w(TAG, 'getPrefixAndSuffix, params are err');
      return result;
    }
    let index = fileName.lastIndexOf('.');
    if (index === -1) {
      HiLog.w(TAG, 'getPrefixAndSuffix, fileName has no suffix');
      result[0] = fileName;
      return result;
    }
    result[0] = fileName.substring(0, index);
    result[1] = fileName.substring(index);
    HiLog.i(TAG, `getPrefixAndSuffix, suffix ${result[1]}`, 'prefix = ' + result[0]);
    return result;
  }

  /**
   * 将uri编码，支持对特殊字符的编码，例如分隔符:"/"
   *
   * @param uri  需要编码的uri
   * @returns 返回编码之后的结果
   */
  public static encodeURIForFileManager(uri: string): string {
    if (StringUtil.isEmpty(uri)) {
      HiLog.w(TAG, 'encodeURIForFileManager input string is empty');
      return uri;
    }
    try {
      uri = encodeURIComponent(uri);
    } catch (err) {
      HiLog.e(TAG, 'encode error : ' + JSON.stringify(err));
      uri = '';
    }
    return uri;
  }

  /**
   * 将uri解码，支持对特殊字符的解码
   *
   * @param uri  需要解码的uri
   * @returns 返回解码之后的结果
   */
  public static decodeURIForFileManager(uri: string): string {
    if (StringUtil.isEmpty(uri)) {
      HiLog.w(TAG, 'decodeURIForFileManager input string is empty');
      return uri;
    }
    try {
      uri = decodeURIComponent(uri);
    } catch (err) {
      HiLog.e(TAG, 'decode error : ' + JSON.stringify(err));
      uri = '';
    }
    return uri;
  }

  public static getParentRelativePath(relativePath: string): string {
    let curPath = relativePath;
    if (StringUtil.isEmpty(relativePath)) {
      HiLog.w(TAG, 'getParentRelativePath input string is empty');
      return '';
    }

    let index: number = curPath.lastIndexOf('/');
    // 去掉最后一个'/'
    if (index === curPath.length - 1) {
      curPath = curPath.substr(0, index);
    }
    index = curPath.lastIndexOf('/');
    if (index <= 0) {
      return '';
    }
    return curPath.substr(0, index);
  }

  /**
   * 是否是uri路径
   * @param uri 路径
   * @returns 结果
   */
  public static isUriPath(uri: string): boolean {
    if (StringUtil.isEmpty(uri)) {
      HiLog.w(TAG, 'isUriPath input string is empty');
      return false;
    }
    // 过滤掉^file:\/\/\/+的非法uri
    const isLegalUri: boolean = uri.startsWith(FileUtil.URI_START) &&
      !uri.substring(FileUtil.URI_START.length).startsWith('/');
    if (!isLegalUri) {
      HiLog.w(TAG, 'isUriPath: path illegal');
    }
    return isLegalUri;
  }

  public static containTrashFile(files: FileInfo[]): boolean {
    return files.some((item: FileInfo) => {
      return item.srcPath !== '';
    })
  }


  public static getPathWithFileSplit(path: string): string {
    let fileSplit: string = '/';
    if (path && (!path.endsWith(fileSplit))) {
      path = path + fileSplit;
    }
    return path;
  }

  public static getFileNameReName(fileName: string): string[] {
    if (StringUtil.isEmpty(fileName)) {
      return [];
    }
    let index = fileName.lastIndexOf(Constant.RENAME_CONNECT_CHARACTER);
    if (index === -1) {
      return [];
    }
    let str = fileName.substring(index + 1, fileName.length);
    let name = fileName.substring(0, index);
    return [name, str];
  }

  public static getCurrentDir(path: string, isFolder: boolean): string {
    if (isFolder) {
      return path;
    }
    if (path) {
      let index: number = path.lastIndexOf('/');
      let len: number = path.length;
      if ((len > 1) && (index > 1)) {
        return path.substring(0, index);
      }
    }
    return path;
  }

  public static openFile(fileUri: string, mode: number = fs.OpenMode.READ_ONLY): number {
    let fd = 0;
    try {
      const file = fs.openSync(fileUri, mode);
      fd = file.fd;
    } catch (error) {
      HiLog.e(TAG, 'openFile fail, error:' + JSON.stringify(error));
    }
    return fd;
  }

  /**
   * 将文件uri转换成FileUri对象
   */
  public static getFileUriObjectFromUri(uri: string): FileUri.FileUri | undefined {
    let fileUriObject: FileUri.FileUri | undefined;
    try {
      fileUriObject = new FileUri.FileUri(uri);
    } catch (error) {
      HiLog.e(TAG, 'getFileUriObjectFromUri fail, error:' + JSON.stringify(error));
    }
    return fileUriObject;
  }

  /**
   * 通过将文件uri转换成FileUri对象获取文件名
   * @param uri 文件uri
   * @returns 文件名
   */
  public static getFileNameFromUri(uri: string): string {
    let fileName = '';
    const fileUriObj = FileUtil.getFileUriObjectFromUri(uri);
    if (!!fileUriObj) {
      fileName = fileUriObj.name;
    }
    return fileName;
  }

  /**
   * 将媒体 URI 规范化为与扫描入库一致的格式（解码 %E4 等非 ASCII 路径段）。
   * 始终以 FileUri 解析出的 filesystem path 为基准重建 URI，保证编码/解码形式幂等。
   */
  public static normalizeMediaUri(uri: string): string {
    if (StringUtil.isEmpty(uri)) {
      return uri;
    }
    let trimmed = uri.trim();
    if (trimmed.endsWith('/')) {
      trimmed = trimmed.slice(0, -1);
    }
    const fileUriObj = FileUtil.getFileUriObjectFromUri(trimmed);
    if (!fileUriObj || StringUtil.isEmpty(fileUriObj.path)) {
      return FileUtil.decodeUriLastSegment(trimmed);
    }
    let canonical = FileUtil.getUriFromPath(fileUriObj.path);
    if (StringUtil.isEmpty(canonical)) {
      return FileUtil.decodeUriLastSegment(trimmed);
    }
    if (canonical.endsWith('/')) {
      canonical = canonical.slice(0, -1);
    }
    return FileUtil.decodeUriLastSegment(canonical);
  }

  private static decodeUriLastSegment(uri: string): string {
    if (uri.indexOf('%') < 0) {
      return uri;
    }
    const slashIndex = uri.lastIndexOf('/');
    if (slashIndex < 0) {
      return FileUtil.decodeURIComponent(uri);
    }
    const prefix = uri.substring(0, slashIndex + 1);
    const encodedSeg = uri.substring(slashIndex + 1);
    const decodedSeg = FileUtil.decodeURIComponent(encodedSeg);
    if (!StringUtil.isEmpty(decodedSeg) && decodedSeg !== encodedSeg) {
      return prefix + decodedSeg;
    }
    return uri;
  }

  /**
   * 统一 fileInfo 的 uri / fileName / path，避免 Picker 编码 URI 与扫描解码 URI 不一致。
   */
  public static applyCanonicalMediaIdentity(fileInfo: FileInfo): void {
    if (!fileInfo || StringUtil.isEmpty(fileInfo.uri)) {
      return;
    }
    const canonicalUri = FileUtil.normalizeMediaUri(fileInfo.uri);
    fileInfo.uri = canonicalUri;
    let fileName = FileUtil.getFileNameFromUri(canonicalUri);
    if (!StringUtil.isEmpty(fileName) && fileName.indexOf('%') >= 0) {
      fileName = FileUtil.decodeURIComponent(fileName);
    }
    if (!StringUtil.isEmpty(fileName)) {
      fileInfo.fileName = fileName;
    }
    const path = FileUtil.getPathFromUri(canonicalUri);
    if (!StringUtil.isEmpty(path)) {
      fileInfo.path = path;
    }
  }

  /**
   * 通过将文件uri转换成FileUri对象获取文件的沙箱路径
   * @param uri 文件uri
   * @returns 文件的沙箱路径
   */
  public static getPathFromUri(uri: string): string {
    let path = '';
    const fileUriObj = FileUtil.getFileUriObjectFromUri(uri);
    if (!!fileUriObj) {
      path = fileUriObj.path;
    }
    return path;
  }

  /**
   * 根据Uri通过fs获取文件夹下的子文件
   * @param uri 文件夹uri
   * @param recursion 是否递归获取子文件夹下的文件
   * @returns 子文件的文件名列表
   */
  public static getSubFileListByUri(uri: string, recursion: boolean = false): string[] {
    let fileNameList: string[] = [];
    const path: string = FileUtil.getPathFromUri(uri);
    try {
      fileNameList = fs.listFileSync(path, {
        recursion: recursion
      });
    } catch (error) {
      HiLog.e(TAG, `getSubFileListByUri fail, error: ${JSON.stringify(error)}`, uri);
    }
    return fileNameList;
  }

  /**
   * 根据Uri通过fs获取文件夹下的子文件信息
   * @param uri 文件夹uri
   * @param recursion 是否递归获取子文件夹下的文件
   * @returns 子文件的文件名列表
   */
  public static async getSubFileNameByUriWithFs(uri: string, recursion: boolean = false,
    showHiddenItem: boolean = false): Promise<string[]> {
    let fileNameList: string[] = [];
    let option: ListFileOptions =
      showHiddenItem ? { recursion: recursion } :
        { recursion: recursion, filter: { displayName: [Constant.HIDDEN_ITEM_FILTER] } };
    const path = FileUtil.getPathFromUri(uri);
    try {
      fileNameList = await fs.listFile(path, option);
    } catch (error) {
      HiLog.e(TAG, `getFileNameListByFs fail, path = ${path} code: ${error?.code}, error: ${error?.message}`);
    }
    return fileNameList;
  }

  /**
   * 根据path通过fs获取文件夹下的子文件信息
   * @param path 文件夹uri
   * @param recursion 是否递归获取子文件夹下的文件
   * @returns 子文件的文件名列表
   */
  public static async getSubFileNameByPathWithFs(path: string, recursion: boolean = false,
    showHiddenItem: boolean = false): Promise<string[]> {
    let fileNameList: string[] = [];
    let option: ListFileOptions =
      showHiddenItem ? { recursion: recursion } :
        { recursion: recursion, filter: { displayName: [Constant.HIDDEN_ITEM_FILTER] } };
    try {
      fileNameList = await fs.listFile(path, option);
    } catch (error) {
      HiLog.e(TAG, 'getFileNameListByFs fail, error:' + JSON.stringify(error));
    }
    return fileNameList;
  }

  /**
   * 通过fs获取文件信息
   * @param uri 文件沙箱路径或fd
   * @returns 文件stat对象
   */
  public static async getFileStatByFs(file: string | number): Promise<fs.Stat | undefined> {
    let stat: fs.Stat | undefined;
    try {
      stat = await fs.stat(file);
    } catch (error) {
      HiLog.e(TAG, 'getFileInfoByFs fail, error:' + JSON.stringify(error));
    }
    return stat;
  }

  /**
   * 通过fs获取文件的大小
   * @param uri 文件沙箱路径或fd
   * @returns 文件大小
   */
  public static async getFileSizeByFs(file: string | number): Promise<number> {
    const fileStat = await FileUtil.getFileStatByFs(file);
    if (!fileStat) {
      return 0;
    }
    return fileStat.size;
  }

  /**
   * 通过fs获取文件夹下的子文件个数
   * @param uri 文件夹uri
   * @returns 子文件个数
   */
  public static async getFolderSubFileCount(uri: string, recursion: boolean = false,
    showHiddenItem: boolean = false): Promise<number> {
    let count = 0;
    try {
      const fileNameList = await FileUtil.getSubFileNameByUriWithFs(uri, recursion, showHiddenItem);
      if (!ArrayUtil.isEmpty(fileNameList)) {
        count = fileNameList.length;
      }
      HiLog.d(TAG, `getSubFileCount uri =, count = ${count}`, `uri = ${uri}`);
    } catch (error) {
      HiLog.e(TAG, `getSubFileCount fail, error: ${JSON.stringify(error)}`, `fileUri:${uri}}`);
    }
    return count;
  }

  /**
   * 根据文件的沙箱路径获取文件uri
   * @param path 文件的沙箱路径
   * @returns 文件的uri
   */
  public static getUriFromPath(path: string): string {
    let uri = '';
    try {
      // 该接口如果以’/'结尾，返回的uri会以‘/'结尾
      uri = FileUri.getUriFromPath(path);
    } catch (error) {
      HiLog.e(TAG, 'getUriFromPath fail, error:' + JSON.stringify(error));
    }
    return uri;
  }


  /**
   * 通过fs获取文件夹下所有子文件的大小
   * @param uri 文件夹uri
   * @returns 文件夹大小
   */
  public static async getFolderSizeByFs(uri: string): Promise<number> {
    HiLog.i(TAG, 'getFolderSizeByFs start: ', uri);
    const fileNameList = await FileUtil.getSubFileNameByUriWithFs(uri, true, true);
    const path = FileUtil.getPathFromUri(uri);
    let tempFolderSize = 0;
    if (!ArrayUtil.isEmpty(fileNameList)) {
      HiLog.i(TAG, 'getFolderSizeByFs fileSize: ' + fileNameList.length);
      for (let fileName of fileNameList) {
        const fileStat = await FileUtil.getFileStatByFs(path + fileName);
        if (!fileStat) {
          continue;
        }
        tempFolderSize += fileStat.size;
      }
    }
    HiLog.i(TAG, 'getFolderSizeByFs end: ' + tempFolderSize);
    return tempFolderSize;
  }

  /**
   * 通过fs接口判断文件是否存在
   * @param uri FAF的uri
   * @returns 返回文件是否存在
   */
  public static isExistByUriWithFs(uri: string): boolean {
    try {
      return fs.accessSync(FileUtil.getPathFromUri(uri));
    } catch (e) {
      HiLog.e(TAG, 'isExistByFs error: ' + JSON.stringify(e));
    }
    return false;
  }

  /**
   * 根据URI 获取文件名  /a/b/c/d.zip
   * @param uri
   * @returns
   */
  public static getFileNameByUri(uri: string): string {
    let fileName: string = '';
    const result: string[] = uri.split('/');
    if (result.length > 0) {
      fileName = result[result.length - 1];
    }
    return fileName;
  }

  /**
   * 根据 uri/path 判断是不是压缩包格式的后缀，目前支持 .zip .7z .rar .tar .gz
   * @param uriOrPath
   * @returns boolean
   */
  public static isArchiveSuffix(uriOrPath: string): boolean {
    if (!uriOrPath) {
      HiLog.w(TAG, 'isArchiveSuffix, uriOrPath is empty string or undefined');
      return false;
    }
    const lowerUri = uriOrPath.toLocaleLowerCase();
    for (const suffix of Object.values(CompressType)) {
      if (lowerUri.endsWith(suffix)) {
        return true;
      }
    }
    return false;
  }

  /**
   * 通过uri/path判断是否是压缩文件
   * @param uriOrPath 文件uri/path
   * @returns 返回是否是压缩文件
   */
  public static isArchiveByUri(uriOrPath: string): boolean {
    if (!uriOrPath) {
      HiLog.w(TAG, 'isArchiveByUri, uriOrPath is empty string or undefined');
      return false;
    }
    if (!FileUtil.isArchiveSuffix(uriOrPath)) {
      return false;
    }
    let fileUriObj: FileUri.FileUri;
    try {
      fileUriObj = new FileUri.FileUri(uriOrPath);
    } catch (e) {
      HiLog.e(TAG, 'invalid file uriOrPath: ', uriOrPath);
      return false;
    }
    return !FsUtil.isFolder(fileUriObj.path);
  }

  /**
   * 通过fs接口判断文件是否存在
   * @param path 绝对路径
   * @returns 返回文件是否存在
   */
  public static async isExistByPathWithFs(path: string): Promise<boolean> {
    HiLog.i(TAG, 'isExistByPathWithFs path: ', path);

    if (StringUtil.isEmpty(path)) {
      return false;
    }
    let isExist = false;
    try {
      isExist = await fs.access(path);
    } catch (e) {
      HiLog.e(TAG, 'isExistByFs error: ' + JSON.stringify(e));
    }
    return isExist;
  }

  public static async syncFile(uri: string): Promise<void> {
    if (StringUtil.isEmpty(uri)) {
      return;
    }
    let newFile = undefined;
    try {
      let newFile = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      await fs.fsync(newFile.fd);
    } catch (error) {
      HiLog.i(TAG, 'createDir error ' + error.toString());
    } finally {
      if (newFile) {
        try {
          fs.closeSync(newFile);
        } catch (error) {
          HiLog.i(TAG, 'close error ' + error.toString());
        }
      }
    }
  }

  /**
   * 将uri解码，支持对特殊字符的解码
   *
   * @param uri  需要解码的uri
   * @returns 返回解码之后的结果
   */
  public static decodeURIComponent(uri: string): string {
    try {
      uri = decodeURIComponent(uri);
    } catch (err) {
      HiLog.e(TAG, JSON.stringify(err));
      uri = '';
    }
    return uri;
  }

  public static getIndex(fileName: string, fileNameList: string[] = []): number {
    return fileNameList.findIndex(value => value.toLowerCase() === fileName.toLowerCase());
  }

  /**
   * 通过uri获取列表中文件夹的最大层级
   *
   * @param uriList uri列表
   * @returns 如果文件列表包含文件夹，则返回文件夹的最大层级；否则返回0
   */
  static async getMaxFolderLevelByUri(uriList: string[]): Promise<number> {
    let folderLevel: number = 0;
    if (uriList.length === 0) {
      return folderLevel;
    }
    for (let i = 0; i < uriList.length; i++) {
      let uri = uriList[i];
      let subFolderList = FileUtil.getSubFoldersSync(uri);
      folderLevel = Math.max(folderLevel, await FileUtil.getMaxFolderLevelByUri(subFolderList) + 1);
    }
    return folderLevel;
  }

  /**
   * 根据Uri获取目标文件夹下的子文件夹uri-同步方法
   *
   * @param dirUri 目标文件夹uri
   * @returns 目标文件夹下的子文件夹列表
   */
  public static getSubFoldersSync(dirUri: string): string[] {
    let folders: string[] = [];
    // 获取文件夹路径
    const path = FileUtil.getPathFromUri(dirUri);
    // 遍历源文件夹下一层所有文件夹
    const listFileOption: ListFileOptions = {
      recursion: false,
      listNum: 0,
    };
    let filenames = FsUtil.listFileSync(path, listFileOption) as string[];
    let len = filenames.length;
    for (let i = 0; i < len; i++) {
      if (filenames[i].startsWith('.')) {
        continue;
      }
      let filePath = path + '/' + filenames[i];
      const result = FsUtil.statSync(filePath);
      if (result instanceof Error || !result.isDirectory()) {
        continue; // 不是文件夹，跳过
      }
      // 根据path获取uri
      let uriTemp = FileUtil.getUriFromPath(filePath);
      folders.push(uriTemp);
    }
    return folders;
  }

  /**
   * 创建文件夹
   * @param parentFolderUri 父目录uri
   * @param newFolderName 新文件夹名
   * @returns 新文件夹uri
   */
  public static async createFolderByFs(parentFolderUri: string, newFolderName: string): Promise<string> {
    try {
      const parentFolderPath = FileUtil.getPathFromUri(parentFolderUri);
      const newFolderPath = parentFolderPath + '/' + newFolderName;
      await fs.mkdir(newFolderPath);
      return FileUtil.getUriFromPath(newFolderPath);
    } catch (error) {
      HiLog.e(TAG, 'createFolderByFs fail, error:' + JSON.stringify(error));
      throw error as Error;
    }
  }

  /**
   *
   * @returns
   */
  public static getMaxLengthFileName(currentFileName: string, caretPosition: number, maxLength: number): string {
    let newFileName = '';
    if (StringUtil.isEmpty(currentFileName)) {
      return newFileName;
    }

    const startPartStr = currentFileName.substring(0, caretPosition);
    const endPartStr = currentFileName.substring(caretPosition);
    const endPartByteLength = StringUtil.strSizeUTF8(endPartStr);
    const startPartByteLength = maxLength - endPartByteLength;
    let newStartPartStr = '';
    let tempLength = 0;
    for (let char of startPartStr) {
      tempLength += StringUtil.getOneCharByteLength(char);
      if (tempLength > startPartByteLength) {
        return newStartPartStr + endPartStr;
      } else {
        newStartPartStr += char;
      }
    }
    return newStartPartStr + endPartStr;
  }


  /**
   * 创建文件流
   * @param filePath 文件路径
   * @returns fs.Stream 文件流
   */
  public static async createStream(filePath: string, mode: string): Promise<fs.Stream | undefined> {
    let stream: fs.Stream | undefined;
    if (StringUtil.isEmpty(filePath)) {
      return stream;
    }
    try {
      stream = await fs.createStream(filePath, mode);
    } catch (error) {
      HiLog.e(TAG, 'createStream fail, error:' + JSON.stringify(error));
    }
    return stream;
  }

  /**
   * 判断给定的URI是否以媒体库的URI头部开始
   * @param uri 需要判断的URI字符串
   * @return 如果URI以媒体库文件的URI头部开始，则返回true，否则返回false
   */
  public static isMediaUri(uri: string): boolean {
    return uri.startsWith(Constant.MediaLibrary_URI_HEAD);
  }

  /**
   * 检查给定的URI数组是否全部为媒体库文件URI
   * @param uris 需要检查的URI数组
   * @return 如果所有URI都是媒体URI，返回true，否则返回false
   */
  public static isAllMediaUri(uris: string[]): boolean {
   return uris.every((uri) => FileUtil.isMediaUri(uri))
  }

  /**
   * 检查给定的URI的文件名是否包含特殊路径
   * @param uri 需要检查的URI
   * @param filterPath 检查过滤的文件名数组
   * @return 如果文件名为特殊文件名，返回true，否则返回false
   */
  public static isIncludeSpecialFile(uri: string, filterPath: Set<string>) {
    if (!uri || uri.length === 0 || filterPath.size === 0) {
      return false;
    }
    const fileName = FileUtil.getFileNameByUri(uri).toLocaleLowerCase();
    if (filterPath.has(fileName)) {
      return true;
    }
    return false;
  }

  /**
   * 检查给定的uri or path是否为沙箱内路径
   * @param uriOrPath 需要检查的uri/path
   * @return 如果uri/path为沙箱内路径，返回true，否则返回false
   */
  public static isSandboxUri(uriOrPath: string): boolean {
    const filePath = uriOrPath.startsWith(FileUtil.URI_START) ? FileUtil.getPathFromUri(uriOrPath) : uriOrPath;
    const sandboxBasePath = FileUtil.getParentRelativePath(Constant.SANDBOX_FILES_ROOT);
    return filePath.startsWith(Constant.SANDBOX_APPDATA_PATH + '/') || (filePath === Constant.SANDBOX_APPDATA_PATH) ||
      filePath.startsWith(sandboxBasePath + '/') || (filePath === sandboxBasePath);
  }


  public static createFile(fileUri: string, fileName: string): string | BusinessError {
    HiLog.i(TAG, 'createFile enter ', fileUri);

    let newFileUri = fileUri;
    if (fileUri.charAt(fileUri.length - 1) === '/') {
      newFileUri = fileUri.substring(0, fileUri.length - 1);
    }

    let filePath = FileUtil.getPathFromUri(`${newFileUri}/${encodeURIComponent(fileName)}`);
    try {
      if (fs.accessSync(filePath)) {
        return { code: ERROR_CODE.FILE_ACCESS.FILE_EXISTS } as BusinessError;
      }
      let fileFd: fs.File = fs.openSync(filePath, fs.OpenMode.CREATE);
      fs.closeSync(fileFd);
      newFileUri += `/${encodeURIComponent(fileName)}`;
      return newFileUri;
    } catch (err) {
      HiLog.e(TAG, `createFile failed, err: ${JSON.stringify(err)}`);
      return err;
    }
  }

  /**
   * 判断fileInfo是否是图库文件夹
   * @param fileInfo
   * @returns
   */
  public static isGalleryFolder(fileInfo: FileInfo): boolean {
    return fileInfo.isGallery && fileInfo.isFolder;
  }
  
  /*
 * 获取文件父路径
 * @param uri 当前文件uri
 * @returns 返回父路径uri
 */
  public static getParentUri(uri: string): string {
    if (uri.endsWith('/')) {
      uri = uri.substring(0, uri.lastIndexOf('/'));
    }
    let lastIndex = uri.lastIndexOf('/');
    if (lastIndex === -1) {
      HiLog.i(TAG, 'No corresponding character found.');
      return '';
    }
    let parentUri = uri.substring(0, lastIndex);
    return parentUri;
  }

  /**
   * 获取uri下文件夹名称
   * @param uri 目录
   * @returns 该目录下一层文件夹名称
   */
  public static getSubFolderNamesSync(uri: string): string[] {
    try {
      const names: string[] = fs.listFileSync(uri, { recursion: false, listNum: 0 });
      let folderNames: string[] = [];
      for (let i = 0; i < names.length; i++) {
        const stat: fs.Stat | BusinessError = FsUtil.statSync(uri + '/' + names[i]);
        if (stat instanceof Error) {
          HiLog.e(TAG, `file stat error: `, `${uri + '/' + names[i]}`);
          continue;
        }
        if (stat.isDirectory()) {
          folderNames.push(names[i]);
        }
      }
      return folderNames;
    } catch (error) {
      HiLog.e(TAG, `getSubFolderNamesSync error: ${JSON.stringify(error)}`);
      return [];
    }
  }

  /**
   * 显示时，将超长文件名进行截断处理
   * @param fileName 文件名
   * @returns 阶段后的文件名
   */
  public static dealCopyCutNameLength(fileName: string): string {
    HiLog.i(TAG, 'dealCopyCutNameLength ' + fileName.length);
    if (ObjectUtil.isNullOrUndefined(fileName)) {
      return fileName;
    }
    let name = fileName;
    // 文件名超长处理：字符长度超过12个，截取前5个后5个，中间拼接...
    if (fileName.length > FileUtil.MAX_NAME_LENGTH) {
      name = fileName.substring(0, FileUtil.KEEP_NAME_LENGTH) + FileUtil.CONNECT_NAME_STR +
      fileName.substring(fileName.length - FileUtil.KEEP_NAME_LENGTH, fileName.length);
    }
    return name;
  }

  /**
   * 判断uri是否是下载与接收页面路径
   * @param fileUri
   * @returns
   */
  public static isDownloadAndReceiveAddress(fileUri: string, relativePath: string): boolean {
    if (StringUtil.isEmpty(fileUri)) {
      return false;
    }
    return (fileUri === FileSourceUri.BLUETOOTH || fileUri === FileSourceUri.DOWNLOAD_MANAGER ||
      fileUri === FileSourceUri.SHARE) && StringUtil.isEmpty(relativePath);
  }

  /**
   * 判断uri是否是本地的路径
   * @param uri
   * @returns
   */
  public static isLocalPath(uri: string): boolean {
    return uri.startsWith(FileUtil.URI_INTERNAL);
  }
  
  /**
   * 将uri转换成path
   *
   * @param uri
   * @returns path
   */
  public static getPath(uri: string) {
    if (uri.startsWith('file://docs')) {
      return FileUtil.decodeURIForFileManager(uri.replace('file://docs', ''));
    }
    return FileUtil.decodeURIForFileManager(uri);
  }
}

const TAG_FSUTIL: string = 'FsUtil';
const PASTE_BUFFER = 4194304; // 4M

export class FsUtil {
  public static async stat(file: string | number): Promise<fs.Stat | BusinessError> {
    try {
      return await fs.stat(file);
    } catch (error) {
      HiLog.e(TAG_FSUTIL, 'fs stat error = ' + error?.message);
      return error;
    }
  }

  public static statSyncByUri(uri: string): fs.Stat | BusinessError {
    try {
      const fileuri: fileUri.FileUri = new fileUri.FileUri(uri);
      return fs.statSync(fileuri.path);
    } catch (error) {
      HiLog.e(TAG_FSUTIL, 'fs statSync error = ' + error?.message);
      return error;
    }
  }

  public static statSync(file: string | number): fs.Stat | BusinessError {
    try {
      return fs.statSync(file);
    } catch (error) {
      HiLog.e(TAG_FSUTIL, 'fs statSync error = ' + error?.message);
      return error;
    }
  }

  public static async access(path: string): Promise<boolean | BusinessError> {
    try {
      return await fs.access(path);
    } catch (error) {
      HiLog.e(TAG_FSUTIL, 'fs access error = ' + error?.message);
      return error;
    }
  }

  public static accessSync(path: string): boolean | BusinessError {
    try {
      return fs.accessSync(path);
    } catch (error) {
      HiLog.e(TAG_FSUTIL, 'fs accessSync error = ' + error?.message);
      return error;
    }
  }

  public static checkAccessSync(path: string): boolean {
    let isExist: boolean = false;
    try {
      isExist = fs.accessSync(path);
    } catch (error) {
      HiLog.e(TAG_FSUTIL, 'fs accessSync error = ' + error?.message);
    }
    return isExist;
  }

  public static openSync(path: string, mode?: number): fs.File | BusinessError {
    try {
      return fs.openSync(path, mode);
    } catch (error) {
      HiLog.e(TAG_FSUTIL, 'fs openSync error = ' + error?.message);
      return error;
    }
  }

  public static async close(file: number | fs.File): Promise<void | BusinessError> {
    try {
      return await fs.close(file);
    } catch (error) {
      HiLog.e(TAG_FSUTIL, 'fs close error = ' + error?.message);
      return error;
    }
  }

  public static closeSync(file: number | fs.File): void | BusinessError {
    try {
      return fs.closeSync(file);
    } catch (error) {
      HiLog.e(TAG_FSUTIL, 'fs closeSync error = ' + error?.message);
      return error;
    }
  }

  public static async mkdir(path: string, recursion: boolean = false): Promise<void | BusinessError> {
    try {
      return await fs.mkdir(path, recursion);
    } catch (error) {
      HiLog.e(TAG_FSUTIL, 'fs mkdir error = ' + error?.message);
      return error;
    }
  }

  public static mkdirSync(path: string, recursion: boolean = false): void | BusinessError {
    try {
      return fs.mkdirSync(path, recursion);
    } catch (error) {
      HiLog.e(TAG_FSUTIL, 'fs mkdirSync error = ' + error?.message);
      return error;
    }
  }

  public static async rmdir(path: string): Promise<void | BusinessError> {
    try {
      return await fs.rmdir(path);
    } catch (error) {
      HiLog.e(TAG_FSUTIL, 'fs rmdir error = ' + error?.message);
      return error;
    }
  }

  public static rmdirSync(path: string): void | BusinessError {
    try {
      return fs.rmdirSync(path);
    } catch (error) {
      HiLog.e(TAG_FSUTIL, 'fs rmdirSync error = ' + error?.message);
      return error;
    }
  }

  public static async moveFile(src: string, dest: string, mode?: number): Promise<void | BusinessError> {
    try {
      return await fs.moveFile(src, dest, mode);
    } catch (error) {
      HiLog.e(TAG_FSUTIL, 'fs moveFile error = ' + error?.message);
      return error;
    }
  }

  public static async moveDir(src: string, dest: string, mode?: number): Promise<void | BusinessError> {
    try {
      return await fs.moveDir(src, dest, mode);
    } catch (error) {
      HiLog.e(TAG_FSUTIL, 'fs moveDir error = ' + error?.message);
      return error;
    }
  }

  public static moveFileSync(src: string, dest: string, mode?: number): void | BusinessError {
    try {
      return fs.moveFileSync(src, dest, mode);
    } catch (error) {
      HiLog.e(TAG_FSUTIL, 'fs moveFileSync error = ' + error?.message);
      return error;
    }
  }

  public static moveDirSync(src: string, dest: string, mode?: number): void | BusinessError {
    try {
      return fs.moveDirSync(src, dest, mode);
    } catch (error) {
      HiLog.e(TAG_FSUTIL, 'fs moveDirSync error = ' + error?.message);
      return error;
    }
  }

  public static async rename(oldPath: string, newPath: string): Promise<void | BusinessError> {
    try {
      return await fs.rename(oldPath, newPath);
    } catch (error) {
      HiLog.e(TAG_FSUTIL, 'fs rename error = ' + error?.message);
      return error;
    }
  }

  public static renameSync(oldPath: string, newPath: string): void | BusinessError {
    try {
      return fs.renameSync(oldPath, newPath);
    } catch (error) {
      HiLog.i(TAG_FSUTIL, 'fs renameSync error = ' + error?.message);
      return error;
    }
  }

  public static async unlink(path: string): Promise<void | BusinessError> {
    try {
      return await fs.unlink(path);
    } catch (error) {
      HiLog.e(TAG_FSUTIL, 'fs unlink error = ' + error?.message);
      return error;
    }
  }

  public static unlinkSync(path: string): void | BusinessError {
    try {
      return fs.unlinkSync(path);
    } catch (error) {
      HiLog.e(TAG_FSUTIL, 'fs unlinkSync error = ' + error?.message);
      return error;
    }
  }

  public static async write(fd: number, buffer: ArrayBuffer | string,
    options?: WriteOptions): Promise<number | BusinessError> {
    try {
      return await fs.write(fd, buffer, options);
    } catch (error) {
      HiLog.e(TAG_FSUTIL, 'fs write error = ' + error?.message);
      return error;
    }
  }

  public static writeSync(fd: number, buffer: ArrayBuffer | string, options?: WriteOptions): number | BusinessError {
    try {
      return fs.writeSync(fd, buffer, options);
    } catch (error) {
      HiLog.e(TAG_FSUTIL, 'fs writeSync error = ' + error?.message);
      return error;
    }
  }

  public static async read(fd: number, buffer: ArrayBuffer, options?: ReadOptions): Promise<number | BusinessError> {
    try {
      return await fs.read(fd, buffer, options);
    } catch (error) {
      HiLog.e(TAG_FSUTIL, 'fs read error = ' + error?.message);
      return error;
    }
  }

  public static readSync(fd: number, buffer: ArrayBuffer, options?: ReadOptions): number | BusinessError {
    try {
      return fs.readSync(fd, buffer, options);
    } catch (error) {
      HiLog.e(TAG_FSUTIL, 'fs readSync error = ' + error?.message);
      return error;
    }
  }

  public static readTextSync(path: string): string | BusinessError {
    try {
      return fs.readTextSync(path);
    } catch (error) {
      HiLog.e(TAG_FSUTIL, `fs readTextSync error =  ${error?.message}`);
      return error;
    }
  }

  public static listFileSync(path: string, options?: ListFileOptions): string[] | BusinessError {
    try {
      return fs.listFileSync(path, options);
    } catch (error) {
      HiLog.e(TAG_FSUTIL, 'fs listFileSync error = ' + error?.message);
      return error;
    }
  }

  public static async fsync(fd: number): Promise<void | BusinessError> {
    try {
      return await fs.fsync(fd);
    } catch (error) {
      HiLog.e(TAG_FSUTIL, 'fs fsync error = ' + error?.message);
      return error;
    }
  }

  public static fsyncSync(fd: number): void | BusinessError {
    try {
      return fs.fsyncSync(fd);
    } catch (error) {
      HiLog.e(TAG_FSUTIL, 'fs fsync error = ' + error?.message);
      return error;
    }
  }

  /**
   * 获取locationType
   *
   * @param filePath 文件路径
   * @returns locationType 文件位置 LOCAL/CLOUD
   */
  public static getLocationType(filePath: string): number {
    try {
      return fs.statSync(filePath).location;
    } catch (error) {
      HiLog.e(TAG_FSUTIL, 'getLocationType err: ' + error?.message);
    }
    return LocationType.LOCAL;
  }

  /**
   * 强制删除文件
   * @param uri 删除文件的uri
   */
  public static forceDelete(uri: string): number | BusinessError {
    try {
      const fileuri: fileUri.FileUri = new fileUri.FileUri(uri);
      if (fs.statSync(fileuri.path).isDirectory()) {
        fs.rmdirSync(fileuri.path);
      } else {
        fs.unlinkSync(fileuri.path);
      }
      return 0;
    } catch (error) {
      HiLog.e(TAG_FSUTIL, 'force delete file error: ' + error?.message);
      return error;
    }
  }

  /**
   * 文件夹判空
   * @param path 文件夹的uri
   */
  public static isFolderEmpty(path: string): boolean {
    try {
      const fileList = fs.listFileSync(path, { listNum: 1 });
      return fileList.length === 0;
    } catch (error) {
      HiLog.e(TAG_FSUTIL, 'isFolderEmpty error: ' + error?.message);
      // 无法判断视为空文件夹
      return false;
    }
  }

  /**
   * 判断文件是否为文件夹（目前暂不支持应用沙箱目录）
   * @param path 文件
   * @returns
   */
  public static isFolder(path: string): boolean | BusinessError {
    try {
      const stat = fs.statSync(path);
      return stat?.isDirectory();
    } catch (error) {
      HiLog.e(TAG_FSUTIL, ' isFolder error: ' + error?.message, path);
      return error;
    }
  }

  /**
   * 判断文件是否为文件
   * @param path 文件路径
   * @returns 是否为普通文件 异常场景视为非文件
   */
  public static isFile(path: string): boolean {
    try {
      const stat = fs.statSync(path);
      return stat.isFile();
    } catch (error) {
      HiLog.e(TAG_FSUTIL, `isFile error: ${error?.code} ${error?.message}`);
      return false;
    }
  }

  /**
   * 判断文件是否存在
   * @param uri 文件uri
   * @returns 判断结果
   */
  public static isFileExist(uri: string): boolean {
    let isExist: boolean = false;
    try {
      HiLog.i(TAG_FSUTIL, 'open start');
      let fileFd: fs.File = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      fs.closeSync(fileFd);
      isExist = true;
    } catch (error) {
      HiLog.e(TAG_FSUTIL, 'openSync fail: ' + error?.message);
      if (error.code === ERROR_CODE.FILE_ACCESS.FILE_NOT_EXIST) {
        HiLog.e(TAG_FSUTIL, 'file is not exist');
      }
    }
    return isExist;
  }

  /**
   * 判断文件是否被删除（包括软删除和硬删除）
   * @param uri 文件uri
   * @returns 判断结果
   */
  public static isFileDeleted(uri: string): boolean {
    try {
      const fileuri: fileUri.FileUri = new fileUri.FileUri(uri);
      return !fs.accessSync(fileuri.path); // 此处报错说明被硬删除了
    } catch (error) {
      HiLog.e(TAG_FSUTIL, 'accessSync fail: ' + error?.message);
    }
    return true;
  }

  /**
   * 判断目录下是否存在同名文件
   * @param destUri：目录uri
   * @param fileName：待判断的文件名
   * @returns 判断结果
   */
  public static isExistDupName(destUri: string, fileName: string): boolean {
    let isExistDupName: boolean = false;
    try {
      const destFileInfo: fileUri.FileUri = new fileUri.FileUri(destUri);
      const newFilePath: string = destFileInfo.path + '/' + fileName;
      isExistDupName = fs.accessSync(newFilePath);
    } catch (err) {
      HiLog.w(TAG_FSUTIL, 'isExistDupName err: ' + err?.message);
    }
    return isExistDupName;
  }

  public static getInoByUri(uri: string): string {
    try {
      const fileuri: fileUri.FileUri = new fileUri.FileUri(uri);
      const stat = fs.statSync(fileuri.path);
      return stat.ino.toString();
    } catch (error) {
      HiLog.e(TAG_FSUTIL, `get ino failed, error message : ${error?.message}, error code : ${error?.code}`);
      return '';
    }
  }

  /**
   * 文件拷贝同步接口，适合十几兆的小文件拷贝
   * @param srcPath 源文件
   * @param destinationPath 目标文件
   * @param mode 拷贝模式
   * @returns true：拷贝成功，目标文件已经存在
   */
  public static copyFileSyncByPath(srcPath: string, destinationPath: string, mode?: number): boolean {
    try {
      fs.copyFileSync(srcPath, destinationPath, mode);
      return FsUtil.isExistSyncByPath(destinationPath);
    } catch (error) {
      HiLog.e(TAG_FSUTIL, 'copyFileSyncByPath err: ' + error?.message);
      return false;
    }
  }

  public static pasteFileByFd(srcFileUri: string, destAlbumUri: string): boolean {
    if ((!srcFileUri) || (!destAlbumUri)) {
      HiLog.w(TAG_FSUTIL, 'params are err');
      return false;
    }
    let srcFile: fs.File | undefined;
    let destFile: fs.File | undefined;
    try {
      srcFile = fs.openSync(srcFileUri, fs.OpenMode.READ_ONLY);
      destFile = fs.openSync(destAlbumUri, fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      let isDone = false;
      let buf = new ArrayBuffer(PASTE_BUFFER);
      while (!isDone) {
        let readLen = fs.readSync(srcFile.fd, buf);
        fs.writeSync(destFile.fd, buf, { length: readLen });
        isDone = readLen === 0;
      }
    } catch (err) {
      return false;
    } finally {
      if (srcFile) {
        FsUtil.closeSync(srcFile);
      }
      if (destFile) {
        FsUtil.closeSync(destFile);
      }
    }
    return true;
  }


  /**
   * 判断文件是否存在
   *
   * @param path 文件全目录
   * @returns true：文件存在
   */
  public static isExistSyncByPath(path: string): boolean {
    try {
      return fs.accessSync(path);
    } catch (error) {
      HiLog.e(TAG_FSUTIL, 'isExistSyncByPath error = ' + error?.message);
      return false;
    }
  }

  /**
   * 重命名异步接口
   * @param oldPath 即将要重命名的文件全路径
   * @param newPath 重命名之后的文件全路径
   * @returns true：命名成功
   */
  public static renameSyncByPath(oldPath: string, newPath: string): boolean {
    try {
      fs.renameSync(oldPath, newPath);
      return FsUtil.isExistSyncByPath(newPath);
    } catch (error) {
      HiLog.i(TAG_FSUTIL, 'fs renameSync error = ' + error?.message);
      return false;
    }
  }

  /**
   * 同步获取文件大小
   * @param path 文件全路径
   * @returns 文件夹大小
   */
  public static getFileSizeSyncByPath(path: string): number {
    try {
      return fs.statSync(path).size;
    } catch (error) {
      HiLog.e(TAG_FSUTIL, 'getFileInfoByFs fail, error:' + error?.message);
      return 0;
    }
  }

  public static async fileCopy(srcFileUri: string, destFileUri: string,
    copySignal: fs.TaskSignal, progressListener: fs.ProgressListener): Promise<boolean> {
    if (!srcFileUri || !destFileUri) {
      HiLog.w(TAG_FSUTIL, 'fileCopy, params are err');
      return false;
    }

    let copyOption: fs.CopyOptions = {
      'progressListener': progressListener,
      'copySignal': copySignal
    };
    try{
      await fs.copy(srcFileUri, destFileUri, copyOption);
    } catch (error) {
      HiLog.e(TAG_FSUTIL, `fileCopy error, code: ${error?.code} message: ${error?.message}`);
      return false;
    }

    return true;
  }

  /**
   * 设置文件拓展信息
   * @param path 文件沙箱路径
   * @param key 拓展信息名称
   * @param value 拓展信息值
   */
  public static setxattr(path: string, key: string, value: string): void {
    if (StringUtil.isEmpty(path)) {
      HiLog.w(TAG_FSUTIL, 'path to be marked is empty');
      return;
    }
    fs.setxattr(path, key, value).catch((err: BusinessError) => {
      HiLog.e(TAG_FSUTIL, 'Failed to set extended attribute with error message: ' +
      err.message + ', error code: ' + err.code);
    });
  }
}