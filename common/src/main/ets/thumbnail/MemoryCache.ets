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


import image from '@ohos.multimedia.image';
import { HiLog } from '../utils/HiLog';

const TAG = 'MemoryCache';
const LARGE_IMAGE_THRESHOLD = 500 * 1024; // 500KB threshold for WeakRef storage
const MAX_CACHE_SIZE = 150 * 1024 * 1024; // 150MB maximum cache size

/**
 * Doubly linked list node for O(1) LRU cache operations
 */
class LRUNode {
  public key: string;
  public value: image.PixelMap | WeakRef<image.PixelMap>;
  public prev: LRUNode | null = null;
  public next: LRUNode | null = null;
  public isWeakRef: boolean = false;
  public size: number = 0; // Size in bytes

  constructor(key: string, value: image.PixelMap | WeakRef<image.PixelMap>, isWeakRef: boolean = false, size: number = 0) {
    this.key = key;
    this.value = value;
    this.isWeakRef = isWeakRef;
    this.size = size;
  }
}

/**
 * Memory cache with O(1) LRU eviction using doubly linked list
 * 
 * Performance:
 * - get(): O(1) - Map lookup + move to head
 * - set(): O(1) - Map insert + add to head + evict from tail if needed
 * - remove(): O(1) - Map delete + unlink node
 * - has(): O(1) - Map lookup
 */
export class MemoryCache {
  private cache: Map<string, LRUNode> = new Map();
  private maxSize: number;
  private currentSize: number = 0; // Current total cache size in bytes
  
  // Doubly linked list: head (most recently used) <-> tail (least recently used)
  private head: LRUNode | null = null;
  private tail: LRUNode | null = null;

  constructor(maxSize: number = 50) {
    this.maxSize = maxSize;
  }

  /**
   * Get cached value and move to head (most recently used)
   * O(1) operation
   */
  public get(key: string): image.PixelMap | undefined {
    const node = this.cache.get(key);
    if (!node) {
      return undefined;
    }
    
    // Handle WeakRef deref
    let pixelMap: image.PixelMap | undefined;
    if (node.isWeakRef && node.value instanceof WeakRef) {
      pixelMap = node.value.deref();
      if (!pixelMap) {
        // WeakRef target has been reclaimed, remove from cache
        HiLog.i(TAG, `WeakRef target reclaimed: ${key}`);
        this.remove(key);
        return undefined;
      }
    } else {
      pixelMap = node.value as image.PixelMap;
    }
    
    // Move to head (most recently used)
    this.moveToHead(node);
    return pixelMap;
  }

  /**
   * Set cached value and add to head (async version)
   * Size tracking with 150MB limit
   */
  public async set(key: string, value: image.PixelMap): Promise<void> {
    const existingNode = this.cache.get(key);
    
    if (existingNode) {
      // Update existing node and move to head
      // Subtract old size and add new size
      this.currentSize -= existingNode.size;
      const newEstimatedSize = await this.estimatePixelMapSize(value);
      existingNode.value = value;
      existingNode.isWeakRef = false;
      existingNode.size = newEstimatedSize;
      this.currentSize += newEstimatedSize;
      this.moveToHead(existingNode);
      
      // Check if size exceeds limit after update
      this.evictIfOverSize();
      return;
    }
    
    // Check if image is large (> 500KB)
    const estimatedSize = await this.estimatePixelMapSize(value);
    const useWeakRef = estimatedSize > LARGE_IMAGE_THRESHOLD;
    
    if (useWeakRef) {
      HiLog.i(TAG, `Large image detected (${estimatedSize} bytes), using WeakRef: ${key}`);
    }
    
    // Create new node with WeakRef if large
    const nodeValue = useWeakRef ? new WeakRef(value) : value;
    const newNode = new LRUNode(key, nodeValue, useWeakRef, estimatedSize);
    
    // Add to cache
    this.cache.set(key, newNode);
    
    // Add to head of linked list
    this.addToHead(newNode);
    
    // Track size
    this.currentSize += estimatedSize;
    
    // Evict if over capacity (count-based)
    if (this.cache.size > this.maxSize) {
      this.evictLRU();
    }
    
    // Evict if over size limit (size-based)
    this.evictIfOverSize();
  }

  /**
   * Set cached value (sync version for testing/non-critical paths)
   * Uses default size estimate (200KB)
   */
  public setSync(key: string, value: image.PixelMap): void {
    const estimatedSize = this.estimatePixelMapSizeDefault(value);
    const useWeakRef = estimatedSize > LARGE_IMAGE_THRESHOLD;
    
    const existingNode = this.cache.get(key);
    if (existingNode) {
      this.currentSize -= existingNode.size;
      existingNode.value = value;
      existingNode.isWeakRef = false;
      existingNode.size = estimatedSize;
      this.currentSize += estimatedSize;
      this.moveToHead(existingNode);
      this.evictIfOverSize();
      return;
    }
    
    const nodeValue = useWeakRef ? new WeakRef(value) : value;
    const newNode = new LRUNode(key, nodeValue, useWeakRef, estimatedSize);
    this.cache.set(key, newNode);
    this.addToHead(newNode);
    this.currentSize += estimatedSize;
    
    if (this.cache.size > this.maxSize) {
      this.evictLRU();
    }
    this.evictIfOverSize();
  }

  /**
   * Check if key exists
   * O(1) operation
   */
  public has(key: string): boolean {
    return this.cache.has(key);
  }

  /**
   * Clear all cached items
   */
  public clear(): void {
    this.releaseAll();
    this.cache.clear();
    this.head = null;
    this.tail = null;
    this.currentSize = 0;
  }

  /**
   * Remove specific key
   * O(1) operation
   */
  public remove(key: string): void {
    const node = this.cache.get(key);
    if (!node) {
      return;
    }
    
    // Subtract size from currentSize
    this.currentSize -= node.size;
    
    // Release PixelMap (only if not WeakRef or still alive)
    if (!node.isWeakRef) {
      try {
        (node.value as image.PixelMap).release();
      } catch (error) {
        HiLog.e(TAG, `PixelMap release failed: ${key}, error: ${error}`);
      }
    } else if (node.value instanceof WeakRef) {
      const pixelMap = node.value.deref();
      if (pixelMap) {
        try {
          pixelMap.release();
        } catch (error) {
          HiLog.e(TAG, `WeakRef PixelMap release failed: ${key}, error: ${error}`);
        }
      }
    }
    
    // Remove from cache
    this.cache.delete(key);
    
    // Remove from linked list
    this.unlinkNode(node);
  }

  /**
   * Get cache size
   */
  public size(): number {
    return this.cache.size;
  }

  /**
   * Get current cache size in bytes
   */
  public getCurrentSize(): number {
    return this.currentSize;
  }

  /**
   * Get maximum cache size in bytes
   */
  public getMaxCacheSize(): number {
    return MAX_CACHE_SIZE;
  }

  /**
   * Evict items if cache size exceeds limit
   * Large files are evicted first to keep more small images
   */
  private evictIfOverSize(): void {
    if (this.currentSize <= MAX_CACHE_SIZE) {
      return;
    }

    HiLog.i(TAG, `Cache size exceeded limit: ${this.currentSize} > ${MAX_CACHE_SIZE}, evicting large files`);

    // Sort nodes by size (descending) to evict largest first
    const nodes: LRUNode[] = [];
    this.cache.forEach((node) => {
      nodes.push(node);
    });

    // Sort by size descending (largest first)
    nodes.sort((a, b) => b.size - a.size);

    // Evict largest files until under limit
    for (const node of nodes) {
      if (this.currentSize <= MAX_CACHE_SIZE) {
        break;
      }

      HiLog.i(TAG, `Evicting large file: ${node.key}, size: ${node.size} bytes`);
      this.remove(node.key);
    }

    HiLog.i(TAG, `Cache size after eviction: ${this.currentSize} bytes`);
  }

  /**
   * Move node to head (most recently used position)
   * O(1) operation
   */
  private moveToHead(node: LRUNode): void {
    if (node === this.head) {
      // Already at head, no need to move
      return;
    }
    
    // Unlink from current position
    this.unlinkNode(node);
    
    // Add to head
    this.addToHead(node);
  }

  /**
   * Add node to head of linked list
   * O(1) operation
   */
  private addToHead(node: LRUNode): void {
    node.prev = null;
    node.next = this.head;
    
    if (this.head) {
      this.head.prev = node;
    }
    
    this.head = node;
    
    // If list was empty, this is also the tail
    if (!this.tail) {
      this.tail = node;
    }
  }

  /**
   * Unlink node from linked list
   * O(1) operation
   */
  private unlinkNode(node: LRUNode): void {
    // Update prev node's next pointer
    if (node.prev) {
      node.prev.next = node.next;
    } else {
      // Node was head, update head
      this.head = node.next;
    }
    
    // Update next node's prev pointer
    if (node.next) {
      node.next.prev = node.prev;
    } else {
      // Node was tail, update tail
      this.tail = node.prev;
    }
    
    // Clear node's pointers
    node.prev = null;
    node.next = null;
  }

  /**
   * Evict least recently used item (tail)
   * O(1) operation
   */
  private evictLRU(): void {
    if (!this.tail) {
      return;
    }
    
    const lruNode = this.tail;
    
    // Subtract size from currentSize
    this.currentSize -= lruNode.size;
    
    // Remove from cache
    this.cache.delete(lruNode.key);
    
    // Remove from linked list
    this.unlinkNode(lruNode);
    
    // Release PixelMap (only if not WeakRef or still alive)
    if (!lruNode.isWeakRef) {
      try {
        (lruNode.value as image.PixelMap).release();
      } catch (error) {
        HiLog.e(TAG, `PixelMap release failed: ${lruNode.key}, error: ${error}`);
      }
    } else if (lruNode.value instanceof WeakRef) {
      const pixelMap = lruNode.value.deref();
      if (pixelMap) {
        try {
          pixelMap.release();
        } catch (error) {
          HiLog.e(TAG, `WeakRef PixelMap release failed: ${lruNode.key}, error: ${error}`);
        }
      }
    }
  }

  /**
   * Release all PixelMaps
   */
  private releaseAll(): void {
    this.cache.forEach((node, key) => {
      // Release PixelMap (only if not WeakRef or still alive)
      if (!node.isWeakRef) {
        try {
          (node.value as image.PixelMap).release();
        } catch (error) {
          HiLog.e(TAG, `PixelMap release failed: ${key}, error: ${error}`);
        }
      } else if (node.value instanceof WeakRef) {
        const pixelMap = node.value.deref();
        if (pixelMap) {
          try {
            pixelMap.release();
          } catch (error) {
            HiLog.e(TAG, `WeakRef PixelMap release failed: ${key}, error: ${error}`);
          }
        }
      }
    });
  }
  
  /**
   * Estimate PixelMap size in bytes (async version)
   * Assumes RGBA format (4 bytes per pixel)
   */
  private async estimatePixelMapSize(pixelMap: image.PixelMap): Promise<number> {
    try {
      const imageInfo = await pixelMap.getImageInfo();
      const bytesPerPixel = 4; // RGBA format
      return imageInfo.size.width * imageInfo.size.height * bytesPerPixel;
    } catch (error) {
      HiLog.e(TAG, `Failed to get PixelMap info: ${error}`);
      return 0;
    }
  }

  /**
   * Estimate PixelMap size in bytes (fallback - uses default estimate)
   * For cases where async is not feasible
   */
  private estimatePixelMapSizeDefault(pixelMap: image.PixelMap): number {
    // Default estimate: assume 200KB for thumbnails
    return 200 * 1024;
  }
}
