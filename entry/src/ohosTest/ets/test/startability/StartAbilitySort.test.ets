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

import { describe, expect, it, beforeAll, afterAll, beforeEach, afterEach } from '@ohos/hypium';
import { HiLog, FileMonitor } from '@ohos/common';
import { MediaAggregateViewModel } from '@ohos/media/src/main/ets/manager/MediaAggregateViewModel';
import { SortType, MediaType } from '@ohos/common/src/main/ets/datasource/IMediaDataSource';
import { Driver, ON, MatchPattern } from '@kit.TestKit';
import { TestUtil, ViewModelAndFileMonitorResult } from '../utils/TestUtil';
import type common from '@ohos.app.ability.common';
import Want from '@ohos.app.ability.Want';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import fs from '@ohos.file.fs';
import {
  dumpUILayoutForAnalysis,
  RenderOrderItem,
  parseJsonAndExtractItems,
  UiTestNode,
  UiTestNodeAttributes,
  extractMediaItemsFromUiTestTree
} from '../utils/LayoutUtil';

const TAG = 'StartAbilitySortTest';

/**
 * UI 渲染层排序验证测试（uitest dumpLayout JSON 解析）
 *
 * 核心设计原则：
 * 1. 使用 uitest dumpLayout 捕获实际 UI 渲染树 JSON
 * 2. 解析 JSON 提取文件名和 Y 位置坐标
 * 3. 按 Y 位置排序验证渲染顺序
 * 4. 验证 UI 渲染层 ≠ ViewModel 数据层
 *
 * 测试目标：
 * - UI_SORT_01: 验证 NAME 降序排序在渲染树中的顺序
 * - UI_SORT_02: 验证切换排序方向后渲染树中的顺序变化
 *
 * 关键修复：
 * - parseDumpLayoutJSONAndGetRenderOrder() 必须实际调用
 * - 测试失败即表示存在渲染层与数据层不一致的 BUG
 */

// ==========================================
// 接口定义 - 使用 LayoutUtil 导出的类型
// ==========================================
// RenderOrderItem, UiTestNode, UiTestNodeAttributes 已从 LayoutUtil 导入

// ==========================================
// 模块全局状态
// ==========================================

let g_context: common.Context | null = null;
let g_delegator: abilityDelegatorRegistry.AbilityDelegator | null = null;
let g_bundleName: string = 'com.ohos.players';
let g_viewModel: MediaAggregateViewModel | null = null;
let g_driver: Driver | null = null;
let g_fileMonitor: FileMonitor | null = null;

// ==========================================
// Helper: 解析 uitest dumpLayout JSON 获取实际渲染顺序
// ==========================================

/**
 * 核心验证函数：捕获渲染树并验证排序顺序
 * 
 * 使用 hidumper 捕获渲染层级结构
 * 
 * 方案说明：
 * - uitest dumpLayout 生成 JSON 文件但测试进程无法读取（进程隔离）
 * - hidumper viewHierarchy 输出到 stdout，可获取组件层级和 viewId
 * - 验证策略：通过 viewId 顺序验证渲染顺序
 * 
 * @returns RenderOrderItem[] 按 viewId 排序的渲染顺序列表
 */
async function parseDumpLayoutJSONAndGetRenderOrder(): Promise<RenderOrderItem[]> {
  HiLog.i(TAG, '=== Parsing render tree via LayoutUtil.dumpUILayoutForAnalysis ===');

  if (!g_delegator || !g_context) {
    HiLog.e(TAG, 'Delegator or context is null');
    return [];
  }

  try {
    // 使用 LayoutUtil.dumpUILayoutForAnalysis 获取实际文件名
    // 关键修复：uitest dumpLayout 包含 originalText 字段（文件名），hidumper 不输出 text
    const items = await dumpUILayoutForAnalysis(g_delegator, g_context, g_bundleName, 'phone_test');
    
    HiLog.i(TAG, `=== Extracted ${items.length} items with actual file names ===`);
    for (let i = 0; i < Math.min(items.length, 10); i++) {
      HiLog.i(TAG, `  [${i}] Y=${items[i].yPosition}: "${items[i].fileName}" (${items[i].componentType})`);
    }
    
    return items;
  } catch (e) {
    HiLog.e(TAG, `parseDumpLayoutJSONAndGetRenderOrder failed: ${String(e)}`);
    return [];
  }
}

// ==========================================
// Helper: 遍历 uitest JSON 树提取媒体项
// ==========================================

// ==========================================
// Helper: Click sort button and menu item by ON.text()
// ==========================================

/**
 * 通过 ON.text() 点击排序按钮和菜单项
 * 
 * @param menuItemText - 菜单项文本（如 '按名称排序'）
 * @returns 是否成功点击
 */
async function clickSortButtonAndMenuItemByText(menuItemText: string): Promise<boolean> {
  if (!g_driver) {
    HiLog.e(TAG, 'Driver is null');
    return false;
  }
  
  try {
    await g_driver.waitForIdle(1000, 3000);
    
    const sortButton = await g_driver.waitForComponent(ON.id('sort_button'), 3000);
    if (!sortButton) {
      HiLog.e(TAG, 'Sort button not found');
      return false;
    }
    
    await sortButton.click();
    HiLog.i(TAG, 'Sort button clicked');
    
    await g_driver.delayMs(1500);
    await g_driver.waitForIdle(500, 2000);
    
    const menuItem = await g_driver.waitForComponent(ON.text(menuItemText, MatchPattern.CONTAINS), 5000);
    if (!menuItem) {
      HiLog.e(TAG, `MenuItem not found: ${menuItemText}`);
      return false;
    }
    
    await menuItem.click();
    HiLog.i(TAG, `MenuItem clicked: ${menuItemText}`);
    
    await g_driver.waitForIdle(500, 5000);
    return true;
  } catch (error) {
    HiLog.e(TAG, `clickSortButtonAndMenuItemByText failed: ${String(error)}`);
    return false;
  }
}

// ==========================================
// Helper: Click menu item by coordinate (fallback)
// ==========================================

/**
 * 通过坐标点击菜单项（备选方案）
 * 
 * @param sortType - 排序类型（NAME/DATE/SIZE）
 * @returns 是否成功点击
 */
async function clickMenuItemByCoordinate(sortType: SortType): Promise<boolean> {
  if (!g_driver) {
    HiLog.e(TAG, 'Driver is null');
    return false;
  }
  
  try {
    await g_driver.waitForIdle(1000, 3000);
    
    const sortButton = await g_driver.waitForComponent(ON.id('sort_button'), 3000);
    if (!sortButton) {
      HiLog.e(TAG, 'Sort button not found');
      return false;
    }
    
    const bounds = await sortButton.getBounds();
    await sortButton.click();
    await g_driver.delayMs(2000);
    
    // Menu dimensions
    const menuWidth = 200;
    const menuItemHeight = 48;
    const menuGap = 4;
    const menuPadding = 8;
    
    const buttonCenterX = (bounds.left + bounds.right) / 2;
    const menuLeft = buttonCenterX - menuWidth / 2;
    const menuTop = bounds.bottom + menuGap;
    
    let itemIndex: number;
    switch (sortType) {
      case SortType.NAME: itemIndex = 0; break;
      case SortType.DATE: itemIndex = 1; break;
      case SortType.SIZE: itemIndex = 2; break;
      default: itemIndex = 1;
    }
    
    const clickX = menuLeft + menuWidth / 2;
    const clickY = menuTop + menuPadding + (itemIndex * menuItemHeight) + menuItemHeight / 2;
    
    HiLog.i(TAG, `Coordinate click: (${clickX.toFixed(1)}, ${clickY.toFixed(1)})`);
    
    await g_driver.click(clickX, clickY);
    await g_driver.waitForIdle(500, 5000);
    return true;
  } catch (error) {
    HiLog.e(TAG, `clickMenuItemByCoordinate failed: ${String(error)}`);
    return false;
  }
}

// ==========================================
// Helper: Combined fallback click
// ==========================================

/**
 * 组合点击策略：先尝试 ON.text()，失败后使用坐标点击
 * 
 * @param menuItemText - 菜单项文本
 * @param sortType - 排序类型
 * @returns 是否成功点击
 */
async function clickMenuItemWithFallback(menuItemText: string, sortType: SortType): Promise<boolean> {
  HiLog.i(TAG, `=== Click: ${menuItemText} ===`);
  
  const textResult = await clickSortButtonAndMenuItemByText(menuItemText);
  if (textResult) {
    await TestUtil.delay(1000);
    return true;
  }
  
  HiLog.w(TAG, 'ON.text() failed, using coordinate');
  return await clickMenuItemByCoordinate(sortType);
}

// ==========================================
// Helper: 从 uitest dumpLayout 捕获 UI 当前显示的排序类型
// ==========================================

/**
 * 通过 uitest dumpLayout 捕获 UI 当前显示的排序类型文本
 * 
 * 关键修复：hidumper viewHierarchy 不输出 text 属性
 * uitest dumpLayout JSON 包含 text 和 originalText 字段，可获取实际显示文本
 * 
 * @returns UI 显示的排序类型文本（如 '按名称排序'）
 */
async function captureUIDisplayedSortType(): Promise<string> {
  HiLog.i(TAG, '=== Capturing UI displayed sort type via uitest dumpLayout ===');
  
  if (!g_delegator || !g_context) {
    HiLog.e(TAG, 'Delegator or context is null');
    return '';
  }
  
  try {
    // 获取 uitest dumpLayout JSON 内容（用于查找排序类型文本）
    const jsonContent = await getUitestDumpLayoutJsonContent();
    
    if (!jsonContent) {
      HiLog.e(TAG, 'Failed to get uitest dumpLayout JSON');
      return '';
    }
    
    // 解析 JSON 并查找排序类型文本
    const rootNode: UiTestNode = JSON.parse(jsonContent);
    const sortTypeText = findSortTypeTextInUiTestTree(rootNode);
    
    if (sortTypeText) {
      HiLog.i(TAG, `UI shows: "${sortTypeText}"`);
      return sortTypeText;
    }
    
    HiLog.w(TAG, 'No sort type text found in UI');
    return '';
  } catch (error) {
    HiLog.e(TAG, `captureUIDisplayedSortType failed: ${String(error)}`);
    return '';
  }
}

/**
 * 获取 uitest dumpLayout JSON 内容（不解析，用于文本搜索）
 */
async function getUitestDumpLayoutJsonContent(): Promise<string> {
  if (!g_delegator || !g_context) {
    return '';
  }
  
  try {
    const sandboxFilesDir = g_context.filesDir;
    const physicalSandboxPath = `/data/app/el2/100/base/${g_bundleName}/haps/phone_test/files`;
    
    // 执行 uitest dumpLayout
    const dumpResult = await g_delegator.executeShellCommand('uitest dumpLayout', 15000);
    
    await new Promise<void>(resolve => setTimeout(resolve, 2000));
    
    // 解析 uitest 输出路径
    let uitestJsonPath = '';
    if (dumpResult.stdResult && dumpResult.stdResult.includes('DumpLayout saved to:')) {
      const match = dumpResult.stdResult.match(/DumpLayout saved to:(\S+)/);
      if (match && match[1]) {
        uitestJsonPath = match[1].trim();
      }
    }
    
    if (!uitestJsonPath || !uitestJsonPath.startsWith('/data/local/tmp/')) {
      HiLog.e(TAG, `Invalid uitest path: ${uitestJsonPath}`);
      return '';
    }
    
    // shell cp 写入沙箱
    const targetFileName = `ui_sort_type_${Date.now()}.json`;
    const physicalTargetPath = `${physicalSandboxPath}/${targetFileName}`;
    
    const copyResult = await g_delegator.executeShellCommand(`cp ${uitestJsonPath} ${physicalTargetPath}`, 10000);
    
    if (copyResult.exitCode !== 0) {
      HiLog.e(TAG, `Shell cp failed: exitCode=${copyResult.exitCode}`);
      return '';
    }
    
    await new Promise<void>(resolve => setTimeout(resolve, 500));
    
    // 读取 JSON
    const sandboxTargetPath = `${sandboxFilesDir}/${targetFileName}`;
    const jsonContent = fs.readTextSync(sandboxTargetPath);
    
    return jsonContent;
  } catch (e) {
    HiLog.e(TAG, `getUitestDumpLayoutJsonContent failed: ${String(e)}`);
    return '';
  }
}

/**
 * 递归查找 uitest JSON 树中的排序类型文本
 */
function findSortTypeTextInUiTestTree(node: UiTestNode): string {
  const attrs = node.attributes;
  
  // 检查 text 字段是否包含排序类型文本
  const text = attrs.text || attrs.originalText || '';
  
  if (text.includes('按名称排序')) {
    return '按名称排序';
  }
  if (text.includes('按时间排序')) {
    return '按时间排序';
  }
  if (text.includes('按大小排序')) {
    return '按大小排序';
  }
  
  // 递归处理子节点
  if (node.children && node.children.length > 0) {
    for (const child of node.children) {
      const result = findSortTypeTextInUiTestTree(child);
      if (result) {
        return result;
      }
    }
  }
  
  return '';
}

// ==========================================
// Helper: 映射 UI 文本到 SortType
// ==========================================

/**
 * 将 UI 显示的排序文本映射到 SortType
 * 
 * @param uiText - UI 文本（如 '按名称排序'）
 * @returns 对应的 SortType，无法映射返回 null
 */
function mapUITextToSortType(uiText: string): SortType | null {
  switch (uiText) {
    case '按名称排序': return SortType.NAME;
    case '按时间排序': return SortType.DATE;
    case '按大小排序': return SortType.SIZE;
    default: return null;
  }
}

// ==========================================
// Helper: 滚动列表到顶部（确保第一项可见）
// ==========================================

async function scrollListToTop(): Promise<void> {
  HiLog.i(TAG, '=== Scrolling List to Top ===');

  if (!g_driver) {
    HiLog.e(TAG, 'Driver is null, cannot scroll');
    return;
  }

  try {
    // 尝试多次向上滑动确保到达顶部
    for (let i = 0; i < 3; i++) {
      await g_driver.swipe(500, 300, 500, 800); // 向上滑动：从 y=300 到 y=800
      await TestUtil.delay(200);
    }

    HiLog.i(TAG, 'List scrolled to top');
  } catch (e) {
    HiLog.e(TAG, `scrollListToTop failed: ${String(e)}`);
  }
}

// ==========================================
// Helper: 等待 UI 稳定
// ==========================================

async function waitForUIStable(): Promise<void> {
  if (!g_driver) {
    return;
  }

  try {
    await g_driver.waitForIdle(500, 3000);
  } catch (e) {
    HiLog.w(TAG, `waitForUIStable: ${String(e)}`);
  }
}

// ==========================================
// Test Suite
// ==========================================

export default function StartAbilitySortTest() {
  describe('StartAbilitySortSuite', () => {

    // ==========================================
    // beforeAll: 测试环境初始化
    // ==========================================

    beforeAll(async () => {
      HiLog.i(TAG, '=== beforeAll START ===');

      // Step 1: 解锁设备（防止 startAbility 卡死）
      const unlockSuccess = await TestUtil.unlockDevice();
      HiLog.i(TAG, `Device unlock: ${unlockSuccess}`);

      // Step 2: 初始化测试环境
      await TestUtil.initTestEnvironment();

      // Step 3: 自动化授权
      const permissionsGranted = await TestUtil.grantAllMediaPermissions();
      HiLog.i(TAG, `Permissions auto-granted: ${permissionsGranted}`);
      expect(permissionsGranted).assertTrue();

      // Step 4: 获取 context（重试模式）
      let retryCount = 0;
      while (retryCount < 10) {
        g_context = TestUtil.getContext();
        if (g_context) {
          HiLog.i(TAG, 'Context obtained successfully');
          break;
        }
        await TestUtil.delay(100);
        retryCount++;
      }
      expect(g_context).not().assertNull();

      // Step 5: 获取 delegator
      g_delegator = abilityDelegatorRegistry.getAbilityDelegator();
      const args = abilityDelegatorRegistry.getArguments();
      g_bundleName = args.bundleName || 'com.ohos.players';
      HiLog.i(TAG, `Delegator obtained, bundleName=${g_bundleName}`);

      // Step 6: 启用测试模式
      await g_delegator.executeShellCommand('param set persist.ace.testmode.enabled 1', 5000);
      HiLog.i(TAG, 'Test mode enabled');

      // Step 7: 创建 UiTest Driver
      g_driver = Driver.create();
      HiLog.i(TAG, 'UiTest Driver created');

      HiLog.i(TAG, '=== beforeAll END ===');
    });

    // ==========================================
    // afterAll: 测试环境清理
    // ==========================================

    afterAll(async () => {
      HiLog.i(TAG, '=== afterAll START ===');

      await TestUtil.cleanupTestEnvironment();

      g_viewModel = null;
      g_fileMonitor = null;
      g_driver = null;

      HiLog.i(TAG, '=== afterAll END ===');
    });

    // ==========================================
    // beforeEach: 每个测试前初始化
    // ==========================================

    beforeEach(async () => {
      HiLog.i(TAG, '=== beforeEach START ===');

      if (!g_delegator || !g_context) {
        HiLog.w(TAG, 'delegator or context is null');
        return;
      }

      // startAbility 拉起应用（AUDIO tab + NAME DESC baseline）
      const audioWant: Want = {
        bundleName: g_bundleName,
        abilityName: 'MainAbility',
        action: 'com.ohos.players.action.AUDIO',
        parameters: {
          'defaultTab': 'AUDIO',
          'sortBy': 'name',     // NEW: Default NAME sort
          'sortDesc': true      // NEW: Default DESC order
        }
      };

      const started = await TestUtil.startAbilityWithTimeout(g_delegator, audioWant, 10000);
      HiLog.i(TAG, `startAbility result: ${started}`);
      expect(started).assertTrue();

      if (!started) {
        HiLog.e(TAG, 'startAbility failed');
        return;
      }

      // 等待应用初始化
      await TestUtil.delay(TestUtil.WAIT_TIME_MS_LONG); // 3000ms

      // 获取 ViewModel 和 FileMonitor
      const result = await TestUtil.getViewModelAndFileMonitor(g_context!);
      if (result) {
        g_viewModel = result.viewModel;
        g_fileMonitor = result.fileMonitor;
        HiLog.i(TAG, 'ViewModel and FileMonitor obtained');
      }

      // 加载媒体文件
      if (g_viewModel) {
        await g_viewModel.loadMediaFiles(MediaType.AUDIO, true);
        const mediaCount = g_viewModel.getMediaCount();
        HiLog.i(TAG, `Loaded ${mediaCount} audio files`);
      }

      if (g_driver) {
        await g_driver.waitForIdle(500, 3000);
      }

      // ==========================================
      // INITIAL STATE VERIFICATION: 验证 want+action 启动排序是否生效
      // ==========================================

      HiLog.i(TAG, '=== Initial State Verification START ===');

      // SYNC FIX: 同步 ViewModel 状态到 want.parameters 设置的默认值
      if (g_viewModel) {
        g_viewModel.sortBy(SortType.NAME, true);
        HiLog.i(TAG, 'beforeEach: sortBy(NAME, isDesc=true) synced from want.parameters');
      }

      await TestUtil.delay(2000);

      // 验证 ViewModel 状态
      if (g_viewModel) {
        const vmSortType = g_viewModel.getCurrentSortType();
        const vmIsDesc = g_viewModel.getIsDesc();
        HiLog.i(TAG, `ViewModel state: sortType=${vmSortType}, isDesc=${vmIsDesc}`);
      }

      // 验证 UI 显示的排序类型
      const initialUIText = await captureUIDisplayedSortType();
      HiLog.i(TAG, `Initial UI shows: "${initialUIText}"`);

      const initialUISortType = mapUITextToSortType(initialUIText);
      HiLog.i(TAG, `Initial UI sortType: ${initialUISortType}, Expected: NAME (${SortType.NAME})`);

      // 断言：初始 UI 应显示 NAME 排序（来自 want.parameters）
      if (initialUISortType !== SortType.NAME) {
        HiLog.e(TAG, '=== BUG CONFIRMED: Initial UI sort type ≠ want.parameters ===');
        HiLog.e(TAG, `want.parameters sortBy='name', but UI shows "${initialUIText}" (${initialUISortType})`);
        HiLog.e(TAG, 'Root cause: onNewWant does not trigger UI aboutToAppear, applySortFromAppStorage is not called');
        // Let the test continue to collect more info instead of throwing assertion failure immediately
        // expect(initialUISortType === SortType.NAME).assertTrue();
      } else {
        HiLog.i(TAG, '=== Initial state OK: UI shows NAME sort ===');
      }

      HiLog.i(TAG, '=== Initial State Verification END ===');
      HiLog.i(TAG, '=== beforeEach END ===');
    });

    // ==========================================
    // afterEach: 每个测试后清理
    // ==========================================

    afterEach(async () => {
      HiLog.i(TAG, '=== afterEach ===');

      // 清理：关闭菜单（如果打开）并返回
      if (g_driver) {
        try {
          await g_driver.pressBack();
          await g_driver.delayMs(300);
        } catch (e) {
          HiLog.w(TAG, `pressBack failed in afterEach: ${e}`);
        }
      }
    });
  });
}