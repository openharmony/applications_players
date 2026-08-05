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

@Component
export struct EmptyStateView {
  @Prop icon: Resource = $r('app.media.ic_empty_state');
  @Prop title: ResourceStr = '';
  @Prop description: ResourceStr = '';
  @Prop fullHeight: boolean = false;

  build() {
    Column({ space: 16 }) {
      Image(this.icon)
        .width(200)
        .height(200)

      Text(this.title)
        .fontSize(16)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        .textAlign(TextAlign.Center)

      Text(this.description)
        .fontSize(14)
        .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .height(this.fullHeight ? '100%' : 300)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}
