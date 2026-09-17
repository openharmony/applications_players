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

/**
 * 「前缀匹配 + 首字符对应中英文字符 + 高亮随输入伸缩」新加的核心实现
 * 原文中的高亮区间 [start, end)
 */
export interface HighlightRange {
  start: number;
  end: number;
}

/**
 * 可匹配的字符单元：中文对应拼音/首字母，英文/数字对应自身
 */
interface CharUnit {
  index: number;
  exact: string;
  initial: string;
  pinyin: string;
}

/**
 * 单次匹配结果：得分 + 原文高亮区间
 */
export interface KeywordMatchResult {
  matched: boolean;
  /** 相对得分 0~100，未匹配为 0 */
  score: number;
  ranges: HighlightRange[];
}

/**
 * 即时搜索匹配引擎（包含匹配）：
 * - 字面：文件名等于 / 开头 / 任意位置包含关键词
 * - 字符单元：从任意字符起，用首字母/全拼前缀/英文字母递进消耗查询
 * 高亮区间锁定命中的原文位置，随输入增减精确伸缩。
 */
export class SearchMatchEngine {
  public static readonly SCORE_EXACT: number = 100;
  public static readonly SCORE_LITERAL_PREFIX: number = 80;
  public static readonly SCORE_UNIT_PREFIX: number = 72;
  public static readonly SCORE_LITERAL_CONTAINS: number = 50;
  public static readonly SCORE_UNIT_CONTAINS: number = 45;

  /**
   * 对文件名（可含后缀）做包含匹配，返回得分与高亮区间。
   */
  public static matchFileName(fileName: string, keyword: string): KeywordMatchResult {
    if (!fileName || !keyword) {
      return SearchMatchEngine.emptyResult();
    }
    const name: string = PinyinConverter.getFileNameWithoutSuffix(fileName);
    return SearchMatchEngine.matchText(name, keyword);
  }

  /**
   * 对任意文本做包含匹配（开头优先，其次任意位置）
   */
  public static matchText(text: string, keyword: string): KeywordMatchResult {
    if (!text || !keyword) {
      return SearchMatchEngine.emptyResult();
    }

    const lowerKeyword: string = keyword.toLowerCase();
    const lowerText: string = text.toLowerCase();

    // 1) 字面：精确 / 前缀 / 包含
    const literal: KeywordMatchResult | null =
      SearchMatchEngine.matchLiteral(text, lowerText, lowerKeyword);
    if (literal !== null && literal.score >= SearchMatchEngine.SCORE_LITERAL_PREFIX) {
      return literal;
    }

    // 2) 字符单元：优先从开头匹配（拼音/首字母），再扫中间
    const unitMatch: KeywordMatchResult | null =
      SearchMatchEngine.matchUnit(text, lowerKeyword);
    if (unitMatch !== null) {
      return unitMatch;
    }

    if (literal !== null) {
      return literal;
    }

    return SearchMatchEngine.emptyResult();
  }

  /**
   * 收集多个关键词在文本上的合并高亮区间（各自均为包含匹配）
   */
  public static collectHighlightRanges(text: string, keywords: string[]): HighlightRange[] {
    if (!text || keywords.length === 0) {
      return [];
    }
    const name: string = PinyinConverter.getFileNameWithoutSuffix(text);
    const ranges: HighlightRange[] = [];
    for (const keyword of keywords) {
      const result: KeywordMatchResult = SearchMatchEngine.matchText(name, keyword);
      if (result.matched) {
        for (const range of result.ranges) {
          SearchMatchEngine.pushRangeUnique(ranges, range);
        }
      }
    }
    return SearchMatchEngine.mergeRanges(ranges);
  }

  private static emptyResult(): KeywordMatchResult {
    return {
      matched: false,
      score: 0,
      ranges: []
    };
  }

  /** 字面：精确 > 前缀 > 任意位置包含 */
  private static matchLiteral(text: string, lowerText: string, lowerKeyword: string): KeywordMatchResult | null {
    if (lowerText === lowerKeyword) {
      return {
        matched: true,
        score: SearchMatchEngine.SCORE_EXACT,
        ranges: [{ start: 0, end: text.length }]
      };
    }
    if (lowerText.startsWith(lowerKeyword)) {
      return {
        matched: true,
        score: SearchMatchEngine.SCORE_LITERAL_PREFIX,
        ranges: [{ start: 0, end: lowerKeyword.length }]
      };
    }
    const containIndex: number = lowerText.indexOf(lowerKeyword);
    if (containIndex >= 0) {
      return {
        matched: true,
        score: SearchMatchEngine.SCORE_LITERAL_CONTAINS,
        ranges: [{ start: containIndex, end: containIndex + lowerKeyword.length }]
      };
    }
    return null;
  }

  /**
   * 字符单元匹配：先从第 0 个单元（文件名前缀），再从后续任意单元。
   * 单字符规则：全拼完整 > 全拼前缀（查询耗尽）> 首字母 > 精确字符
   */
  private static matchUnit(text: string, lowerKeyword: string): KeywordMatchResult | null {
    const units: CharUnit[] = SearchMatchEngine.buildCharUnits(text);
    if (units.length === 0) {
      return null;
    }

    const prefixRange: HighlightRange | null =
      SearchMatchEngine.tryMatchFrom(units, 0, lowerKeyword);
    if (prefixRange !== null) {
      const leading: string = text.substring(0, units[0].index);
      const isPrefix: boolean = units[0].index === 0 || leading.trim().length === 0;
      return {
        matched: true,
        score: isPrefix ? SearchMatchEngine.SCORE_UNIT_PREFIX : SearchMatchEngine.SCORE_UNIT_CONTAINS,
        ranges: [prefixRange]
      };
    }

    for (let i = 1; i < units.length; i++) {
      const containRange: HighlightRange | null =
        SearchMatchEngine.tryMatchFrom(units, i, lowerKeyword);
      if (containRange !== null) {
        return {
          matched: true,
          score: SearchMatchEngine.SCORE_UNIT_CONTAINS,
          ranges: [containRange]
        };
      }
    }
    return null;
  }

  private static tryMatchFrom(units: CharUnit[], start: number, query: string): HighlightRange | null {
    let qi: number = 0;
    let ui: number = start;
    let endExclusive: number = units[start].index;

    while (qi < query.length && ui < units.length) {
      const unit: CharUnit = units[ui];
      const remaining: string = query.substring(qi);
      const consumed: number = SearchMatchEngine.consumeUnit(unit, remaining);
      if (consumed <= 0) {
        return null;
      }
      qi += consumed;
      endExclusive = unit.index + 1;
      ui++;
    }

    if (qi !== query.length) {
      return null;
    }
    return { start: units[start].index, end: endExclusive };
  }

  /**
   * 尝试用当前字符单元消耗查询前缀，返回消耗的查询字符数；无法匹配返回 0。
   */
  private static consumeUnit(unit: CharUnit, remaining: string): number {
    if (!remaining) {
      return 0;
    }
    if (unit.pinyin.length > 0 && remaining.startsWith(unit.pinyin)) {
      return unit.pinyin.length;
    }
    if (unit.pinyin.length > 1 &&
      remaining.length < unit.pinyin.length &&
      unit.pinyin.startsWith(remaining)) {
      return remaining.length;
    }
    if (unit.initial.length > 0 && remaining.startsWith(unit.initial)) {
      return unit.initial.length;
    }
    if (unit.exact.length > 0 && remaining.startsWith(unit.exact)) {
      return unit.exact.length;
    }
    return 0;
  }

  private static buildCharUnits(text: string): CharUnit[] {
    const units: CharUnit[] = [];
    for (let i = 0; i < text.length; i++) {
      const char: string = text.charAt(i);
      const arr: string[] = PinyinConverter.toPinyinArray(char);
      if (arr.length === 1 && PinyinConverter.containsChinese(char)) {
        const py: string = arr[0];
        units.push({
          index: i,
          exact: char,
          initial: py.length > 0 ? py.charAt(0) : '',
          pinyin: py
        });
        continue;
      }
      if (PinyinConverter.isEnglishLetter(char)) {
        const lower: string = char.toLowerCase();
        units.push({
          index: i,
          exact: lower,
          initial: lower,
          pinyin: lower
        });
        continue;
      }
      if (PinyinConverter.isDigit(char)) {
        units.push({
          index: i,
          exact: char,
          initial: char,
          pinyin: char
        });
        continue;
      }
      if (char.trim().length > 0) {
        units.push({
          index: i,
          exact: char.toLowerCase(),
          initial: '',
          pinyin: ''
        });
      }
    }
    return units;
  }

  private static pushRangeUnique(ranges: HighlightRange[], range: HighlightRange): void {
    const exists: boolean = ranges.some((r: HighlightRange): boolean =>
      r.start === range.start && r.end === range.end
    );
    if (!exists) {
      ranges.push(range);
    }
  }

  public static mergeRanges(ranges: HighlightRange[]): HighlightRange[] {
    if (ranges.length === 0) {
      return [];
    }
    const sorted: HighlightRange[] = ranges.slice().sort(
      (a: HighlightRange, b: HighlightRange): number => a.start - b.start
    );
    const merged: HighlightRange[] = [];
    for (const range of sorted) {
      if (merged.length === 0) {
        merged.push({ start: range.start, end: range.end });
        continue;
      }
      const last: HighlightRange = merged[merged.length - 1];
      if (range.start <= last.end) {
        last.end = Math.max(last.end, range.end);
      } else {
        merged.push({ start: range.start, end: range.end });
      }
    }
    return merged;
  }
}
