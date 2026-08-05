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
import { HiLog } from '../utils/HiLog';
import { MediaPlaybackFileOpener } from '../utils/MediaPlaybackFileOpener';
import { MediaMetadataResolver } from '../utils/MediaMetadataResolver';
import { SupportedMediaFormats } from '../constants/media/SupportedMediaFormats';
import media from '@ohos.multimedia.media';
import image from '@ohos.multimedia.image';

const TAG = 'RetryHelper';

/**
 * 重试提取时长
 *
 * @param fileInfo 文件信息
 * @returns 是否成功
 */
export async function retryDuration(fileInfo: FileInfo): Promise<boolean> {
  if (fileInfo.duration > 0) {
    return true;
  }
  await MediaMetadataResolver.fillDuration(fileInfo);
  return fileInfo.duration > 0;
}

/**
 * 重试获取文件大小
 *
 * @param fileInfo 文件信息
 * @returns 是否成功
 */
export async function retrySize(fileInfo: FileInfo): Promise<boolean> {
  if (fileInfo.size > 0) {
    return true;
  }
  const opened = await MediaPlaybackFileOpener.openReadOnly(fileInfo.uri, fileInfo.fileName);
  if (opened) {
    try {
      fileInfo.size = opened.size;
      return fileInfo.size > 0;
    } finally {
      await opened.release();
    }
  }
  return false;
}

/**
 * 重试提取封面
 *
 * @param fileInfo 文件信息
 * @returns 是否成功
 */
export async function retryCover(fileInfo: FileInfo): Promise<boolean> {
  if (fileInfo.thumbGenerated) {
    return true;
  }

  const isAudio = SupportedMediaFormats.isSupportedAudio(fileInfo.fileName);
  const isVideo = SupportedMediaFormats.isSupportedVideo(fileInfo.fileName);

  if (isAudio) {
    return retryAudioCover(fileInfo);
  } else if (isVideo) {
    return retryVideoThumbnail(fileInfo);
  }
  return false;
}

/**
 * 重试提取音频封面
 *
 * @param fileInfo 音频文件信息
 * @returns 是否成功
 */
async function retryAudioCover(fileInfo: FileInfo): Promise<boolean> {
  const opened = await MediaPlaybackFileOpener.openReadOnly(fileInfo.uri, fileInfo.fileName);
  if (!opened) {
    return false;
  }

  try {
    const extractor = await media.createAVMetadataExtractor();
    const fdSrc: media.AVFileDescriptor = {
      fd: opened.fd,
      offset: 0,
      length: opened.size
    };
    extractor.fdSrc = fdSrc;
    const pixelMap = await extractor.fetchAlbumCover();
    if (pixelMap) {
      await pixelMap.release();
      HiLog.i(TAG, `Audio cover extracted: ${fileInfo.fileName}`);
      return true;
    }
    await extractor.release();
  } catch (e) {
    HiLog.w(TAG, `Audio cover extraction failed: ${fileInfo.fileName}`);
  } finally {
    await opened.release();
  }
  return false;
}

/**
 * 重试提取视频缩略图
 *
 * @param fileInfo 视频文件信息
 * @returns 是否成功
 */
async function retryVideoThumbnail(fileInfo: FileInfo): Promise<boolean> {
  const opened = await MediaPlaybackFileOpener.openReadOnly(fileInfo.uri, fileInfo.fileName);
  if (!opened) {
    return false;
  }

  try {
    const generator = await media.createAVImageGenerator();
    const fdSrc: media.AVFileDescriptor = {
      fd: opened.fd,
      offset: 0,
      length: opened.size
    };
    generator.fdSrc = fdSrc;
    const options = media.AVImageQueryOptions.AV_IMAGE_QUERY_NEXT_SYNC;
    const param: media.PixelMapParams = {
      width: 320,
      height: 320
    };

    let pixelMap: image.PixelMap | undefined = undefined;
    try {
      pixelMap = await generator.fetchFrameByTime(0, options, param);
    } catch (e) {
      try {
        pixelMap = await generator.fetchFrameByTime(1000000, options, param);
      } catch (e2) {
        // 忽略
      }
    }

    if (pixelMap) {
      await pixelMap.release();
      HiLog.i(TAG, `Video thumbnail extracted: ${fileInfo.fileName}`);
      return true;
    }
    await generator.release();
  } catch (e) {
    HiLog.w(TAG, `Video thumbnail extraction failed: ${fileInfo.fileName}`);
  } finally {
    await opened.release();
  }
  return false;
}
