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


export class ThumbnailConfig {
  private static readonly BYTES_IN_MB = 1024 * 1024;
  private static readonly BYTES_IN_GB = 1024 * 1024 * 1024;

  static readonly THUMBNAIL_SIZE = 200;

  static readonly IMAGE_QUALITY = 90;
  static readonly IMAGE_FORMAT = 'image/jpeg';
  static readonly MAX_IMAGE_BYTE_SIZE = 20 * ThumbnailConfig.BYTES_IN_MB;

  static readonly MAX_CACHE_SIZE = 100 * ThumbnailConfig.BYTES_IN_MB;
  static readonly MAX_CACHE_AGE = 30 * 24 * 60 * 60 * 1000;

  static readonly MAX_CONCURRENT_TASKS = 6;
  static readonly MAX_TASK_QUEUES = 50;
  static readonly TASK_TIMEOUT = 30000;

  static readonly CLEAN_INTERVAL = 30 * 24 * 60 * 60 * 1000;
  static readonly DEEP_CLEAN_THRESHOLD = 1 * ThumbnailConfig.BYTES_IN_GB;
  static readonly USB_CLEAN_INTERVAL = 7 * 24 * 60 * 60 * 1000;

  static readonly MAX_IMAGE_ASPECT_RATIO = 16 / 9;
  /** 首页宫格封面宽高比，与 MediaGridItem 16:9 容器一致 */
  static readonly VIDEO_COVER_RATIO = 16 / 9;
  /** 视频 16:9 缩略图缓存键后缀，比例变更后使旧 1:1 缓存失效 */
  static readonly VIDEO_THUMB_CACHE_SUFFIX = '_ar169';
  /** 视频缩略图提取/输出尺寸（宽 × 高） */
  static readonly VIDEO_THUMB_WIDTH = 356;
  static readonly VIDEO_THUMB_HEIGHT = 200;

  static readonly THUMBNAIL_CACHE_FOLDER_NAME = 'thumbnail';
  static readonly DEFAULT_STORAGE_DEVICE_UID = 'localDevice';
  static readonly THUMBNAIL_CACHE_PATH_PREFIX = 'file://';
  static readonly THUMBNAIL_FILE_SUFFIX = '.jpg';
}
