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
import fs from '@ohos.file.fs';
import { HiLog } from '../utils/HiLog';
import { ThumbnailConfig } from './ThumbnailConfig';

const TAG = 'ImageProcessor';

export class ImageProcessor {
  private static async convertPixelMap2ImageSource(pixelMap: image.PixelMap): Promise<image.ImageSource> {
    let imagePacker: image.ImagePacker | undefined = undefined;
    try {
      const imageInfo = await pixelMap.getImageInfo();
      imagePacker = image.createImagePacker();
      const packOpts: image.PackingOption = {
        format: 'image/jpeg',
        quality: 100
      };
      // Use deprecated packing method - still available for backward compatibility
      const arrayBuffer = await imagePacker.packing(pixelMap, packOpts);
      const sourceOpts: image.SourceOptions = {
        sourceDensity: 0,
        sourcePixelFormat: image.PixelMapFormat.RGBA_8888,
        sourceSize: imageInfo.size
      };
      return image.createImageSource(arrayBuffer, sourceOpts);
    } finally {
      if (imagePacker) {
        await imagePacker.release();
      }
    }
  }

  public static async resize(pixelMap: image.PixelMap, size: number): Promise<image.PixelMap> {
    try {
      const imageInfo = await pixelMap.getImageInfo();
      const maxSize = Math.max(imageInfo.size.width, imageInfo.size.height);
      
      if (maxSize <= size) {
        return pixelMap;
      }

      const ratio = size / maxSize;
      await pixelMap.scale(ratio, ratio);

      const desiredSize: image.Size = {
        width: size,
        height: size
      };

      const decodingOptions: image.DecodingOptions = {
        desiredSize: desiredSize,
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888
      };

      const imageSource = await ImageProcessor.convertPixelMap2ImageSource(pixelMap);
      const resultPixelMap = await imageSource.createPixelMap(decodingOptions);

      await imageSource.release();

      return resultPixelMap;
    } catch (error) {
      HiLog.e(TAG, `Image resize failed: ${error}`);
      throw new Error(`Image resize failed: ${error}`);
    }
  }

  public static async resizeWithAspectRatio(
    pixelMap: image.PixelMap,
    targetSize: number
  ): Promise<image.PixelMap> {
    try {
      const imageInfo = await pixelMap.getImageInfo();
      let desiredWidth = targetSize;
      let desiredHeight = targetSize;

      if (imageInfo.size.width > imageInfo.size.height) {
        desiredWidth = (imageInfo.size.width / imageInfo.size.height) * desiredHeight;
      } else {
        desiredHeight = (imageInfo.size.height / imageInfo.size.width) * desiredWidth;
      }

      const desiredSize: image.Size = {
        width: Math.round(desiredWidth),
        height: Math.round(desiredHeight)
      };

      const ratio = desiredWidth / imageInfo.size.width;
      await pixelMap.scale(ratio, ratio);

      const decodingOptions: image.DecodingOptions = {
        desiredSize: desiredSize,
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888
      };

      const imageSource = await ImageProcessor.convertPixelMap2ImageSource(pixelMap);
      const resultPixelMap = await imageSource.createPixelMap(decodingOptions);

      await imageSource.release();

      return resultPixelMap;
    } catch (error) {
      HiLog.e(TAG, `Aspect ratio resize failed: ${error}`);
      throw new Error(`Aspect ratio resize failed: ${error}`);
    }
  }

  public static async cropToRatio(
    pixelMap: image.PixelMap,
    targetRatio: number,
    strategy: 'center' | 'top' = 'center'
  ): Promise<image.PixelMap> {
    try {
      const imageInfo = await pixelMap.getImageInfo();
      const currentRatio = imageInfo.size.width / imageInfo.size.height;

      if (Math.abs(currentRatio - targetRatio) < 0.01) {
        return pixelMap;
      }

      let cropWidth = imageInfo.size.width;
      let cropHeight = imageInfo.size.height;
      let cropX = 0;
      let cropY = 0;

      if (currentRatio > targetRatio) {
        cropWidth = cropHeight * targetRatio;
        cropX = (imageInfo.size.width - cropWidth) / 2;
      } else {
        cropHeight = cropWidth / targetRatio;
        if (strategy === 'center') {
          cropY = (imageInfo.size.height - cropHeight) / 2;
        } else {
          cropY = 0;
        }
      }

      const cropRegion: image.Region = {
        x: Math.round(cropX),
        y: Math.round(cropY),
        size: {
          width: Math.round(cropWidth),
          height: Math.round(cropHeight)
        }
      };

      await pixelMap.crop(cropRegion);
      return pixelMap;
    } catch (error) {
      HiLog.e(TAG, `Image crop failed: ${error}`);
      throw new Error(`Image crop failed: ${error}`);
    }
  }

  public static async limitAspectRatio(
    pixelMap: image.PixelMap,
    maxRatio: number
  ): Promise<image.PixelMap> {
    try {
      const imageInfo = await pixelMap.getImageInfo();
      const currentRatio = imageInfo.size.width / imageInfo.size.height;

      if (currentRatio <= maxRatio && currentRatio >= (1 / maxRatio)) {
        return pixelMap;
      }

      let cropWidth = imageInfo.size.width;
      let cropHeight = imageInfo.size.height;
      let cropX = 0;
      let cropY = 0;

      if (currentRatio > maxRatio) {
        cropWidth = cropHeight * maxRatio;
        cropX = (imageInfo.size.width - cropWidth) / 2;
      } else {
        cropHeight = cropWidth * maxRatio;
      }

      const cropRegion: image.Region = {
        x: Math.round(cropX),
        y: Math.round(cropY),
        size: {
          width: Math.round(cropWidth),
          height: Math.round(cropHeight)
        }
      };

      await pixelMap.crop(cropRegion);
      return pixelMap;
    } catch (error) {
      HiLog.e(TAG, `Aspect ratio limit failed: ${error}`);
      throw new Error(`Aspect ratio limit failed: ${error}`);
    }
  }

  public static async saveAsJpg(
    pixel: image.PixelMap,
    filePath: string,
    quality: number = ThumbnailConfig.IMAGE_QUALITY
  ): Promise<boolean> {
    let imagePacker: image.ImagePacker | undefined = undefined;
    let file: fs.File | undefined = undefined;

    try {
      imagePacker = image.createImagePacker();
      const packOpts: image.PackingOption = {
        format: ThumbnailConfig.IMAGE_FORMAT,
        quality: quality
      };

      // Use packing method to get ArrayBuffer, then write to file
      const packedData: ArrayBuffer = await imagePacker.packing(pixel, packOpts);

      // Write to file synchronously
      file = fs.openSync(filePath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY);
      fs.writeSync(file.fd, packedData);

      HiLog.d(TAG, `JPG saved: ${filePath}`);
      return true;
    } catch (error) {
      HiLog.e(TAG, `JPG save failed: ${filePath}, error: ${error}`);
      return false;
    } finally {
      if (file) {
        fs.closeSync(file.fd);
      }
      if (imagePacker) {
        await imagePacker.release();
      }
    }
  }
}
