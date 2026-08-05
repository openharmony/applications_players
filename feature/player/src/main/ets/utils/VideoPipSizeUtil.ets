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


import window from '@ohos.window';
import { HiLog } from '@ohos/common/src/main/ets/utils/HiLog';
import { VideoPipConstants, VideoPipContentSize } from '../constants/VideoPipConstants';
import { alignEvenPx, alignSurfacePx } from './VideoLayoutUtil';

const TAG: string = 'VideoPipSizeUtil';
/** contentWidth/Height 仅表达比例；长边上限避免把 4K 源像素当成缓冲尺寸提示 */
const PIP_CONTENT_MAX_EDGE_PX: number = 1920;

/** 解析 PiP 内容尺寸所需的页面快照 */
export interface VideoPipSizeContext {
  isLandscapeMode: boolean;
  videoWinClass?: window.Window;
  videoPixelSize?: VideoPipContentSize;
  storedVideoInfo?: VideoPipContentSize;
}

/**
 * 计算画中画 contentWidth/contentHeight（px）。
 * 优先片源宽高比：横屏整窗矩形会把 PiP 撑成 ~1146×480，而视频 dst 仅 ~860×361，黑边闪现更明显。
 *
 * @param context 当前播放页布局与视频元数据快照
 * @returns 内容宽高
 */
export function resolveVideoPipContentSize(context: VideoPipSizeContext): VideoPipContentSize {
  const streamSize = normalizeVideoStreamSize(context.videoPixelSize, context.storedVideoInfo, context.isLandscapeMode);
  if (streamSize !== undefined) {
    HiLog.i(TAG, `resolve videoStream width=${streamSize.width} height=${streamSize.height} landscape=${context.isLandscapeMode}`);
    return streamSize;
  }

  // 无片源元数据时再退回窗口矩形，并压到比例上限
  if (context.videoWinClass !== undefined) {
    try {
      const windowRect = context.videoWinClass.getWindowProperties().windowRect;
      if (windowRect.width > 0 && windowRect.height > 0) {
        const windowSize = reducePipContentSize(windowRect.width, windowRect.height);
        HiLog.i(TAG, `resolve windowFallback width=${windowSize.width} height=${windowSize.height}`);
        return windowSize;
      }
    } catch (exception) {
      HiLog.e(TAG, `resolve windowRect failed: ${JSON.stringify(exception)}`);
    }
  }

  const defaultSize: VideoPipContentSize = {
    width: VideoPipConstants.DEFAULT_CONTENT_WIDTH_PX,
    height: VideoPipConstants.DEFAULT_CONTENT_HEIGHT_PX,
  };
  return defaultSize;
}

/**
 * 取 AVPlayer 或缓存元数据尺寸；横屏时对竖屏编码流做宽高交换。
 */
function normalizeVideoStreamSize(
  videoPixelSize: VideoPipContentSize | undefined,
  storedVideoInfo: VideoPipContentSize | undefined,
  isLandscapeMode: boolean,
): VideoPipContentSize | undefined {
  let width = 0;
  let height = 0;
  if (videoPixelSize !== undefined) {
    width = videoPixelSize.width;
    height = videoPixelSize.height;
  } else if (storedVideoInfo !== undefined) {
    width = storedVideoInfo.width;
    height = storedVideoInfo.height;
  }
  if (width <= 0 || height <= 0) {
    return undefined;
  }
  if (isLandscapeMode && width < height) {
    const swapped = width;
    width = height;
    height = swapped;
  }
  return reducePipContentSize(width, height);
}

/**
 * 保持宽高比，将长边压到上限并对齐偶数，避免 PiP 比例参数携带片源 4K 像素。
 */
function reducePipContentSize(width: number, height: number): VideoPipContentSize {
  const longEdge = Math.max(width, height);
  if (longEdge <= PIP_CONTENT_MAX_EDGE_PX) {
    const size: VideoPipContentSize = {
      width: alignEvenPx(width),
      height: alignEvenPx(height),
    };
    return size;
  }
  const scale = PIP_CONTENT_MAX_EDGE_PX / longEdge;
  const size: VideoPipContentSize = {
    width: alignEvenPx(width * scale),
    height: alignEvenPx(height * scale),
  };
  return size;
}

/**
 * 将系统 PiP 窗口尺寸换算为显示像素。
 * 只做对齐，不压高度，避免改变宽高比导致拉伸。
 */
export function resolvePipDisplaySurfaceSize(windowWidth: number, windowHeight: number,
  windowScale: number): VideoPipContentSize | undefined {
  if (windowWidth <= 0 || windowHeight <= 0) {
    return undefined;
  }
  const scale = windowScale > 0 ? windowScale : 1;
  const width = alignSurfacePx(Math.round(windowWidth * scale));
  const height = alignSurfacePx(Math.round(windowHeight * scale));
  if (width < 4 || height < 4) {
    return undefined;
  }
  const displaySize: VideoPipContentSize = { width: width, height: height };
  return displaySize;
}
