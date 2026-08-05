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



import { HiLog } from '@ohos/common/src/main/ets/utils/HiLog';
import { AppNavRoutes } from '../constants/AppNavRoutes';
import { AppNavTransitionConstants } from '../constants/AppNavTransitionConstants';
import { HomeViewModel } from '../viewmodel/HomeViewModel';
import { PlaylistViewModel } from '../viewmodel/PlaylistViewModel';

const TAG = 'NavRouterHelper';

/**
 * 统一封装 NavPathStack push/pop，并在路由变更时同步 ViewModel 显隐状态
 */
export class NavRouterHelper {
  private static stack: NavPathStack | null = null;

  /**
   * 绑定 MainPage 提供的 NavPathStack
   *
   * @param stack 导航栈
   */
  public static attach(stack: NavPathStack): void {
    NavRouterHelper.stack = stack;
    NavRouterHelper.registerStackInterception();
    HiLog.i(TAG, 'attach NavPathStack');
  }

  /** 解绑导航栈（页面销毁时） */
  public static detach(): void {
    if (NavRouterHelper.stack !== null) {
      NavRouterHelper.stack.setInterception(undefined);
    }
    NavRouterHelper.stack = null;
    HiLog.i(TAG, 'detach NavPathStack');
  }

  /** 注册栈拦截：系统侧滑/三键返回 POP 不经过 NavRouterHelper.pop，需在 didShow 补齐同步 */
  private static registerStackInterception(): void {
    if (NavRouterHelper.stack === null) {
      return;
    }
    NavRouterHelper.stack.setInterception({
      willShow: NavRouterHelper.handleStackWillShow,
      didShow: NavRouterHelper.handleStackDidShow
    });
  }

  /**
   * NavPathStack 即将 POP：在目标页 aboutToDisappear 前标记音频最小化，避免 AVPlayer 被释放
   *
   * @param from 出栈前的栈顶页
   * @param to 出栈后的栈顶页
   * @param operation 导航操作类型
   * @param isAnimated 是否带动画
   */
  private static handleStackWillShow = (
    from: NavDestinationContext | 'navBar',
    to: NavDestinationContext | 'navBar',
    operation: NavigationOperation,
    isAnimated: boolean
  ): void => {
    if (operation !== NavigationOperation.POP) {
      return;
    }
    if (typeof from === 'string') {
      return;
    }
    const fromName: string = from.pathInfo.name;
    HiLog.i(TAG, `stackWillShow POP from=${fromName} animated=${isAnimated}`);
    if (fromName === AppNavRoutes.AUDIO_PLAYER) {
      HomeViewModel.getInstance().prepareAudioPlayerMinimizeBeforePop();
    }
  };

  /**
   * NavPathStack 完成 POP 后的回调（含系统返回）
   *
   * @param from 出栈前的栈顶页
   * @param to 出栈后的栈顶页
   * @param operation 导航操作类型
   * @param isAnimated 是否带动画
   */
  private static handleStackDidShow = (
    from: NavDestinationContext | 'navBar',
    to: NavDestinationContext | 'navBar',
    operation: NavigationOperation,
    isAnimated: boolean
  ): void => {
    if (operation !== NavigationOperation.POP) {
      return;
    }
    if (typeof from === 'string') {
      return;
    }
    const fromName: string = from.pathInfo.name;
    HiLog.i(TAG, `stackDidShow POP from=${fromName} animated=${isAnimated}`);
    NavRouterHelper.onRouteHidden(fromName);
  };

  /**
   * 获取当前栈顶路由名
   *
   * @returns 路由名，栈空时返回空字符串
   */
  public static getTopRouteName(): string {
    if (NavRouterHelper.stack === null || NavRouterHelper.stack.size() === 0) {
      return '';
    }
    const names: string[] = NavRouterHelper.stack.getAllPathName();
    return names[names.length - 1];
  }

  /**
   * 压入目标路由
   *
   * @param name 路由名
   * @param param 可选参数
   */
  public static push(name: string, param?: Object): void {
    if (NavRouterHelper.stack === null) {
      HiLog.e(TAG, `push failed stack=null name=${name}`);
      return;
    }
    HiLog.i(TAG, `push name=${name} stackSize=${NavRouterHelper.stack.size()} animated=${AppNavTransitionConstants.ANIMATED}`);
    NavRouterHelper.stack.pushPath(
      { name: name, param: param ?? new Object() },
      AppNavTransitionConstants.ANIMATED
    );
    NavRouterHelper.onRouteShown(name);
  }

  /**
   * 弹出栈顶路由并同步 ViewModel
   */
  public static pop(): void {
    if (NavRouterHelper.stack === null || NavRouterHelper.stack.size() === 0) {
      HiLog.w(TAG, 'pop skipped empty stack');
      return;
    }
    const topName: string = NavRouterHelper.getTopRouteName();
    HiLog.i(TAG, `pop top=${topName} stackSize=${NavRouterHelper.stack.size()} animated=${AppNavTransitionConstants.ANIMATED}`);
    NavRouterHelper.stack.pop(AppNavTransitionConstants.ANIMATED);
    NavRouterHelper.onRouteHidden(topName);
  }

  /**
   * 弹出所有歌单子页路由（回到 Tab 内列表层），单次 popToIndex 保留转场动画
   */
  public static popAllPlaylistRoutes(): void {
    if (NavRouterHelper.stack === null) {
      return;
    }
    const names: string[] = NavRouterHelper.stack.getAllPathName();
    if (names.length === 0) {
      return;
    }
    let targetIndex: number = names.length - 1;
    while (targetIndex >= 0 && AppNavRoutes.isPlaylistRoute(names[targetIndex])) {
      targetIndex--;
    }
    if (targetIndex === names.length - 1) {
      return;
    }
    const poppedNames: string[] = [];
    for (let i = names.length - 1; i > targetIndex; i--) {
      poppedNames.push(names[i]);
    }
    HiLog.i(TAG,
      `popAllPlaylistRoutes targetIndex=${targetIndex} count=${poppedNames.length} animated=${AppNavTransitionConstants.ANIMATED}`);
    NavRouterHelper.stack.popToIndex(targetIndex, AppNavTransitionConstants.ANIMATED);
    for (const name of poppedNames) {
      NavRouterHelper.onRouteHidden(name);
    }
  }

  /**
   * 打开全屏播放器：若已在播放器路由则替换，否则压栈
   *
   * @param route AUDIO_PLAYER 或 VIDEO_PLAYER
   */
  public static openPlayerRoute(route: string): void {
    if (NavRouterHelper.stack === null) {
      HiLog.e(TAG, `openPlayerRoute failed stack=null route=${route}`);
      return;
    }
    const top: string = NavRouterHelper.getTopRouteName();
    if (top === route) {
      return;
    }
    const pathInfo: NavPathInfo = { name: route, param: new Object() };
    if (AppNavRoutes.isPlayerRoute(top)) {
      HiLog.i(TAG, `replacePlayerRoute from=${top} to=${route} animated=${AppNavTransitionConstants.ANIMATED}`);
      NavRouterHelper.stack.replacePath(pathInfo, AppNavTransitionConstants.ANIMATED);
      NavRouterHelper.onRouteHidden(top);
      NavRouterHelper.onRouteShown(route);
      return;
    }
    NavRouterHelper.push(route);
  }

  /**
   * 关闭栈顶播放器路由（若当前为播放器页）
   */
  public static closePlayerRoute(): void {
    const top: string = NavRouterHelper.getTopRouteName();
    if (!AppNavRoutes.isPlayerRoute(top)) {
      return;
    }
    NavRouterHelper.pop();
  }

  /**
   * 路由入栈后同步各 ViewModel 显隐
   *
   * @param name 路由名
   */
  private static onRouteShown(name: string): void {
    switch (name) {
      case AppNavRoutes.SEARCH:
        HomeViewModel.getInstance().syncSearchOverlayNavVisible(true);
        break;
      case AppNavRoutes.SETTINGS:
        HomeViewModel.getInstance().syncSettingsOverlayNavVisible(true);
        break;
      case AppNavRoutes.HOME_MEDIA_EDIT:
        HomeViewModel.getInstance().syncHomeMediaEditNavVisible(true);
        break;
      case AppNavRoutes.AUDIO_PLAYER:
      case AppNavRoutes.VIDEO_PLAYER:
        HomeViewModel.getInstance().syncPlayerNavVisible(true);
        break;
      default:
        break;
    }
  }

  /**
   * 路由出栈后同步各 ViewModel 显隐
   *
   * @param name 被弹出的路由名
   */
  private static onRouteHidden(name: string): void {
    switch (name) {
      case AppNavRoutes.SEARCH:
        HomeViewModel.getInstance().syncSearchOverlayNavVisible(false);
        break;
      case AppNavRoutes.SETTINGS:
        HomeViewModel.getInstance().syncSettingsOverlayNavVisible(false);
        break;
      case AppNavRoutes.HOME_MEDIA_EDIT:
        HomeViewModel.getInstance().syncHomeMediaEditNavVisible(false);
        break;
      case AppNavRoutes.AUDIO_PLAYER:
      case AppNavRoutes.VIDEO_PLAYER:
        HomeViewModel.getInstance().syncPlayerNavVisible(false);
        break;
      case AppNavRoutes.PLAYLIST_DETAIL:
      case AppNavRoutes.PLAYLIST_EDIT:
      case AppNavRoutes.PLAYLIST_ADD_AUDIO:
      case AppNavRoutes.PLAYLIST_LIST_SELECT:
        PlaylistViewModel.getInstance().syncAfterPlaylistNavPop(name);
        break;
      default:
        break;
    }
  }
}
