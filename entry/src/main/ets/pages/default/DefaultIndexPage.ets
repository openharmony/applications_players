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

import { CustomContentDialog } from '@kit.ArkUI';

import { AppThemeConstants } from '@ohos/common/src/main/ets/constants/ui/AppThemeConstants';
import { SortType } from '@ohos/common/src/main/ets/datasource/IMediaDataSource';
import FileInfo from '@ohos/common/src/main/ets/model/FileInfo';
import { MediaType } from '@ohos/common/src/main/ets/datasource/MediaDataSource';
import { AppContext } from '@ohos/common/src/main/ets/context/AppContext';
import { FontScaleUtil } from '@ohos/common/src/main/ets/utils/FontScaleUtil';
import { HiLog } from '@ohos/common/src/main/ets/utils/HiLog';
import { MediaAggregateView } from '@ohos/media/src/main/ets/components/MediaAggregateView';

import { HomeCategoryTabs } from '../../components/HomeCategoryTabs';
import { HomePageHeader } from '../../components/HomePageHeader';
import { HomeViewConstants } from '../../constants/HomeViewConstants';
import { HomeUiState, HomeViewModel, MediaListUiState } from '../../viewmodel/HomeViewModel';

const TAG = 'DefaultIndexPage';

interface SortOptionItem {
  type: SortType;
  label: ResourceStr;
}

/**
 * 首页 View：绑定 HomeViewModel，搜索/设置/播放器由 NavPathStack 承载。
 */
@Component
export struct DefaultIndexPage {
  @State showSortDialog: boolean = false;
  @State menuDismissSignal: number = 0;
  @State currentFilter: string = HomeViewConstants.FILTER_ALL;
  @State showScanDialog: boolean = false;
  @State scanPercent: number = 0;
  @State scanProgressTitle: string = '';
  @State isGridView: boolean = true;
  @State currentSortType: SortType = SortType.DATE;
  @State isDesc: boolean = true;
  @State nameSortDesc: boolean = true;
  @State dateSortDesc: boolean = true;
  @State sizeSortDesc: boolean = true;
  @State mediaType: MediaType = MediaType.UNKNOWN;
  @State isMediaLoading: boolean = true;
  @State hasMediaItems: boolean = false;
  @State showMediaPermissionTip: boolean = false;
  @State usePartialPermissionTip: boolean = false;
  @State isRequestingMediaPermission: boolean = false;
  @State mediaLoadingHint: string = '';
  @State showMediaScanProgress: boolean = false;
  @State mediaItems: FileInfo[] = [];
  @State listItemIsAudio: boolean = false;
  @State listRevision: number = 0;
  @StorageProp('fontScale') @Watch('onFontScaleChanged') fontScale: number = FontScaleUtil.DEFAULT_SCALE;
  private homeViewModel: HomeViewModel = HomeViewModel.getInstance();
  private sortDialogController: CustomDialogController | null = null;
  private scanProgressDialogController: CustomDialogController | null = null;

  aboutToAppear(): void {
    HiLog.i(TAG, 'aboutToAppear');
    const appContext: AppContext = AppContext.getInstance();
    this.homeViewModel.addUiStateListener(this.handleUiStateChange);
    this.homeViewModel.init(appContext.getMainAbilityContext());
    this.homeViewModel.tryPlayPendingExternalFile();
    HiLog.i(TAG, `DefaultIndexPage initialized, filter=${this.currentFilter}`);
  }

  aboutToDisappear(): void {
    HiLog.i(TAG, 'aboutToDisappear');
    this.homeViewModel.removeUiStateListener(this.handleUiStateChange);
    this.homeViewModel.onPageDestroy();
    this.dismissSortDialog();
    this.dismissScanProgressDialog();
  }

  /** HomeViewModel UI 状态回调：将快照同步到 @State */
  private handleUiStateChange = (state: HomeUiState): void => {
    this.menuDismissSignal = state.menuDismissSignal;
    this.showSortDialog = state.showSortDialog;
    this.showScanDialog = state.showScanDialog;
    this.scanPercent = state.scanPercent;
    this.scanProgressTitle = state.scanProgressTitle;
    this.currentFilter = state.currentFilter;
    this.isGridView = state.isGridView;
    this.currentSortType = state.currentSortType;
    this.isDesc = state.isDesc;
    this.nameSortDesc = state.nameSortDesc;
    this.dateSortDesc = state.dateSortDesc;
    this.sizeSortDesc = state.sizeSortDesc;
    this.syncMediaListState(state.mediaList);
    this.syncSortDialog();
    this.syncScanProgressDialog();
  };

  /** 同步媒体列表区 UI 状态 */
  private syncMediaListState(mediaList: MediaListUiState): void {
    this.mediaType = mediaList.mediaType;
    this.isMediaLoading = mediaList.isLoading;
    this.hasMediaItems = mediaList.hasMediaItems;
    this.showMediaPermissionTip = mediaList.showPermissionTip;
    this.usePartialPermissionTip = mediaList.usePartialPermissionTip;
    this.isRequestingMediaPermission = mediaList.isRequestingPermission;
    this.mediaLoadingHint = mediaList.loadingHintText;
    this.showMediaScanProgress = mediaList.showScanProgressDetail;
    this.mediaItems = mediaList.mediaItems;
    this.listItemIsAudio = mediaList.listItemIsAudio;
    this.listRevision = mediaList.listRevision;
    HiLog.i(TAG, `Pipeline[sync/7] Page.syncMediaListState mediaType=${MediaType[mediaList.mediaType]} count=${mediaList.mediaItems.length} revision=${mediaList.listRevision} fontScale=${this.fontScale}`);
  }

  /** AppStorage fontScale 变更：链路[缩放/2] 委托 HomeViewModel 递增 revision 并通知 Page */
  private onFontScaleChanged(): void {
    HiLog.i(TAG, `Pipeline[fontScale/2] Page.onFontScaleChanged fontScale=${this.fontScale}`);
    this.homeViewModel.onFontScaleChanged();
  }

  /** 排序选项列表 */
  private getSortOptionItems(): SortOptionItem[] {
    return [
      { type: SortType.NAME, label: $r('app.string.sort_by_name') },
      { type: SortType.DATE, label: $r('app.string.sort_by_time') },
      { type: SortType.SIZE, label: $r('app.string.sort_by_size') }
    ];
  }

  private getSortDirection(sortType: SortType): boolean {
    switch (sortType) {
      case SortType.NAME:
        return this.nameSortDesc;
      case SortType.DATE:
        return this.dateSortDesc;
      case SortType.SIZE:
        return this.sizeSortDesc;
      default:
        return this.isDesc;
    }
  }

  /** 同步排序弹窗显隐：按 ViewModel showSortDialog 状态驱动 CustomDialogController */
  private syncSortDialog(): void {
    const isOpen: boolean = this.sortDialogController !== null;
    if (this.showSortDialog && !isOpen) {
      this.openSortDialog();
    } else if (!this.showSortDialog && isOpen) {
      this.dismissSortDialog();
    }
  }

  private openSortDialog(): void {
    this.dismissSortDialog();
    this.sortDialogController = new CustomDialogController({
      builder: CustomContentDialog({
        primaryTitle: $r('app.string.sort_dialog_title'),
        contentBuilder: () => {
          this.SortDialogContent();
        },
        buttons: [
          {
            value: $r('app.string.cancel'),
            buttonStyle: ButtonStyleMode.TEXTUAL,
            fontColor: $r('sys.color.font_emphasize'),
            action: () => {
              HiLog.i(TAG, 'Sort dialog cancelled');
              this.homeViewModel.closeSortDialog();
            }
          }
        ]
      }),
      autoCancel: true,
      alignment: DialogAlignment.Center,
      cancel: () => {
        this.homeViewModel.closeSortDialog();
      }
    });
    this.sortDialogController.open();
  }

  private dismissSortDialog(): void {
    if (this.sortDialogController) {
      this.sortDialogController.close();
      this.sortDialogController = null;
    }
  }

  /** 排序弹窗内容区：排序选项列表 */
  @Builder
  SortDialogContent() {
    Column() {
      ForEach(this.getSortOptionItems(), (item: SortOptionItem, index: number) => {
        this.SortOptionRow(item, index > 0)
      }, (item: SortOptionItem) => `${item.type}`)
    }
  }

  @Builder
  SortOptionRow(item: SortOptionItem, showDivider: boolean) {
    Column() {
      if (showDivider) {
        this.SortDivider()
      }
      this.SortOption(item.type, item.label)
    }
    .width('100%')
  }

  @Builder
  SortDivider() {
    Divider()
      .strokeWidth(0.5)
      .color(AppThemeConstants.BORDER)
      .margin({ left: 16, right: 16 })
  }

  @Builder
  SortOption(sortType: SortType, label: ResourceStr) {
    Stack() {
      Text(label)
        .fontSize(15)
        .fontColor(this.currentSortType === sortType ? AppThemeConstants.ACCENT : AppThemeConstants.TEXT_PRIMARY)
        .fontWeight(this.currentSortType === sortType ? 600 : 400)
        .width('100%')
        .textAlign(TextAlign.Center)
      if (this.currentSortType === sortType) {
        Row() {
          Blank().layoutWeight(1)
          SymbolGlyph(this.getSortDirection(sortType) ? $r('sys.symbol.arrow_down') : $r('sys.symbol.arrow_up'))
            .fontSize(16)
            .fontColor([AppThemeConstants.ACCENT])
            .margin({ right: 12 })
        }
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height(48)
    .onClick(() => {
      const nextIsDesc: boolean = this.currentSortType === sortType ? !this.getSortDirection(sortType) :
        this.getSortDirection(sortType);
      HiLog.i(TAG, `Pipeline[sort/1] Sort item clicked sortType=${sortType}`);
      this.homeViewModel.selectSort(sortType, nextIsDesc);
    })
  }

  /** 同步扫描进度弹窗显隐 */
  private syncScanProgressDialog(): void {
    const isOpen: boolean = this.scanProgressDialogController !== null;
    if (this.showScanDialog && !isOpen) {
      this.openScanProgressDialog();
    } else if (!this.showScanDialog && isOpen) {
      this.dismissScanProgressDialog();
    }
  }

  private openScanProgressDialog(): void {
    this.dismissScanProgressDialog();
    this.scanProgressDialogController = new CustomDialogController({
      builder: CustomContentDialog({
        contentBuilder: () => {
          this.ScanProgressDialogContent();
        }
      }),
      autoCancel: false,
      alignment: DialogAlignment.Center
    });
    this.scanProgressDialogController.open();
  }

  private dismissScanProgressDialog(): void {
    if (this.scanProgressDialogController) {
      this.scanProgressDialogController.close();
      this.scanProgressDialogController = null;
    }
  }

  /** 扫描进度弹窗内容区：标题 + 进度条 + 百分比 */
  @Builder
  ScanProgressDialogContent() {
    Column({ space: 12 }) {
      Text() {
        Span(this.scanProgressTitle.length > 0 ?
          this.scanProgressTitle : $r('app.string.scanning_media_files'))
          .fontSize($r('sys.float.ohos_id_text_size_body1'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Span('⋯')
          .fontSize($r('sys.float.ohos_id_text_size_body1'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
      }
      .width('100%')
      .textAlign(TextAlign.Start)

      Progress({
        value: this.scanPercent,
        total: 100,
        type: ProgressType.Linear
      })
        .width('100%')
        .height(6)
        .color(AppThemeConstants.ACCENT)
        .backgroundColor(AppThemeConstants.BORDER)

      Text($r('app.string.progress',`${this.scanPercent}%`))
        .fontSize($r('sys.float.ohos_id_text_size_body2'))
        .fontWeight(FontWeight.Regular)
        .fontColor($r('sys.color.font_secondary'))
        .width('100%')
        .textAlign(TextAlign.End)
    }
    .width('100%')
  }

  build() {
    Stack() {
      Column() {
        this.Header()
        MediaAggregateView({
          mediaType: this.mediaType,
          isLoading: this.isMediaLoading,
          hasMediaItems: this.hasMediaItems,
          showPermissionTip: this.showMediaPermissionTip,
          isRequestingPermission: this.isRequestingMediaPermission,
          loadingHintText: this.mediaLoadingHint,
          showScanProgressDetail: this.showMediaScanProgress,
          mediaItems: this.mediaItems,
          listItemIsAudio: this.listItemIsAudio,
          listRevision: this.listRevision,
          fontScale: this.fontScale,
          isGridView: $isGridView,
          homeLayoutStyle: true,
          homeEmptyTitle: $r('app.string.media_empty_title'),
          homeEmptyHint: $r('app.string.media_empty_hint'),
          permissionTipText: this.usePartialPermissionTip
            ? $r('app.string.media_permission_tip_partial')
            : $r('app.string.media_permission_tip'),
          permissionGrantText: $r('app.string.media_permission_grant'),
          loadingDefaultText: $r('app.string.media_loading'),
          onRequestPermission: () => {
            this.homeViewModel.requestMediaPermission();
          },
          onMediaClick: (fileInfo: FileInfo) => {
            this.homeViewModel.playFromFileInfo(fileInfo);
          },
          onSwipeDeleteMedia: (fileInfo: FileInfo) => {
            void this.homeViewModel.deleteMediaBySwipe(fileInfo.uri);
          }
        })
          .width('100%')
          .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(HomeViewConstants.PAGE_BACKGROUND)

    }
  }

  @Builder
  Header() {
    Column() {
      this.NormalHeader()
    }
    .width('100%')
    .backgroundColor(HomeViewConstants.PAGE_BACKGROUND)
  }

  /** 常规顶栏（标题 + 搜索/导入/更多菜单 + 分类 Tab） */
  @Builder
  NormalHeader() {
    Column() {
      HomePageHeader({
        menuDismissSignal: this.menuDismissSignal,
        isGridView: this.isGridView,
        onSearch: () => {
          this.homeViewModel.openSearchOverlay();
        },
        onImport: () => {
          this.homeViewModel.importMediaFilesAndScan();
        },
        onRefresh: () => {
          this.homeViewModel.startScan(true);
        },
        onToggleView: () => {
          this.homeViewModel.toggleViewMode();
        },
        onOpenSort: () => {
          this.homeViewModel.openSortDialog();
        },
        onOpenEdit: () => {
          this.homeViewModel.openHomeMediaEdit();
        },
        onOpenSettings: () => {
          this.homeViewModel.openSettingsOverlay();
        }
      })

      HomeCategoryTabs({
        currentFilter: this.currentFilter,
        onFilterSelected: (filterKey: string) => {
          this.homeViewModel.setFilter(filterKey);
        }
      })
    }
    .width('100%')
    .backgroundColor(HomeViewConstants.PAGE_BACKGROUND)
  }
}
