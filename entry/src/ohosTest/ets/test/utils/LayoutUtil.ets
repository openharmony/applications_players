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

/**
 * LayoutUtil - UI Layout Dump Analysis Utility
 * 
 * 用于解析 uitest dumpLayout 输出的 JSON，提取 UI 渲染的媒体文件项及其位置信息。
 * 
 * 关键发现：
 * 1. uitest dumpLayout -p <path> 参数被忽略，始终保存到 /data/local/tmp/layout_<timestamp>.json
 * 2. uitest daemon 作为系统进程运行，可访问 /data/local/tmp
 * 3. 测试应用在沙箱中运行，fs.readTextSync 只能读取沙箱内路径
 * 4. 路径映射差异：
 *    - 应用沙箱逻辑路径: /data/storage/el2/base/haps/phone_test/files
 *    - 物理沙箱路径: /data/app/el2/100/base/com.ohos.players/haps/phone_test/files
 * 
 * 解决方案：shell cp 写入物理沙箱路径，fs.readTextSync 使用逻辑路径读取
 */

import fs from '@ohos.file.fs';
import { HiLog } from '@ohos/common/src/main/ets/utils/HiLog';
import type common from '@ohos.app.ability.common';
import { abilityDelegatorRegistry } from '@kit.TestKit';

type AbilityDelegator = abilityDelegatorRegistry.AbilityDelegator;

const TAG = 'LayoutUtil';

// ============================================
// Interfaces
// ============================================

/**
 * uitest dumpLayout JSON node attributes format
 */
export interface UiTestNodeAttributes {
  accessibilityId: string;
  backgroundColor: string;
  bounds: string;  // "[left,top][right,bottom]"
  checkable: string;
  clickable: string;
  description: string;
  enabled: string;
  focused: string;
  id: string;
  text: string;           // 显示文本
  originalText: string;   // 原始文本（文件名在这里）
  type: string;           // 组件类型
}

/**
 * uitest dumpLayout JSON node structure
 */
export interface UiTestNode {
  attributes: UiTestNodeAttributes;
  children?: UiTestNode[];
}

/**
 * 渲染项信息 - 包含文件名、Y位置和组件类型
 */
export interface RenderOrderItem {
  fileName: string;
  yPosition: number;
  componentType: string;
}

// ============================================
// Main Functions
// ============================================

/**
 * Dump UI Layout and extract media render order
 * 
 * 执行 uitest dumpLayout，将 JSON 复制到沙箱，解析提取媒体项
 * 
 * @param delegator - AbilityDelegator for executing shell commands
 * @param context - Application context for sandbox path
 * @param bundleName - Application bundle name (default: 'com.ohos.players')
 * @param moduleName - Test module name (default: 'phone_test')
 * @returns Promise<RenderOrderItem[]> - Array of extracted media items sorted by Y position
 */
export async function dumpUILayoutForAnalysis(
  delegator: AbilityDelegator,
  context: common.Context,
  bundleName: string = 'com.ohos.players',
  moduleName: string = 'phone_test'
): Promise<RenderOrderItem[]> {
  HiLog.i(TAG, '=== Dumping UI Layout for Analysis ===');
  
  if (!delegator || !context) {
    HiLog.e(TAG, 'Delegator or context is null');
    return [];
  }
  
  try {
    // 应用沙箱逻辑路径（用于 fs.readTextSync）
    const sandboxFilesDir = context.filesDir;
    HiLog.i(TAG, `Sandbox filesDir (logical): ${sandboxFilesDir}`);
    
    // 物理沙箱路径（用于 shell 命令写入）
    // 映射规则: bundleName + moduleName
    const physicalSandboxPath = `/data/app/el2/100/base/${bundleName}/haps/${moduleName}/files`;
    HiLog.i(TAG, `Physical sandbox path: ${physicalSandboxPath}`);
    
    // Step 1: 执行 uitest dumpLayout
    const dumpResult = await delegator.executeShellCommand(
      'uitest dumpLayout',
      15000
    );
    HiLog.i(TAG, `uitest dumpLayout exitCode=${dumpResult.exitCode}, stdResult="${dumpResult.stdResult}"`);
    
    // Step 2: 等待文件写入完成
    await delay(2000);
    
    // Step 3: 解析 uitest 输出路径
    let uitestJsonPath = '';
    if (dumpResult.stdResult && dumpResult.stdResult.includes('DumpLayout saved to:')) {
      const match = dumpResult.stdResult.match(/DumpLayout saved to:(\S+)/);
      if (match && match[1]) {
        uitestJsonPath = match[1].trim();
        HiLog.i(TAG, `uitest JSON path: ${uitestJsonPath}`);
      }
    }
    
    if (!uitestJsonPath || !uitestJsonPath.startsWith('/data/local/tmp/')) {
      HiLog.e(TAG, `Invalid uitest path: ${uitestJsonPath}`);
      return [];
    }
    
    // Step 4: shell cp 写入物理沙箱路径
    const targetFileName = `ui_dump_${Date.now()}.json`;
    const physicalTargetPath = `${physicalSandboxPath}/${targetFileName}`;
    HiLog.i(TAG, `Shell cp: ${uitestJsonPath} -> ${physicalTargetPath}`);
    
    const copyResult = await delegator.executeShellCommand(
      `cp ${uitestJsonPath} ${physicalTargetPath}`,
      10000
    );
    HiLog.i(TAG, `Shell cp exitCode=${copyResult.exitCode}`);
    
    await delay(500);
    
    // Step 5: fs.readTextSync 使用沙箱逻辑路径
    const sandboxTargetPath = `${sandboxFilesDir}/${targetFileName}`;
    HiLog.i(TAG, `Reading from sandbox: ${sandboxTargetPath}`);
    
    try {
      const jsonContent = fs.readTextSync(sandboxTargetPath);
      HiLog.i(TAG, `SUCCESS: read JSON, length=${jsonContent.length}`);
      return parseJsonAndExtractItems(jsonContent);
    } catch (readError) {
      HiLog.e(TAG, `fs.readTextSync failed: ${String(readError)}`);
      
      // 备选：直接使用物理路径读取
      HiLog.i(TAG, `Fallback: try fs.readTextSync from physical path`);
      try {
        const directContent = fs.readTextSync(physicalTargetPath);
        HiLog.i(TAG, `Physical path read SUCCESS, length=${directContent.length}`);
        return parseJsonAndExtractItems(directContent);
      } catch (physicalReadError) {
        HiLog.e(TAG, `Physical path also failed: ${String(physicalReadError)}`);
        return [];
      }
    }
  } catch (e) {
    HiLog.e(TAG, `dumpUILayoutForAnalysis failed: ${String(e)}`);
    return [];
  }
}

/**
 * Parse JSON content and extract media items
 * 
 * @param jsonContent - JSON string from uitest dumpLayout
 * @returns RenderOrderItem[] - Array of extracted media items
 */
export function parseJsonAndExtractItems(jsonContent: string): RenderOrderItem[] {
  try {
    const rootNode: UiTestNode = JSON.parse(jsonContent);
    HiLog.i(TAG, 'Successfully parsed uitest JSON');
    
    // Log root node structure
    HiLog.i(TAG, `Root node type: ${rootNode.attributes?.type || 'undefined'}`);
    HiLog.i(TAG, `Root node has children: ${rootNode.children?.length || 0}`);
    
    const items: RenderOrderItem[] = [];
    extractMediaItemsFromUiTestTree(rootNode, items, 0);
    
    // 按 Y 位置排序（Y 小的在屏幕上方）
    items.sort((a, b) => a.yPosition - b.yPosition);
    
    HiLog.i(TAG, `=== Extracted ${items.length} media items from UI dump ===`);
    for (let i = 0; i < Math.min(items.length, 10); i++) {
      HiLog.i(TAG, `  [${i}] Y=${items[i].yPosition}: "${items[i].fileName}"`);
    }
    
    return items;
  } catch (parseError) {
    HiLog.e(TAG, `JSON parse failed: ${String(parseError)}`);
    return [];
  }
}

// ============================================
// Helper Functions
// ============================================

/**
 * Recursively traverse uitest JSON tree to extract media items
 * 
 * @param node - Current node in the tree
 * @param items - Array to collect extracted items
 * @param depth - Current recursion depth (for debug logging)
 */
export function extractMediaItemsFromUiTestTree(
  node: UiTestNode,
  items: RenderOrderItem[],
  depth: number
): void {
  const indent = '  '.repeat(depth);
  const attrs = node.attributes;
  
  // Log node being processed (limit depth to avoid log spam)
  if (depth < 4) {
    HiLog.i(TAG, `${indent}[depth=${depth}] Processing node type="${attrs?.type || 'undefined'}"`);
  }
  
  // 检查是否是包含文件名的 Text 组件
  // 文件名特征：包含 .mp3, .m4a, .mp4, .webm 扩展名
  // 关键：文件名在 originalText 字段，不是 text 字段
  const text = attrs.originalText || attrs.text || '';
  const isMediaFileName = /\.(mp3|m4a|mp4|webm|aac|flac|ogg|wav|mov|mkv)$/i.test(text);
  
  // Log text content for potential filename nodes
  if (text.length > 0 && depth < 5) {
    HiLog.i(TAG, `${indent}  text="${text.substring(0, 50)}", isMedia=${isMediaFileName}`);
  }
  
  if (isMediaFileName && attrs.bounds) {
    // 解析 bounds 获取 Y 位置
    const yPosition = parseUiTestBoundsY(attrs.bounds);
    
    if (yPosition >= 0) {
      items.push({
        fileName: text,
        yPosition: yPosition,
        componentType: attrs.type || 'Text'
      });
      HiLog.i(TAG, `${indent}*** FOUND MEDIA ITEM: "${text}" at Y=${yPosition} ***`);
    }
  }
  
  // 递归处理子节点
  if (node.children && node.children.length > 0) {
    if (depth < 3) {
      HiLog.i(TAG, `${indent}  Processing ${node.children.length} children...`);
    }
    for (const child of node.children) {
      extractMediaItemsFromUiTestTree(child, items, depth + 1);
    }
  }
}

/**
 * Parse uitest bounds string to get Y position (top value)
 * 
 * @param boundsStr - Bounds string in format "[left,top][right,bottom]"
 * @returns Y position (top value), or -1 if parsing fails
 */
export function parseUiTestBoundsY(boundsStr: string): number {
  try {
    // 格式: "[18,380][376,468]"
    // 提取 top 值（第一个方括号里的第二个数字）
    const match = boundsStr.match(/\[(\d+),(\d+)\]\[(\d+),(\d+)\]/);
    if (match) {
      return parseInt(match[2]);  // top 是第一个方括号里的第二个数字
    }
    return -1;
  } catch (e) {
    HiLog.e(TAG, `parseUiTestBoundsY failed for: ${boundsStr}`);
    return -1;
  }
}

/**
 * Simple delay utility
 * 
 * @param ms - Milliseconds to wait
 */
export function delay(ms: number): Promise<void> {
  return new Promise<void>(resolve => setTimeout(resolve, ms));
}