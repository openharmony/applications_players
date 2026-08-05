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


import { Want } from '@kit.AbilityKit';
import fs from '@ohos.file.fs';
import FileInfo from '@ohos/common/src/main/ets/model/FileInfo';
import { FileUtil } from '@ohos/common';
import { HiLog } from '@ohos/common/src/main/ets/utils/HiLog';
import FileMimeTypeUtil from '@ohos/common/src/main/ets/utils/FileMimeTypeUtil';
import { SupportedMediaFormats } from '@ohos/common/src/main/ets/constants/media/SupportedMediaFormats';
import { MimeType } from '@ohos/common/src/main/ets/constants/media/MimeType';

const TAG: string = 'ExternalWantResolver';

/** 从系统 / 其他应用 Want 解析出的外部媒体打开请求 */
export interface ExternalWantPayload {
  uri: string;
  mimeType: string;
  isAudio: boolean;
}

/**
 * 解析外部「打开方式」Want：提取 URI、MIME，并推断音频/视频类型。
 */
export class ExternalWantResolver {
  /**
   * 判断 Want 是否携带可播放的外部媒体 URI。
   *
   * @param want 系统传入的 Want
   * @returns 解析成功则返回载荷，否则 null
   */
  public static resolve(want: Want): ExternalWantPayload | null {
    const rawUri = ExternalWantResolver.resolveUri(want);
    if (rawUri.length === 0) {
      return null;
    }
    const uri = FileUtil.normalizeMediaUri(rawUri);
    const fileName = ExternalWantResolver.extractFileName(uri);
    const mimeType = ExternalWantResolver.resolveMimeType(want, fileName);
    if (!ExternalWantResolver.isSupportedMedia(mimeType, fileName)) {
      HiLog.w(TAG, `resolve unsupported media uri=${uri} mime=${mimeType}`);
      return null;
    }
    const isAudio = ExternalWantResolver.inferIsAudio(mimeType, fileName);
    const payload: ExternalWantPayload = {
      uri: uri,
      mimeType: mimeType,
      isAudio: isAudio,
    };
    HiLog.i(TAG, `resolve success uri=${uri} mime=${mimeType} isAudio=${isAudio} fileName=${fileName}`);
    return payload;
  }

  /**
   * 将外部 Want 载荷转为播放层 FileInfo。
   *
   * @param payload 已解析的外部打开请求
   * @returns 实体 FileInfo
   */
  public static toFileInfo(payload: ExternalWantPayload): FileInfo {
    const uri = FileUtil.normalizeMediaUri(payload.uri);
    const fileName = ExternalWantResolver.extractFileName(uri);
    const mimeType = ExternalWantResolver.resolveCanonicalMimeType(payload.mimeType, fileName);
    const fileSize = ExternalWantResolver.resolveFileSize(uri);
    const updateTime = ExternalWantResolver.resolveFileMtime(uri);
    return new FileInfo(fileName, uri, mimeType,
      fileSize > 0 ? fileSize : undefined,
      updateTime > 0 ? updateTime : undefined);
  }

  /**
   * 根据 AppStorage 中缓存的 URI / MIME 重建载荷（首页冷启动播放用）。
   *
   * @param uri 媒体 URI
   * @param mimeType MIME，可为空则由扩展名推断
   * @returns 外部打开载荷
   */
  public static fromStored(uri: string, mimeType: string): ExternalWantPayload {
    const normalizedUri = FileUtil.normalizeMediaUri(uri);
    const fileName = ExternalWantResolver.extractFileName(normalizedUri);
    const resolvedMime = mimeType.length > 0 ? mimeType :
      ExternalWantResolver.resolveMimeTypeFromFileName(fileName);
    const isAudio = ExternalWantResolver.inferIsAudio(resolvedMime, fileName);
    const payload: ExternalWantPayload = {
      uri: normalizedUri,
      mimeType: resolvedMime,
      isAudio: isAudio,
    };
    return payload;
  }

  /**
   * 从 Want 提取媒体文件 URI（兼容 fileUrl / uri 参数）。
   */
  private static resolveUri(want: Want): string {
    if (want.uri && want.uri.length > 0) {
      return want.uri;
    }
    const fileUrl = want.parameters?.['fileUrl'] as string | undefined;
    if (fileUrl && fileUrl.length > 0) {
      return fileUrl;
    }
    const paramUri = want.parameters?.['uri'] as string | undefined;
    if (paramUri && paramUri.length > 0) {
      return paramUri;
    }
    return '';
  }

  /**
   * 判断外部媒体是否应按音频打开（后缀优先，其次 MIME 前缀）。
   */
  public static isAudioMedia(mimeType: string, fileName: string): boolean {
    return ExternalWantResolver.inferIsAudio(mimeType, fileName);
  }

  /**
   * 从 Want.type 或扩展名推断 MIME。
   */
  private static resolveMimeType(want: Want, fileName: string): string {
    if (want.type && want.type.length > 0) {
      return want.type;
    }
    const paramType = want.parameters?.['type'] as string | undefined;
    if (paramType && paramType.length > 0) {
      return paramType;
    }
    const paramMime = want.parameters?.['mimeType'] as string | undefined;
    if (paramMime && paramMime.length > 0) {
      return paramMime;
    }
    if (fileName.length === 0) {
      return '';
    }
    return ExternalWantResolver.resolveMimeTypeFromFileName(fileName);
  }

  /**
   * 仅凭文件名推断 MIME。
   */
  private static resolveMimeTypeFromFileName(fileName: string): string {
    const mimeObj = FileMimeTypeUtil.getFileMimeType(fileName);
    if (mimeObj.mimeType.length > 0) {
      return mimeObj.mimeType;
    }
    return ExternalWantResolver.inferIsAudio('', fileName) ? 'audio/*' : 'video/*';
  }

  /**
   * 是否为支持的音频/视频类型。
   */
  private static isSupportedMedia(mimeType: string, fileName: string): boolean {
    return SupportedMediaFormats.isSupportedMedia(fileName);
  }

  /**
   * 根据后缀与 MIME 判断是否为音频（后缀优先，避免目录名干扰）。
   */
  private static inferIsAudio(mimeType: string, fileName: string): boolean {
    if (SupportedMediaFormats.isSupportedAudio(fileName)) {
      return true;
    }
    if (SupportedMediaFormats.isSupportedVideo(fileName)) {
      return false;
    }
    if (mimeType.startsWith('audio/')) {
      return true;
    }
    if (mimeType.startsWith('video/')) {
      return false;
    }
    if (fileName.length === 0) {
      return mimeType.startsWith('audio/');
    }
    const mimeObj = FileMimeTypeUtil.getFileMimeType(fileName);
    return mimeObj.fileCategory === MimeType.FILE_CATEGORY_AUDIO;
  }

  /**
   * 将 Want 携带的 MIME 规范为与后缀一致的 audio/* 或 video/*。
   */
  private static resolveCanonicalMimeType(mimeType: string, fileName: string): string {
    const fromExtension = ExternalWantResolver.resolveMimeTypeFromFileName(fileName);
    if (ExternalWantResolver.isAudioMedia(mimeType, fileName)) {
      return fromExtension.startsWith('audio/') ? fromExtension : 'audio/*';
    }
    if (fromExtension.length > 0) {
      return fromExtension;
    }
    return mimeType;
  }

  /**
   * 从 URI 提取并解码文件名（与扫描入库、FileUtil 规范一致）。
   */
  private static extractFileName(uri: string): string {
    const normalizedUri = FileUtil.normalizeMediaUri(uri);
    let fileName = FileUtil.getFileNameFromUri(normalizedUri);
    if (fileName.length === 0) {
      const withoutQuery = normalizedUri.split('?')[0];
      const lastSlash = withoutQuery.lastIndexOf('/');
      fileName = lastSlash >= 0 ? withoutQuery.substring(lastSlash + 1) : withoutQuery;
    }
    if (fileName.indexOf('%') >= 0) {
      fileName = FileUtil.decodeURIComponent(fileName);
    }
    return fileName;
  }

  /**
   * 读取外部文件大小，供播放器元信息展示。
   */
  private static resolveFileSize(uri: string): number {
    const stat = ExternalWantResolver.statExternalFile(uri);
    return stat !== null ? stat.size : 0;
  }

  /**
   * 读取外部文件修改时间。
   */
  private static resolveFileMtime(uri: string): number {
    const stat = ExternalWantResolver.statExternalFile(uri);
    return stat !== null ? stat.mtime : 0;
  }

  /**
   * 对 docs / file URI 做 stat，失败时返回 null。
   */
  private static statExternalFile(uri: string): fs.Stat | null {
    try {
      const fileUriObj = FileUtil.getFileUriObjectFromUri(uri);
      if (fileUriObj !== undefined && fileUriObj.path.length > 0) {
        return fs.statSync(fileUriObj.path);
      }
      const file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      try {
        return fs.statSync(file.fd);
      } finally {
        fs.closeSync(file);
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      HiLog.w(TAG, `statExternalFile failed uri=${uri} message=${message}`);
      return null;
    }
  }
}
