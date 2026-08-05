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
import { HiLog } from './HiLog';
import { BusinessError } from '@ohos.base';
import DeviceConfigUtil from './DeviceConfigUtil';
import { DeviceTypeUtil } from './DeviceTypeUtil';
import { PlayConstants } from '../constants/player/PlayConstants';
import { SafeAreaConstants } from '../constants/ui/SafeAreaConstants';
import { syncAppLocalStorageSafeArea } from '../storage/AppLocalStorage';
import { AppThemeModeHelper } from './AppThemeModeHelper';

let TAG = 'WindowUtil';

/** 进入播放页前的窗口方向快照，用于退出时恢复壳层横竖屏 */
export interface OrientationSnapshot {
  isLandscape: boolean;
  preferredOrientation: window.Orientation;
}

const ORIENTATION_APPLY_DELAY_MS: number = 50;

/** 透明状态栏：上滑多任务时图标浮在壁纸/背景上，不出现底色通条（与系统电话应用一致） */
const STATUS_BAR_TRANSPARENT: string = '#00000000';

const PLAYER_DARK_BAR_PROPERTIES: window.SystemBarProperties = {
  statusBarColor: '#FF000000',
  navigationBarColor: '#FF000000',
  statusBarContentColor: '#FFFFFFFF',
  navigationBarContentColor: '#FFFFFFFF',
};

const PLAYER_LIGHT_BAR_PROPERTIES: window.SystemBarProperties = {
  statusBarColor: STATUS_BAR_TRANSPARENT,
  navigationBarColor: '#FFF2F2F7',
  statusBarContentColor: '#FF000000',
  navigationBarContentColor: '#FF000000',
};

/** 播放器页系统栏：随应用深浅色模式切换 */
function buildPlayerSystemBarProperties(): window.SystemBarProperties {
  if (AppThemeModeHelper.isDarkMode()) {
    return PLAYER_DARK_BAR_PROPERTIES;
  }
  return PLAYER_LIGHT_BAR_PROPERTIES;
}

/** 应用主壳系统栏：状态栏透明，页面背景由 Index expandSafeArea 绘制；导航栏仍与页面同色 */
function buildAppMainImmersiveBarProperties(): window.SystemBarProperties {
  if (AppThemeModeHelper.isDarkMode()) {
    return {
      statusBarColor: STATUS_BAR_TRANSPARENT,
      navigationBarColor: '#FF000000',
      statusBarContentColor: '#FFFFFFFF',
      navigationBarContentColor: '#FFFFFFFF',
    };
  }
  return {
    statusBarColor: STATUS_BAR_TRANSPARENT,
    navigationBarColor: '#FFF2F2F7',
    statusBarContentColor: '#FF000000',
    navigationBarContentColor: '#FF000000',
  };
}

/** 与 theme_page_background 一致，透明状态栏或未铺满时避免露出错误窗口底色 */
function buildAppWindowBackgroundArgb(): string {
  if (AppThemeModeHelper.isDarkMode()) {
    return '#FF000000';
  }
  return '#FFF2F2F7';
}

export default class WindowUtil {
  private static playerDarkBarsEnabled: boolean = false;
  /** 视频播放页存活期间为 true（含横屏藏栏），回前台不得刷浅灰底色 */
  private static videoPlayerPageActive: boolean = false;
  /** PiP 进/出迁窗静默期：回前台完全跳过壳层 chrome，避免闪一下 */
  private static pipTransitionQuiet: boolean = false;
  private static appAvoidAreaListenerBound: boolean = false;
  /** 系统权限半模态展示中：避免避让区监听把底部 inset 写回导致弹窗悬空 */
  private static permissionSheetChromeActive: boolean = false;
  private isPCConfig: boolean = DeviceConfigUtil.checkConfigForPC();

  /**
   * 视频播放页进/出：标记页仍在栈上，避免 PiP 还原时 onForeground 刷 #FFF2F2F7 闪一下。
   */
  public static setVideoPlayerPageActive(active: boolean): void {
    WindowUtil.videoPlayerPageActive = active;
    HiLog.i(TAG, `setVideoPlayerPageActive active=${active}`);
  }

  public static isVideoPlayerPageActive(): boolean {
    return WindowUtil.videoPlayerPageActive;
  }

  public static setPipTransitionQuiet(quiet: boolean): void {
    WindowUtil.pipTransitionQuiet = quiet;
    HiLog.i(TAG, `setPipTransitionQuiet quiet=${quiet}`);
  }

  public static isPipTransitionQuiet(): boolean {
    return WindowUtil.pipTransitionQuiet;
  }

  /** 视频页/PiP 还原：强制纯黑窗口底，覆盖浅灰壳层底色 */
  public static async applyVideoWindowBackgroundColor(windowClass: window.Window): Promise<void> {
    if (!windowClass) {
      return;
    }
    try {
      await windowClass.setWindowBackgroundColor('#FF000000');
      HiLog.i(TAG, 'applyVideoWindowBackgroundColor color=#FF000000');
    } catch (err) {
      const error = err as BusinessError;
      HiLog.w(TAG, `applyVideoWindowBackgroundColor failed message=${error.message} code=${error.code}`);
    }
  }

  public setWindowSystemBarEnable(windowClass: window.Window, names: ('status' | 'navigation')[]) {
    try {
      windowClass.setWindowSystemBarEnable(names);
      HiLog.i(TAG, `setWindowSystemBarEnable: names: ${JSON.stringify(names)}`);
    } catch (err) {
      let error = err as BusinessError;
      HiLog.e(TAG, `Failed to set window SystemBarEnable. Cause: ${error.message} code: ${error.code}`);
    }
  }

  public async setWindowFullScreen(windowClass: window.Window, isFull: boolean): Promise<void> {
    try {
      HiLog.i(TAG, `setWindowFullScreen`);
      await windowClass.setWindowLayoutFullScreen(isFull);
      HiLog.i(TAG, 'Succeeded in setting window layout to full-screen mode.');
    } catch (exception) {
      HiLog.e(TAG, `Failed to set window layout to full-screen mode. Cause:${JSON.stringify(exception)}`);
    }
  }

  public async setPCWindowFullScreen(windowClass: window.Window, isFull: boolean): Promise<void> {
    if (!windowClass) {
      HiLog.e(TAG, `setPCWindowFullScreen failed, windowClass is undefined`);
      return;
    }
    try {
      if (isFull) {
        await windowClass.maximize(window.MaximizePresentation.ENTER_IMMERSIVE);
      } else {
        await windowClass.restore();
      }
      HiLog.i(TAG, 'Succeeded in setting window layout to full-screen mode.');
    } catch (exception) {
      HiLog.e(TAG, `Failed to set window layout to full-screen mode. Cause:${JSON.stringify(exception)}`);
    }
  }

  public async setWindowBrightness(windowClass: window.Window, bright: number): Promise<void> {
    if (!windowClass) {
      HiLog.e(TAG, `setWindowBrightness, windowClass is undefined`);
      return;
    }
    if (!Number.isFinite(bright) || bright < PlayConstants.MIN_VALUE || bright > PlayConstants.MAX_VALUE) {
      HiLog.e(TAG, `setWindowBrightness invalid bright=${bright}`);
      return;
    }
    try {
      await windowClass.setWindowBrightness(bright);
      HiLog.i(TAG, `setWindowBrightness, bright=${bright}`);
    } catch (err) {
      let error = err as BusinessError;
      HiLog.e(TAG, `Failed to set window brightness. Cause: ${error.message} code: ${error.code}`);
    }
  }

  public getCurrentBrightness(windowClass: window.Window | undefined): number {
    if (!windowClass) {
      HiLog.e(TAG, `getCurrentBrightness, windowClass is undefined`);
      return PlayConstants.PLAY_PAGE_DEFAULT_BRIGHTNESS;
    }
    let windowBrightness: number = PlayConstants.PLAY_PAGE_DEFAULT_BRIGHTNESS;
    try {
      windowBrightness = windowClass.getWindowProperties().brightness;
      HiLog.i(TAG, `getCurrentBrightness, windowBrightness=${windowBrightness}`);
    } catch (error) {
      HiLog.e(TAG, `error code: ${error.code}, error msg: ${error.message}.`);
      return PlayConstants.PLAY_PAGE_DEFAULT_BRIGHTNESS;
    }
    if (!Number.isFinite(windowBrightness)) {
      HiLog.w(TAG, `getCurrentBrightness invalid=${windowBrightness}, use default`);
      return PlayConstants.PLAY_PAGE_DEFAULT_BRIGHTNESS;
    }
    if (this.isPCConfig || windowBrightness === PlayConstants.FOLLOW_SYSTEM_BRIGHTNESS) {
      return PlayConstants.FOLLOW_SYSTEM_BRIGHTNESS;
    }
    return Math.min(PlayConstants.MAX_VALUE, Math.max(PlayConstants.MIN_VALUE, windowBrightness));
  }

  public getWindowProperties(windowClass: window.Window) {
    if (!windowClass) {
      HiLog.e(TAG, 'getWindowProperties windowClass is null');
      return undefined;
    }
    try {
      let windowProperties = windowClass.getWindowProperties();
      return windowProperties;
    } catch (err) {
      let error = err as BusinessError;
      HiLog.e(TAG, `Failed to get window properties. Cause: ${error.message} code: ${error.code}`);
      return undefined;
    }
  }

  public recover(windowClass: window.Window) {
    if (!windowClass) {
      HiLog.e(TAG, `recover, windowClass is undefined`);
      return;
    }
    try {
      windowClass.restore();
      HiLog.i(TAG, `restore window`);
    } catch (err) {
      let error = err as BusinessError;
      HiLog.e(TAG, `recover window error, message:${error.message} code:${error.code}`);
    }
  }

  public static getCurrentBrightness(windowClass: window.Window | undefined): number {
    let instance = new WindowUtil();
    return instance.getCurrentBrightness(windowClass);
  }

  public static setWindowBrightness(windowClass: window.Window, bright: number): Promise<void> {
    let instance = new WindowUtil();
    return instance.setWindowBrightness(windowClass, bright);
  }

  public static setWindowSystemBarEnable(windowClass: window.Window, names: ('status' | 'navigation')[]) {
    let instance = new WindowUtil();
    instance.setWindowSystemBarEnable(windowClass, names);
  }

  public setWindowSystemBarProperties(windowClass: window.Window, properties: window.SystemBarProperties) {
    try {
      windowClass.setWindowSystemBarProperties(properties);
      HiLog.i(TAG, `setWindowSystemBarProperties: ${JSON.stringify(properties)}`);
    } catch (err) {
      let error = err as BusinessError;
      HiLog.e(TAG, `Failed to set window system bar properties. Cause: ${error.message} code: ${error.code}`);
    }
  }

  public static setWindowSystemBarProperties(windowClass: window.Window, properties: window.SystemBarProperties) {
    let instance = new WindowUtil();
    instance.setWindowSystemBarProperties(windowClass, properties);
  }

  public static setWindowLayoutFullScreen(windowClass: window.Window, isFull: boolean): Promise<void> {
    const instance = new WindowUtil();
    return instance.setWindowFullScreen(windowClass, isFull);
  }

  public static setPlayerDarkSystemBarProperties(windowClass: window.Window): void {
    WindowUtil.setWindowSystemBarProperties(windowClass, buildPlayerSystemBarProperties());
  }

  /** handleSystemBar 异步 enable 完成后仅刷新颜色，避免重复 enable 导致闪烁和卡顿 */
  public static refreshPlayerDarkSystemBarColors(windowClass: window.Window): void {
    if (!windowClass) {
      return;
    }
    WindowUtil.setPlayerDarkSystemBarProperties(windowClass);
  }

  private static enablePlayerDarkSystemBars(windowClass: window.Window): void {
    try {
      windowClass.setWindowSystemBarEnable(['status', 'navigation'], (err: BusinessError) => {
        if (err.code) {
          HiLog.e(TAG, `Failed to enable player system bars. Cause: ${err.message} code: ${err.code}`);
          return;
        }
        WindowUtil.playerDarkBarsEnabled = true;
        WindowUtil.setPlayerDarkSystemBarProperties(windowClass);
        // 系统栏恢复后避让区滞后更新，立即同步供 TitleBar inset 使用
        WindowUtil.syncAppSafeAreaToStorage(windowClass);
      });
    } catch (exception) {
      HiLog.e(TAG, `Failed to enable player system bars. Cause: ${JSON.stringify(exception)}`);
      WindowUtil.setWindowSystemBarEnable(windowClass, ['status', 'navigation']);
      WindowUtil.playerDarkBarsEnabled = true;
      WindowUtil.setPlayerDarkSystemBarProperties(windowClass);
      WindowUtil.syncAppSafeAreaToStorage(windowClass);
    }
  }

  public static applyDarkVideoSystemBars(windowClass: window.Window, showBars: boolean): void {
    if (!windowClass) {
      return;
    }
    if (showBars) {
      WindowUtil.applyPlayerDarkSystemBars(windowClass);
      return;
    }
    // 视频横屏隐藏系统栏后必须重置标记，回到竖屏时才会重新 enable，避免状态栏不恢复。
    WindowUtil.playerDarkBarsEnabled = false;
    try {
      windowClass.setWindowSystemBarEnable([], (err: BusinessError) => {
        if (err.code) {
          HiLog.e(TAG, `Failed to hide system bars. Cause: ${err.message} code: ${err.code}`);
        }
      });
    } catch (exception) {
      WindowUtil.setWindowSystemBarEnable(windowClass, []);
    }
  }

  /** 播放器黑色系统栏：同一会话内仅 enable 一次，后续只刷新颜色属性 */
  public static applyPlayerDarkSystemBars(windowClass: window.Window): void {
    if (!windowClass) {
      return;
    }
    if (WindowUtil.playerDarkBarsEnabled) {
      WindowUtil.setPlayerDarkSystemBarProperties(windowClass);
      return;
    }
    WindowUtil.enablePlayerDarkSystemBars(windowClass);
  }

  private static lastSyncedStatusBarHeightVp: number = -1;
  private static lastSyncedNaviIndicatorHeightVp: number = -1;

  /**
   * 读取窗口实时状态栏避让高度（vp）；系统栏隐藏时 topRect 为 0，此时返回 0。
   *
   * @param windowClass 主窗口实例
   * @returns 状态栏避让高度（vp）
   */
  public static getStatusBarInsetVp(windowClass: window.Window | undefined): number {
    if (!windowClass) {
      return 0;
    }
    try {
      const systemArea = windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const systemTopPx = systemArea.topRect.height;
      if (systemTopPx <= 0) {
        return 0;
      }
      const cutoutArea = windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_CUTOUT);
      return px2vp(Math.max(systemTopPx, cutoutArea.topRect.height));
    } catch (err) {
      const error = err as BusinessError;
      HiLog.e(TAG, `getStatusBarInsetVp failed message=${error.message} code=${error.code}`);
      return 0;
    }
  }

  /**
   * 读取窗口顶部刘海/挖孔避让高度（vp）；横屏隐藏系统栏时仍可用于顶栏贴顶避让。
   *
   * @param windowClass 主窗口实例
   * @returns cutout 顶部避让高度（vp）
   */
  public static getCutoutTopInsetVp(windowClass: window.Window | undefined): number {
    if (!windowClass) {
      return 0;
    }
    try {
      const cutoutArea = windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_CUTOUT);
      const topPx = cutoutArea.topRect.height;
      if (topPx <= 0) {
        return 0;
      }
      return px2vp(topPx);
    } catch (err) {
      const error = err as BusinessError;
      HiLog.e(TAG, `getCutoutTopInsetVp failed message=${error.message} code=${error.code}`);
      return 0;
    }
  }

  /** 同步系统避让区到 AppStorage，供 MainPage 等页面按状态栏/导航条高度做 padding */
  private static syncAppSafeAreaToStorage(windowClass: window.Window): void {
    // 权限半模态期间冻结避让区，避免底栏/迷你播放器随 naviIndicatorHeight 变化而位移
    if (WindowUtil.permissionSheetChromeActive) {
      return;
    }
    try {
      const systemArea = windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const cutoutArea = windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_CUTOUT);
      const navArea = windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      const systemTopPx = systemArea.topRect.height;
      const cutoutTopPx = cutoutArea.topRect.height;
      const bottomPx = Math.max(navArea.bottomRect.height, systemArea.bottomRect.height);
      const naviIndicatorHeight = px2vp(bottomPx);
      // 横屏隐藏系统栏时 systemTopPx 为 0，勿仅用 cutout 覆写 AppStorage，避免 Nav 顶距偏大
      let statusBarHeight: number = WindowUtil.lastSyncedStatusBarHeightVp >= 0 ?
        WindowUtil.lastSyncedStatusBarHeightVp : 0;
      if (systemTopPx > 0) {
        statusBarHeight = px2vp(Math.max(systemTopPx, cutoutTopPx));
      }
      if (statusBarHeight === WindowUtil.lastSyncedStatusBarHeightVp &&
        naviIndicatorHeight === WindowUtil.lastSyncedNaviIndicatorHeightVp) {
        return;
      }
      WindowUtil.lastSyncedStatusBarHeightVp = statusBarHeight;
      WindowUtil.lastSyncedNaviIndicatorHeightVp = naviIndicatorHeight;
      AppStorage.set<number>(SafeAreaConstants.STATUS_BAR_HEIGHT_KEY, statusBarHeight);
      AppStorage.set<number>(SafeAreaConstants.NAVI_INDICATOR_HEIGHT_KEY, naviIndicatorHeight);
      syncAppLocalStorageSafeArea();
      HiLog.i(TAG, `syncAppSafeArea statusBarHeight=${statusBarHeight} naviIndicatorHeight=${naviIndicatorHeight}`);
    } catch (err) {
      const error = err as BusinessError;
      HiLog.e(TAG, `Failed to sync app safe area. Cause: ${error.message} code: ${error.code}`);
    }
  }

  /**
   * 从窗口实时读取避让区并写入 AppStorage / LocalStorage（播放器打开时调用）。
   *
   * @param windowClass 主窗口实例
   */
  public static refreshAppSafeArea(windowClass: window.Window): void {
    if (!windowClass) {
      return;
    }
    WindowUtil.syncAppSafeAreaToStorage(windowClass);
  }

  /** 首页沉浸式系统栏：显示状态栏/导航栏并与 MainPage 背景色一致 */
  private static applyAppMainSystemBars(windowClass: window.Window): void {
    WindowUtil.playerDarkBarsEnabled = false;
    WindowUtil.setWindowSystemBarEnable(windowClass, ['status', 'navigation']);
    WindowUtil.setWindowSystemBarProperties(windowClass, buildAppMainImmersiveBarProperties());
    WindowUtil.syncAppSafeAreaToStorage(windowClass);
  }

  /** 主题切换后刷新首页系统栏（非播放器深色栏场景） */
  public static refreshAppMainSystemBars(windowClass: window.Window): void {
    if (WindowUtil.playerDarkBarsEnabled || WindowUtil.permissionSheetChromeActive) {
      return;
    }
    WindowUtil.applyAppMainSystemBars(windowClass);
  }

  /**
   * 设置窗口底色与页面灰底一致，避免沉浸式/透明状态栏区域露出白底
   *
   * @param windowClass 主窗口实例
   */
  public static async applyAppWindowBackgroundColor(windowClass: window.Window): Promise<void> {
    if (!windowClass) {
      return;
    }
    try {
      await windowClass.setWindowBackgroundColor(buildAppWindowBackgroundArgb());
      HiLog.i(TAG, `applyAppWindowBackgroundColor color=${buildAppWindowBackgroundArgb()}`);
    } catch (err) {
      const error = err as BusinessError;
      HiLog.w(TAG, `applyAppWindowBackgroundColor failed message=${error.message} code=${error.code}`);
    }
  }

  /**
   * 注册避让区变化监听，折叠屏旋转等场景下自动刷新 AppStorage 中的安全区高度。
   *
   * @param windowClass 主窗口实例
   */
  private static registerAppAvoidAreaListenerIfNeeded(windowClass: window.Window): void {
    if (WindowUtil.appAvoidAreaListenerBound) {
      return;
    }
    WindowUtil.appAvoidAreaListenerBound = true;
    try {
      windowClass.on('avoidAreaChange', (data: window.AvoidAreaOptions) => {
        if (data.type === window.AvoidAreaType.TYPE_SYSTEM ||
          data.type === window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR ||
          data.type === window.AvoidAreaType.TYPE_CUTOUT) {
          WindowUtil.syncAppSafeAreaToStorage(windowClass);
        }
      });
      HiLog.i(TAG, 'registerAppAvoidAreaListener bound');
    } catch (err) {
      const error = err as BusinessError;
      HiLog.e(TAG, `Failed to register avoidAreaChange listener. Cause: ${error.message} code: ${error.code}`);
      WindowUtil.appAvoidAreaListenerBound = false;
    }
  }

  /**
   * 读取当前窗口横竖屏快照（进入播放页前调用）。
   *
   * @param windowClass 主窗口实例
   * @returns 横竖屏与对应首选方向
   */
  public static captureOrientationSnapshot(windowClass: window.Window): OrientationSnapshot {
    try {
      const windowRect = windowClass.getWindowProperties().windowRect;
      const isLandscape = windowRect.width > windowRect.height;
      return {
        isLandscape,
        preferredOrientation: isLandscape ?
          window.Orientation.LANDSCAPE : window.Orientation.PORTRAIT,
      };
    } catch (err) {
      const error = err as BusinessError;
      HiLog.e(TAG, `captureOrientationSnapshot failed message=${error.message} code=${error.code}`);
      return {
        isLandscape: false,
        preferredOrientation: window.Orientation.PORTRAIT,
      };
    }
  }

  private static delayForOrientationApply(): Promise<void> {
    return new Promise((resolve) => {
      setTimeout(() => resolve(), ORIENTATION_APPLY_DELAY_MS);
    });
  }

  /**
   * 退出播放页后恢复壳层方向：先恢复到进入前横竖屏，再切回受旋转锁定约束的自动旋转。
   *
   * @param windowClass 主窗口实例
   * @param snapshot 进入播放页前的方向快照，为 null 时仅恢复自动旋转策略
   */
  public static async restoreShellOrientation(
    windowClass: window.Window,
    snapshot: OrientationSnapshot | null
  ): Promise<void> {
    if (!windowClass || DeviceTypeUtil.isPC()) {
      return;
    }
    try {
      if (snapshot !== null) {
        windowClass.setPreferredOrientation(snapshot.preferredOrientation);
        await WindowUtil.delayForOrientationApply();
      }
      windowClass.setPreferredOrientation(window.Orientation.AUTO_ROTATION_RESTRICTED);
      HiLog.i(TAG, `restoreShellOrientation landscape=${snapshot?.isLandscape ?? 'null'}`);
    } catch (err) {
      const error = err as BusinessError;
      HiLog.e(TAG, `restoreShellOrientation failed message=${error.message} code=${error.code}`);
      WindowUtil.applyAppAutoRotation(windowClass);
    }
  }

  /**
   * 音频全屏页方向：真手机锁竖屏；大屏横屏保持横屏；其余跟随传感器；PC 不处理。
   *
   * @param windowClass 主窗口实例
   */
  public static applyAudioPlaybackOrientation(windowClass: window.Window): void {
    if (!windowClass || DeviceTypeUtil.isPC()) {
      return;
    }
    try {
      if (DeviceTypeUtil.shouldLockAudioPortrait()) {
        windowClass.setPreferredOrientation(window.Orientation.PORTRAIT);
        HiLog.i(TAG, 'applyAudioPlaybackOrientation phone portrait lock');
        return;
      }
      const snapshot = WindowUtil.captureOrientationSnapshot(windowClass);
      if (snapshot.isLandscape) {
        windowClass.setPreferredOrientation(window.Orientation.LANDSCAPE);
        HiLog.i(TAG, 'applyAudioPlaybackOrientation large-screen landscape keep');
      } else {
        windowClass.setPreferredOrientation(window.Orientation.AUTO_ROTATION_RESTRICTED);
        HiLog.i(TAG, 'applyAudioPlaybackOrientation large-screen auto rotation restricted');
      }
    } catch (err) {
      const error = err as BusinessError;
      HiLog.e(TAG, `applyAudioPlaybackOrientation failed message=${error.message} code=${error.code}`);
    }
  }

  /**
   * 手机/平板主壳层跟随传感器旋转，且受控制中心「旋转锁定」约束（PC 固定窗口不设置）。
   *
   * @param windowClass 主窗口实例
   */
  public static applyAppAutoRotation(windowClass: window.Window): void {
    if (!windowClass || DeviceTypeUtil.isPC()) {
      return;
    }
    try {
      windowClass.setPreferredOrientation(window.Orientation.AUTO_ROTATION_RESTRICTED);
      HiLog.i(TAG, 'applyAppAutoRotation restricted done');
    } catch (err) {
      const error = err as BusinessError;
      HiLog.e(TAG, `applyAppAutoRotation failed message=${error.message} code=${error.code}`);
    }
  }

  /** 系统权限半模态是否仍在展示（供 Ability 回前台时判断是否跳过 chrome 恢复） */
  public static isPermissionSheetChromeActive(): boolean {
    return WindowUtil.permissionSheetChromeActive;
  }

  /**
   * 权限半模态窗口 chrome：仅隐藏导航条指示器，不改动系统栏/AppStorage 避让区。
   * 系统半模态由 PermissionManager 全屏覆盖，无需隐藏状态栏或清零 inset。
   */
  private static async disablePermissionSheetNavigationIndicator(windowClass: window.Window): Promise<void> {
    try {
      await windowClass.setSpecificSystemBarEnabled('navigationIndicator', false, false);
    } catch (err) {
      const error = err as BusinessError;
      HiLog.w(TAG, `disablePermissionSheetNavigationIndicator failed: ${error.message}`);
    }
  }

  private static async enablePermissionSheetNavigationIndicator(windowClass: window.Window): Promise<void> {
    try {
      await windowClass.setSpecificSystemBarEnabled('navigationIndicator', true, false);
    } catch (err) {
      const error = err as BusinessError;
      HiLog.w(TAG, `enablePermissionSheetNavigationIndicator failed: ${error.message}`);
    }
  }

  /**
   * 权限半模态进行中回前台：重新隐藏导航条指示器，不触碰 AppStorage 避让区。
   *
   * @param windowClass 主窗口实例
   */
  public static async reassertSystemPermissionSheetChrome(windowClass: window.Window | undefined): Promise<void> {
    if (!windowClass || !WindowUtil.permissionSheetChromeActive) {
      return;
    }
    HiLog.i(TAG, 'reassertSystemPermissionSheetChrome disable navigation indicator only');
    await WindowUtil.disablePermissionSheetNavigationIndicator(windowClass);
  }

  /**
   * 应用壳层窗口 chrome 恢复：全屏布局 + 窗口底色 + 同步避让区（应在 Ability 启动/回前台统一调用）。
   * 播放器页活跃时不覆盖播放器系统栏色，仅恢复布局与底色，避免底部上滑后状态栏通条异常。
   * 权限半模态展示中跳过系统栏恢复，改为重新隐藏导航栏，避免回前台后弹窗底部留白。
   *
   * @param windowClass 主窗口实例
   */
  public static async reapplyAppWindowChrome(windowClass: window.Window): Promise<void> {
    if (!windowClass) {
      return;
    }
    if (WindowUtil.permissionSheetChromeActive) {
      HiLog.i(TAG, 'reapplyAppWindowChrome skipped: permission sheet active, reasserting chrome');
      await WindowUtil.reassertSystemPermissionSheetChrome(windowClass);
      return;
    }
    // PiP 迁窗静默 / 视频页：完全跳过壳层刷新（日志 #FFF2F2F7 会闪一下就消失）
    if (WindowUtil.pipTransitionQuiet || WindowUtil.videoPlayerPageActive) {
      HiLog.i(TAG,
        `reapplyAppWindowChrome skipped video/pip quiet=${WindowUtil.pipTransitionQuiet} videoPage=${WindowUtil.videoPlayerPageActive}`);
      await WindowUtil.applyVideoWindowBackgroundColor(windowClass);
      return;
    }
    HiLog.i(TAG, `reapplyAppWindowChrome playerBars=${WindowUtil.playerDarkBarsEnabled}`);
    await WindowUtil.setWindowLayoutFullScreen(windowClass, true);
    if (WindowUtil.playerDarkBarsEnabled) {
      await WindowUtil.applyVideoWindowBackgroundColor(windowClass);
    } else {
      await WindowUtil.applyAppWindowBackgroundColor(windowClass);
    }
    WindowUtil.registerAppAvoidAreaListenerIfNeeded(windowClass);
    WindowUtil.syncAppSafeAreaToStorage(windowClass);
    if (!WindowUtil.playerDarkBarsEnabled) {
      WindowUtil.applyAppMainSystemBars(windowClass);
      WindowUtil.applyAppAutoRotation(windowClass);
    }
  }

  /**
   * 冷启动应用级沉浸式：全屏布局 + 首页系统栏 + 避让区监听（仅 MainAbility 调用）。
   *
   * @param windowClass 主窗口实例
   */
  public static async applyAppImmersiveMode(windowClass: window.Window): Promise<void> {
    if (!windowClass) {
      HiLog.e(TAG, 'applyAppImmersiveMode failed, windowClass is undefined');
      return;
    }
    HiLog.i(TAG, 'applyAppImmersiveMode start');
    WindowUtil.playerDarkBarsEnabled = false;
    await WindowUtil.reapplyAppWindowChrome(windowClass);
    HiLog.i(TAG, 'applyAppImmersiveMode done');
  }

  /** 退出播放器后恢复首页沉浸式系统栏、全屏布局与受旋转锁定约束的自动旋转 */
  public static restoreDefaultSystemBars(windowClass: window.Window): void {
    if (!windowClass) {
      return;
    }
    WindowUtil.playerDarkBarsEnabled = false;
    WindowUtil.reapplyAppWindowChrome(windowClass)
      .catch((exception: BusinessError) => {
        HiLog.e(TAG, `restoreDefaultSystemBars failed message=${exception.message}`);
      });
  }

  /**
   * 退出音频播放页：恢复系统栏与壳层 chrome，并按快照恢复横竖屏。
   *
   * @param windowClass 主窗口实例
   * @param snapshot 进入播放页前的方向快照
   */
  public static restoreDefaultSystemBarsWithOrientation(
    windowClass: window.Window,
    snapshot: OrientationSnapshot | null
  ): void {
    if (!windowClass) {
      return;
    }
    WindowUtil.playerDarkBarsEnabled = false;
    WindowUtil.reapplyAppWindowChrome(windowClass)
      .then(() => WindowUtil.restoreShellOrientation(windowClass, snapshot))
      .catch((exception: BusinessError) => {
        HiLog.e(TAG, `restoreDefaultSystemBarsWithOrientation failed message=${exception.message}`);
        WindowUtil.restoreShellOrientation(windowClass, snapshot);
      });
  }

  public static setPCWindowFullScreen(windowClass: window.Window, isFull: boolean): Promise<void> {
    let instance = new WindowUtil();
    return instance.setPCWindowFullScreen(windowClass, isFull);
  }

  /**
   * 系统权限半模态弹出前：仅隐藏导航条指示器并冻结 AppStorage 避让区，避免播放器/迷你播放器底栏位移。
   *
   * @param windowClass 主窗口实例
   */
  public static async prepareSystemPermissionSheet(windowClass: window.Window | undefined): Promise<void> {
    if (!windowClass || WindowUtil.permissionSheetChromeActive) {
      return;
    }
    WindowUtil.permissionSheetChromeActive = true;
    HiLog.i(TAG, 'prepareSystemPermissionSheet disable navigation indicator only, freeze safe area');
    await WindowUtil.disablePermissionSheetNavigationIndicator(windowClass);
  }

  /**
   * 系统权限半模态关闭后恢复导航条指示器与避让区（播放器页恢复深色栏，首页恢复沉浸式栏）。
   *
   * @param windowClass 主窗口实例
   */
  public static async restoreAfterSystemPermissionSheet(windowClass: window.Window | undefined): Promise<void> {
    if (!WindowUtil.permissionSheetChromeActive) {
      return;
    }
    WindowUtil.permissionSheetChromeActive = false;
    HiLog.i(TAG, `restoreAfterSystemPermissionSheet playerBars=${WindowUtil.playerDarkBarsEnabled}`);
    if (!windowClass) {
      return;
    }
    await WindowUtil.enablePermissionSheetNavigationIndicator(windowClass);
    WindowUtil.syncAppSafeAreaToStorage(windowClass);
    if (WindowUtil.playerDarkBarsEnabled) {
      WindowUtil.applyPlayerDarkSystemBars(windowClass);
      return;
    }
  }
}
