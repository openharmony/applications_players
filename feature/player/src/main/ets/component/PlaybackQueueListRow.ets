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


import { PlaybackQueueEntry } from '@ohos/common';
import { AppThemeConstants } from '@ohos/common/src/main/ets/constants/ui/AppThemeConstants';
import { MediaFormatUtil } from '@ohos/common/src/main/ets/utils/MediaFormatUtil';
import { PlaybackQueueSheetConstants } from '../constants/PlaybackQueueSheetConstants';
import { PlayingEqualizerBars } from './PlayingEqualizerBars';

/**
 * 播放队列半模态列表行：上行文件名，下行大小/分辨率；当前项白底圆角高亮
 */
@Component
export struct PlaybackQueueListRow {
  @Prop @Watch('onEntryPropChange') entry: PlaybackQueueEntry = {
    index: -1,
    uri: '',
    fileName: '',
    mimeType: '',
    isCurrent: false,
    fileSize: 0,
    picWidth: 0,
    picHeight: 0
  };
  @Prop @Watch('syncRowHighlightState') isCurrent: boolean = false;
  @Prop @Watch('syncRowHighlightState') isDragging: boolean = false;
  @Prop @Watch('syncEqualizerState') isMediaPlaying: boolean = false;
  @Prop @Watch('syncEqualizerState') equalizerAnimTick: number = 0;
  /** 历史等只读：隐藏均衡器与移除叉号 */
  @Prop showQueueActions: boolean = true;
  @Prop isSelectionMode: boolean = false;
  @Prop isSelected: boolean = false;
  /** 历史扁平列表：略宽左右内边距，无通栏贴边 */
  @Prop flatHistoryStyle: boolean = false;
  /** 兼容旧卡片内嵌（与 flatHistoryStyle 相同边距策略） */
  @Prop insideCard: boolean = false;
  onRemove?: () => void;
  onRowClick?: () => void;
  onToggleSelect?: () => void;

  @State titleText: string = '';
  @State subtitleText: string = '';
  @State currentItemActive: boolean = false;
  @State rowDragging: boolean = false;
  @State equalizerPlaying: boolean = false;
  @State equalizerTick: number = 0;

  aboutToAppear(): void {
    this.syncRowHighlightState();
    this.syncEqualizerState();
    this.refreshDisplay();
  }

  aboutToUpdate(): void {
    this.syncRowHighlightState();
    this.syncEqualizerState();
    this.refreshDisplay();
  }

  private onEntryPropChange(): void {
    this.refreshDisplay();
  }

  private syncEqualizerState(): void {
    this.equalizerPlaying = this.isMediaPlaying;
    this.equalizerTick = this.equalizerAnimTick;
  }

  private syncRowHighlightState(): void {
    this.currentItemActive = this.isCurrent;
    this.rowDragging = this.isDragging;
  }

  private shouldShowHighlightBackground(): boolean {
    return this.isCurrent || this.rowDragging;
  }

  private getRowBackgroundColor(): ResourceColor {
    if (this.isSelectionMode && this.isSelected) {
      return PlaybackQueueSheetConstants.ROW_SELECTED_OVERLAY;
    }
    if (this.isCurrent) {
      return PlaybackQueueSheetConstants.ROW_ITEM_CURRENT_BACKGROUND;
    }
    if (this.rowDragging) {
      return PlaybackQueueSheetConstants.ROW_ITEM_DRAG_BACKGROUND;
    }
    return $r('sys.color.ohos_id_color_background_transparent');
  }

  private handleRowActivated(): void {
    if (this.isSelectionMode) {
      if (this.onToggleSelect) {
        this.onToggleSelect();
      }
      return;
    }
    if (this.onRowClick) {
      this.onRowClick();
    }
  }

  private resolveFileSizeBytes(): number {
    if (this.entry.fileSize !== undefined && this.entry.fileSize > 0) {
      return this.entry.fileSize;
    }
    return 0;
  }

  private resolveResolutionText(): string {
    const width = this.entry.picWidth !== undefined ? this.entry.picWidth : 0;
    const height = this.entry.picHeight !== undefined ? this.entry.picHeight : 0;
    if (width > 0 && height > 0) {
      return `${width}×${height}`;
    }
    return '';
  }

  /** 下行：有分辨率则「大小 · 分辨率」，否则仅大小 */
  private buildSubtitle(): string {
    const sizeBytes = this.resolveFileSizeBytes();
    const sizeText = sizeBytes > 0 ? MediaFormatUtil.formatFileSizeDecimal(sizeBytes) : '';
    const resolution = this.resolveResolutionText();
    if (sizeText.length > 0 && resolution.length > 0) {
      return `${sizeText} · ${resolution}`;
    }
    if (sizeText.length > 0) {
      return sizeText;
    }
    return resolution;
  }

  private refreshDisplay(): void {
    this.titleText = this.entry.fileName.length > 0 ? this.entry.fileName : this.entry.uri;
    this.subtitleText = this.buildSubtitle();
  }

  @Builder
  TrackTexts() {
    Column({ space: 2 }) {
      Text(this.titleText)
        .fontSize(PlaybackQueueSheetConstants.ROW_TITLE_FONT_SIZE)
        .fontWeight(this.isCurrent ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(PlaybackQueueSheetConstants.ROW_TITLE_COLOR)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      if (this.subtitleText.length > 0) {
        Text(this.subtitleText)
          .fontSize(PlaybackQueueSheetConstants.ROW_SUBTITLE_FONT_SIZE)
          .fontColor(PlaybackQueueSheetConstants.ROW_SUBTITLE_COLOR)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Start)
  }

  @Builder
  RowActionButton(icon: Resource, onClick?: () => void) {
    Button({ type: ButtonType.Circle }) {
      SymbolGlyph(icon)
        .fontSize(PlaybackQueueSheetConstants.ROW_ACTION_ICON_SIZE)
        .fontColor([PlaybackQueueSheetConstants.ROW_ACTION_COLOR])
        .fontWeight(FontWeight.Medium)
    }
    .width(PlaybackQueueSheetConstants.ROW_ACTION_HIT_SIZE)
    .height(PlaybackQueueSheetConstants.ROW_ACTION_HIT_SIZE)
    .backgroundColor($r('sys.color.ohos_id_color_background_transparent'))
    .draggable(false)
    .onClick(() => {
      if (onClick) {
        onClick();
      }
    })
  }

  build() {
    Column() {
      Row({ space: PlaybackQueueSheetConstants.ROW_TEXT_GAP }) {
        if (this.isSelectionMode) {
          Checkbox()
            .select(this.isSelected)
            .selectedColor(AppThemeConstants.ACCENT)
            .width(PlaybackQueueSheetConstants.ROW_CHECKBOX_SIZE)
            .height(PlaybackQueueSheetConstants.ROW_CHECKBOX_SIZE)
            .hitTestBehavior(HitTestMode.None)
            .alignSelf(ItemAlign.Center)
        }

        this.TrackTexts()

        // 当前播放均衡器在文件名右侧、移除叉号之前；叉号相对双行文案垂直居中
        if (this.showQueueActions && !this.isSelectionMode) {
          Row({ space: PlaybackQueueSheetConstants.ROW_ACTION_GAP }) {
            if (this.currentItemActive) {
              PlayingEqualizerBars({
                alwaysVisible: true,
                isPlaying: this.equalizerPlaying,
                animTick: this.equalizerTick
              })
            }

            this.RowActionButton(PlaybackQueueSheetConstants.ICON_REMOVE, () => {
              if (this.onRemove) {
                this.onRemove();
              }
            })
          }
          .alignItems(VerticalAlign.Center)
          .alignSelf(ItemAlign.Center)
        }
      }
      .width('100%')
      .padding({
        left: PlaybackQueueSheetConstants.ROW_CONTENT_PADDING_H,
        right: PlaybackQueueSheetConstants.ROW_CONTENT_PADDING_H,
        top: PlaybackQueueSheetConstants.ROW_VERTICAL_PADDING,
        bottom: PlaybackQueueSheetConstants.ROW_VERTICAL_PADDING
      })
      .margin({
        left: PlaybackQueueSheetConstants.ROW_MARGIN_H,
        right: PlaybackQueueSheetConstants.ROW_MARGIN_H
      })
      .backgroundColor(this.getRowBackgroundColor())
      .borderRadius(this.shouldShowHighlightBackground() ?
        PlaybackQueueSheetConstants.ROW_HIGHLIGHT_RADIUS : 0)
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        this.handleRowActivated();
      })

      if (!this.isCurrent && !this.rowDragging) {
        // 分割线对齐首页「更多」：1px 发丝线 + list_separator + 左右缩进
        Divider()
          .color(PlaybackQueueSheetConstants.ROW_DIVIDER_COLOR)
          .height(PlaybackQueueSheetConstants.ROW_DIVIDER_STROKE)
          .lineCap(LineCapStyle.Square)
          .padding({
            left: PlaybackQueueSheetConstants.ROW_DIVIDER_PADDING,
            right: PlaybackQueueSheetConstants.ROW_DIVIDER_PADDING
          })
      }
    }
    .width('100%')
  }
}
