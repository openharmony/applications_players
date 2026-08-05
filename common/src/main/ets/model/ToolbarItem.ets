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

import { WindowType } from '../constants/preview/PreviewConstants';
import { Constants } from '../constants/ui/Constants';

@Observed
export default class ToolbarItem {
  public title: ResourceStr;
  public icon: Resource;
  public backgroundColor: Resource = Constants.TRANSPARENT_BACKGROUND;
  public enable: boolean = true;
  public action: (event?: ClickEvent) => void = (event?: ClickEvent) => {
  };
  public id: string;
  public isTitleBar: boolean = false;
  public opacity: number = 1;
  public activate: boolean = false;
  public isVisible: boolean = true;
  public popupActivate: boolean = false;

  constructor(id: string, title: ResourceStr, icon: Resource, backgroundColor?: Resource, enable?: boolean,
    action?: (event?: ClickEvent) => void, isTitleBar?: boolean, opacity?: number, activate?: boolean,
    isVisible?: boolean, popupActivate?: boolean) {
    this.id = id;
    this.title = title;
    this.icon = icon;
    this.enable = enable ?? this.enable;
    this.action = action ?? this.action;
    this.backgroundColor = backgroundColor ?? this.backgroundColor;
    this.isTitleBar = isTitleBar ?? this.isTitleBar;
    this.opacity = opacity ?? this.opacity;
    this.activate = activate ?? this.activate;
    this.isVisible = isVisible ?? this.isVisible;
    this.popupActivate = popupActivate ?? this.popupActivate;
  }
}

@Observed

export class ToolbarArray extends Array<ToolbarItem> {
}
