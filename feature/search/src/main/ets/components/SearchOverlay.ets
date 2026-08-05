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

import { NavBackButton } from '@ohos/common';
import { AudioItem } from '@ohos/common/src/main/ets/model/AudioItem';
import { VideoItem } from '@ohos/common/src/main/ets/model/VideoItem';
import { EmptyStateView } from '@ohos/common/src/main/ets/component/EmptyStateView';
import { SearchViewModel, SearchOverlayUiState } from '../viewmodel/SearchViewModel';
import { AudioSearchResultItem, VideoSearchResultItem } from './SearchResultItem';
import { HiLog } from '@ohos/common/src/main/ets/utils/HiLog';
import { SearchUiConstants } from '@ohos/common/src/main/ets/constants/SearchUiConstants';
import { SearchBar } from '@ohos/common/src/main/ets/component/SearchBar';
import { AppThemeConstants } from '@ohos/common/src/main/ets/constants/ui/AppThemeConstants';

const TAG = 'SearchOverlay';

/**
 * 即时反馈型全局搜索单页：
 * 无输入 → 搜索历史；有输入 → 实时结果列表 / 空状态。
 */
@Component
export struct SearchOverlay {
  onClose?: () => void;
  onPlayAudio?: (audio: AudioItem) => void;
  onPlayVideo?: (video: VideoItem) => void;

  @State searchText: string = '';
  @State historyKeywords: string[] = [];
  @State quickKeywords: string[] = [];
  @State showIdlePanel: boolean = true;
  @State showResultPanel: boolean = false;
  @State filteredAudios: AudioItem[] = [];
  @State filteredVideos: VideoItem[] = [];
  @State isSearching: boolean = false;
  @State totalCount: number = 0;
  @State keywords: string[] = [];

  private searchViewModel: SearchViewModel = SearchViewModel.getInstance();

  aboutToAppear(): void {
    HiLog.i(TAG, 'aboutToAppear');
    this.searchViewModel.addOverlayUiListener(this.handleOverlayUiStateChange);
    this.searchViewModel.onOverlayOpened();
  }

  aboutToDisappear(): void {
    HiLog.i(TAG, 'aboutToDisappear');
    this.searchViewModel.removeOverlayUiListener(this.handleOverlayUiStateChange);
    this.searchViewModel.onOverlayClosed();
  }

  private handleOverlayUiStateChange = (state: SearchOverlayUiState): void => {
    this.searchText = state.searchText;
    this.historyKeywords = state.historyKeywords;
    this.quickKeywords = state.quickKeywords;
    this.showIdlePanel = state.showIdlePanel;
    this.showResultPanel = state.showResultPanel;
    this.filteredAudios = state.filteredAudios;
    this.filteredVideos = state.filteredVideos;
    this.isSearching = state.isSearching;
    this.totalCount = state.totalCount;
    this.keywords = state.keywords;
  };

  private getNoResultDescription(): ResourceStr {
    return $r('app.string.search_no_audio_desc', this.searchText);
  }

  @Builder
  SearchNavBar() {
    Row({ space: 10 }) {
      NavBackButton({
        onBack: () => {
          this.onCancelClick();
        }
      })

      SearchBar({
        text: this.searchText,
        placeholder: $r('app.string.search_placeholder'),
        isSearching: this.isSearching,
        onTextChange: (value: string) => {
          this.searchViewModel.updateSearchText(value);
        }
      })
        .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({
      left: SearchUiConstants.NAV_HORIZONTAL_PADDING,
      right: SearchUiConstants.NAV_HORIZONTAL_PADDING,
      top: SearchUiConstants.NAV_TOP_PADDING,
      bottom: 8
    })
  }

  @Builder
  IdlePanel() {
    Scroll() {
      Column({ space: SearchUiConstants.CARD_MARGIN_TOP }) {
        this.HistoryCard()
      }
      .width('100%')
      .padding({
        left: SearchUiConstants.CARD_MARGIN_H,
        right: SearchUiConstants.CARD_MARGIN_H,
        top: 4,
        bottom: 16
      })
    }
    .layoutWeight(1)
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
  }

  @Builder
  HistoryCard() {
    Column() {
      Row() {
        Text($r('app.string.search_history_title'))
          .fontSize(SearchUiConstants.CARD_TITLE_FONT_SIZE)
          .fontWeight(SearchUiConstants.CARD_TITLE_FONT_WEIGHT)
          .fontColor(SearchUiConstants.TITLE_COLOR)
          .layoutWeight(1)

        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.trash'))
            .fontSize(SearchUiConstants.TRASH_ICON_SIZE)
            .fontColor([AppThemeConstants.TEXT_SECONDARY])
        }
        .width(32)
        .height(32)
        .backgroundColor($r('sys.color.ohos_id_color_background_transparent'))
        .onClick(() => {
          this.searchViewModel.clearOverlaySearchHistory();
        })
      }
      .width('100%')
      .margin({ bottom: 12 })

      if (this.historyKeywords.length === 0) {
        Text($r('app.string.search_history_empty'))
          .fontSize(SearchUiConstants.CHIP_SUBTITLE_FONT_SIZE)
          .fontColor(SearchUiConstants.CHIP_SUBTITLE_COLOR)
      } else {
        // 每行固定 2 条：左对齐、无背景、文字自动换行
        Grid() {
          ForEach(this.historyKeywords, (keyword: string) => {
            GridItem() {
              this.HistoryTextItem(keyword)
            }
          }, (keyword: string) => `history_${keyword}`)
        }
        .columnsTemplate('1fr 1fr')
        .columnsGap(SearchUiConstants.HISTORY_ITEM_GAP_H)
        .rowsGap(SearchUiConstants.HISTORY_ITEM_GAP_V)
        .width('100%')
      }
    }
    .width('100%')
    .padding(SearchUiConstants.CARD_PADDING)
    .backgroundColor(SearchUiConstants.CARD_BACKGROUND)
    .borderRadius(SearchUiConstants.CARD_RADIUS)
  }

  @Builder
  HistoryTextItem(keyword: string) {
    Text(keyword)
      .fontSize(SearchUiConstants.HISTORY_FONT_SIZE)
      .fontColor(SearchUiConstants.TITLE_COLOR)
      .textAlign(TextAlign.Start)
      .width('100%')
      .backgroundColor($r('sys.color.ohos_id_color_background_transparent'))
      .onClick(() => {
        this.searchViewModel.applyKeywordAndSearch(keyword);
      })
  }

  @Builder
  ResultPanel() {
    if (this.isSearching && this.filteredAudios.length === 0 && this.filteredVideos.length === 0) {
      Column() {
        LoadingProgress()
          .width(48)
          .height(48)
          .color($r('sys.color.ohos_id_color_emphasize'))
        Text($r('app.string.searching'))
          .fontSize(14)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          .margin({ top: 12 })
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    } else if (this.totalCount === 0 && !this.isSearching) {
      // 无结果：图标+文本作为整体在剩余区域居中
      Column() {
        EmptyStateView({
          title: $r('app.string.search_no_audio_title'),
          description: this.getNoResultDescription()
        })
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    } else {
      Scroll() {
        Column() {
          this.ResultCard()
        }
        .width('100%')
        .padding({
          left: SearchUiConstants.RESULT_CARD_MARGIN_H,
          right: SearchUiConstants.RESULT_CARD_MARGIN_H,
          top: SearchUiConstants.RESULT_CARD_MARGIN_TOP,
          bottom: 16
        })
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
  }

  /**
   * 搜索结果白底卡片：左右外边距由 ResultPanel 控制为 16
   */
  @Builder
  ResultCard() {
    Column() {
      Row() {
        Text($r('app.string.search_result_count', this.totalCount))
          .fontSize(SearchUiConstants.RESULT_HEADER_FONT_SIZE)
          .fontWeight(SearchUiConstants.RESULT_HEADER_FONT_WEIGHT)
          .fontColor(SearchUiConstants.TITLE_COLOR)
          .layoutWeight(1)

        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.trash'))
            .fontSize(SearchUiConstants.TRASH_ICON_SIZE)
            .fontColor([AppThemeConstants.TEXT_SECONDARY])
        }
        .width(SearchUiConstants.RESULT_HEADER_ACTION_SIZE)
        .height(SearchUiConstants.RESULT_HEADER_ACTION_SIZE)
        .backgroundColor($r('sys.color.ohos_id_color_background_transparent'))
        .onClick(() => {
          // 清空当前搜索词，回到历史空态
          this.searchViewModel.updateSearchText('');
        })
      }
      .width('100%')
      .margin({ bottom: SearchUiConstants.RESULT_HEADER_MARGIN_BOTTOM })

      ForEach(this.filteredAudios, (item: AudioItem, index: number) => {
        AudioSearchResultItem({
          audio: item,
          keywords: this.keywords,
          showDivider: index < this.filteredAudios.length - 1 || this.filteredVideos.length > 0,
          onItemClick: (audio: AudioItem) => this.playAudio(audio)
        })
      }, (item: AudioItem) => `audio_${item.id}`)

      ForEach(this.filteredVideos, (item: VideoItem, index: number) => {
        VideoSearchResultItem({
          video: item,
          keywords: this.keywords,
          showDivider: index < this.filteredVideos.length - 1,
          onItemClick: (video: VideoItem) => this.playVideo(video)
        })
      }, (item: VideoItem) => `video_${item.id}`)
    }
    .width('100%')
    .padding({
      left: SearchUiConstants.RESULT_CARD_PADDING_H,
      right: SearchUiConstants.RESULT_CARD_PADDING_RIGHT,
      top: SearchUiConstants.RESULT_CARD_PADDING_V,
      bottom: SearchUiConstants.RESULT_CARD_PADDING_V
    })
    .backgroundColor(SearchUiConstants.CARD_BACKGROUND)
    .borderRadius(SearchUiConstants.RESULT_CARD_RADIUS)
  }

  private onCancelClick(): void {
    HiLog.i(TAG, 'Back button pressed, closing search');
    this.searchViewModel.closeOverlaySession();
    if (this.onClose) {
      this.onClose();
    }
  }

  private playAudio(audio: AudioItem): void {
    // 选中结果视为最终确认，写入历史
    if (this.searchText.trim().length > 0) {
      this.searchViewModel.addSearchHistory(this.searchText.trim());
    }
    if (this.onPlayAudio) {
      this.onPlayAudio(audio);
    }
  }

  private playVideo(video: VideoItem): void {
    if (this.searchText.trim().length > 0) {
      this.searchViewModel.addSearchHistory(this.searchText.trim());
    }
    if (this.onPlayVideo) {
      this.onPlayVideo(video);
    }
  }

  build() {
    Column() {
      this.SearchNavBar()
      if (this.showIdlePanel) {
        this.IdlePanel()
      } else if (this.showResultPanel) {
        this.ResultPanel()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(SearchUiConstants.PAGE_BACKGROUND)
  }
}
