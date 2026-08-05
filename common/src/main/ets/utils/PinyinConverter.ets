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

import { PINYIN_DICT } from './PinyinDict';

export class PinyinConverter {
  static toPinyin(text: string): string {
    if (!text) {
      return '';
    }
    
    let result: string = '';
    for (let i = 0; i < text.length; i++) {
      const char: string = text.charAt(i);
      const pinyin: string | undefined = PINYIN_DICT[char];
      if (pinyin) {
        result += pinyin;
      } else if (PinyinConverter.isEnglishLetter(char)) {
        result += char.toLowerCase();
      } else if (PinyinConverter.isDigit(char)) {
        result += char;
      }
    }
    return result;
  }

  static toPinyinInitials(text: string): string {
    if (!text) {
      return '';
    }
    
    let result: string = '';
    for (let i = 0; i < text.length; i++) {
      const char: string = text.charAt(i);
      const pinyin: string | undefined = PINYIN_DICT[char];
      if (pinyin && pinyin.length > 0) {
        result += pinyin.charAt(0);
      } else if (PinyinConverter.isEnglishLetter(char)) {
        result += char.toLowerCase();
      }
    }
    return result;
  }

  static toPinyinArray(text: string): string[] {
    if (!text) {
      return [];
    }
    
    const result: string[] = [];
    for (let i = 0; i < text.length; i++) {
      const char: string = text.charAt(i);
      const pinyin: string | undefined = PINYIN_DICT[char];
      if (pinyin) {
        result.push(pinyin);
      } else if (PinyinConverter.isEnglishLetter(char)) {
        result.push(char.toLowerCase());
      } else if (PinyinConverter.isDigit(char)) {
        result.push(char);
      }
    }
    return result;
  }

  static matchPinyin(text: string, query: string): boolean {
    if (!text || !query) {
      return false;
    }
    
    const lowerQuery: string = query.toLowerCase();
    
    const fullPinyin: string = PinyinConverter.toPinyin(text);
    if (fullPinyin.includes(lowerQuery)) {
      return true;
    }
    
    const initials: string = PinyinConverter.toPinyinInitials(text);
    if (initials.includes(lowerQuery)) {
      return true;
    }
    
    return false;
  }

  static isEnglishLetter(char: string): boolean {
    const code: number = char.charCodeAt(0);
    return (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
  }

  static isDigit(char: string): boolean {
    const code: number = char.charCodeAt(0);
    return code >= 48 && code <= 57;
  }

  static containsChinese(text: string): boolean {
    if (!text) {
      return false;
    }
    
    for (let i = 0; i < text.length; i++) {
      const char: string = text.charAt(i);
      const code: number = char.charCodeAt(0);
      if (code >= 0x4E00 && code <= 0x9FFF) {
        return true;
      }
    }
    return false;
  }

  static getFileNameWithoutSuffix(fileName: string): string {
    if (!fileName) {
      return '';
    }
    const lastDotIndex: number = fileName.lastIndexOf('.');
    if (lastDotIndex > 0) {
      return fileName.substring(0, lastDotIndex);
    }
    return fileName;
  }
}
