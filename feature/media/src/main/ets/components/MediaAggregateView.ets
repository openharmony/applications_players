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


import FileInfo from '@ohos/common/src/main/ets/model/FileInfo';
import { MediaType } from '@ohos/common/src/main/ets/datasource/MediaDataSource';
import { FontScaleUtil } from '@ohos/common/src/main/ets/utils/FontScaleUtil';
import { EmptyStateView } from '@ohos/common/src/main/ets/component/EmptyStateView';
import { SwipeDeleteEndAction } from '@ohos/common/src/main/ets/component/SwipeDeleteEndAction';
import { SwipeDeleteUtil } from '@ohos/common/src/main/ets/utils/SwipeDeleteUtil';
import { MediaGridItem } from './MediaGridItem';
import { MediaAggregateListItem } from './MediaAggregateListItem';
import { MediaHomeEmptyState } from './MediaHomeEmptyState';
import { MediaViewLayoutConstants } from '../constants/MediaViewLayoutConstants';
import { MediaViewUiConstants } from '@ohos/common/src/main/ets/constants/MediaViewUiConstants';
import { MediaSelectionConstants } from '../constants/MediaSelectionConstants';
import { MediaViewArrayDataSource } from '../datasource/MediaViewArrayDataSource';
import { HiLog } from '@ohos/common/src/main/ets/utils/HiLog';


const TAG = 'MediaAggregateView';

/** 列表项的全局矩形（vp），供拖动滑选命中测试使用 */
interface ItemRect {
  x: number;
  y: number;
  width: number;
  height: number;
}

/**
 * 媒体聚合列表纯 View 组件。
 * 仅负责布局与样式；可变状态由 Page/ViewModel 注入，固定样式见 constants 目录。
 * 列表刷新：LazyForEach(MediaViewArrayDataSource)，@Prop 变更时由 onMediaItemsChange 同步。
 * 多选交互：编辑 Nav 页内点击切换选中；容器级 Pan 直接滑动涂选（首页不再长按进入多选）。
 */
@Component
export struct MediaAggregateView {
  /** 由 Page 注入，与 AppStorage fontScale 同步，驱动列表项字号刷新 */
  @Prop fontScale: number = FontScaleUtil.DEFAULT_SCALE;
  @Link isGridView: boolean;
  @Prop mediaType: MediaType = MediaType.AUDIO;
  @Prop isLoading: boolean = false;
  @Prop hasMediaItems: boolean = false;
  @Prop showPermissionTip: boolean = false;
  @Prop isRequestingPermission: boolean = false;
  @Prop loadingHintText: string = '';
  @Prop showScanProgressDetail: boolean = false;
  /** 实体 FileInfo 列表快照，由 HomeViewModel 同步，经 IDataSource 适配后供 LazyForEach 绑定 */
  @Prop @Watch('onMediaItemsChange') mediaItems: FileInfo[] = [];
  @Prop listItemIsAudio: boolean = false;
  /** 列表刷新序号，筛选/排序后递增以强制列表区重建 */
  @Prop listRevision: number = 0;
  @Prop homeLayoutStyle: boolean = false;
  @Prop homeEmptyTitle: ResourceStr = '';
  @Prop homeEmptyHint: ResourceStr = '';
  @Prop permissionTipText: ResourceStr = '';
  @Prop permissionGrantText: ResourceStr = '';
  @Prop loadingDefaultText: ResourceStr = '';
  @Prop emptyStateTitle: string = '';
  @Prop emptyStateDescription: string = '';
  @Prop emptyStateIcon: Resource = $r('app.media.ic_empty_state');
  /** 是否处于多选模式 */
  @Prop isSelectionMode: boolean = false;
  /** 已选中项 URI 列表，驱动子项勾选态 */
  @Prop selectedUris: string[] = [];
  onMediaClick: (fileInfo: FileInfo) => void = () => {};
  onRequestPermission: () => void = () => {};
  /** 仅进入多选模式（不改变选中集合） */
  onEnterSelectionMode: () => void = () => {};
  /** 点击条目：切换选中态 */
  onToggleSelect: (uri: string) => void = () => {};
  /** 拖动涂选：以完整的选中 URI 集合覆盖当前选择 */
  onReplaceSelection: (uris: string[]) => void = () => {};
  /** 列表滑动删除（拉到底直接删除，由 Page/ViewModel 执行） */
  onSwipeDeleteMedia: (media: FileInfo) => void = () => {};

  /** 拖动涂选进行中：用于禁用容器自身滚动，避免内容位移导致命中抖动 */
  @State isDragSelecting: boolean = false;
  /** 各列表项的全局矩形缓存（uri -> rect），由 onAreaChange 维护 */
  private itemRectMap: Map<string, ItemRect> = new Map();
  /** 拖动涂选锚点索引（Pan 起点），-1 表示未在涂选 */
  private dragAnchorIndex: number = -1;
  /** 拖动涂选当前命中的索引 */
  private dragLastIndex: number = -1;
  /** 本次涂选目标态：true=选中，false=取消（由锚点初始状态决定） */
  private dragTarget: boolean = true;
  /** 涂选开始前的选中快照，用于拖回时还原区间外的项 */
  private dragSnapshot: Set<string> = new Set();
  /** 最近一次手指垂直移动方向：-1 上，1 下，0 未形成方向，用于过滤反向陈旧命中 */
  private dragMoveDir: number = 0;
  /** 涂选结束后置位：忽略随之而来的一次 Tap，避免涂选起点项被误点选 */
  private suppressNextTap: boolean = false;
  /** 宫格/列表滚动控制器，列表使用 ListScroller 以支持 closeAllSwipeActions */
  private gridScroller: Scroller = new Scroller();
  private listScroller: ListScroller = new ListScroller();
  /** 列表区可视范围上下边界（全局 y，vp） */
  private containerTop: number = 0;
  private containerBottom: number = 0;
  /** 最近一次手指全局坐标（vp），自动滚动期间复用 */
  private lastFingerX: number = 0;
  private lastFingerY: number = 0;
  /** 自动滚动定时器与方向（-1 上，1 下，0 停） */
  private autoScrollTimer: number = -1;
  private autoScrollDir: number = 0;
  /** LazyForEach 数据源适配器，@Prop 数组变更时由 onMediaItemsChange 同步 */
  private dataSource: MediaViewArrayDataSource = new MediaViewArrayDataSource();

  /** @Prop mediaItems 变更时同步到 LazyForEach 数据源 */
  private onMediaItemsChange(): void {
    this.dataSource.replaceData(this.mediaItems);
  }

  aboutToAppear(): void {
    HiLog.i(TAG, 'aboutToAppear');
    this.dataSource.replaceData(this.mediaItems);
  }

  aboutToDisappear(): void {
    this.stopAutoScroll();
    this.closeAllListSwipeActions();
  }

  /** 收起列表已展开的滑动删除区域 */
  private closeAllListSwipeActions(): void {
    SwipeDeleteUtil.closeAllSwipeActionsSafe(this.listScroller, TAG);
  }

  /**
   * 滑动删除：对齐联系人，点击垃圾桶或拉到底触发删除动效后执行
   *
   * @param media 媒体项
   */
  private runSwipeDelete(media: FileInfo): void {
    this.closeAllListSwipeActions();
    SwipeDeleteUtil.runDeleteAnimation(() => {
      this.onSwipeDeleteMedia(media);
    });
  }

  /** swipeAction.onAction：拉到底删除（联系人 onAction 规格） */
  private runSwipeEndDelete(media: FileInfo): void {
    this.closeAllListSwipeActions();
    SwipeDeleteUtil.runSwipeEndDelete(() => {
      this.onSwipeDeleteMedia(media);
    });
  }

  /**
   * Length 取 vp 数值（仅 number 有效，string/Resource 回退 0）
   *
   * @param value 布局 Length
   * @returns vp 数值
   */
  private lengthToVp(value: Length | undefined): number {
    return typeof value === 'number' ? value : 0;
  }

  /**
   * 记录列表项的全局矩形，供拖动滑选命中测试
   *
   * @param uri 媒体 URI
   * @param area onAreaChange 区域
   */
  private recordItemRect(uri: string, area: Area): void {
    this.itemRectMap.set(uri, {
      x: this.lengthToVp(area.globalPosition.x),
      y: this.lengthToVp(area.globalPosition.y),
      width: this.lengthToVp(area.width),
      height: this.lengthToVp(area.height)
    });
  }

  /**
   * 当前项是否被选中
   *
   * @param uri 媒体 URI
   * @returns 是否选中
   */
  private isItemSelected(uri: string): boolean {
    return this.selectedUris.includes(uri);
  }

  /**
   * 条目点击：多选模式切换选中，否则正常播放
   *
   * @param media 媒体项
   */
  private handleItemTap(media: FileInfo): void {
    // 首次长按进入多选后，松手会触发本次 Tap，需吞掉以免长按项被选中
    if (this.suppressNextTap) {
      this.suppressNextTap = false;
      return;
    }
    if (this.isSelectionMode) {
      this.onToggleSelect(media.uri);
    } else {
      this.onMediaClick(media);
    }
  }

  /**
   * 矩形是否落在当前可视范围内（用于过滤滚动后未刷新的离屏陈旧矩形，避免误命中远处条目）
   *
   * @param rect 列表项全局矩形
   * @returns 是否与可视范围相交
   */
  private isRectVisible(rect: ItemRect): boolean {
    return rect.y + rect.height >= this.containerTop && rect.y <= this.containerBottom;
  }

  /**
   * 根据手指全局坐标精确命中当前所在项的索引。
   * 仅在可视范围内命中，且跳过已不在当前列表的陈旧 uri，避免离屏陈旧矩形导致选区跳变。
   *
   * @param gx 手指全局 x（vp）
   * @param gy 手指全局 y（vp）
   * @returns 命中项在 mediaItems 中的索引，未命中返回 -1
   */
  private findIndexAt(gx: number, gy: number): number {
    let bestIndex: number = -1;
    this.itemRectMap.forEach((rect: ItemRect, uri: string) => {
      if (bestIndex >= 0 || !this.isRectVisible(rect)) {
        return;
      }
      if (gx >= rect.x && gx <= rect.x + rect.width &&
        gy >= rect.y && gy <= rect.y + rect.height) {
        const idx = this.mediaItems.findIndex((m: FileInfo) => m.uri === uri);
        if (idx >= 0) {
          bestIndex = idx;
        }
      }
    });
    return bestIndex;
  }

  /**
   * 取可视范围内沿滚动方向最靠边的项索引（自动滚动时驱动选区，免受陈旧矩形与未命中影响）。
   * 宫格同一行存在多个相同 y 的项时，按手指 x 选择最近列，避免上边缘命中整行其它列。
   *
   * @param dir 滚动方向：-1 取最靠上项，1 取最靠下项
   * @returns 最靠边项索引，无可视项返回 -1
   */
  private findExtremeVisibleIndex(dir: number): number {
    let bestIndex: number = -1;
    let bestY: number = dir > 0 ? -1 : Number.MAX_VALUE;
    let bestXDistance: number = Number.MAX_VALUE;
    this.itemRectMap.forEach((rect: ItemRect, uri: string) => {
      if (!this.isRectVisible(rect)) {
        return;
      }
      const idx = this.mediaItems.findIndex((m: FileInfo) => m.uri === uri);
      if (idx < 0) {
        return;
      }
      const isBetterRow = dir > 0 ? rect.y > bestY : rect.y < bestY;
      const isSameRow = Math.abs(rect.y - bestY) <= MediaSelectionConstants.GRID_ROW_EPSILON_VP;
      const xDistance = Math.abs(rect.x + rect.width / 2 - this.lastFingerX);
      if (isBetterRow || (isSameRow && xDistance < bestXDistance)) {
        bestY = rect.y;
        bestXDistance = xDistance;
        bestIndex = idx;
      }
    });
    return bestIndex;
  }

  /** 记录列表区可视范围上下边界（自动滚动边缘判定用） */
  private recordContainerRect(area: Area): void {
    this.containerTop = this.lengthToVp(area.globalPosition.y);
    this.containerBottom = this.containerTop + this.lengthToVp(area.height);
  }

  /**
   * 涂选起点：多选模式下根据手指落点记录锚点；非多选模式忽略。
   *
   * @param uri 起点命中的媒体 URI
   */
  private beginDragSelect(uri: string): void {
    // 防御：若上一次涂选被打断遗留了状态（定时器/锚点/拖动标记），先复位，确保本次涂选可正常开始
    if (this.isDragSelecting || this.dragAnchorIndex >= 0 || this.autoScrollTimer >= 0) {
      this.endDragSelect();
    }
    if (!this.isSelectionMode) {
      HiLog.i(TAG, 'Trace[drag-select] Non-selection mode, ignoring drag-select');
      return;
    }
    const index = this.mediaItems.findIndex((m: FileInfo) => m.uri === uri);
    if (index < 0) {
      return;
    }
    this.dragAnchorIndex = index;
    this.dragLastIndex = index;
    this.dragMoveDir = 0;
    this.lastFingerX = 0;
    this.lastFingerY = 0;
    this.dragSnapshot = new Set<string>();
    for (const u of this.selectedUris) {
      this.dragSnapshot.add(u);
    }
    // 锚点未选中 -> 本次为选中；锚点已选中 -> 本次为取消
    this.dragTarget = !this.dragSnapshot.has(uri);
    // 仅记录锚点，不在此选中锚点（需拖动经过才选）
    HiLog.i(TAG, `Trace[drag-select] begin anchor=${index} target=${this.dragTarget}`);
  }

  /**
   * 根据手指全局坐标启动涂选（容器级 Pan 入口）
   *
   * @param gx 手指全局 x（vp）
   * @param gy 手指全局 y（vp）
   */
  private beginDragSelectAtFinger(gx: number, gy: number): void {
    const index = this.findIndexAt(gx, gy);
    if (index < 0) {
      return;
    }
    this.beginDragSelect(this.mediaItems[index].uri);
    this.onDragPanStart();
    this.suppressNextTap = true;
    this.lastFingerX = gx;
    this.lastFingerY = gy;
  }

  /** 拖动真正开始：禁用容器滚动，避免内容位移引起命中抖动 */
  private onDragPanStart(): void {
    if (this.dragAnchorIndex < 0) {
      return;
    }
    this.isDragSelecting = true;
  }

  /**
   * 拖动过程中：命中当前项并刷新锚点→当前的整段选择，并按边缘触发自动滚动
   *
   * @param event Pan 手势事件
   */
  private updateDragSelect(event: GestureEvent): void {
    if (this.dragAnchorIndex < 0) {
      return;
    }
    if (!event.fingerList || event.fingerList.length === 0) {
      return;
    }
    const currentFingerY = event.fingerList[0].globalY;
    if (this.lastFingerY > 0) {
      if (currentFingerY > this.lastFingerY) {
        this.dragMoveDir = 1;
      } else if (currentFingerY < this.lastFingerY) {
        this.dragMoveDir = -1;
      }
    }
    this.lastFingerX = event.fingerList[0].globalX;
    this.lastFingerY = currentFingerY;
    // 先判定是否进入边缘自动滚动区；边缘区交由定时器以「可视最靠边项」驱动选区，
    // 非边缘区才用精确命中，避免滚动中陈旧矩形导致反向/跳变选中
    this.evaluateAutoScroll(this.lastFingerY);
    if (this.autoScrollDir === 0) {
      this.applySelectionAtFinger();
    }
  }

  /** 以最近手指坐标命中当前项并刷新区间选择 */
  private applySelectionAtFinger(): void {
    const index = this.findIndexAt(this.lastFingerX, this.lastFingerY);
    if (!this.canMoveDragLastIndexTo(index)) {
      return;
    }
    this.dragLastIndex = index;
    this.applyDragRange();
  }

  /**
   * 判断本次命中是否允许更新拖选终点。
   * 列表/宫格快速反向滑动时，onAreaChange 可能滞后，旧矩形会误命中反方向条目；用手指移动方向过滤。
   *
   * @param index 候选终点索引
   * @returns 是否允许更新终点
   */
  private canMoveDragLastIndexTo(index: number): boolean {
    if (index < 0 || index >= this.mediaItems.length || index === this.dragLastIndex) {
      return false;
    }
    if (this.isGridView) {
      return true;
    }
    if (this.dragMoveDir < 0 && index > this.dragLastIndex) {
      return false;
    }
    if (this.dragMoveDir > 0 && index < this.dragLastIndex) {
      return false;
    }
    return true;
  }

  /**
   * 以快照为基线，对锚点→当前索引区间应用目标态，区间外保持快照，最终覆盖选择集合
   */
  private applyDragRange(): void {
    const start = Math.min(this.dragAnchorIndex, this.dragLastIndex);
    const end = Math.max(this.dragAnchorIndex, this.dragLastIndex);
    const result = new Set<string>();
    this.dragSnapshot.forEach((u: string) => result.add(u));
    for (let i = start; i <= end; i++) {
      const uri = this.mediaItems[i].uri;
      if (this.dragTarget) {
        result.add(uri);
      } else {
        result.delete(uri);
      }
    }
    const uris: string[] = [];
    result.forEach((u: string) => uris.push(u));
    this.onReplaceSelection(uris);
  }

  /**
   * 根据手指是否接近上下边缘启停自动滚动
   *
   * @param fingerY 手指全局 y（vp）
   */
  private evaluateAutoScroll(fingerY: number): void {
    if (fingerY < this.containerTop + MediaSelectionConstants.AUTO_SCROLL_EDGE_VP) {
      this.startAutoScroll(-1);
    } else if (fingerY > this.containerBottom - MediaSelectionConstants.AUTO_SCROLL_EDGE_VP) {
      this.startAutoScroll(1);
    } else {
      this.stopAutoScroll();
    }
  }

  /**
   * 启动自动滚动定时器：边缘按住不动时持续滚动并选中划过的条目
   *
   * @param dir -1 向上，1 向下
   */
  private startAutoScroll(dir: number): void {
    if (this.autoScrollDir === dir && this.autoScrollTimer >= 0) {
      return;
    }
    this.autoScrollDir = dir;
    // 进入边缘区时先按当前方向推进一次，避免手指快速到达底部导航栏时只滚动不选中
    this.applyAutoScrollSelection();
    if (this.autoScrollTimer >= 0) {
      return;
    }
    this.autoScrollTimer = setInterval(() => {
      const scroller = this.isGridView ? this.gridScroller : this.listScroller;
      scroller.scrollBy(0, this.autoScrollDir * MediaSelectionConstants.AUTO_SCROLL_STEP_VP);
      this.applyAutoScrollSelection();
    }, MediaSelectionConstants.AUTO_SCROLL_INTERVAL_MS);
  }

  /**
   * 自动滚动期间推进拖选终点。
   * 列表按索引逐项推进，避免快速滑到底部时依赖未刷新的矩形；宫格保留按手指列命中可视边缘项。
   */
  private applyAutoScrollSelection(): void {
    if (this.dragAnchorIndex < 0 || this.autoScrollDir === 0) {
      return;
    }
    let index: number = -1;
    if (this.isGridView) {
      index = this.findExtremeVisibleIndex(this.autoScrollDir);
    } else {
      index = this.dragLastIndex + this.autoScrollDir;
    }
    if (this.canMoveDragLastIndexTo(index)) {
      this.dragLastIndex = index;
      this.applyDragRange();
    }
  }

  /** 停止自动滚动 */
  private stopAutoScroll(): void {
    if (this.autoScrollTimer >= 0) {
      clearInterval(this.autoScrollTimer);
      this.autoScrollTimer = -1;
    }
    this.autoScrollDir = 0;
  }

  /** 结束拖动涂选 */
  private endDragSelect(): void {
    HiLog.i(TAG, `Trace[drag-select] end anchor=${this.dragAnchorIndex} last=${this.dragLastIndex}`);
    this.stopAutoScroll();
    this.isDragSelecting = false;
    this.dragAnchorIndex = -1;
    this.dragLastIndex = -1;
    this.dragMoveDir = 0;
    // 拖动结束时清除吞 Tap 标记，避免下次正常点击被误吞
    this.suppressNextTap = false;
  }


  build() {
    Column() {
      if (this.showPermissionTip) {
        this.buildPermissionTip()
      }

      if (this.isLoading) {
        this.buildLoadingView()
      } else if (!this.hasMediaItems) {
        this.buildEmptyView()
      } else if (this.isGridView) {
        this.buildGridView()
      } else {
        this.buildListView()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.homeLayoutStyle ?
      MediaViewLayoutConstants.HOME_ROOT_BACKGROUND : $r('sys.color.ohos_id_color_sub_background'))
  }

  /** 未授权时顶部橙色横幅 */
  @Builder
  buildPermissionTip() {
    Row() {
      Text(this.permissionTipText)
        .fontSize(MediaViewUiConstants.PERMISSION_TEXT_FONT_SIZE)
        .fontColor(Color.White)
        .layoutWeight(1)

      Button(this.permissionGrantText)
        .fontSize(MediaViewUiConstants.PERMISSION_TEXT_FONT_SIZE)
        .fontColor(Color.White)
        .backgroundColor(MediaViewUiConstants.PERMISSION_GRANT_BG)
        .height(MediaViewUiConstants.PERMISSION_GRANT_HEIGHT)
        .padding({
          left: MediaViewUiConstants.PERMISSION_GRANT_HORIZONTAL_PADDING,
          right: MediaViewUiConstants.PERMISSION_GRANT_HORIZONTAL_PADDING
        })
        .enabled(!this.isRequestingPermission)
        .onClick(() => {
          this.onRequestPermission();
        })
    }
    .width('100%')
    .height(MediaViewUiConstants.PERMISSION_TIP_HEIGHT)
    .padding({
      left: MediaViewUiConstants.PERMISSION_HORIZONTAL_PADDING,
      right: MediaViewUiConstants.PERMISSION_HORIZONTAL_PADDING
    })
    .backgroundColor(MediaViewUiConstants.PERMISSION_TIP_BG)
  }


  /** 加载中占位 */
  @Builder
  buildLoadingView() {
    Column() {
      LoadingProgress()
        .width(MediaViewUiConstants.LOADING_PROGRESS_SIZE)
        .height(MediaViewUiConstants.LOADING_PROGRESS_SIZE)
        .color($r('sys.color.ohos_id_color_primary'))

      Text(this.showScanProgressDetail ? this.loadingHintText : this.loadingDefaultText)
        .fontSize(MediaViewUiConstants.LOADING_HINT_FONT_SIZE)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        .margin({ top: MediaViewUiConstants.LOADING_HINT_MARGIN_TOP })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  /** 无媒体时的空态 */
  @Builder
  buildEmptyView() {
    if (this.homeLayoutStyle) {
      MediaHomeEmptyState({
        title: this.homeEmptyTitle,
        hint: this.homeEmptyHint
      })
        .layoutWeight(1)
    } else {
      EmptyStateView({
        icon: this.emptyStateIcon,
        title: this.emptyStateTitle,
        description: this.emptyStateDescription,
        fullHeight: true
      })
        .layoutWeight(1)
    }
  }


  /**
   * 首页宫格列模板：两列 1:1；非首页样式走默认三列。
   *
   * @returns Grid columnsTemplate
   */
  private getGridColumnsTemplate(): string {
    return this.homeLayoutStyle ?
      MediaViewLayoutConstants.HOME_GRID_COLUMNS :
      MediaViewLayoutConstants.DEFAULT_GRID_COLUMNS;
  }

  /** 宫格 LazyForEach 条目 */
  @Builder
  buildGridItems() {
    LazyForEach(this.dataSource, (media: FileInfo, index: number) => {
      if (this.isSelectionMode) {
        GridItem() {
          MediaGridItem({
            media: media,
            mediaType: this.mediaType,
            fontScale: this.fontScale,
            isSelectionMode: this.isSelectionMode,
            isSelected: this.isItemSelected(media.uri)
          })
        }
        .onAreaChange((_oldArea: Area, newArea: Area) => {
          this.recordItemRect(media.uri, newArea);
        })
        .gesture(
          TapGesture({ count: 1 })
            .onAction(() => {
              this.handleItemTap(media);
            })
        )
      } else {
        GridItem() {
          MediaGridItem({
            media: media,
            mediaType: this.mediaType,
            fontScale: this.fontScale,
            isSelectionMode: this.isSelectionMode,
            isSelected: this.isItemSelected(media.uri)
          })
        }
        .onAreaChange((_oldArea: Area, newArea: Area) => {
          this.recordItemRect(media.uri, newArea);
        })
        .gesture(
          GestureGroup(GestureMode.Exclusive,
            TapGesture({ count: 1 })
              .onAction(() => {
                this.handleItemTap(media);
              }),
            GestureGroup(GestureMode.Sequence,
              LongPressGesture({ repeat: false, duration: MediaSelectionConstants.LONG_PRESS_DURATION_MS })
                .onAction(() => {
                  this.beginDragSelect(media.uri);
                }),
              PanGesture({ distance: MediaSelectionConstants.PAN_SELECT_MIN_DISTANCE })
                .onActionStart(() => {
                  this.onDragPanStart();
                })
                .onActionUpdate((event: GestureEvent) => {
                  this.updateDragSelect(event);
                })
                .onActionEnd(() => {
                  this.endDragSelect();
                })
                .onActionCancel(() => {
                  this.endDragSelect();
                })
            )
          )
        )
      }
    }, (media: FileInfo) => media.uri)
  }


  /** 宫格视图 */
  @Builder
  buildGridView() {
    if (this.isSelectionMode) {
      this.buildSelectionGridView()
    } else {
      this.buildNormalGridView()
    }
  }

  /** 多选宫格：容器级 Pan 涂选 */
  @Builder
  buildSelectionGridView() {
    Grid(this.gridScroller) {
      this.buildGridItems()
    }
    .enableScrollInteraction(!this.isDragSelecting)
    .onAreaChange((_oldArea: Area, newArea: Area) => {
      this.recordContainerRect(newArea);
    })
    .id(`media_grid_${this.mediaType}_${this.listRevision}_${this.fontScale}`)
    .columnsTemplate(this.getGridColumnsTemplate())
    .rowsGap(this.homeLayoutStyle ?
      MediaViewLayoutConstants.HOME_GRID_ROWS_GAP : MediaViewLayoutConstants.DEFAULT_GRID_ROWS_GAP)
    .columnsGap(this.homeLayoutStyle ?
      MediaViewLayoutConstants.HOME_GRID_COLUMNS_GAP : MediaViewLayoutConstants.DEFAULT_GRID_COLUMNS_GAP)
    .padding({
      left: this.homeLayoutStyle ?
        MediaViewLayoutConstants.HOME_GRID_PADDING_LEFT : MediaViewLayoutConstants.DEFAULT_GRID_PADDING_LEFT,
      right: this.homeLayoutStyle ?
        MediaViewLayoutConstants.HOME_GRID_PADDING_RIGHT : MediaViewLayoutConstants.DEFAULT_GRID_PADDING_RIGHT,
      top: this.homeLayoutStyle ?
        MediaViewLayoutConstants.HOME_GRID_PADDING_TOP : MediaViewLayoutConstants.DEFAULT_GRID_PADDING_TOP,
      bottom: MediaViewLayoutConstants.GRID_BOTTOM_PADDING
    })
    .layoutWeight(1)
    .cachedCount(MediaViewLayoutConstants.GRID_CACHED_COUNT)
    .parallelGesture(
      PanGesture({
        direction: PanDirection.All,
        distance: MediaSelectionConstants.PAN_SELECT_MIN_DISTANCE
      })
        .onActionStart((event: GestureEvent) => {
          if (!event.fingerList || event.fingerList.length === 0) {
            return;
          }
          const finger = event.fingerList[0];
          this.beginDragSelectAtFinger(finger.globalX, finger.globalY);
        })
        .onActionUpdate((event: GestureEvent) => {
          this.updateDragSelect(event);
        })
        .onActionEnd(() => {
          this.endDragSelect();
        })
        .onActionCancel(() => {
          this.endDragSelect();
        }),
      GestureMask.Normal
    )
  }

  /** 非多选宫格 */
  @Builder
  buildNormalGridView() {
    Grid(this.gridScroller) {
      this.buildGridItems()
    }
    .enableScrollInteraction(!this.isDragSelecting)
    .onAreaChange((_oldArea: Area, newArea: Area) => {
      this.recordContainerRect(newArea);
    })
    .id(`media_grid_${this.mediaType}_${this.listRevision}_${this.fontScale}`)
    .columnsTemplate(this.getGridColumnsTemplate())
    .rowsGap(this.homeLayoutStyle ?
      MediaViewLayoutConstants.HOME_GRID_ROWS_GAP : MediaViewLayoutConstants.DEFAULT_GRID_ROWS_GAP)
    .columnsGap(this.homeLayoutStyle ?
      MediaViewLayoutConstants.HOME_GRID_COLUMNS_GAP : MediaViewLayoutConstants.DEFAULT_GRID_COLUMNS_GAP)
    .padding({
      left: this.homeLayoutStyle ?
        MediaViewLayoutConstants.HOME_GRID_PADDING_LEFT : MediaViewLayoutConstants.DEFAULT_GRID_PADDING_LEFT,
      right: this.homeLayoutStyle ?
        MediaViewLayoutConstants.HOME_GRID_PADDING_RIGHT : MediaViewLayoutConstants.DEFAULT_GRID_PADDING_RIGHT,
      top: this.homeLayoutStyle ?
        MediaViewLayoutConstants.HOME_GRID_PADDING_TOP : MediaViewLayoutConstants.DEFAULT_GRID_PADDING_TOP,
      bottom: MediaViewLayoutConstants.GRID_BOTTOM_PADDING
    })
    .layoutWeight(1)
    .cachedCount(MediaViewLayoutConstants.GRID_CACHED_COUNT)
  }


  /** 列表项内容 */
  @Builder
  buildListItemContent(media: FileInfo) {
    MediaAggregateListItem({
      media: media,
      mediaType: this.mediaType,
      fontScale: this.fontScale,
      isSelectionMode: this.isSelectionMode,
      isSelected: this.isItemSelected(media.uri)
    })
  }

  /** 列表滑动删除 end 区域 */
  @Builder
  buildListSwipeDeleteEnd(media: FileInfo) {
    SwipeDeleteEndAction({
      onDelete: () => {
        this.runSwipeDelete(media);
      }
    })
  }

  /**
   * 列表单项：手势与可选滑动删除（ArkTS 中 GestureGroup 不能作返回类型，故用 Builder 封装）
   *
   * @param media 媒体项
   * @param enableSwipeDelete 非多选时为 true
   */
  @Builder
  buildMediaListItem(media: FileInfo, enableSwipeDelete: boolean) {
    if (enableSwipeDelete) {
      ListItem() {
        this.buildListItemContent(media)
      }
      .onAreaChange((_oldArea: Area, newArea: Area) => {
        this.recordItemRect(media.uri, newArea);
      })
      .gesture(
        GestureGroup(GestureMode.Exclusive,
          TapGesture({ count: 1 })
            .onAction(() => {
              this.handleItemTap(media);
            }),
          GestureGroup(GestureMode.Sequence,
            LongPressGesture({ repeat: false, duration: MediaSelectionConstants.LONG_PRESS_DURATION_MS })
              .onAction(() => {
                this.beginDragSelect(media.uri);
              }),
            PanGesture({ distance: MediaSelectionConstants.PAN_SELECT_MIN_DISTANCE })
              .onActionStart(() => {
                this.onDragPanStart();
              })
              .onActionUpdate((event: GestureEvent) => {
                this.updateDragSelect(event);
              })
              .onActionEnd(() => {
                this.endDragSelect();
              })
              .onActionCancel(() => {
                this.endDragSelect();
              })
          )
        )
      )
      .swipeAction({
        end: {
          builder: () => {
            this.buildListSwipeDeleteEnd(media)
          },
          onAction: () => {
            this.runSwipeEndDelete(media);
          }
        }
      })
    } else {
      ListItem() {
        this.buildListItemContent(media)
      }
      .onAreaChange((_oldArea: Area, newArea: Area) => {
        this.recordItemRect(media.uri, newArea);
      })
      .gesture(
        TapGesture({ count: 1 })
          .onAction(() => {
            this.handleItemTap(media);
          })
      )
    }
  }

  /** 列表 LazyForEach 内容 */
  @Builder
  buildListItems() {
    LazyForEach(this.dataSource, (media: FileInfo, _index: number) => {
      this.buildMediaListItem(media, !this.isSelectionMode)
    }, (media: FileInfo) => media.uri)
  }

  /** 多选列表：容器级 Pan 涂选 */
  @Builder
  buildSelectionListView() {
    List({ scroller: this.listScroller }) {
      this.buildListItems()
    }
    .enableScrollInteraction(!this.isDragSelecting)
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down || event.type === TouchType.Move) {
        this.closeAllListSwipeActions();
      }
    })
    .onAreaChange((_oldArea: Area, newArea: Area) => {
      this.recordContainerRect(newArea);
    })
    .id(`media_list_${this.mediaType}_${this.listRevision}_${this.fontScale}`)
    .divider({
      strokeWidth: MediaViewLayoutConstants.LIST_DIVIDER_STROKE_WIDTH,
      color: $r('sys.color.ohos_id_color_list_separator'),
      startMargin: this.homeLayoutStyle ?
        MediaViewLayoutConstants.HOME_LIST_DIVIDER_START_MARGIN :
        MediaViewLayoutConstants.LIST_DIVIDER_START_MARGIN,
      endMargin: MediaViewLayoutConstants.LIST_DIVIDER_END_MARGIN
    })
    .padding({
      left: this.homeLayoutStyle ?
        MediaViewLayoutConstants.HOME_LIST_CARD_INNER_PADDING_H : MediaViewLayoutConstants.DEFAULT_LIST_PADDING_LEFT,
      right: this.homeLayoutStyle ?
        MediaViewLayoutConstants.HOME_LIST_CARD_INNER_PADDING_H : MediaViewLayoutConstants.DEFAULT_LIST_PADDING_RIGHT,
      bottom: this.homeLayoutStyle ?
        MediaViewLayoutConstants.HOME_LIST_BOTTOM_PADDING : MediaViewLayoutConstants.GRID_BOTTOM_PADDING
    })
    .layoutWeight(1)
    .cachedCount(MediaViewLayoutConstants.GRID_CACHED_COUNT)
    .parallelGesture(
      PanGesture({
        direction: PanDirection.All,
        distance: MediaSelectionConstants.PAN_SELECT_MIN_DISTANCE
      })
        .onActionStart((event: GestureEvent) => {
          if (!event.fingerList || event.fingerList.length === 0) {
            return;
          }
          const finger = event.fingerList[0];
          this.beginDragSelectAtFinger(finger.globalX, finger.globalY);
        })
        .onActionUpdate((event: GestureEvent) => {
          this.updateDragSelect(event);
        })
        .onActionEnd(() => {
          this.endDragSelect();
        })
        .onActionCancel(() => {
          this.endDragSelect();
        }),
      GestureMask.Normal
    )
  }

  /** 非多选列表 */
  @Builder
  buildNormalListView() {
    List({ scroller: this.listScroller }) {
      this.buildListItems()
    }
    .enableScrollInteraction(!this.isDragSelecting)
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down || event.type === TouchType.Move) {
        this.closeAllListSwipeActions();
      }
    })
    .onAreaChange((_oldArea: Area, newArea: Area) => {
      this.recordContainerRect(newArea);
    })
    .id(`media_list_${this.mediaType}_${this.listRevision}_${this.fontScale}`)
    .divider({
      strokeWidth: MediaViewLayoutConstants.LIST_DIVIDER_STROKE_WIDTH,
      color: $r('sys.color.ohos_id_color_list_separator'),
      startMargin: this.homeLayoutStyle ?
        MediaViewLayoutConstants.HOME_LIST_DIVIDER_START_MARGIN :
        MediaViewLayoutConstants.LIST_DIVIDER_START_MARGIN,
      endMargin: MediaViewLayoutConstants.LIST_DIVIDER_END_MARGIN
    })
    .padding({
      left: this.homeLayoutStyle ?
        MediaViewLayoutConstants.HOME_LIST_CARD_INNER_PADDING_H : MediaViewLayoutConstants.DEFAULT_LIST_PADDING_LEFT,
      right: this.homeLayoutStyle ?
        MediaViewLayoutConstants.HOME_LIST_CARD_INNER_PADDING_H : MediaViewLayoutConstants.DEFAULT_LIST_PADDING_RIGHT,
      bottom: this.homeLayoutStyle ?
        MediaViewLayoutConstants.HOME_LIST_BOTTOM_PADDING : MediaViewLayoutConstants.GRID_BOTTOM_PADDING
    })
    .layoutWeight(1)
    .cachedCount(MediaViewLayoutConstants.GRID_CACHED_COUNT)
  }

  /** 列表视图：外层 padding 与底栏一致（16），内层白底圆角卡片 */
  @Builder
  buildListView() {
    if (this.homeLayoutStyle) {
      Column() {
        Column() {
          if (this.isSelectionMode) {
            this.buildSelectionListView()
          } else {
            this.buildNormalListView()
          }
        }
        .width('100%')
        .layoutWeight(1)
        .backgroundColor(MediaViewLayoutConstants.HOME_LIST_CARD_BACKGROUND)
        .borderRadius(MediaViewLayoutConstants.HOME_LIST_CARD_RADIUS)
        .clip(true)
      }
      .width('100%')
      .layoutWeight(1)
      .padding({
        left: MediaViewLayoutConstants.HOME_LIST_CARD_MARGIN_H,
        right: MediaViewLayoutConstants.HOME_LIST_CARD_MARGIN_H,
        top: MediaViewLayoutConstants.HOME_LIST_CARD_MARGIN_TOP,
        bottom: MediaViewLayoutConstants.HOME_LIST_CARD_MARGIN_BOTTOM
      })
    } else if (this.isSelectionMode) {
      this.buildSelectionListView()
    } else {
      this.buildNormalListView()
    }
  }
}
