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

import { PinyinConverter } from './PinyinConverter';
import { HighlightRange, SearchMatchEngine } from './SearchMatchEngine';

export { HighlightRange };

export interface HighlightSegment {
  text: string;
  isHighlight: boolean;
}

/**
 * 搜索结果高亮：与 SearchMatchEngine 统一使用前缀匹配，
 * 保证「首字符/拼音前缀」时高亮从文件名开头锁定对应中英文字符，并随输入实时伸缩。
 */
export class SearchHighlighter {
  public static highlight(text: string, keywords: string[]): HighlightSegment[] {
    if (!text || keywords.length === 0) {
      const defaultSegment: HighlightSegment = { text: text, isHighlight: false };
      return [defaultSegment];
    }

    const fileName: string = PinyinConverter.getFileNameWithoutSuffix(text);
    const suffix: string = text.length > fileName.length ? text.substring(fileName.length) : '';
    const mergedMatches: HighlightRange[] = SearchMatchEngine.collectHighlightRanges(text, keywords);

    if (mergedMatches.length === 0) {
      const defaultSegment: HighlightSegment = { text: text, isHighlight: false };
      return [defaultSegment];
    }

    const segments: HighlightSegment[] = [];
    let currentPos: number = 0;

    for (const match of mergedMatches) {
      if (match.start > currentPos) {
        const segment: HighlightSegment = {
          text: fileName.substring(currentPos, match.start),
          isHighlight: false
        };
        segments.push(segment);
      }

      const highlightSegment: HighlightSegment = {
        text: fileName.substring(match.start, match.end),
        isHighlight: true
      };
      segments.push(highlightSegment);
      currentPos = match.end;
    }

    if (currentPos < fileName.length) {
      const segment: HighlightSegment = {
        text: fileName.substring(currentPos),
        isHighlight: false
      };
      segments.push(segment);
    }

    if (suffix) {
      const segment: HighlightSegment = {
        text: suffix,
        isHighlight: false
      };
      segments.push(segment);
    }

    return segments;
  }

  public static getHighlightRanges(text: string, keywords: string[]): HighlightRange[] {
    return SearchMatchEngine.collectHighlightRanges(text, keywords);
  }
}
