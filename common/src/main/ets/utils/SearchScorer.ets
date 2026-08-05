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

import FileInfo from '../model/FileInfo';
import { PinyinConverter } from './PinyinConverter';
import { HighlightRange, KeywordMatchResult, SearchMatchEngine } from './SearchMatchEngine';

export { HighlightRange };

export interface MatchResult {
  score: number;
  matchedKeywords: string[];
  highlightRanges: HighlightRange[];
}

export interface ScoredFile {
  file: FileInfo;
  matchResult: MatchResult;
}

export class SearchScorer {
  public static readonly SCORE_EXACT_MATCH: number = 100;
  public static readonly SCORE_PREFIX_MATCH: number = 80;
  public static readonly SCORE_CONTAINS_MATCH: number = 50;
  public static readonly SCORE_SUFFIX_MATCH: number = 30;
  public static readonly SCORE_PINYIN_FULL: number = 70;
  public static readonly SCORE_PINYIN_INITIALS: number = 60;
  public static readonly SCORE_PINYIN_CONTAINS: number = 40;
  public static readonly SCORE_PINYIN_INITIALS_CONTAINS: number = 35;

  public static readonly FIELD_WEIGHT_FILE_NAME: number = 100;
  public static readonly FIELD_WEIGHT_FILE_PATH: number = 20;

  public static readonly MIN_SCORE_THRESHOLD: number = 30;

  public static parseKeywords(keyword: string): string[] {
    if (!keyword) {
      return [];
    }

    const trimmed: string = keyword.trim();
    if (!trimmed) {
      return [];
    }

    return trimmed.split(/\s+/).filter((k: string): boolean => k.length > 0);
  }

  public static scoreFile(file: FileInfo, keywords: string[]): MatchResult {
    const fileName: string = PinyinConverter.getFileNameWithoutSuffix(file.fileName || '');
    const filePath: string = file.filePath || '';

    let totalScore: number = 0;
    const matchedKeywords: string[] = [];
    const highlightRanges: HighlightRange[] = [];

    for (const keyword of keywords) {
      const lowerKeyword: string = keyword.toLowerCase();

      // 文件名：统一前缀匹配（字面 / 首字符 / 拼音），并回填精确高亮
      const nameMatch: KeywordMatchResult = SearchMatchEngine.matchText(fileName, lowerKeyword);
      if (nameMatch.matched && nameMatch.score > 0) {
        totalScore += nameMatch.score * SearchScorer.FIELD_WEIGHT_FILE_NAME / 100;
        matchedKeywords.push(keyword);
        for (const range of nameMatch.ranges) {
          SearchScorer.pushHighlightRange(highlightRanges, range);
        }
        continue;
      }

      // 路径仅做字面前缀弱匹配，不高亮文件名
      const pathScore: number = SearchScorer.scorePrefixOnly(filePath, lowerKeyword);
      if (pathScore > 0) {
        totalScore += pathScore * SearchScorer.FIELD_WEIGHT_FILE_PATH / 100;
        matchedKeywords.push(keyword);
      }
    }

    const result: MatchResult = {
      score: totalScore,
      matchedKeywords: matchedKeywords,
      highlightRanges: SearchMatchEngine.mergeRanges(highlightRanges)
    };

    return result;
  }

  /** 仅前缀匹配（精确或 startsWith），不做包含/后缀 */
  public static scorePrefixOnly(fieldValue: string, keyword: string): number {
    if (!fieldValue || !keyword) {
      return 0;
    }
    const lowerField: string = fieldValue.toLowerCase();
    if (lowerField === keyword) {
      return SearchScorer.SCORE_EXACT_MATCH;
    }
    if (lowerField.startsWith(keyword)) {
      return SearchScorer.SCORE_PREFIX_MATCH;
    }
    return 0;
  }

  /** @deprecated 请使用 scorePrefixOnly；保留兼容旧调用，语义已统一为前缀 */
  public static scoreField(fieldValue: string, keyword: string, _isFileName: boolean): number {
    return SearchScorer.scorePrefixOnly(fieldValue, keyword);
  }

  public static addHighlightRanges(text: string, keyword: string, ranges: HighlightRange[]): void {
    const match: KeywordMatchResult = SearchMatchEngine.matchText(text, keyword);
    if (!match.matched) {
      return;
    }
    for (const range of match.ranges) {
      SearchScorer.pushHighlightRange(ranges, range);
    }
  }

  private static pushHighlightRange(ranges: HighlightRange[], range: HighlightRange): void {
    const existingRange: HighlightRange | undefined = ranges.find((r: HighlightRange): boolean =>
      (range.start >= r.start && range.start < r.end) || (range.end > r.start && range.end <= r.end) ||
        (r.start >= range.start && r.end <= range.end)
    );
    if (!existingRange) {
      ranges.push({ start: range.start, end: range.end });
    }
  }

  public static sortResults(files: FileInfo[], keywords: string[], minScore: number): ScoredFile[] {
    const scoredFiles: ScoredFile[] = [];

    for (const file of files) {
      const matchResult: MatchResult = SearchScorer.scoreFile(file, keywords);
      if (matchResult.score >= minScore) {
        const scoredFile: ScoredFile = {
          file: file,
          matchResult: matchResult
        };
        scoredFiles.push(scoredFile);
      }
    }

    scoredFiles.sort((a: ScoredFile, b: ScoredFile): number => {
      if (b.matchResult.score !== a.matchResult.score) {
        return b.matchResult.score - a.matchResult.score;
      }
      return (b.file.updateTime ?? 0) - (a.file.updateTime ?? 0);
    });

    return scoredFiles;
  }

  public static filterAndSort(files: FileInfo[], keyword: string, minScore: number = SearchScorer.MIN_SCORE_THRESHOLD): ScoredFile[] {
    const keywords: string[] = SearchScorer.parseKeywords(keyword);
    if (keywords.length === 0) {
      return [];
    }

    return SearchScorer.sortResults(files, keywords, minScore);
  }
}
