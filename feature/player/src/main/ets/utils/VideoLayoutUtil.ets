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

import { Constants } from '@ohos/common/src/main/ets/constants/ui/Constants';

export class VideoLayoutRatio {
  widthRatio: string;
  heightRatio: string;

  constructor(widthRatio: string, heightRatio: string) {
    this.widthRatio = widthRatio;
    this.heightRatio = heightRatio;
  }
}

export class VideoLayoutSize {
  width: number;
  height: number;

  constructor(width: number, height: number) {
    this.width = width;
    this.height = height;
  }
}

/** AVPlayer 就绪前按 16:9 预估竖屏 contain 比例，避免首帧 100% 闪动。 */
export const DEFAULT_VIDEO_LAYOUT_SIZE: VideoLayoutSize = new VideoLayoutSize(16, 9);

/**
 * 全屏旋转过渡期：Stack 实测宽高可能仍是旧方向，按目标面板方向临时对调后再算 contain。
 * 分屏/悬浮窗禁止调用：窗口真实宽高即布局基准，对调会导致比例套错容器而拉伸。
 *
 * @param container 实测容器尺寸
 * @param portraitPanelMode 是否竖屏面板（contain）
 */
export function normalizeContainerForOrientation(
  container: VideoLayoutSize,
  portraitPanelMode: boolean
): VideoLayoutSize {
  if (container.width <= 0 || container.height <= 0) {
    return container;
  }
  const containerLandscape = container.width > container.height;
  if (portraitPanelMode && containerLandscape) {
    return new VideoLayoutSize(container.height, container.width);
  }
  if (!portraitPanelMode && !containerLandscape) {
    return new VideoLayoutSize(container.height, container.width);
  }
  return container;
}

/**
 * 将布局像素对齐为偶数，避免 NV12/HWC 奇数高（如 503）与 src.x=1 类裁剪产生扫描线白条。
 */
export function alignEvenPx(value: number): number {
  const floored = Math.floor(value);
  const even = floored - (floored % 2);
  return Math.max(2, even);
}

/**
 * 视频 Surface 对齐到 4 的倍数（NV12 色度 / 硬解常见要求），向下取整。
 */
export function alignSurfacePx(value: number): number {
  const floored = Math.floor(value);
  const aligned = floored - (floored % 4);
  return Math.max(4, aligned);
}

/** 竖屏/窗口模式：UI 层 contain 比例；结果按偶数像素回算百分比。 */
export function computeVideoContainRatio(
  container: VideoLayoutSize,
  video: VideoLayoutSize
): VideoLayoutRatio {
  if (container.width <= 0 || container.height <= 0 || video.width <= 0 || video.height <= 0) {
    return new VideoLayoutRatio(Constants.ALL_PERCENT, Constants.ALL_PERCENT);
  }
  const windowRatio = container.width / container.height;
  const videoRatio = video.width / video.height;
  if (videoRatio > windowRatio) {
    const targetHeight = alignEvenPx(container.width / videoRatio);
    const heightPct = Constants.ONE_HUNDRED * targetHeight / container.height;
    return new VideoLayoutRatio(
      Constants.ALL_PERCENT,
      heightPct.toString() + '%'
    );
  }
  const targetWidth = alignEvenPx(container.height * videoRatio);
  const widthPct = Constants.ONE_HUNDRED * targetWidth / container.width;
  return new VideoLayoutRatio(
    widthPct.toString() + '%',
    Constants.ALL_PERCENT
  );
}

/** 横屏/PC 全屏：Surface 铺满容器。 */
export function computeVideoCoverRatio(): VideoLayoutRatio {
  return new VideoLayoutRatio(Constants.ALL_PERCENT, Constants.ALL_PERCENT);
}

/**
 * 按片源宽高比生成 Surface 像素尺寸（长边不超过 maxEdge）。
 * 避免默认 1920×1080 与超宽片（如 3840×1608）宽高比不一致导致 UI contain 后被拉伸。
 */
export function computeAspectMatchedSurfaceSize(
  maxEdge: number,
  videoWidth: number,
  videoHeight: number
): VideoLayoutSize {
  if (maxEdge < 4 || videoWidth <= 0 || videoHeight <= 0) {
    return new VideoLayoutSize(alignSurfacePx(maxEdge), alignSurfacePx(maxEdge * 9 / 16));
  }
  const videoRatio = videoWidth / videoHeight;
  let width: number;
  let height: number;
  if (videoRatio >= 1) {
    width = alignSurfacePx(maxEdge);
    height = alignSurfacePx(width / videoRatio);
  } else {
    height = alignSurfacePx(maxEdge);
    width = alignSurfacePx(height * videoRatio);
  }
  return new VideoLayoutSize(Math.max(4, width), Math.max(4, height));
}
