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

export default class LRUCache<K> {
  private cache: Map<K, number> = new Map();
  private capacity: number;

  constructor(capacity: number) {
    this.capacity = capacity;
  }

  put(key: K): K | undefined {
    if (this.cache.has(key)) {
      this.cache.delete(key);
    } else if (this.cache.size >= this.capacity) {
      const firstKey: K | undefined = this.cache.keys().next().value;
      if (firstKey !== undefined) {
        this.cache.delete(firstKey);
        return firstKey;
      }
    }
    this.cache.set(key, Date.now());
    return undefined;
  }

  remove(key: K): void {
    this.cache.delete(key);
  }

  getSize(): number {
    return this.cache.size;
  }
}
