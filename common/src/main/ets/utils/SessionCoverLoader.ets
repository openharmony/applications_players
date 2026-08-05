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


import image from '@ohos.multimedia.image';
import media from '@ohos.multimedia.media';
import { HiLog } from './HiLog';

const TAG = 'SessionCoverLoader';

/** 播控中心封面加载：磁盘缩略图或视频首帧 */
export class SessionCoverLoader {
  static async loadPixelMap(coverUri: string, maxEdgePx: number): Promise<image.PixelMap | null> {
    if (coverUri.length === 0) {
      return null;
    }
    let source: image.ImageSource | undefined = undefined;
    try {
      source = image.createImageSource(coverUri);
      const decodingOptions: image.DecodingOptions = {
        desiredSize: { width: maxEdgePx, height: maxEdgePx }
      };
      return await source.createPixelMap(decodingOptions);
    } catch (error) {
      HiLog.w(TAG, `loadPixelMap failed uri=${coverUri} error=${error}`);
      return null;
    } finally {
      if (source) {
        await source.release();
      }
    }
  }

  static async extractVideoFrameFromFd(fd: number, size: number, maxEdgePx: number): Promise<image.PixelMap | null> {
    if (fd < 0 || size <= 0) {
      return null;
    }
    let avImageGenerator: media.AVImageGenerator | undefined = undefined;
    try {
      avImageGenerator = await media.createAVImageGenerator();
      avImageGenerator.fdSrc = {
        fd: fd,
        offset: 0,
        length: size
      };
      const param: media.PixelMapParams = {
        width: maxEdgePx,
        height: maxEdgePx
      };
      return await avImageGenerator.fetchFrameByTime(0, media.AVImageQueryOptions.AV_IMAGE_QUERY_NEXT_SYNC, param);
    } catch (error) {
      HiLog.w(TAG, `extractVideoFrameFromFd failed error=${error}`);
      return null;
    } finally {
      if (avImageGenerator) {
        await avImageGenerator.release();
      }
    }
  }
}
