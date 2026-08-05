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
import { MediaViewUiConstants } from '@ohos/common/src/main/ets/constants/MediaViewUiConstants';
import { PlaylistConstants } from '../constants/PlaylistConstants';

/**
 * 歌单曲目行封面区（详�?/ 编辑 / 添加音频共用�?
 * 有封面展示专辑图，无封面展示与添加音频页一致的居中占位图标�?
 */
@Component
export struct PlaylistTrackThumb {
  @Prop track: FileInfo;
  @Prop hasCustomThumb: boolean = false;
  @Prop thumbnailSrc: string | Resource = '';
  @Prop placeholderIcon: Resource = $r('app.media.ic_normal_music');
  @Prop thumbObjectFit: ImageFit = ImageFit.Cover;
  /** Image.key 前缀，区分不同列表场�?*/
  @Prop imageKeyPrefix: string = 'track';
  /** Image 是否允许拖拽（勿命名�?draggable，会与组件内置属性冲突） */
  @Prop imageDraggable: boolean = false;

  build() {
    Stack() {
      Column()
        .width(PlaylistConstants.THUMB_SIZE)
        .height(PlaylistConstants.THUMB_SIZE)
        .backgroundColor(PlaylistConstants.TRACK_THUMB_NO_COVER_BACKGROUND)

      if (this.hasCustomThumb) {
        Image(this.thumbnailSrc)
          .key(`${this.imageKeyPrefix}_cover_${this.track.uri}`)
          .width(PlaylistConstants.THUMB_SIZE)
          .height(PlaylistConstants.THUMB_SIZE)
          .objectFit(this.thumbObjectFit)
          .draggable(this.imageDraggable)
      } else {
        Column() {
          Image(this.placeholderIcon)
            .width(MediaViewUiConstants.PLACEHOLDER_ICON_SIZE)
            .height(MediaViewUiConstants.PLACEHOLDER_ICON_SIZE)
            .objectFit(ImageFit.Contain)
            .opacity(MediaViewUiConstants.PLACEHOLDER_ICON_OPACITY)
        }
        .width(PlaylistConstants.THUMB_SIZE)
        .height(PlaylistConstants.THUMB_SIZE)
        .justifyContent(FlexAlign.Center)
      }
    }
    .width(PlaylistConstants.THUMB_SIZE)
    .height(PlaylistConstants.THUMB_SIZE)
    .borderRadius(6)
    .clip(true)
  }
}
