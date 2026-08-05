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
import { MediaAggregateView } from '@ohos/media/src/main/ets/components/MediaAggregateView';
import { HiLog } from '@ohos/common/src/main/ets/utils/HiLog';
import { HomeViewModel, HomeUiState, MediaListUiState } from '../viewmodel/HomeViewModel';
import { HomeSelectionHeader } from './HomeSelectionHeader';
import { HomeCategoryTabs } from './HomeCategoryTabs';
import { HomeViewConstants } from '../constants/HomeViewConstants';
import { MediaType } from '@ohos/common/src/main/ets/datasource/MediaDataSource';
import { FontScaleUtil } from '@ohos/common/src/main/ets/utils/FontScaleUtil';
//import { AlertDialog } from '@kit.ArkUI';

const TAG = 'HomeMediaEditPage';

/**
 * 首页媒体编辑 Nav 页：多选、全选、滑动涂选与批量删除（视图模式与首页一致）
 */
@Component
export struct HomeMediaEditPage {
  @State currentFilter: string = HomeViewConstants.FILTER_ALL;
  @State isGridView: boolean = true;
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
  @State selectedUris: string[] = [];
  @State selectedCount: number = 0;
  @State isAllSelected: boolean = false;
  @State showDeleteConfirm: boolean = false;
  @StorageProp('fontScale') fontScale: number = FontScaleUtil.DEFAULT_SCALE;
  private homeViewModel: HomeViewModel = HomeViewModel.getInstance();
  /** 弹出批量删除确认弹窗（AlertDialog 高级组件） */
  private showDeleteDialog(): void {
    if (this.selectedCount === 0) {
      return;
    }
    this.getUIContext().showAlertDialog({
      title: $r('app.string.media_delete_confirm_title'),
      message: $r('app.string.media_delete_confirm_message', this.selectedCount),
      primaryButton: {
        value: $r('app.string.cancel'),
        action: () => {
          HiLog.i(TAG, 'cancel delete');
        }
      },
      secondaryButton: {
        value: $r('app.string.delete'),
        action: () => {
          this.homeViewModel.confirmDeleteSelected();
        }
      }
    });
  }


  aboutToAppear(): void {
    HiLog.i(TAG, 'aboutToAppear');
    this.homeViewModel.addUiStateListener(this.handleUiStateChange);
    this.applyUiState(this.homeViewModel.getUiState());
  }

  aboutToDisappear(): void {
    HiLog.i(TAG, 'aboutToDisappear');
    this.homeViewModel.removeUiStateListener(this.handleUiStateChange);
  }

  /** HomeViewModel UI 状态回调：将快照同步到 @State */
  private handleUiStateChange = (state: HomeUiState): void => {
    this.applyUiState(state);
  };

  /** 将 HomeUiState 同步到本页 @State */
  private applyUiState(state: HomeUiState): void {
    this.currentFilter = state.currentFilter;
    this.isGridView = state.isGridView;
    this.selectedUris = state.selectedUris;
    this.selectedCount = state.selectedCount;
    this.isAllSelected = state.isAllSelected;
    this.showDeleteConfirm = state.showDeleteConfirm;
    this.syncMediaListState(state.mediaList);
  }

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
  }

  build() {
    Stack() {
      Column() {
        HomeSelectionHeader({
          selectedCount: this.selectedCount,
          isAllSelected: this.isAllSelected,
          onBack: () => {
            HiLog.i(TAG, 'Back clicked, exiting edit mode');
            this.homeViewModel.closeHomeMediaEdit();
          },
          onToggleSelectAll: () => {
            this.homeViewModel.toggleSelectAll();
          },
          onDelete: () => {
            this.showDeleteDialog();
          }
        })

        HomeCategoryTabs({
          currentFilter: this.currentFilter,
          onFilterSelected: (filterKey: string) => {
            this.homeViewModel.setFilter(filterKey);
          }
        })

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
          isSelectionMode: true,
          selectedUris: this.selectedUris,
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
          onMediaClick: (_fileInfo: FileInfo) => {
          },
          onToggleSelect: (uri: string) => {
            this.homeViewModel.toggleSelect(uri);
          },
          onReplaceSelection: (uris: string[]) => {
            this.homeViewModel.replaceSelection(uris);
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
}
