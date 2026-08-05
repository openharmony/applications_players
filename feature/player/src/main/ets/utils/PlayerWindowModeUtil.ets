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
import display from '@ohos.display';
import { WindowType } from '@ohos/common/src/main/ets/constants/ui/Constants';
import { HiLog } from '@ohos/common';

const TAG: string = 'PlayerWindowModeUtil';

/**
 * 播放器窗口展示形态枚举。
 * 统一描述播放器当前所处的窗口模式，供 UI 布局、视频缩放策略等消费。
 */
export enum PlayerWindowMode {
  /** 手机竖屏全屏 */
  PORTRAIT_FULLSCREEN = 'portrait_fullscreen',
  /** 手机横屏全屏 */
  LANDSCAPE_FULLSCREEN = 'landscape_fullscreen',
  /** 分屏模式（含上下分屏与左右分屏） */
  SPLIT_SCREEN = 'split_screen',
  /** 悬浮窗模式 */
  FLOATING_WINDOW = 'floating_window',
  /** PC 窗口模式（非全屏） */
  PC_WINDOWED = 'pc_windowed',
  /** PC 沉浸全屏 */
  PC_FULLSCREEN = 'pc_fullscreen',
  /** UI 扩展窗口（如其他应用内嵌拉起） */
  UI_EXTENSION = 'ui_extension',
}

/**
 * 播放器窗口模式判断所需参数快照。
 */
export interface PlayerWindowModeParams {
  /** 是否 PC 设备配置（来自 DeviceConfigUtil.checkConfigForPC()） */
  isPCConfig: boolean;
  /** 当前主窗口实例（手机/平板场景必传，用于读取窗口矩形判断分屏/悬浮） */
  windowClass?: window.Window;
  /** 当前是否横屏（来自页面 @State isLandscapeMode 或窗口尺寸比较） */
  isLandscapeMode: boolean;
  /** PC 是否处于沉浸全屏（可选，默认 false） */
  isPcFullScreen?: boolean;
  /** 当前窗口类型（可选，默认 MAIN_WINDOW） */
  windowType?: WindowType;
}

/** 内部使用的窗口/屏幕快照，避免各方法重复获取 rect 和 display。 */
class WindowMetrics {
  public rect: window.Rect;
  public displayWidth: number;
  public displayHeight: number;

  constructor(rect: window.Rect, displayWidth: number, displayHeight: number) {
    this.rect = rect;
    this.displayWidth = displayWidth;
    this.displayHeight = displayHeight;
  }
}

/**
 * 播放器窗口模式工具类。
 *
 * 将分屏（上下/左右）、悬浮窗、横竖屏等窗口形态的判断逻辑集中管理，
 * 避免在 VideoPlayPage 与 VideoPlayerController 中重复实现相同检测。
 *
 * 使用方式：
 * 1. 构建 {@link PlayerWindowModeParams} 快照
 * 2. 调用静态方法获取窗口模式或布局策略
 *
 * @example
 * ```typescript
 * const params: PlayerWindowModeParams = {
 *   isPCConfig: this.isPCConfig,
 *   windowClass: this.videoWinClass,
 *   isLandscapeMode: this.isLandscapeMode,
 * };
 * if (PlayerWindowModeUtil.isPortraitPanelMode(params)) {
 *   // 使用竖屏 contain 布局
 * }
 * ```
 */
export class PlayerWindowModeUtil {
  /**
   * 安全读取窗口矩形与屏幕尺寸，统一处理 null/PC/try-catch 样板。
   *
   * @param windowClass 主窗口实例
   * @returns 窗口/屏幕快照；窗口不可用或发生异常时返回 null
   */
  private static fetchWindowMetrics(windowClass?: window.Window): WindowMetrics | null {
    if (!windowClass) {
      return null;
    }
    try {
      const rect = windowClass.getWindowProperties().windowRect;
      const curDisplay: display.Display = display.getDefaultDisplaySync();
      return new WindowMetrics(rect, curDisplay.width, curDisplay.height);
    } catch (e) {
      HiLog.e(TAG, `fetchWindowMetrics failed, code:${e?.code}, message:${e?.message}`);
      return null;
    }
  }

  /**
   * 判断是否处于分屏或悬浮窗等非全屏窗口模式。
   * PC 设备不存在分屏/悬浮窗机制，直接返回 false。
   *
   * 检测策略：
   * - 窗口位置非 (0,0) → 悬浮窗或非主半屏分屏
   * - 窗口尺寸小于显示区域 → 分屏（含主半屏）或悬浮窗
   *
   * @param windowClass 主窗口实例（手机/平板场景必传）
   * @param isPCConfig 是否 PC 设备配置
   * @returns 是否处于分屏或悬浮窗模式
   */
  static isInSplitOrFloatingMode(windowClass?: window.Window, isPCConfig?: boolean): boolean {
    if (isPCConfig) {
      return false;
    }
    const metrics = PlayerWindowModeUtil.fetchWindowMetrics(windowClass);
    if (metrics === null) {
      return false;
    }
    // 窗口位置非 (0,0) 说明处于分屏/悬浮模式
    if (metrics.rect.top !== 0 || metrics.rect.left !== 0) {
      return true;
    }
    // 窗口尺寸小于显示区域，说明处于分屏/悬浮模式
    return metrics.rect.width < metrics.displayWidth || metrics.rect.height < metrics.displayHeight;
  }

  /**
   * 判断是否为分屏模式（含上下分屏与左右分屏）。
   *
   * 分屏特征：窗口占满一维（全宽=上下分屏，或全高=左右分屏），
   * 另一维小于显示区域，且至少有一条边贴屏幕边缘（区分悬浮窗）。
   *
   * @param windowClass 主窗口实例
   * @returns 是否为分屏模式
   */
  static isSplitMode(windowClass?: window.Window): boolean {
    const metrics = PlayerWindowModeUtil.fetchWindowMetrics(windowClass);
    if (metrics === null) {
      return false;
    }
    return PlayerWindowModeUtil.isSplitByMetrics(metrics);
  }

  /**
   * 判断是否为上下分屏（窗口占满屏幕宽度、高度缩小，贴顶部或底部）。
   *
   * @param windowClass 主窗口实例
   * @returns 是否为上下分屏
   */
  static isSplitTopBottom(windowClass?: window.Window): boolean {
    const metrics = PlayerWindowModeUtil.fetchWindowMetrics(windowClass);
    if (metrics === null) {
      return false;
    }
    return PlayerWindowModeUtil.isSplitTopBottomByMetrics(metrics);
  }

  /**
   * 判断是否为左右分屏（窗口占满屏幕高度、宽度缩小，贴左侧或右侧）。
   *
   * @param windowClass 主窗口实例
   * @returns 是否为左右分屏
   */
  static isSplitLeftRight(windowClass?: window.Window): boolean {
    const metrics = PlayerWindowModeUtil.fetchWindowMetrics(windowClass);
    if (metrics === null) {
      return false;
    }
    return PlayerWindowModeUtil.isSplitLeftRightByMetrics(metrics);
  }

  /**
   * 判断是否为悬浮窗模式。
   *
   * 悬浮窗特征：窗口宽与高均小于显示区域（与分屏占满一维区分）。
   *
   * @param windowClass 主窗口实例
   * @returns 是否为悬浮窗模式
   */
  static isFloatingWindowMode(windowClass?: window.Window): boolean {
    const metrics = PlayerWindowModeUtil.fetchWindowMetrics(windowClass);
    if (metrics === null) {
      return false;
    }
    return PlayerWindowModeUtil.isFloatingByMetrics(metrics);
  }

  /**
   * 按优先级获取当前播放器窗口展示形态。
   *
   * 判定顺序：PC → UI 扩展窗口 → 悬浮窗 → 分屏 → 横屏全屏 → 竖屏全屏
   *
   * @param params 窗口模式判断参数
   * @returns 当前窗口模式枚举值
   */
  static getPlayerWindowMode(params: PlayerWindowModeParams): PlayerWindowMode {
    if (params.isPCConfig) {
      if (params.isPcFullScreen === true) {
        return PlayerWindowMode.PC_FULLSCREEN;
      }
      return PlayerWindowMode.PC_WINDOWED;
    }

    if (params.windowType === WindowType.UI_EXTENSION_WINDOW) {
      return PlayerWindowMode.UI_EXTENSION;
    }

    // 一次获取 metrics，复用给后续多个判断
    const metrics = PlayerWindowModeUtil.fetchWindowMetrics(params.windowClass);
    if (metrics !== null) {
      if (PlayerWindowModeUtil.isFloatingByMetrics(metrics)) {
        return PlayerWindowMode.FLOATING_WINDOW;
      }
      if (PlayerWindowModeUtil.isSplitByMetrics(metrics)) {
        return PlayerWindowMode.SPLIT_SCREEN;
      }
    }

    if (params.isLandscapeMode) {
      return PlayerWindowMode.LANDSCAPE_FULLSCREEN;
    }

    return PlayerWindowMode.PORTRAIT_FULLSCREEN;
  }

  /**
   * 判断是否竖屏视频面板模式。
   *
   * 手机设备在以下情况统一使用竖屏 contain 布局：
   * - 竖屏全屏
   * - 分屏（上下或左右）
   * - 悬浮窗
   *
   * 此方法与 VideoPlayPage 中原 isPortraitPanelMode() 行为完全一致。
   *
   * @param params 窗口模式判断参数
   * @returns 是否竖屏视频面板
   */
  static isPortraitPanelMode(params: PlayerWindowModeParams): boolean {
    if (params.isPCConfig) {
      return false;
    }
    // 分屏或悬浮窗统一使用竖屏 contain 布局
    if (PlayerWindowModeUtil.isInSplitOrFloatingMode(params.windowClass, params.isPCConfig)) {
      return true;
    }
    return !params.isLandscapeMode;
  }

  /**
   * 判断是否横屏全屏模式（手机横屏 + 主窗口 + 非分屏非悬浮）。
   *
   * @param params 窗口模式判断参数
   * @returns 是否横屏全屏
   */
  static isLandscapeFullscreen(params: PlayerWindowModeParams): boolean {
    const mode = PlayerWindowModeUtil.getPlayerWindowMode(params);
    return mode === PlayerWindowMode.LANDSCAPE_FULLSCREEN;
  }

  /**
   * 判断当前是否应使用 contain 等比布局。
   * 竖屏面板 / 分屏 / 悬浮窗 / UI 扩展窗口均使用 contain，仅横屏全屏与 PC 全屏使用 cover。
   *
   * @param params 窗口模式判断参数
   * @returns 是否使用 contain 布局
   */
  static shouldUseContainLayout(params: PlayerWindowModeParams): boolean {
    const mode = PlayerWindowModeUtil.getPlayerWindowMode(params);
    return mode !== PlayerWindowMode.LANDSCAPE_FULLSCREEN && mode !== PlayerWindowMode.PC_FULLSCREEN;
  }

  /**
   * 判断当前是否应使用 cover 铺满布局。
   *
   * @param params 窗口模式判断参数
   * @returns 是否使用 cover 布局
   */
  static shouldUseCoverLayout(params: PlayerWindowModeParams): boolean {
    return !PlayerWindowModeUtil.shouldUseContainLayout(params);
  }

  /**
   * 判断系统栏是否应该显示。
   * 与非视频页行为一致：仅竖屏主窗口显示系统栏，横屏 / PC / 非主窗口均隐藏。
   * 注意：此方法不引入分屏/悬浮窗强制竖屏逻辑，与原始 VideoPlaybackViewModel 行为一致。
   *
   * @param params 窗口模式判断参数
   * @returns 是否显示系统栏
   */
  static shouldShowSystemBars(params: PlayerWindowModeParams): boolean {
    if (params.isPCConfig) {
      return false;
    }
    const windowType = params.windowType ?? WindowType.MAIN_WINDOW;
    if (windowType !== WindowType.MAIN_WINDOW) {
      return false;
    }
    return !params.isLandscapeMode;
  }

  // ──────────────────────────────────────
  //  内部方法：基于已获取的 WindowMetrics 做纯计算，不重复访问系统 API
  // ──────────────────────────────────────

  /** 宽度严格小于显示区域且高度严格小于显示区域 → 悬浮窗 */
  private static isFloatingByMetrics(metrics: WindowMetrics): boolean {
    return metrics.rect.width < metrics.displayWidth && metrics.rect.height < metrics.displayHeight;
  }

  /** 占满一维（全宽=上下分屏，或全高=左右分屏），另一维缩小，且贴边 → 分屏 */
  private static isSplitByMetrics(metrics: WindowMetrics): boolean {
    const isPartialSize = metrics.rect.width < metrics.displayWidth ||
      metrics.rect.height < metrics.displayHeight;
    if (!isPartialSize) {
      return false;
    }
    const isFlushToEdge = metrics.rect.top === 0 || metrics.rect.left === 0;
    if (!isFlushToEdge) {
      return false;
    }
    return PlayerWindowModeUtil.isSplitTopBottomByMetrics(metrics) ||
      PlayerWindowModeUtil.isSplitLeftRightByMetrics(metrics);
  }

  /** 宽度占满 + 高度缩小 → 上下分屏 */
  private static isSplitTopBottomByMetrics(metrics: WindowMetrics): boolean {
    return metrics.rect.width >= metrics.displayWidth && metrics.rect.height < metrics.displayHeight;
  }

  /** 高度占满 + 宽度缩小 → 左右分屏 */
  private static isSplitLeftRightByMetrics(metrics: WindowMetrics): boolean {
    return metrics.rect.height >= metrics.displayHeight && metrics.rect.width < metrics.displayWidth;
  }
}
