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
import userFileManager from '@ohos.filemanagement.userFileManager';
import dataSharePredicates from '@ohos.data.dataSharePredicates';
import { AppContext } from '../context/AppContext';
import { FileUtil } from './FileUtil';
import { HiLog } from './HiLog';
import { SupportedMediaFormats } from '../constants/media/SupportedMediaFormats';

const TAG = 'MediaPlaybackFileOpener';

/** 只读打开的媒体文件句柄，供 AVPlayer fdSrc 使用 */
export interface MediaPlaybackOpenResult {
  fd: number;
  size: number;
  release: () => Promise<void>;
}

/**
 * 播放链路媒体文件打开：沙箱 / file://docs 走 fs.open；file://media 走 userFileManager，统一产出 fd 供 AVPlayer
 */
export class MediaPlaybackFileOpener {
  /**
   * 以只读方式打开音频/视频源并转为 fd（AVPlayer 仅支持 fd:// 或网络地址）
   *
   * @param uri 文件 URI（沙箱、file://docs 或 file://media）
   * @param fileName 显示文件名，用于媒体库资产匹配
   * @returns 打开结果，失败返回 null
   */
  public static async openReadOnly(uri: string, fileName: string): Promise<MediaPlaybackOpenResult | null> {
    HiLog.i(TAG, `openReadOnly start fileName=${fileName}`);
    // 媒体库 content URI 在各机型上 fs.open 行为不一致，统一走 userFileManager
    if (uri.startsWith('file://media/')) {
      return MediaPlaybackFileOpener.openMediaLibraryAsset(uri, fileName);
    }
    const fsOpened = MediaPlaybackFileOpener.tryFsOpen(uri);
    if (fsOpened) {
      return fsOpened;
    }
    if (uri.startsWith('file://docs/')) {
      return MediaPlaybackFileOpener.tryDocsUriOpen(uri, fileName);
    }
    const pathOpened = MediaPlaybackFileOpener.tryFsOpenByPath(uri, fileName);
    if (pathOpened) {
      return pathOpened;
    }
    HiLog.w(TAG, `openReadOnly failed fileName=${fileName}`);
    return null;
  }

  /**
   * 尝试 fs.open 只读打开
   *
   * @param uri 目标 URI
   * @returns 打开结果或 null
   */
  private static tryFsOpen(uri: string): MediaPlaybackOpenResult | null {
    try {
      const file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      const stat = fs.statSync(file.fd);
      const fd = file.fd;
      const result: MediaPlaybackOpenResult = {
        fd: fd,
        size: stat.size,
        release: async (): Promise<void> => {
          fs.closeSync(fd);
        }
      };
      HiLog.i(TAG, `tryFsOpen success fileName=${MediaPlaybackFileOpener.fileNameFromUri(uri)} size=${stat.size}`);
      return result;
    } catch (error) {
      HiLog.w(TAG, `tryFsOpen failed uri=${uri} fileName=${MediaPlaybackFileOpener.fileNameFromUri(uri)}`);
      return null;
    }
  }

  /**
   * 将 URI 转为沙箱 path 后再 fs.open（部分机型 file://docs 直开失败但 path 可开）
   *
   * @param uri 原始 URI
   * @param fileName 显示文件名
   * @returns 打开结果或 null
   */
  private static tryFsOpenByPath(uri: string, fileName: string): MediaPlaybackOpenResult | null {
    const path = FileUtil.getPathFromUri(uri);
    if (path.length === 0 || path === uri) {
      return null;
    }
    const opened = MediaPlaybackFileOpener.tryFsOpen(path);
    if (opened) {
      HiLog.i(TAG, `tryFsOpenByPath success fileName=${fileName}`);
    }
    return opened;
  }

  /**
   * 打开 file://docs 公共目录媒体：依次尝试原始 URI、规范化 URI、path 回退
   *
   * @param uri file://docs URI
   * @param fileName 显示文件名
   * @returns 打开结果或 null
   */
  private static tryDocsUriOpen(uri: string, fileName: string): MediaPlaybackOpenResult | null {
    const candidates: string[] = [uri];
    const normalized = FileUtil.normalizeMediaUri(uri);
    if (normalized.length > 0 && normalized !== uri) {
      candidates.push(normalized);
    }
    for (let i = 0; i < candidates.length; i++) {
      const opened = MediaPlaybackFileOpener.tryFsOpen(candidates[i]);
      if (opened) {
        HiLog.i(TAG, `tryDocsUriOpen hit fileName=${fileName} candidateIndex=${i}`);
        return opened;
      }
      const pathOpened = MediaPlaybackFileOpener.tryFsOpenByPath(candidates[i], fileName);
      if (pathOpened) {
        HiLog.i(TAG, `tryDocsUriOpen path hit fileName=${fileName} candidateIndex=${i}`);
        return pathOpened;
      }
    }
    HiLog.w(TAG, `tryDocsUriOpen failed fileName=${fileName}`);
    return null;
  }

  /**
   * 通过 userFileManager 打开媒体库资产（fs.open 对部分 m4a 等返回 13900001）
   *
   * @param uri 媒体库 content URI
   * @param fileName 显示文件名
   * @returns 打开结果或 null
   */
  private static async openMediaLibraryAsset(uri: string,
    fileName: string): Promise<MediaPlaybackOpenResult | null> {
    const context = AppContext.getInstance().getMainAbilityContext() ??
      AppContext.getInstance().getCommonContext();
    if (!context) {
      HiLog.e(TAG, `openMediaLibraryAsset no context uri=${uri}`);
      return null;
    }
    const userFileMgr = userFileManager.getUserFileMgr(context);
    const asset = await MediaPlaybackFileOpener.findMediaAsset(userFileMgr, uri, fileName);
    if (!asset) {
      HiLog.w(TAG, `openMediaLibraryAsset asset not found uri=${uri} fileName=${fileName}`);
      return null;
    }
    try {
      const fd = await asset.open('r');
      const stat = await fs.stat(fd);
      const result: MediaPlaybackOpenResult = {
        fd: fd,
        size: stat.size,
        release: async (): Promise<void> => {
          await asset.close(fd);
        }
      };
      HiLog.i(TAG, `openMediaLibraryAsset success fileName=${fileName} size=${stat.size}`);
      return result;
    } catch (error) {
      HiLog.e(TAG, `openMediaLibraryAsset asset.open failed fileName=${fileName}`);
      return null;
    }
  }

  /**
   * 在媒体库中按 URI 或 displayName 查找 FileAsset
   *
   * @param userFileMgr UserFileManager 实例
   * @param uri 目标 URI
   * @param fileName 显示文件名
   * @returns 匹配的 FileAsset 或 null
   */
  private static async findMediaAsset(userFileMgr: userFileManager.UserFileManager,
    uri: string, fileName: string): Promise<userFileManager.FileAsset | null> {
    const isAudio = MediaPlaybackFileOpener.isAudioMedia(uri, fileName);
    const byUri = await MediaPlaybackFileOpener.findMediaAssetByUri(userFileMgr, uri, isAudio);
    if (byUri !== null) {
      return byUri;
    }
    const byScan = await MediaPlaybackFileOpener.findMediaAssetByScan(userFileMgr, uri, fileName, isAudio, true);
    if (byScan !== null) {
      return byScan;
    }
    return MediaPlaybackFileOpener.findMediaAssetByScan(userFileMgr, uri, fileName, isAudio, false);
  }

  /**
   * 判断媒体库资产查询应走音频还是视频/相册索引
   *
   * @param uri 媒体 URI
   * @param fileName 显示文件名
   * @returns 是否为音频
   */
  private static isAudioMedia(uri: string, fileName: string): boolean {
    if (uri.includes('/Audio/')) {
      return true;
    }
    if (uri.includes('/Photo/') || uri.includes('/Video/')) {
      return false;
    }
    const lower = fileName.toLowerCase();
    if (SupportedMediaFormats.isSupportedAudio(lower)) {
      return true;
    }
    if (SupportedMediaFormats.isSupportedVideo(lower)) {
      return false;
    }
    return true;
  }

  /**
   * 按 URI 精确查询媒体库资产（O(1)，避免 getAllObject 全量加载卡顿）
   *
   * @param userFileMgr UserFileManager 实例
   * @param uri 目标 URI
   * @param isAudio 是否为音频 URI
   * @returns 匹配的 FileAsset 或 null
   */
  private static async findMediaAssetByUri(userFileMgr: userFileManager.UserFileManager,
    uri: string, isAudio: boolean): Promise<userFileManager.FileAsset | null> {
    const predicates = new dataSharePredicates.DataSharePredicates();
    predicates.equalTo('uri', uri);
    const fetchOptions: userFileManager.FetchOptions = {
      fetchColumns: ['duration'],
      predicates: predicates
    };
    try {
      const fetchResult = isAudio ?
        await userFileMgr.getAudioAssets(fetchOptions) :
        await userFileMgr.getPhotoAssets(fetchOptions);
      if (fetchResult.getCount() > 0) {
        const asset = await fetchResult.getFirstObject();
        fetchResult.close();
        HiLog.i(TAG, `findMediaAssetByUri hit fileName=${asset.displayName}`);
        return asset;
      }
      fetchResult.close();
    } catch (error) {
      HiLog.w(TAG, `findMediaAssetByUri failed uri=${uri}`);
    }
    return null;
  }

  /**
   * 按 displayName 增量扫描媒体库（URI 查询不可用时的回退，匹配后立即停止）
   *
   * @param userFileMgr UserFileManager 实例
   * @param uri 目标 URI
   * @param fileName 显示文件名
   * @param isAudio 是否为音频 URI
   * @returns 匹配的 FileAsset 或 null
   */
  private static async findMediaAssetByScan(userFileMgr: userFileManager.UserFileManager,
    uri: string, fileName: string, isAudio: boolean,
    requirePositiveDuration: boolean): Promise<userFileManager.FileAsset | null> {
    const predicates = new dataSharePredicates.DataSharePredicates();
    if (requirePositiveDuration) {
      predicates.greaterThan('duration', 0);
    }
    const fetchOptions: userFileManager.FetchOptions = {
      fetchColumns: ['duration'],
      predicates: predicates
    };
    try {
      const fetchResult = isAudio ?
        await userFileMgr.getAudioAssets(fetchOptions) :
        await userFileMgr.getPhotoAssets(fetchOptions);
      let asset = await fetchResult.getFirstObject();
      while (asset !== undefined) {
        if (asset.uri === uri || asset.displayName === fileName) {
          fetchResult.close();
          HiLog.i(TAG, `findMediaAssetByScan hit fileName=${fileName} requireDuration=${requirePositiveDuration}`);
          return asset;
        }
        asset = await fetchResult.getNextObject();
      }
      fetchResult.close();
    } catch (error) {
      HiLog.e(TAG, `findMediaAssetByScan failed uri=${uri} fileName=${fileName} requireDuration=${requirePositiveDuration}`);
    }
    return null;
  }

  /**
   * 从 URI 尾段解析文件名（仅用于日志）
   *
   * @param uri 文件 URI
   * @returns 文件名
   */
  private static fileNameFromUri(uri: string): string {
    const slash = uri.lastIndexOf('/');
    return slash >= 0 ? uri.substring(slash + 1) : uri;
  }
}
