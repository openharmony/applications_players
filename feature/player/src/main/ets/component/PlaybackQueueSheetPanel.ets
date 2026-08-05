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

import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';

import { HiLog, PlaybackHistoryRestoreCallback, PlaybackHistoryTrackItem, PlaybackQueueEntry } from '@ohos/common';
import { AppThemeConstants } from '@ohos/common/src/main/ets/constants/ui/AppThemeConstants';
import { Constants } from '@ohos/common/src/main/ets/constants/ui/Constants';
import { AudioLoopMode } from '@ohos/common/src/main/ets/constants/player/PlayConstants';
import { SafeAreaConstants } from '@ohos/common/src/main/ets/constants/ui/SafeAreaConstants';

import { PlaybackHistoryConstants } from '../constants/PlaybackHistoryConstants';
import { PlaybackQueueSheetConstants, PlaybackQueueSheetTab } from '../constants/PlaybackQueueSheetConstants';
import { AVPlayerController } from '../controller/AVPlayerController';
import { AudioPlaybackSession } from '../session/AudioPlaybackSession';
import { PlaybackQueueSheetUiState, PlaybackQueueSheetViewModel } from '../viewmodel/PlaybackQueueSheetViewModel';
import { PlaybackQueueListRow } from './PlaybackQueueListRow';

const TAG = 'PlaybackQueueSheetPanel';

/**
 * 播放队列半模态 View：顶栏 + 胶囊 Tab + 操作条 + 列表
 */
@Component
export struct PlaybackQueueSheetPanel {
  @Link activeTab: number;
  @Prop isAudio: boolean = true;
  @Prop avPlayerController: AVPlayerController = new AVPlayerController();
  onRestoreHistoryPlayback?: PlaybackHistoryRestoreCallback;
  onAudioQueueEmpty?: () => void;
  onDismiss?: () => void;
  @State isMediaPlaying: boolean = false;
  @State equalizerAnimTick: number = 0;
  @State currentIndex: number = -1;
  @State queueCount: number = 0;
  @State sourceName: string = '';
  @State longPressUri: string = '';
  @State historyTracks: PlaybackHistoryTrackItem[] = [];
  @State isSelectionMode: boolean = false;
  @State selectedUris: string[] = [];
  @State audioLoopMode: AudioLoopMode = AudioLoopMode.LIST;
  @StorageProp(SafeAreaConstants.NAVI_INDICATOR_HEIGHT_KEY) naviIndicatorHeight: number = 0;

  private viewModel: PlaybackQueueSheetViewModel = PlaybackQueueSheetViewModel.getInstance();
  private listScroller: ListScroller = new ListScroller();
  private pendingInitialScroll: boolean = false;

  aboutToAppear(): void {
    this.pendingInitialScroll = true;
    this.activeTab = PlaybackQueueSheetTab.CURRENT;
    this.viewModel.addUiListener(this.handleUiStateChange);
    const context = getContext(this) as common.UIAbilityContext;
    if (this.onRestoreHistoryPlayback !== undefined) {
      this.viewModel.setHistoryRestoreHandler(this.onRestoreHistoryPlayback);
    }
    if (this.onAudioQueueEmpty !== undefined) {
      this.viewModel.setAudioQueueEmptyHandler(this.onAudioQueueEmpty);
    }
    this.syncLoopModeFromController();
    this.viewModel.onPanelAppear(this.isAudio, this.avPlayerController, context);
    HiLog.i(TAG, `aboutToAppear tab=${this.activeTab}`);
  }

  aboutToDisappear(): void {
    this.exitSelectionMode();
    this.viewModel.removeUiListener(this.handleUiStateChange);
    this.viewModel.onPanelDisappear();
    HiLog.i(TAG, 'aboutToDisappear');
  }

  private handleUiStateChange = (state: PlaybackQueueSheetUiState): void => {
    this.currentIndex = state.currentIndex;
    this.queueCount = state.queueCount;
    this.sourceName = state.sourceName;
    this.isMediaPlaying = state.isMediaPlaying;
    this.longPressUri = state.longPressUri;
    this.equalizerAnimTick = state.equalizerAnimTick;
    if (this.historyTracks !== state.historyTracks) {
      this.historyTracks = state.historyTracks;
    }
    this.tryScrollToCurrentItem(state.currentIndex, state.queueCount);
  };

  private resolvePlaybackController(): AVPlayerController {
    if (this.isAudio) {
      return AudioPlaybackSession.getInstance().getController();
    }
    return this.avPlayerController;
  }

  private syncLoopModeFromController(): void {
    this.audioLoopMode = this.resolvePlaybackController().getAudioLoopMode();
  }

  private getLoopModeIcon(): Resource {
    if (this.audioLoopMode === AudioLoopMode.SINGLE) {
      return Constants.APP_BAR_ICON_REPEAT_ONE;
    }
    if (this.audioLoopMode === AudioLoopMode.RANDOM) {
      return Constants.APP_BAR_ICON_SHUFFLE;
    }
    return Constants.APP_BAR_ICON_REPEAT_LIST;
  }

  private getLoopModeLabel(): Resource {
    if (this.audioLoopMode === AudioLoopMode.SINGLE) {
      return $r('app.string.player_mode_single_loop');
    }
    if (this.audioLoopMode === AudioLoopMode.RANDOM) {
      return $r('app.string.player_mode_shuffle');
    }
    return $r('app.string.player_mode_list_loop');
  }

  private handleCycleLoopMode(): void {
    this.audioLoopMode = this.resolvePlaybackController().cycleAudioLoopMode();
    promptAction.showToast({ message: this.getLoopModeLabel() });
    HiLog.i(TAG, `cycleLoopMode mode=${this.audioLoopMode}`);
  }

  private handleDismiss(): void {
    if (this.onDismiss) {
      this.onDismiss();
    }
  }

  private tryScrollToCurrentItem(currentIndex: number, queueCount: number): void {
    if (!this.pendingInitialScroll) {
      return;
    }
    if (this.activeTab !== PlaybackQueueSheetTab.CURRENT || queueCount === 0 || currentIndex < 0) {
      return;
    }
    this.pendingInitialScroll = false;
    setTimeout(() => {
      try {
        this.listScroller.scrollToIndex(currentIndex, false, ScrollAlign.CENTER);
        HiLog.i(TAG, `scrollToCurrentItem index=${currentIndex}`);
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        HiLog.w(TAG, `scrollToCurrentItem failed message=${message}`);
      }
    }, PlaybackQueueSheetConstants.LIST_INITIAL_SCROLL_DELAY_MS);
  }

  private selectTab(tab: number): void {
    if (this.isSelectionMode || this.activeTab === tab) {
      return;
    }
    HiLog.i(TAG, `selectTab tab=${tab}`);
    this.activeTab = tab;
    if (tab === PlaybackQueueSheetTab.HISTORY) {
      this.viewModel.onHistoryTabSelected();
    }
  }

  private handleQueueItemClick(uri: string): void {
    this.viewModel.playQueueItemByUri(uri);
  }

  private handleRemoveItem(uri: string): void {
    this.viewModel.removeQueueItemByUri(uri);
  }

  private handleQueueItemLongPress(uri: string, fileName: string): void {
    this.viewModel.onLongPressStart(uri, fileName);
  }

  private isQueueRowCurrent(uri: string): boolean {
    return this.viewModel.matchesCurrentUri(uri, this.currentIndex);
  }

  private isQueueRowDragging(uri: string): boolean {
    return this.longPressUri.length > 0 && this.longPressUri === uri;
  }

  private enterSelectionMode(): void {
    this.isSelectionMode = true;
    this.selectedUris = [];
  }

  private exitSelectionMode(): void {
    this.isSelectionMode = false;
    this.selectedUris = [];
  }

  private toggleSelection(uri: string): void {
    const pos = this.selectedUris.indexOf(uri);
    if (pos >= 0) {
      const next: string[] = [];
      for (let i = 0; i < this.selectedUris.length; i++) {
        if (this.selectedUris[i] !== uri) {
          next.push(this.selectedUris[i]);
        }
      }
      this.selectedUris = next;
    } else {
      this.selectedUris = this.selectedUris.concat([uri]);
    }
  }

  private toggleSelectAll(): void {
    const total = this.viewModel.getDataSource().totalCount();
    if (total === 0) {
      return;
    }
    if (this.selectedUris.length >= total) {
      this.selectedUris = [];
      return;
    }
    const allUris: string[] = [];
    for (let i = 0; i < total; i++) {
      allUris.push(this.viewModel.getDataSource().getData(i).uri);
    }
    this.selectedUris = allUris;
  }

  private isQueueAllSelected(): boolean {
    const total = this.viewModel.getDataSource().totalCount();
    return total > 0 && this.selectedUris.length >= total;
  }

  private isUriSelected(uri: string): boolean {
    return this.selectedUris.indexOf(uri) >= 0;
  }

  private showDeleteSelectedConfirm(): void {
    if (this.selectedUris.length === 0) {
      return;
    }
    const count = this.selectedUris.length;
    const urisToDelete: string[] = this.selectedUris.slice();
    AlertDialog.show({
      message: $r('app.string.player_queue_delete_confirm', count),
      primaryButton: {
        value: $r('app.string.player_queue_cancel'),
        action: () => {
        }
      },
      secondaryButton: {
        value: $r('app.string.player_queue_delete_selected'),
        fontColor: AppThemeConstants.DELETE,
        action: () => {
          this.viewModel.removeQueueItemsByUris(urisToDelete);
          this.exitSelectionMode();
        }
      }
    });
  }

  /** 顶栏：播放列表纯文本 + 关闭 */
  @Builder
  TopBar() {
    Row() {
      Text($r('app.string.player_queue_sheet_title'))
        .fontSize(PlaybackQueueSheetConstants.SOURCE_FONT_SIZE)
        .fontWeight(FontWeight.Bold)
        .fontColor(PlaybackQueueSheetConstants.SOURCE_TEXT_COLOR)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)

      Button({ type: ButtonType.Circle }) {
        SymbolGlyph(PlaybackQueueSheetConstants.ICON_CLOSE)
          .fontSize(PlaybackQueueSheetConstants.CLOSE_ICON_SIZE)
          .fontColor([PlaybackQueueSheetConstants.TAB_ACTIVE_TEXT])
      }
      .width(PlaybackQueueSheetConstants.CLOSE_BUTTON_SIZE)
      .height(PlaybackQueueSheetConstants.CLOSE_BUTTON_SIZE)
      .backgroundColor(PlaybackQueueSheetConstants.CLOSE_BUTTON_BG)
      .onClick(() => {
        this.handleDismiss();
      })
    }
    .width('100%')
    .padding({
      left: PlaybackQueueSheetConstants.SHEET_HEADER_PADDING_H,
      right: PlaybackQueueSheetConstants.SHEET_HEADER_PADDING_H,
      top: PlaybackQueueSheetConstants.SHEET_HEADER_PADDING_TOP,
      bottom: PlaybackQueueSheetConstants.SHEET_HEADER_PADDING_BOTTOM
    })
    .alignItems(VerticalAlign.Center)
  }

  /** 操作条「来自」标识（书名号括起） */
  @Builder
  SourceBadge() {
    Text(this.sourceName.length > 0 ?
      $r('app.string.player_queue_source_playlist', this.sourceName) :
      $r('app.string.player_queue_source_library'))
      .fontSize(PlaybackQueueSheetConstants.ACTION_BAR_FONT_SIZE)
      .fontColor($r('sys.color.font_secondary'))
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .constraintSize({ maxWidth: '42%' })
  }

  /** 大胶囊分段 Tab */
  @Builder
  SegmentTabs() {
    Row() {
      Row() {
        this.SegmentTabItem(PlaybackQueueSheetTab.CURRENT, $r('app.string.player_queue_tab_current'),
          this.queueCount)
        this.SegmentTabItem(PlaybackQueueSheetTab.HISTORY, $r('app.string.player_queue_tab_history'),
          this.historyTracks.length)
      }
      .width('100%')
      .height(PlaybackQueueSheetConstants.SEGMENT_HEIGHT)
      .padding(PlaybackQueueSheetConstants.SEGMENT_PADDING)
      .backgroundColor(PlaybackQueueSheetConstants.SEGMENT_BG)
      .borderRadius(PlaybackQueueSheetConstants.SEGMENT_RADIUS)
    }
    .width('100%')
    .padding({
      left: PlaybackQueueSheetConstants.SEGMENT_MARGIN_H,
      right: PlaybackQueueSheetConstants.SEGMENT_MARGIN_H
    })
    .margin({ bottom: PlaybackQueueSheetConstants.SEGMENT_BOTTOM_MARGIN })
  }

  @Builder
  SegmentTabItem(tab: number, label: Resource, count: number) {
    Row({ space: 4 }) {
      Text(label)
        .fontSize(PlaybackQueueSheetConstants.SEGMENT_FONT_SIZE)
        .fontWeight(this.activeTab === tab ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(PlaybackQueueSheetConstants.TAB_ACTIVE_TEXT)
      if (count > 0) {
        Text(`${count}`)
          .fontSize(PlaybackQueueSheetConstants.SEGMENT_FONT_SIZE)
          .fontWeight(this.activeTab === tab ? FontWeight.Medium : FontWeight.Regular)
          .fontColor(PlaybackQueueSheetConstants.TAB_ACTIVE_TEXT)
      }
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .borderRadius(PlaybackQueueSheetConstants.SEGMENT_RADIUS - 2)
    .backgroundColor(this.activeTab === tab ?
      PlaybackQueueSheetConstants.SEGMENT_ACTIVE_BG :
      $r('sys.color.ohos_id_color_background_transparent'))
    .onClick(() => {
      HiLog.i(TAG, `segmentTab clicked tab=${tab}`);
      this.selectTab(tab);
    })
  }

  /** 当前播放操作条：循环模式 + 来自标识 + 多选垃圾桶 */
  @Builder
  CurrentActionBar() {
    Row() {
      Row({ space: PlaybackQueueSheetConstants.ACTION_BAR_GAP }) {
        SymbolGlyph(this.getLoopModeIcon())
          .fontSize(PlaybackQueueSheetConstants.ACTION_BAR_ICON_SIZE)
          .fontColor([PlaybackQueueSheetConstants.TAB_ACTIVE_TEXT])
        Text(this.getLoopModeLabel())
          .fontSize(PlaybackQueueSheetConstants.ACTION_BAR_FONT_SIZE)
          .fontColor(PlaybackQueueSheetConstants.TAB_ACTIVE_TEXT)
      }
      .onClick(() => {
        this.handleCycleLoopMode();
      })

      Row() {
        this.SourceBadge()
      }
      .margin({ left: PlaybackQueueSheetConstants.ACTION_BAR_GAP })
      .layoutWeight(1)
      .justifyContent(FlexAlign.Start)

      if (this.queueCount > 1) {
        SymbolGlyph(PlaybackQueueSheetConstants.ICON_CLEAR_QUEUE)
          .fontSize(PlaybackQueueSheetConstants.ACTION_BAR_ICON_SIZE)
          .fontColor([PlaybackQueueSheetConstants.TAB_ACTIVE_TEXT])
          .onClick(() => {
            this.enterSelectionMode();
          })
      }
    }
    .width('100%')
    .height(PlaybackQueueSheetConstants.ACTION_BAR_HEIGHT)
    .padding({
      left: PlaybackQueueSheetConstants.ACTION_BAR_MARGIN_H,
      right: PlaybackQueueSheetConstants.ACTION_BAR_MARGIN_H
    })
    .margin({ bottom: PlaybackQueueSheetConstants.ACTION_BAR_BOTTOM_MARGIN })
    .alignItems(VerticalAlign.Center)
  }

  /** 历史播放操作条：仅右侧垃圾桶（多于一首时清空历史） */
  @Builder
  HistoryActionBar() {
    Row() {
      Blank()

      if (this.historyTracks.length > 1) {
        SymbolGlyph(PlaybackQueueSheetConstants.ICON_CLEAR_QUEUE)
          .fontSize(PlaybackQueueSheetConstants.ACTION_BAR_ICON_SIZE)
          .fontColor([PlaybackQueueSheetConstants.TAB_ACTIVE_TEXT])
          .onClick(() => {
            this.viewModel.clearHistoryTracks();
          })
      }
    }
    .width('100%')
    .height(PlaybackQueueSheetConstants.ACTION_BAR_HEIGHT)
    .padding({
      left: PlaybackQueueSheetConstants.ACTION_BAR_MARGIN_H,
      right: PlaybackQueueSheetConstants.ACTION_BAR_MARGIN_H
    })
    .margin({ bottom: PlaybackQueueSheetConstants.ACTION_BAR_BOTTOM_MARGIN })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  SelectionHeader() {
    Row() {
      Text($r('app.string.player_queue_cancel'))
        .fontSize(PlaybackQueueSheetConstants.SHEET_TAB_FONT_SIZE)
        .fontColor(PlaybackQueueSheetConstants.TAB_ACTIVE_TEXT)
        .onClick(() => {
          this.exitSelectionMode();
        })

      Text(this.selectedUris.length > 0 ?
        $r('app.string.player_queue_selection_count', this.selectedUris.length) :
        $r('app.string.player_queue_selection_none'))
        .fontSize(PlaybackQueueSheetConstants.SHEET_TAB_FONT_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor(PlaybackQueueSheetConstants.TAB_ACTIVE_TEXT)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      Button({ type: ButtonType.Normal }) {
        SymbolGlyph(this.isQueueAllSelected() ?
          $r('sys.symbol.checkmark_square_on_square_fill') :
          $r('sys.symbol.checkmark_square_on_square'))
          .fontSize(PlaybackQueueSheetConstants.SHEET_HEADER_ACTION_ICON_SIZE)
          .fontColor([this.isQueueAllSelected() ?
            $r('sys.color.font_emphasize') :
            PlaybackQueueSheetConstants.TAB_ACTIVE_TEXT])
          .renderingStrategy(SymbolRenderingStrategy.SINGLE)
      }
      .width(PlaybackQueueSheetConstants.ROW_ACTION_HIT_SIZE)
      .height(PlaybackQueueSheetConstants.ROW_ACTION_HIT_SIZE)
      .backgroundColor($r('sys.color.ohos_id_color_background_transparent'))
      .onClick(() => {
        this.toggleSelectAll();
      })
    }
    .width('100%')
    .padding({
      left: PlaybackQueueSheetConstants.SHEET_HEADER_PADDING_H,
      right: PlaybackQueueSheetConstants.SHEET_HEADER_PADDING_H,
      top: PlaybackQueueSheetConstants.SHEET_HEADER_PADDING_TOP,
      bottom: PlaybackQueueSheetConstants.SHEET_HEADER_PADDING_BOTTOM
    })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  SelectionDeleteBar() {
    Row() {
      Button($r('app.string.player_queue_delete_selected'))
        .width('100%')
        .height(PlaybackQueueSheetConstants.SELECTION_DELETE_BAR_HEIGHT)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
        .backgroundColor(AppThemeConstants.DELETE)
        .borderRadius(PlaybackQueueSheetConstants.SELECTION_DELETE_RADIUS)
        .enabled(this.selectedUris.length > 0)
        .opacity(this.selectedUris.length > 0 ? 1 : 0.45)
        .onClick(() => {
          this.showDeleteSelectedConfirm();
        })
    }
    .width('100%')
    .padding({
      left: PlaybackQueueSheetConstants.SHEET_HEADER_PADDING_H,
      right: PlaybackQueueSheetConstants.SHEET_HEADER_PADDING_H,
      top: 8,
      bottom: 8
    })
  }

  @Builder
  CurrentQueueList() {
    if (this.queueCount === 0) {
      Column() {
        Text($r('app.string.player_queue_empty'))
          .fontSize(PlaybackQueueSheetConstants.EMPTY_TEXT_FONT_SIZE)
          .fontColor(PlaybackQueueSheetConstants.EMPTY_TEXT_COLOR)
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    } else {
      List({ scroller: this.listScroller, space: PlaybackQueueSheetConstants.LIST_ITEM_SPACE }) {
        LazyForEach(this.viewModel.getDataSource(), (entry: PlaybackQueueEntry) => {
          ListItem() {
            PlaybackQueueListRow({
              entry: entry,
              isCurrent: this.isQueueRowCurrent(entry.uri),
              isDragging: this.isQueueRowDragging(entry.uri),
              isMediaPlaying: this.isMediaPlaying,
              equalizerAnimTick: this.equalizerAnimTick,
              isSelectionMode: this.isSelectionMode,
              isSelected: this.isUriSelected(entry.uri),
              showQueueActions: !this.isSelectionMode,
              onRemove: () => {
                this.handleRemoveItem(entry.uri);
              },
              onRowClick: () => {
                this.handleQueueItemClick(entry.uri);
              },
              onToggleSelect: () => {
                this.toggleSelection(entry.uri);
              }
            })
          }
          .width('100%')
          .parallelGesture(
            LongPressGesture({
              repeat: false,
              duration: PlaybackQueueSheetConstants.ROW_DRAG_LONG_PRESS_DURATION_MS
            })
              .onAction(() => {
                if (this.isSelectionMode) {
                  return;
                }
                this.handleQueueItemLongPress(entry.uri, entry.fileName);
              })
              .onActionEnd(() => {
                this.viewModel.onLongPressEnd();
              }),
            GestureMask.Normal
          )
        }, (entry: PlaybackQueueEntry) => this.viewModel.buildQueueItemKey(entry))
          .onMove((from: number, to: number) => {
            if (this.isSelectionMode) {
              return;
            }
            this.viewModel.reorderQueue(from, to);
          })
      }
      .layoutWeight(1)
      .width('100%')
      .clip(true)
      .cachedCount(PlaybackQueueSheetConstants.LIST_PREFETCH_COUNT)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .divider({ strokeWidth: 0 })
      .padding({
        left: PlaybackQueueSheetConstants.LIST_CONTENT_MARGIN_H,
        right: PlaybackQueueSheetConstants.LIST_CONTENT_MARGIN_H
      })
    }
  }

  private handleHistoryTrackClick(track: PlaybackHistoryTrackItem): void {
    this.viewModel.playHistoryTrack(track);
    this.handleDismiss();
  }

  private toHistoryQueueEntry(track: PlaybackHistoryTrackItem, index: number): PlaybackQueueEntry {
    return {
      index: index,
      uri: track.uri,
      fileName: track.fileName,
      mimeType: track.mimeType,
      isCurrent: false,
      fileSize: track.fileSize !== undefined ? track.fileSize : 0,
      picWidth: track.picWidth !== undefined ? track.picWidth : 0,
      picHeight: track.picHeight !== undefined ? track.picHeight : 0
    };
  }

  /** 历史播放：扁平单曲列表（无卡片描边/阴影；无均衡器与叉号） */
  @Builder
  HistoryTrackList() {
    if (this.historyTracks.length === 0) {
      Column() {
        Text($r('app.string.player_queue_history_empty'))
          .fontSize(PlaybackHistoryConstants.EMPTY_TEXT_FONT_SIZE)
          .fontColor(PlaybackHistoryConstants.EMPTY_TEXT_COLOR)
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    } else {
      List({ space: PlaybackQueueSheetConstants.LIST_ITEM_SPACE }) {
        ForEach(this.historyTracks, (track: PlaybackHistoryTrackItem, index: number) => {
          ListItem() {
            PlaybackQueueListRow({
              entry: this.toHistoryQueueEntry(track, index),
              isCurrent: false,
              isDragging: false,
              isMediaPlaying: false,
              equalizerAnimTick: 0,
              showQueueActions: false,
              flatHistoryStyle: true,
              onRowClick: () => {
                this.handleHistoryTrackClick(track);
              }
            })
          }
          .width('100%')
        }, (track: PlaybackHistoryTrackItem, index: number) => `${track.uri}_${index}`)
      }
      .layoutWeight(1)
      .width('100%')
      .clip(true)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .divider({ strokeWidth: 0 })
      .padding({
        left: PlaybackQueueSheetConstants.LIST_CONTENT_MARGIN_H,
        right: PlaybackQueueSheetConstants.LIST_CONTENT_MARGIN_H
      })
    }
  }

  build() {
    Column() {
      Column() {
        if (this.isSelectionMode) {
          this.SelectionHeader()
        } else {
          this.TopBar()
          this.SegmentTabs()
          if (this.activeTab === PlaybackQueueSheetTab.CURRENT) {
            this.CurrentActionBar()
          } else {
            this.HistoryActionBar()
          }
        }
      }
      .width('100%')
      .backgroundColor(PlaybackQueueSheetConstants.SHEET_ROOT_BACKGROUND)
      .zIndex(1)

      if (this.activeTab === PlaybackQueueSheetTab.CURRENT || this.isSelectionMode) {
        this.CurrentQueueList()
      } else {
        this.HistoryTrackList()
      }

      if (this.isSelectionMode) {
        this.SelectionDeleteBar()
      }
    }
    .width('100%')
    .height('100%')
    .clip(true)
    .padding({ bottom: this.naviIndicatorHeight })
    .backgroundColor(PlaybackQueueSheetConstants.SHEET_ROOT_BACKGROUND)
  }
}
