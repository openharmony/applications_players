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
import { zlib } from '@kit.BasicServicesKit';
import { AppContext } from '../context/AppContext';
import { FileUtil } from './FileUtil';
import { HiLog } from './HiLog';
import { MediaPlaybackOpenResult } from './MediaPlaybackOpenResult';

const TAG = 'ArchivePlaybackExtractor';
const CACHE_ROOT = 'archive_playback';
const STAGED_ZIP_NAME = '_source.zip';
const COPY_BUFFER_SIZE = 1024 * 1024;

/**
 * 将压缩包内媒体解压到应用缓存后打开，供 AVPlayer fdSrc 使用。
 */
export class ArchivePlaybackExtractor {
  /**
   * 解压并只读打开压缩包内目标文件。
   */
  public static async openInnerFile(archiveUri: string, innerPath: string,
    fileName: string): Promise<MediaPlaybackOpenResult | null> {
    const context = AppContext.getInstance().getMainAbilityContext() ??
      AppContext.getInstance().getCommonContext();
    if (!context) {
      HiLog.w(TAG, `openInnerFile no context fileName=${fileName}`);
      return null;
    }
    const cacheDir = `${context.cacheDir}/${CACHE_ROOT}/${ArchivePlaybackExtractor.buildCacheKey(archiveUri, innerPath)}`;
    const extractedPath = `${cacheDir}/${innerPath}`;
    try {
      if (await ArchivePlaybackExtractor.isCacheValid(archiveUri, extractedPath)) {
        HiLog.i(TAG, `openInnerFile cache hit fileName=${fileName}`);
        return ArchivePlaybackExtractor.openExtractedFile(extractedPath, fileName);
      }
      await ArchivePlaybackExtractor.ensureDir(cacheDir);
      const archiveLocalPath = await ArchivePlaybackExtractor.resolveArchiveLocalPath(archiveUri, cacheDir);
      if (archiveLocalPath === null) {
        HiLog.w(TAG, `openInnerFile unresolved archive uri=${archiveUri} fileName=${fileName}`);
        return null;
      }
      HiLog.i(TAG, `openInnerFile decompress start fileName=${fileName} archivePath=${archiveLocalPath}`);
      await zlib.decompressFile(archiveLocalPath, cacheDir);
      try {
        fs.accessSync(extractedPath);
      } catch (_) {
        HiLog.w(TAG, `openInnerFile extracted missing path=${extractedPath}`);
        return null;
      }
      HiLog.i(TAG, `openInnerFile decompress done fileName=${fileName}`);
      return ArchivePlaybackExtractor.openExtractedFile(extractedPath, fileName);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      HiLog.e(TAG, `openInnerFile failed fileName=${fileName} message=${message}`);
      return null;
    }
  }

  /**
   * 解析可读的压缩包本地路径。
   * file://docs URI 经 FileUri 转出的 /storage/Users/currentUser/... 在设备上往往不存在，
   * 需先通过 fs.open(file://docs/...) 复制到应用缓存再交给 zlib.decompressFile。
   */
  private static async resolveArchiveLocalPath(archiveUri: string, cacheDir: string): Promise<string | null> {
    const pathFromUri = FileUtil.getPathFromUri(archiveUri);
    if (pathFromUri.length > 0 && ArchivePlaybackExtractor.canAccess(pathFromUri)) {
      HiLog.i(TAG, `resolveArchiveLocalPath hit path fileName=${pathFromUri}`);
      return pathFromUri;
    }
    const stagedZip = `${cacheDir}/${STAGED_ZIP_NAME}`;
    if (ArchivePlaybackExtractor.stageUriToFile(archiveUri, stagedZip)) {
      HiLog.i(TAG, `resolveArchiveLocalPath staged uri=${archiveUri}`);
      return stagedZip;
    }
    HiLog.w(TAG, `resolveArchiveLocalPath failed uri=${archiveUri}`);
    return null;
  }

  private static canAccess(path: string): boolean {
    try {
      fs.accessSync(path);
      return true;
    } catch (_) {
      return false;
    }
  }

  /** 将 file://docs 等 URI 复制到沙箱路径，供 zlib 解压使用 */
  private static stageUriToFile(uri: string, destPath: string): boolean {
    try {
      fs.copyFileSync(uri, destPath);
      if (ArchivePlaybackExtractor.canAccess(destPath)) {
        return true;
      }
    } catch (_) {
    }
    let srcFile: fs.File | undefined = undefined;
    let destFile: fs.File | undefined = undefined;
    try {
      srcFile = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      destFile = fs.openSync(destPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      const buf = new ArrayBuffer(COPY_BUFFER_SIZE);
      let done = false;
      while (!done) {
        const readLen = fs.readSync(srcFile.fd, buf);
        if (readLen <= 0) {
          done = true;
          break;
        }
        fs.writeSync(destFile.fd, buf, { length: readLen });
      }
      return ArchivePlaybackExtractor.canAccess(destPath);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      HiLog.w(TAG, `stageUriToFile failed uri=${uri} message=${message}`);
      return false;
    } finally {
      if (srcFile !== undefined) {
        fs.closeSync(srcFile);
      }
      if (destFile !== undefined) {
        fs.closeSync(destFile);
      }
    }
  }

  private static statUri(uri: string): fs.Stat | null {
    try {
      const file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      try {
        return fs.statSync(file.fd);
      } finally {
        fs.closeSync(file);
      }
    } catch (_) {
      const path = FileUtil.getPathFromUri(uri);
      if (path.length > 0) {
        try {
          return fs.statSync(path);
        } catch (_) {
        }
      }
      return null;
    }
  }

  private static async ensureDir(path: string): Promise<void> {
    try {
      fs.accessSync(path);
    } catch (_) {
      fs.mkdirSync(path, true);
    }
  }

  private static async isCacheValid(archiveUri: string, extractedPath: string): Promise<boolean> {
    try {
      fs.accessSync(extractedPath);
      const archiveStat = ArchivePlaybackExtractor.statUri(archiveUri);
      if (archiveStat === null) {
        return true;
      }
      const extractedStat = fs.statSync(extractedPath);
      return extractedStat.mtime >= archiveStat.mtime;
    } catch (_) {
      return false;
    }
  }

  private static openExtractedFile(path: string, fileName: string): MediaPlaybackOpenResult | null {
    let file: fs.File | undefined = undefined;
    try {
      file = fs.openSync(path, fs.OpenMode.READ_ONLY);
      const stat = fs.statSync(file.fd);
      const fd = file.fd;
      const result: MediaPlaybackOpenResult = {
        fd: fd,
        size: stat.size,
        release: async (): Promise<void> => {
          fs.closeSync(fd);
        }
      };
      HiLog.i(TAG, `openExtractedFile success fileName=${fileName} size=${stat.size}`);
      return result;
    } catch (error) {
      HiLog.w(TAG, `openExtractedFile failed fileName=${fileName}`);
      return null;
    } finally {
      if (file) {
        fs.closeSync(file);
      }
    }
  }

  private static buildCacheKey(archivePath: string, innerPath: string): string {
    const raw = `${archivePath}|${innerPath}`;
    let hash = 0;
    for (let i = 0; i < raw.length; i++) {
      hash = ((hash << 5) - hash + raw.charCodeAt(i)) | 0;
    }
    const safeArchive = archivePath.split('/').pop() ?? 'archive';
    return `${safeArchive}_${Math.abs(hash)}`;
  }
}
