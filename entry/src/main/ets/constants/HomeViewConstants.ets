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


import { AppThemeConstants } from '@ohos/common/src/main/ets/constants/ui/AppThemeConstants';

/** 首页 ViewModel / Page 固定常量 */
export class HomeViewConstants {
  public static readonly FILTER_ALL: string = 'all';
  public static readonly FILTER_MUSIC: string = 'music';
  public static readonly FILTER_VIDEO: string = 'video';

  public static readonly PAGE_BACKGROUND: Resource = AppThemeConstants.PAGE_BACKGROUND;

  public static readonly SCAN_POLL_INTERVAL_MS: number = 100;
  public static readonly SCAN_CLOSE_DELAY_MS: number = 600;
  /** 全量扫描可能超过 15s，避免超时误取消通知 */
  public static readonly SCAN_TIMEOUT_MS: number = 120000;

  public static readonly MEDIA_LOAD_DEBOUNCE_MS: number = 150;
  public static readonly VM_READY_POLL_MS: number = 100;
  public static readonly VM_READY_MAX_RETRIES: number = 10;

  public static readonly SCAN_PROGRESS_PREFIX: string = '扫描中... ';
  public static readonly IMPORT_MAX_SELECT_COUNT: number = 100;

  public static readonly IMPORT_PROGRESS_TITLE: string = '正在导入媒体文件';
  public static readonly SCAN_PROGRESS_TITLE: string = '正在扫描媒体文件';
  public static readonly IMPORT_COMPLETE_TITLE: string = '媒体文件导入完成';
  public static readonly SCAN_COMPLETE_TITLE: string = '媒体文件扫描完成';
  public static readonly IMPORT_COMPLETE_TEXT: string = '导入已完成，可在播放器中查看';
  public static readonly SCAN_COMPLETE_TEXT: string = '扫描已完成，可在播放器中查看';
}
