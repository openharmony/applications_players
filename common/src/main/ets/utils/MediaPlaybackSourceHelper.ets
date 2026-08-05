/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import fs from '@ohos.file.fs';
import { HiLog } from './HiLog';
import { FileUtil } from './FileUtil';

const TAG = 'MediaPlaybackSourceHelper';

/** 播放前源文件可访问性 */
export enum MediaSourceAccessState {
  /** 本地路径可访问 */
  EXISTS = 0,
  /** 本地路径明确不存在 */
  MISSING = 1,
  /** 无法用 path 预检（如 file://media 或路径为空） */
  UNVERIFIABLE = 2
}

/**
 * 播放链路源文件存在性预检：切歌/开播前判断文件是否真实存在，避免一律提示「已删除」。
 */
export class MediaPlaybackSourceHelper {
  /**
   * 解析用于 access 的本地路径候选
   *
   * @param uri 媒体 URI
   * @param filePath FileInfo.filePath
   * @param mediaPath FileInfo.mediaPath
   * @returns 路径；无法解析时返回空串
   */
  public static resolveCheckPath(uri: string, filePath: string, mediaPath: string): string {
    if (filePath.length > 0) {
      return filePath;
    }
    if (mediaPath.length > 0) {
      return mediaPath;
    }
    if (uri.length === 0 || uri.startsWith('file://media/')) {
      return '';
    }
    const fromUri = FileUtil.getPathFromUri(uri);
    if (fromUri.length > 0 && fromUri !== uri) {
      return fromUri;
    }
    return '';
  }

  /**
   * 预检源文件是否真实存在（不打开播放）
   *
   * @param uri 媒体 URI
   * @param filePath 本地路径
   * @param mediaPath 媒体路径
   * @returns 存在性状态
   */
  public static checkAccess(uri: string, filePath: string, mediaPath: string): MediaSourceAccessState {
    const path = MediaPlaybackSourceHelper.resolveCheckPath(uri, filePath, mediaPath);
    if (path.length === 0) {
      HiLog.w(TAG, `checkAccess unverifiable uri=${uri}`);
      return MediaSourceAccessState.UNVERIFIABLE;
    }
    if (MediaPlaybackSourceHelper.canAccess(path)) {
      return MediaSourceAccessState.EXISTS;
    }
    // path 失败时再试原始 URI（部分 file://docs 场景 path 与 uri 行为不一致）
    if (uri.length > 0 && uri !== path && MediaPlaybackSourceHelper.canAccess(uri)) {
      return MediaSourceAccessState.EXISTS;
    }
    HiLog.w(TAG, `checkAccess missing path=${path} uri=${uri}`);
    return MediaSourceAccessState.MISSING;
  }

  /**
   * open 失败后归因：优先复检路径；原先已确认为 EXISTS 则归为打开失败
   *
   * @param uri 媒体 URI
   * @param filePath 本地路径
   * @param mediaPath 媒体路径
   * @param beforeOpen 打开前的预检结果
   * @returns 用于 Toast 的最终状态
   */
  public static classifyOpenFailure(uri: string, filePath: string, mediaPath: string,
    beforeOpen: MediaSourceAccessState): MediaSourceAccessState {
    if (beforeOpen === MediaSourceAccessState.EXISTS) {
      return MediaSourceAccessState.EXISTS;
    }
    const after = MediaPlaybackSourceHelper.checkAccess(uri, filePath, mediaPath);
    if (after === MediaSourceAccessState.MISSING) {
      return MediaSourceAccessState.MISSING;
    }
    if (beforeOpen === MediaSourceAccessState.MISSING) {
      return MediaSourceAccessState.MISSING;
    }
    return after === MediaSourceAccessState.EXISTS ?
      MediaSourceAccessState.EXISTS : MediaSourceAccessState.UNVERIFIABLE;
  }

  private static canAccess(target: string): boolean {
    try {
      fs.accessSync(target);
      return true;
    } catch (_) {
      return false;
    }
  }
}
