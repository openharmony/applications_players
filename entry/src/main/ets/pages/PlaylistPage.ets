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



import { AlertDialog, CustomContentDialog } from '@kit.ArkUI';

import { AppContext } from '@ohos/common/src/main/ets/context/AppContext';
import { HiLog } from '@ohos/common/src/main/ets/utils/HiLog';
import {
  PlaylistConfirmMode,
  PlaylistConstants,
  PlaylistDataSource,
  PlaylistItem,
  PlaylistListView,
  PlaylistNameDialogMode,
  PlaylistNameInputHintType,
  PlaylistNameInputUtil
} from '@ohos/playlist';

import {
  PlaylistUiState,
  PlaylistViewModel
} from '../viewmodel/PlaylistViewModel';

const TAG = 'PlaylistPage';

/**
 * 播放列表 Tab 根页面：列表层 + CustomDialog；详情/编辑/添加音频由 NavPathStack 承载
 */
@Component
export struct PlaylistPage {
  @State isEmpty: boolean = true;
  /** CustomContentDialog 内容区状态 */
  @State nameDialogMode: PlaylistNameDialogMode = PlaylistNameDialogMode.NONE;
  @State nameDialogInputName: string = '';
  @State nameDialogInputHintType: PlaylistNameInputHintType = PlaylistNameInputHintType.NONE;

  private viewModel: PlaylistViewModel = PlaylistViewModel.getInstance();
  private playlistDataSource: PlaylistDataSource = this.viewModel.getPlaylistDataSource();
  private nameDialogController: CustomDialogController | null = null;
  private confirmDialogController: CustomDialogController | null = null;

  aboutToAppear(): void {
    HiLog.i(TAG, 'aboutToAppear');
    this.viewModel.addUiStateListener(this.handleUiStateChange);
    this.viewModel.init(AppContext.getInstance().getMainAbilityContext());
    this.viewModel.syncDetailResumeUi();
  }

  aboutToDisappear(): void {
    HiLog.i(TAG, 'aboutToDisappear');
    this.dismissNameDialog();
    this.dismissConfirmDialog();
    this.viewModel.removeUiStateListener(this.handleUiStateChange);
  }

  /**
   * 按 ViewModel 意图同步 CustomDialog 显隐
   */
  private syncCustomDialog(shouldOpen: boolean, isOpen: boolean, onOpen: () => void, onClose: () => void): void {
    if (shouldOpen && !isOpen) {
      onOpen();
    } else if (!shouldOpen && isOpen) {
      onClose();
    }
  }

  private syncNameDialog(mode: PlaylistNameDialogMode, initialName: string): void {
    this.syncCustomDialog(
      mode !== PlaylistNameDialogMode.NONE,
      this.nameDialogController !== null,
      () => this.showNameDialog(mode, initialName),
      () => this.dismissNameDialog()
    );
  }

  private syncConfirmDialog(mode: PlaylistConfirmMode, targetCount: number): void {
    this.syncCustomDialog(
      mode !== PlaylistConfirmMode.NONE,
      this.confirmDialogController !== null,
      () => this.showConfirmDialog(mode, targetCount),
      () => this.dismissConfirmDialog()
    );
  }

  private showNameDialog(mode: PlaylistNameDialogMode, initialName: string): void {
    this.dismissNameDialog();
    this.nameDialogMode = mode;
    this.nameDialogInputName = PlaylistNameInputUtil.sanitize(initialName);
    this.nameDialogInputHintType = PlaylistNameInputHintType.NONE;

    this.nameDialogController = new CustomDialogController({
      builder: CustomContentDialog({
        primaryTitle: this.nameDialogMode === PlaylistNameDialogMode.CREATE ?
          $r('app.string.playlist_create_dialog_title') :
          $r('app.string.playlist_rename_dialog_title'),
        contentBuilder: () => {
          this.NameDialogContent();
        },
        buttons: [
          {
            value: $r('app.string.cancel'),
            buttonStyle: ButtonStyleMode.TEXTUAL,
           fontColor: $r('sys.color.font_emphasize'),
            action: () => {
              HiLog.i(TAG, `name dialog cancel mode=${this.nameDialogMode}`);
              this.viewModel.closeNameDialog();
            }
          },
          {
            value: $r('app.string.confirm'),
            buttonStyle: ButtonStyleMode.TEXTUAL,
           fontColor: $r('sys.color.font_emphasize'),
            role: ButtonRole.NORMAL,
            action: () => {
              if (this.nameDialogInputName.length === 0) {
                return;
              }
              HiLog.i(TAG, `name dialog confirm name=${this.nameDialogInputName}`);
              this.viewModel.submitNameDialog(this.nameDialogInputName);
            }
          }
        ]
      }),
      autoCancel: true,
      alignment: DialogAlignment.Center,
      cancel: () => {
        this.viewModel.closeNameDialog();
      }
    });
    this.nameDialogController.open();
    HiLog.i(TAG, `showNameDialog mode=${mode}`);
  }

  private dismissNameDialog(): void {
    if (this.nameDialogController) {
      this.nameDialogController.close();
      this.nameDialogController = null;
    }
    this.nameDialogInputHintType = PlaylistNameInputHintType.NONE;
  }

  /**
   * CustomContentDialog 内容区 @Builder：标题 + 输入 + 提示
   */
  @Builder
  NameDialogContent() {
    Column() {
      Column() {
        TextInput({
          text: this.nameDialogInputName,
          placeholder: $r('app.string.playlist_name_placeholder')
        })
          .maxLength(PlaylistConstants.MAX_NAME_LENGTH)
          .width('100%')
          .showUnderline(true)
          .padding(0)
          .height(PlaylistConstants.NAME_DIALOG_INPUT_HEIGHT)
          .fontWeight(FontWeight.Regular)
          .placeholderColor($r('sys.color.font_secondary'))
          .fontColor($r('sys.color.font_primary'))
          .fontSize($r('sys.float.ohos_id_text_size_body1'))
          .inputFilter(PlaylistConstants.PLAYLIST_NAME_INPUT_FILTER, (invalid: string) => {
            HiLog.i(TAG, `nameInputReject invalid=${invalid}`);
            this.nameDialogInputHintType = PlaylistNameInputHintType.INVALID_CHAR;
          })
          .onChange((value: string) => {
            this.onNameInputChange(value);
          })
      }
      .width('100%')
      .padding({
        left: PlaylistConstants.NAME_DIALOG_HORIZONTAL_PADDING,
        right: PlaylistConstants.NAME_DIALOG_HORIZONTAL_PADDING,
        bottom: PlaylistConstants.NAME_DIALOG_INPUT_BOTTOM_PADDING
      })

      Row() {
        if (this.nameDialogInputHintType === PlaylistNameInputHintType.INVALID_CHAR) {
          Text($r('app.string.playlist_name_invalid_chars'))
            .fontSize(PlaylistConstants.NAME_DIALOG_HINT_FONT_SIZE)
            .fontColor(PlaylistConstants.DELETE_COLOR)
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        } else if (this.nameDialogInputHintType === PlaylistNameInputHintType.TOO_LONG) {
          Text($r('app.string.playlist_name_too_long'))
            .fontSize(PlaylistConstants.NAME_DIALOG_HINT_FONT_SIZE)
            .fontColor(PlaylistConstants.DELETE_COLOR)
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        } else {
          Text('')
            .layoutWeight(1)
        }

        Text(`${this.nameDialogInputName.length}/${PlaylistConstants.MAX_NAME_LENGTH}`)
          .fontSize(PlaylistConstants.NAME_DIALOG_HINT_FONT_SIZE)
          .fontColor(this.nameDialogInputName.length >= PlaylistConstants.MAX_NAME_LENGTH ?
            PlaylistConstants.DELETE_COLOR : PlaylistConstants.TEXT_SECONDARY)
      }
      .width('100%')
      .height(PlaylistConstants.NAME_DIALOG_HINT_AREA_HEIGHT)
      .alignItems(VerticalAlign.Center)
      .padding({
        left: PlaylistConstants.NAME_DIALOG_HORIZONTAL_PADDING,
        right: PlaylistConstants.NAME_DIALOG_HORIZONTAL_PADDING
      })
    }
  }

  /**
   * 输入变更：超长截断并展示提示；合法输入时清除超长提示。
   */
  private onNameInputChange(value: string): void {
    if (value.length >= PlaylistConstants.MAX_NAME_LENGTH) {
      this.nameDialogInputName = value.substring(0, PlaylistConstants.MAX_NAME_LENGTH);
      this.nameDialogInputHintType = PlaylistNameInputHintType.TOO_LONG;
      HiLog.w(TAG, `nameInputExceed max=${PlaylistConstants.MAX_NAME_LENGTH}`);
      return;
    }
    this.nameDialogInputName = value;
    if (this.nameDialogInputHintType !== PlaylistNameInputHintType.INVALID_CHAR) {
      this.nameDialogInputHintType = PlaylistNameInputHintType.NONE;
    }
  }

  private showConfirmDialog(mode: PlaylistConfirmMode, targetCount: number): void {
    this.dismissConfirmDialog();
    this.confirmDialogController = new CustomDialogController({
      builder: AlertDialog({
        primaryTitle: mode === PlaylistConfirmMode.DELETE_PLAYLIST ?
          $r('app.string.playlist_delete_confirm_title') :
          mode === PlaylistConfirmMode.DELETE_PLAYLISTS ?
            $r('app.string.playlist_delete_playlists_confirm', targetCount) :
            $r('app.string.playlist_delete_tracks_confirm', targetCount),
        primaryButton: {
          value: $r('app.string.cancel'),
          action: () => {
            HiLog.i(TAG, `confirm dialog cancel mode=${mode}`);
            this.viewModel.closeConfirmDialog();
          }
        },
        secondaryButton: {
          value: $r('app.string.delete'),
          action: () => {
            HiLog.i(TAG, `confirm dialog delete mode=${mode} count=${targetCount}`);
            void this.viewModel.confirmDialogAction();
          }
        }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Center,
      cancel: () => {
        this.viewModel.closeConfirmDialog();
      }
    });
    this.confirmDialogController.open();
    HiLog.i(TAG, `showConfirmDialog mode=${mode} count=${targetCount}`);
  }

  private dismissConfirmDialog(): void {
    if (this.confirmDialogController) {
      this.confirmDialogController.close();
      this.confirmDialogController = null;
    }
  }

  private handleUiStateChange = (state: PlaylistUiState): void => {
    this.isEmpty = state.isEmpty;
    this.syncNameDialog(state.nameDialogMode, state.nameDialogInitialName);
    this.syncConfirmDialog(state.confirmDialogMode, state.confirmTargetCount);
  };

  @Builder
  build() {
    PlaylistListView({
      isEmpty: this.isEmpty,
      dataSource: this.playlistDataSource,
      onCreateClick: () => {
        this.viewModel.openCreateDialog();
      },
      onOpenDetail: (item: PlaylistItem) => {
        void this.viewModel.openPlaylistDetail(item);
      },
      onPlay: (item: PlaylistItem) => {
        this.viewModel.playPlaylist(item);
      },
      onRename: (item: PlaylistItem) => {
        this.viewModel.openRenameDialog(item);
      },
      onDelete: (item: PlaylistItem) => {
        this.viewModel.openDeletePlaylistConfirm(item);
      },
      onSwipeDeletePlaylist: (item: PlaylistItem) => {
        HiLog.i(TAG, `onSwipeDeletePlaylist id=${item.id} name=${item.name}`);
        void this.viewModel.deletePlaylistBySwipe(item);
      },
      onReorderPlaylist: (from: number, to: number) => {
        this.viewModel.reorderPlaylist(from, to);
      },
      onEnterSelectMode: (item: PlaylistItem) => {
        this.viewModel.openListSelectPage(item);
      }
    })
  }
}
