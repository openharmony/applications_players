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


import { SearchUiConstants } from '../constants/SearchUiConstants';

/**
 * 搜索胶囊：无外部搜索按钮，输入即回调；有内容时保留系统清除按钮。
 * 背景/文字色使用鸿蒙系统资源（sys.color）。
 */
@Component
export struct SearchBar {
  @Prop @Watch('syncTextFromParent') text: string = '';
  placeholder: ResourceStr = $r('app.string.search_placeholder');
  @Prop isSearching: boolean = false;
  onTextChange: (value: string) => void = () => {};

  @State private draftText: string = '';

  aboutToAppear(): void {
    this.draftText = this.text;
  }

  private syncTextFromParent(): void {
    if (this.draftText !== this.text) {
      this.draftText = this.text;
    }
  }

  build() {
    Stack({ alignContent: Alignment.End }) {
      Search({ value: this.draftText, placeholder: this.placeholder })
        .width('100%')
        .height(SearchUiConstants.SEARCH_BAR_HEIGHT)
        .backgroundColor(SearchUiConstants.SEARCH_BAR_BACKGROUND)
        .borderRadius(SearchUiConstants.SEARCH_BAR_RADIUS)
        .border({
          width: SearchUiConstants.SEARCH_BAR_BORDER_WIDTH,
          color: SearchUiConstants.SEARCH_BAR_BORDER_COLOR
        })
        .placeholderColor($r('sys.color.ohos_id_color_text_secondary'))
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .textFont({ size: SearchUiConstants.SEARCH_INPUT_FONT_SIZE })
        .placeholderFont({ size: SearchUiConstants.SEARCH_INPUT_FONT_SIZE })
        .searchButton('')
        .cancelButton({
          style: CancelButtonStyle.INPUT
        })
        .enterKeyType(EnterKeyType.Search)
        .onChange((value: string) => {
          this.draftText = value;
          this.onTextChange(value);
        })

      if (this.isSearching) {
        LoadingProgress()
          .width(20)
          .height(20)
          .color(SearchUiConstants.SEARCH_BUTTON_COLOR)
          .margin({ right: SearchUiConstants.SEARCH_BUTTON_PADDING_H })
      }
    }
    .width('100%')
    .height(SearchUiConstants.SEARCH_BAR_HEIGHT)
  }
}
