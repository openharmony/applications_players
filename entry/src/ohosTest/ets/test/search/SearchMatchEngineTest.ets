/*
 * Copyright (c) 2025. All rights reserved.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/** 测试文件
 * 完整覆盖了搜索匹配和高亮的核心行为，包括英文前缀匹配、中文拼音（全拼和首字母）匹配、中英文混合匹配、高亮范围动态同步以及前缀匹配拒绝中间匹配等关键场景
 * 是确保搜索功能准确性和状态同步的质量保障
 */

import { describe, it, expect } from '@ohos/hypium';
import {
  SearchMatchEngine,
  KeywordMatchResult,
  HighlightRange,
  SearchHighlighter,
  HighlightSegment
} from '@ohos/search';

export default function SearchMatchEngineTest() {
  describe('SearchMatchEngineTestSuite', () => {
    it('MATCH_01_english_prefix_highlight_shrinks_with_input', 0, () => {
      const name: string = 'lletter_video';

      const one: KeywordMatchResult = SearchMatchEngine.matchText(name, 'l');
      expect(one.matched).assertTrue();
      expect(one.ranges[0].start).assertEqual(0);
      expect(one.ranges[0].end).assertEqual(1);

      const two: KeywordMatchResult = SearchMatchEngine.matchText(name, 'll');
      expect(two.matched).assertTrue();
      expect(two.ranges[0].end).assertEqual(2);

      const three: KeywordMatchResult = SearchMatchEngine.matchText(name, 'lle');
      expect(three.matched).assertTrue();
      expect(three.ranges[0].end).assertEqual(3);

      // 删除回退：高亮随之缩减
      const back: KeywordMatchResult = SearchMatchEngine.matchText(name, 'll');
      expect(back.ranges[0].end).assertEqual(2);
    });

    it('MATCH_02_chinese_initial_matches_char_and_highlights_exact_char', 0, () => {
      const name: string = '刘德华';

      const one: KeywordMatchResult = SearchMatchEngine.matchText(name, 'l');
      expect(one.matched).assertTrue();
      expect(one.ranges[0].start).assertEqual(0);
      expect(one.ranges[0].end).assertEqual(1);

      const two: KeywordMatchResult = SearchMatchEngine.matchText(name, 'ld');
      expect(two.matched).assertTrue();
      expect(two.ranges[0].start).assertEqual(0);
      expect(two.ranges[0].end).assertEqual(2);

      const three: KeywordMatchResult = SearchMatchEngine.matchText(name, 'ldh');
      expect(three.matched).assertTrue();
      expect(three.ranges[0].end).assertEqual(3);
    });

    it('MATCH_03_chinese_full_pinyin_prefix_highlights_single_char', 0, () => {
      const name: string = '刘德华';

      const partial: KeywordMatchResult = SearchMatchEngine.matchText(name, 'li');
      expect(partial.matched).assertTrue();
      expect(partial.ranges[0].start).assertEqual(0);
      expect(partial.ranges[0].end).assertEqual(1);

      const full: KeywordMatchResult = SearchMatchEngine.matchText(name, 'liu');
      expect(full.matched).assertTrue();
      expect(full.ranges[0].end).assertEqual(1);

      const longer: KeywordMatchResult = SearchMatchEngine.matchText(name, 'liud');
      expect(longer.matched).assertTrue();
      expect(longer.ranges[0].end).assertEqual(2);
    });

    it('MATCH_04_mixed_chinese_english_first_char', 0, () => {
      const name: string = '鱼yousa';

      const y: KeywordMatchResult = SearchMatchEngine.matchText(name, 'y');
      expect(y.matched).assertTrue();
      // 优先匹配开头中文「鱼」
      expect(y.ranges[0].start).assertEqual(0);
      expect(y.ranges[0].end).assertEqual(1);

      const yu: KeywordMatchResult = SearchMatchEngine.matchText(name, 'yu');
      expect(yu.matched).assertTrue();
      expect(yu.ranges[0].start).assertEqual(0);
      expect(yu.ranges[0].end).assertEqual(1);
    });

    it('MATCH_05_highlighter_segments_sync_with_keywords', 0, () => {
      const fileName: string = '刘德华.mp3';
      const segments1: HighlightSegment[] = SearchHighlighter.highlight(fileName, ['l']);
      const highlight1: string = segments1.filter((s: HighlightSegment) => s.isHighlight)
        .map((s: HighlightSegment) => s.text).join('');
      expect(highlight1).assertEqual('刘');

      const segments2: HighlightSegment[] = SearchHighlighter.highlight(fileName, ['ld']);
      const highlight2: string = segments2.filter((s: HighlightSegment) => s.isHighlight)
        .map((s: HighlightSegment) => s.text).join('');
      expect(highlight2).assertEqual('刘德');

      const segments3: HighlightSegment[] = SearchHighlighter.highlight(fileName, ['l']);
      const highlight3: string = segments3.filter((s: HighlightSegment) => s.isHighlight)
        .map((s: HighlightSegment) => s.text).join('');
      expect(highlight3).assertEqual('刘');
    });

    it('MATCH_06_prefix_only_rejects_middle_match', 0, () => {
      // 「德」在中间：单独输入 d 不应命中（非前缀）
      const mid: KeywordMatchResult = SearchMatchEngine.matchText('刘德华', 'd');
      expect(mid.matched).assertFalse();

      // 英文中间片段也不应命中
      const engMid: KeywordMatchResult = SearchMatchEngine.matchText('lletter_video', 'video');
      expect(engMid.matched).assertFalse();

      const ranges: HighlightRange[] = SearchMatchEngine.collectHighlightRanges('刘德华', ['ld']);
      expect(ranges.length).assertEqual(1);
      expect(ranges[0].start).assertEqual(0);
      expect(ranges[0].end).assertEqual(2);
    });
  });
}
