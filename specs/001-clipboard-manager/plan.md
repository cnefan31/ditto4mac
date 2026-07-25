# 实施计划: macOS 剪切板管理器 (MVP)

**分支**: `001-clipboard-manager` | **日期**: 2026-04-13 | **规范**: [spec.md](./spec.md)
**输入**: 来自 `/specs/001-clipboard-manager/spec.md` 的功能规范

## 摘要

开发一个 macOS 菜单栏常驻的纯文本剪切板管理器 MVP，核心功能：后台自动捕获剪切板纯文本内容、全局快捷键弹出历史记录窗口（默认显示 10 条）、实时搜索过滤、固定常用片段。采用 SwiftUI + AppKit 原生开发，文件存储，零第三方依赖。

## 技术背景

**语言/版本**: Swift 5.9+ / Xcode 15+
**主要依赖**: 无第三方依赖，仅使用 Apple 原生框架（SwiftUI, AppKit, Carbon）
**存储**: 文件系统存储（独立 .txt 文件 + JSON 元数据索引）
**测试**: XCTest 单元测试
**目标平台**: macOS 13 (Ventura) 及以上
**项目类型**: macOS 桌面应用（菜单栏应用 / Menu Bar App）
**性能目标**: 快捷键响应 ≤ 200ms，搜索过滤 ≤ 100ms（50+ 条记录），内存占用 ≤ 50MB，CPU 使用率 < 1%
**约束条件**: 纯文本仅（UTF-8），无网络，无云同步，单用户，单机存储
**规模/范围**: MVP 产品，预期代码量 2000-3000 行 Swift 代码

## 章程检查

*门控: 必须在阶段 0 研究前通过。阶段 1 设计后重新检查。*

### 章程合规性分析

| 章程条款 | 合规性 | 说明 |
|---------|--------|------|
| **代码质量 - 可读性** | 通过 | 模块分层清晰（Models/Services/Views），每个文件职责单一 |
| **代码质量 - 架构纪律** | 通过 | 依赖方向：Views → Services → Models，无循环依赖 |
| **代码质量 - 代码规范** | 通过 | 遵循 Swift 官方编码规范，使用 SwiftLint（可选） |
| **测试标准 - 覆盖率** | 通过 | 核心逻辑（StorageService, ClipboardMonitor）单元测试目标 ≥ 85% |
| **测试标准 - 测试类型** | 通过 | 单元测试覆盖数据层和服务层，集成测试通过手动验证 |
| **用户体验一致性** | 通过 | SwiftUI 原生组件保证 UI 一致性，键盘导航统一 |
| **性能要求 - 加载性能** | 通过 | 按需加载文本内容，不一次性加载所有 .txt 文件 |
| **性能要求 - 运行时性能** | 通过 | 轮询间隔 0.5s，主线程任务远 < 50ms |
| **安全要求 - 数据安全** | 通过 | 纯本地存储，无网络传输，支持敏感内容手动删除 |

## 项目结构

### 文档（此功能）

```
specs/001-clipboard-manager/
├── plan.md              # 此文件 (/speckit.plan 命令输出)
├── research.md          # 阶段 0 输出 (/speckit.plan 命令)
├── data-model.md        # 阶段 1 输出 (/speckit.plan 命令)
├── quickstart.md        # 阶段 1 输出 (/speckit.plan 命令)
├── contracts/           # 阶段 1 输出 (/speckit.plan 命令)
│   └── api-contracts.md
└── tasks.md             # 阶段 2 输出 (/speckit.tasks 命令 - 非 /speckit.plan 创建)
```

### 源代码（Xcode 项目根目录）

```
Ditto4Mac/
├── Ditto4MacApp.swift           # @main 入口，MenuBarExtra 定义
├── Models/
│   ├── ClipboardItem.swift      # 剪切板记录数据模型
│   └── AppSettings.swift        # 用户设置数据模型
├── Services/
│   ├── ClipboardMonitor.swift   # NSPasteboard 轮询监听器 (AppKit)
│   ├── HotkeyManager.swift      # Carbon 全局快捷键管理 (AppKit)
│   └── StorageService.swift     # 文件存储读写 (index.json + settings.json + .txt)
├── ViewModels/
│   └── ClipboardViewModel.swift # 连接 UI 与 Services 的状态管理
├── Views/
│   ├── ClipboardListView.swift  # 主弹出窗口：搜索框 + 历史列表
│   ├── ClipboardItemRow.swift   # 单行显示：文本预览 + 固定/删除操作
│   └── SettingsView.swift       # 设置窗口：快捷键、存储路径、数量限制
└── Resources/
    └── Assets.xcassets            # 菜单栏图标、应用图标
```

**结构决策**: 采用单一 Xcode 项目、分层架构（MVVM 模式）。Models 层纯数据结构，Services 层处理所有系统交互（剪切板、快捷键、文件），ViewModels 层连接 UI 与服务，Views 层仅负责展示和交互。此结构适合 MVP 规模，保持代码简洁高效。

## 实现阶段规划

### Phase 1: 数据层与存储（P1 基础）
- 实现 ClipboardItem 和 AppSettings 模型
- 实现 StorageService：index.json、settings.json、.txt 文件的读写删除
- 单元测试：存储服务的 CRUD 操作

### Phase 2: 剪切板监听（P1 核心）
- 实现 ClipboardMonitor：Timer 轮询 NSPasteboard.changeCount
- 纯文本检测与过滤
- 与 StorageService 集成，自动保存新记录
- 单元测试：剪切板变化检测逻辑

### Phase 3: 全局快捷键（P1 核心）
- 实现 HotkeyManager：Carbon RegisterEventHotKey
- 可配置快捷键组合
- 单元测试：快捷键注册/注销逻辑

### Phase 4: UI 弹出窗口（P1 + P2）
- MenuBarExtra(.window) 弹出窗口
- ClipboardListView：搜索框 + 列表
- ClipboardItemRow：单行显示、点击复制
- 键盘导航（上下箭头、回车、Escape）

### Phase 5: 固定片段功能（P3）
- 固定/取消固定操作
- 列表中固定片段优先展示
- 手动添加固定片段

### Phase 6: 删除功能（P4）
- 删除历史记录和固定片段
- 确认对话框

### Phase 7: 设置页面
- SettingsView：快捷键配置、存储路径、数量限制
- 设置持久化

### Phase 8: 打磨与测试
- 边界情况处理
- 性能优化
- 端到端测试

## 复杂度跟踪

> **仅在章程检查有必须证明的违规时填写**

无违规。本设计遵循章程要求，结构简洁，无不必要的复杂性。
