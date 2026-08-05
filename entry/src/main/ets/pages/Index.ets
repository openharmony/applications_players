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
import { appLocalStorage, initAppLocalStorageDefaults } from '@ohos/common/src/main/ets/storage/AppLocalStorage';
import { HiLog } from '@ohos/common/src/main/ets/utils/HiLog';
import WindowUtil from '@ohos/common/src/main/ets/utils/WindowUtil';

import { PermissionUiConstants } from '../constants/PermissionUiConstants';
import { PermissionViewModel } from '../viewmodel/PermissionViewModel';
import { MainPage } from './MainPage';

const TAG = 'Index';

/** 应用入口：挂载 MainPage，首次启动时展示权限弹窗 */
@Entry(appLocalStorage)
@Component
struct Index {
  @State isRequesting: boolean = false;
  private viewModel: PermissionViewModel = PermissionViewModel.getInstance();
  private permissionDialogController: CustomDialogController | null = null;

  aboutToAppear(): void {
    initAppLocalStorageDefaults();
    const permState = this.viewModel.getPermissionState();
    HiLog.i(TAG, `aboutToAppear permissionState=${permState}`);
    this.preparePermissionDialog();
  }

  aboutToDisappear(): void {
    this.dismissPermissionDialog();
  }

  /** 页面重新可见：权限半模态已结束但 isRequesting 未复位时解除按钮禁用 */
  onPageShow(): void {
    if (this.isRequesting && !WindowUtil.isPermissionSheetChromeActive()) {
      HiLog.w(TAG, 'onPageShow reset isRequesting: permission sheet chrome inactive');
      this.isRequesting = false;
    }
  }

  /** 冷启动时异步检查系统授权，仅未授权且本会话未拒绝时展示弹窗 */
  private preparePermissionDialog(): void {
    this.viewModel.prepareLaunchPermissionCheck()
      .then((shouldShow: boolean) => {
        HiLog.i(TAG, `preparePermissionDialog shouldShow=${shouldShow}`);
        if (shouldShow) {
          this.showPermissionDialog();
        }
      })
      .catch((error: Error) => {
        HiLog.e(TAG, `preparePermissionDialog failed message=${error.message}`);
      });
  }

  private showPermissionDialog(): void {
    this.dismissPermissionDialog();
    this.permissionDialogController = new CustomDialogController({
      builder: CustomContentDialog({
        primaryTitle: $r('app.string.permission_dialog_title'),
        contentBuilder: () => {
          this.PermissionDialogContent();
        }
      }),
      autoCancel: false,
      alignment: DialogAlignment.Center
    });
    this.permissionDialogController.open();
  }

  private dismissPermissionDialog(): void {
    if (this.permissionDialogController) {
      this.permissionDialogController.close();
      this.permissionDialogController = null;
    }
  }

  /**
   * 先发起系统授权（或跳转设置），成功后再关闭弹窗。
   * 提前关闭 CustomDialog 会导致系统授权窗/设置页无法可靠拉起。
   */
  private handleGrantClick(): void {
    if (this.isRequesting) {
      return;
    }
    this.isRequesting = true;
    HiLog.i(TAG, `permission grant clicked requesting=${this.isRequesting}`);
    this.viewModel.confirmGrantFromCustomDialog()
      .then((state: string) => {
        HiLog.i(TAG, `permission grant finished state=${state}`);
        this.isRequesting = false;
        this.dismissPermissionDialog();
      })
      .catch((error: Error) => {
        HiLog.e(TAG, `permission grant failed message=${error.message}`);
        this.isRequesting = false;
        this.dismissPermissionDialog();
      });
  }

  /** 权限弹窗内容区：描述 + 功能列表 + 按钮 */
  @Builder
  PermissionDialogContent() {
    Column({ space: PermissionUiConstants.DIALOG_CONTENT_SPACE }) {
      Text($r('app.string.permission_dialog_desc'))
        .fontSize(PermissionUiConstants.DESC_FONT_SIZE)
        .fontColor(PermissionUiConstants.DESC_COLOR)
        .lineHeight(22)
        .width('100%')
        .textAlign(TextAlign.Start)

      Column({ space: PermissionUiConstants.FEATURE_ITEM_SPACE }) {
        Text($r('app.string.permission_feature_scan'))
          .fontSize(PermissionUiConstants.FEATURE_FONT_SIZE)
          .fontColor(PermissionUiConstants.FEATURE_COLOR)
          .width('100%')
        Text($r('app.string.permission_feature_play'))
          .fontSize(PermissionUiConstants.FEATURE_FONT_SIZE)
          .fontColor(PermissionUiConstants.FEATURE_COLOR)
          .width('100%')
        Text($r('app.string.permission_feature_playlist'))
          .fontSize(PermissionUiConstants.FEATURE_FONT_SIZE)
          .fontColor(PermissionUiConstants.FEATURE_COLOR)
          .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .margin({ top: 4, bottom: 8 })

      Button($r('app.string.permission_grant_enter'))
        .width('100%')
        .height(PermissionUiConstants.PRIMARY_BUTTON_HEIGHT)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppThemeConstants.ON_ACCENT_TEXT)
        .backgroundColor(PermissionUiConstants.PRIMARY_BUTTON_COLOR)
        .borderRadius(10)
        .enabled(!this.isRequesting)
        .onClick(() => {
          HiLog.i(TAG, `Grant permission clicked requesting=${this.isRequesting}`);
          this.handleGrantClick();
        })

      Button($r('app.string.permission_deny'))
        .width('100%')
        .height(PermissionUiConstants.SECONDARY_BUTTON_HEIGHT)
        .fontSize(14)
        .fontColor(PermissionUiConstants.SECONDARY_TEXT_COLOR)
        .backgroundColor(AppThemeConstants.CHIP_BACKGROUND)
        .borderRadius(10)
        .enabled(!this.isRequesting)
        .onClick(() => {
          HiLog.i(TAG, `Close dialog clicked requesting=${this.isRequesting}`);
          this.viewModel.dismissDialogWithoutGrant();
          this.dismissPermissionDialog();
        })
    }
    .width('100%')
    .padding(PermissionUiConstants.DIALOG_PADDING)
  }

  build() {
    Column() {
      MainPage()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppThemeConstants.PAGE_BACKGROUND)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
