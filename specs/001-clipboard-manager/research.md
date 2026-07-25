# 研究文档: macOS 剪切板管理器

## 决策记录

### Decision 1: 剪切板监听方式

**选择了**: 基于 `NSPasteboard.changeCount` 的定时轮询方式，轮询间隔 0.5 秒

**理由**:
- macOS AppKit **没有**原生的剪切板变化通知（不同于 iOS 的 `UIPasteboardChangedNotification`）
- 行业通用做法是轮询 `NSPasteboard.general.changeCount`，Maccy（19k stars）等成熟产品均采用此方式
- 轮询方式简单可靠，0.5 秒间隔在性能和实时性之间取得平衡
- 使用 `.string` 类型的 `availableType(from:)` 检测，避免读取实际内容（在 macOS 16+ 上会触发隐私弹窗）

**备选方案**:
- `UIPasteboardChangedNotification`（Mac Catalyst 13.0+）：需要 Mac Catalyst 环境，不适合纯原生 AppKit 应用
- CGEventTap 监控粘贴操作：过于底层，需要辅助功能权限，复杂度不匹配 MVP 需求

### Decision 2: 全局快捷键注册方式

**选择了**: Carbon `RegisterEventHotKey` API

**理由**:
- 这是 macOS 上唯一能**消费**全局快捷键事件的方案（阻止事件传递到前台应用）
- `soffes/HotKey`（1k stars）等成熟库均采用此方案
- 虽然 Carbon 已废弃，但 `RegisterEventHotKey` 仍在 macOS 最新系统中正常工作
- 快捷键组合可配置（默认 Cmd+Shift+V），需要在 AppKit 层实现

**备选方案**:
- `NSEvent.addGlobalMonitorForEvents`：只能**监听**不能消费事件，快捷键会同时传递给前台应用，造成冲突
- `CGEventTap`：过于底层，需要辅助功能权限

### Decision 3: 菜单栏应用实现

**选择了**: SwiftUI `MenuBarExtra`（macOS 13+ 原生支持）

**理由**:
- macOS 13 Ventura 原生支持 `MenuBarExtra`，纯 SwiftUI 实现
- 支持两种风格：`.menu`（标准系统菜单）和 `.window`（自定义内容窗口）
- 本项目使用 `.window` 风格，以便在弹出窗口中显示列表、搜索框等复杂 UI
- 设置 `LSUIElement = YES` 隐藏 Dock 图标，保持为纯菜单栏应用

**备选方案**:
- AppKit `NSStatusItem` + `NSPopover`：代码量更大，但对于需要浮动面板（floating panel）场景更灵活。MVP 阶段用 `MenuBarExtra(.window)` 足够

### Decision 4: 文件存储格式

**选择了**: 每条记录独立 `.txt` 文件 + 单文件 JSON 元数据索引

**理由**:
- **文本文件**（`~/.ditto4mac/items/<id>.txt`）：纯文本内容直接以 `.txt` 存储，便于调试和手动编辑
- **元数据索引**（`~/.ditto4mac/index.json`）：包含所有记录的元数据数组（id、时间戳、是否固定、文本文件路径）
- **设置文件**（`~/.ditto4mac/settings.json`）：用户配置（快捷键、最大条数、最大字符数、存储路径）
- 结构简单、可调试、无外部依赖
- macOS 文件系统对小型文件操作性能足够

**备选方案**:
- SQLite：功能强大但对于 MVP 过度设计，增加依赖
- CoreData：Apple 官方但学习曲线陡峭，MVP 不需要
- plist：不适合存储大量文本内容

### Decision 5: 弹出窗口交互方式

**选择了**: `MenuBarExtra(.window)` + `NSPanel` 增强模式

**理由**:
- `MenuBarExtra(.window)` 提供基本的弹出窗口能力
- 对于"点击其他应用不关闭窗口"的需求（如用户选择历史记录后窗口保持可见），需要 `NSPanel` 的 `.nonactivatingPanel` 特性
- MVP 阶段先用 `MenuBarExtra(.window)`，如果需要面板行为再升级到 `NSPanel`
- 弹出窗口支持：搜索框、列表、右键菜单（固定/删除）

### Decision 6: 测试策略

**选择了**: XCTest 单元测试 + 手动集成测试

**理由**:
- SwiftUI 视图的 UI 测试（XCUITest）在 macOS 上相对不稳定
- 核心逻辑（剪切板监听、文件存储、搜索过滤）可以通过纯 Swift 单元测试覆盖
- MVP 阶段以单元测试为主，集成测试通过手动验证
- 测试覆盖率目标：核心逻辑 85%+

**备选方案**:
- SnapshotTesting：需要额外依赖，MVP 阶段不需要
- Swift Testing（Xcode 16+）：macOS 13 可能无法使用最新版本
