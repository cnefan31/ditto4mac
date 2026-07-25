# 任务: macOS 剪切板管理器 (MVP)

**输入**: 来自 `/specs/001-clipboard-manager/` 的设计文档
**前置条件**: plan.md(必需), spec.md(用户故事必需), research.md, data-model.md, contracts/

**实施策略**: 测试是可选的——本 MVP 版本以功能实现优先，不包含独立测试任务。每个用户故事可以独立实施和验证。

## 格式: `[ID] [P?] [Story] 描述`
- **[P]**: 可以并行运行（不同文件，无依赖关系）
- **[Story]**: 此任务属于哪个用户故事（例如: US1, US2, US3）
- 在描述中包含确切的文件路径

---

## 阶段 1: 设置（项目初始化）

**目的**: Xcode 项目创建、Info.plist 配置、目录结构

- [x] T001 在 Xcode 中创建 macOS App 项目，命名为 Ditto4Mac，选择 SwiftUI 界面 + Swift 语言，最低部署版本 macOS 13.0
- [x] T002 在 Info.plist 中添加 `Application is agent (UIElement) = YES`，隐藏 Dock 图标
- [x] T003 创建项目目录结构: `Models/`, `Services/`, `ViewModels/`, `Views/`, `Resources/`

---

## 阶段 2: 基础（阻塞前置条件）

**目的**: 数据模型和存储层——所有用户故事的共同基础

**⚠️ 关键**: 在此阶段完成之前，无法开始任何用户故事工作

- [x] T004 [P] 在 `Models/ClipboardItem.swift` 中实现 ClipboardItem 结构体（id、createdAt、isPinned、pinnedAt，符合 Codable、Identifiable、Equatable）
- [x] T005 [P] 在 `Models/AppSettings.swift` 中实现 AppSettings 结构体（hotkeyModifiers、hotkeyKeyCode、maxItems、maxCharsPerItem、displayCount、storagePath、pollingInterval、launchAtLogin，含默认值）
- [x] T006 在 `Services/StorageService.swift` 中实现 StorageService 类:
  - 目录结构初始化（`~/.ditto4mac/` + `items/` 子目录）
  - `loadItems()` / `saveItem(_:text:)` / `deleteItem(_:)` / `updateItem(_:)`
  - `loadSettings()` / `saveSettings(_:)`
  - `searchItems(query:)` 不区分大小写搜索
  - 写入原子性（临时文件 + 重命名）
  - 超出 maxItems 时自动清理最旧的非固定记录

**检查点**: 基础就绪——数据层可独立工作，现在可以开始用户故事实施

---

## 阶段 3: 用户故事 1 - 自动捕获并查看剪切板历史 (优先级: P1) 🎯 MVP

**目标**: 后台持续监听剪切板变化，全局快捷键弹出历史列表，点击复制内容到系统剪切板

**独立测试**: 复制几段文本，按 Cmd+Shift+V 打开历史窗口，选择某条记录并粘贴，验证内容正确恢复

- [x] T007 [P] [US1] 在 `Services/ClipboardMonitor.swift` 中实现 ClipboardMonitor 类:
  - Timer 轮询 `NSPasteboard.general.changeCount`（间隔从 AppSettings 读取，默认 0.5s）
  - 检测纯文本类型: `availableType(from: [.string]) == .string`
  - 忽略自己写入的变更（记录自身 changeCount）
  - 回调 `onNewContent: ((String) -> Void)?`
  - `startMonitoring()` / `stopMonitoring()` 方法
- [x] T008 [P] [US1] 在 `Services/HotkeyManager.swift` 中实现 HotkeyManager 类:
  - Carbon `RegisterEventHotKey` / `UnregisterEventHotKey`
  - 从 AppSettings 读取修饰键和键码
  - 回调 `onHotkeyTriggered: (() -> Void)?`
  - 启动时注册，退出时注销
- [x] T009 [US1] 在 `ViewModels/ClipboardViewModel.swift` 中实现 ClipboardViewModel:
  - 整合 ClipboardMonitor + StorageService
  - 管理 items 数组（按时间倒序，固定片段优先）
  - 处理新捕获内容：校验长度（≤ maxCharsPerItem）、去重、保存
  - 提供 `selectItem(_:)` 方法：将文本写入系统剪切板
  - 提供 `displayItems` 计算属性：返回前 displayCount 条记录
- [x] T010 [US1] 在 `Ditto4MacApp.swift` 中实现应用入口:
  - `@main Ditto4MacApp` 结构体
  - `MenuBarExtra` with `.menuBarExtraStyle(.window)`
  - 初始化 ClipboardViewModel、ClipboardMonitor、HotkeyManager
  - 启动时自动加载历史并开始监听

**检查点**: 此时，用户故事 1 应该完全功能化——用户可以复制文本、按快捷键查看历史、点击复制回系统剪切板

---

## 阶段 4: 用户故事 2 - 搜索剪切板历史 (优先级: P2)

**目标**: 弹出窗口中实时搜索过滤历史记录，匹配文字高亮显示

**独立测试**: 复制 20+ 条不同文本，打开历史窗口，输入关键词搜索，验证过滤正确

- [x] T011 [US2] 在 `Views/ClipboardListView.swift` 中实现搜索功能:
  - 顶部搜索框（TextField），打开窗口时自动聚焦
  - `@State searchText: String`
  - 输入时实时过滤 items（使用 ClipboardViewModel.searchItems(query:)）
  - 无匹配结果时显示"无匹配结果"提示
  - 搜索时固定片段始终显示在顶部（不受搜索影响）
- [x] T012 [US2] 在 `Views/ClipboardListView.swift` 中完成列表展示和键盘导航:
  - 显示 `displayItems` 列表（默认 10 条）
  - 滚动加载更多（如果总记录 > displayCount）
  - 键盘导航: ↑↓ 移动选择、回车确认、Escape 关闭
  - 点击某条记录时调用 ViewModel 的 `selectItem(_:)`
  - 列表按时间倒序排列

**检查点**: 此时，用户故事 1 + 2 共同工作——用户可以搜索并快速找到历史剪切板内容

---

## 阶段 5: 用户故事 3 - 管理固定片段 (优先级: P3)

**目标**: 将常用文本片段固定保存，始终显示在列表顶部，不被自动清除

**独立测试**: 添加若干固定片段，打开历史窗口验证始终可见，选择并粘贴验证内容正确

- [x] T013 [US3] 在 `Views/ClipboardItemRow.swift` 中实现行视图操作:
  - 显示文本预览（截断显示前 100 字符）+ 时间戳
  - 固定状态图标（📌 或 SF Symbol）
  - 右键菜单: "固定片段" / "取消固定" / "删除"
  - 点击行: 复制内容到系统剪切板
  - 匹配高亮（搜索场景中）
- [x] T014 [US3] 在 `ViewModels/ClipboardViewModel.swift` 中扩展固定片段功能:
  - `pinItem(_:)` 方法: 设置 `isPinned=true`, 记录 `pinnedAt`
  - `unpinItem(_:)` 方法: 设置 `isPinned=false`
  - `addPinnedItem(text:)` 方法: 手动添加固定片段
  - 更新 `displayItems` 排序逻辑: 固定片段在前（按 pinnedAt 倒序），普通记录在后（按 createdAt 倒序）
  - 确保 StorageService 保存固定状态
- [x] T015 [US3] 在 `Views/ClipboardListView.swift` 中实现手动添加固定片段:
  - 顶部"添加固定片段"按钮或快捷键
  - 弹出文本输入对话框
  - 保存后刷新列表

**检查点**: 此时，用户故事 1 + 2 + 3 共同工作——用户可以固定常用内容，始终可及

---

## 阶段 6: 用户故事 4 - 删除历史记录 (优先级: P4)

**目标**: 用户可以删除不需要的历史记录和固定片段，保护隐私

**独立测试**: 复制一段文本，打开历史窗口删除，验证不再出现

- [x] T016 [US4] 在 `ViewModels/ClipboardViewModel.swift` 中实现删除功能:
  - `deleteItem(_:)` 方法: 调用 StorageService.deleteItem()
  - 删除后刷新 items 列表
- [x] T017 [US4] 在 `Views/ClipboardItemRow.swift` 中完善右键菜单:
  - 右键菜单 → "删除" 选项
  - 弹出确认对话框（避免误删）
  - Delete / Backspace 键盘快捷键删除当前高亮项
  - 固定片段删除时完全移除（不再是固定状态）

**检查点**: 此时，所有用户故事完成——用户可以完整管理剪切板历史

---

## 阶段 7: 设置页面

**目的**: 用户配置界面——快捷键、存储路径、数量限制

- [x] T018 [P] 在 `Views/SettingsView.swift` 中实现设置窗口:
  - 快捷键配置（修饰键 + 键码选择器）
  - 存储路径配置（路径选择器，默认 `~/.ditto4mac`）
  - 最大存储条数（Stepper，范围 10-10000）
  - 单条最大字符数（Stepper，范围 100-1000000）
  - 默认显示条数（Stepper，范围 1-maxItems）
  - 开机自启开关
  - 修改时实时保存到 settings.json
  - 修改存储路径时迁移现有数据
- [x] T019 在 `Ditto4MacApp.swift` 中连接 Settings 场景:
  - `.commands { CommandGroup(...) }` 添加设置菜单项

**范围排除声明**:

FR-014"窗口关闭时自动将复制的内容粘贴到目标位置"标记为可选优化，不在 MVP 范围内。此功能需要 Accessibility API 模拟键盘事件（Cmd+V），实现复杂度和权限开销不匹配 MVP 目标。后续版本可评估添加。

---

## 阶段 8: 完善与横切关注点

**目的**: 边界情况处理、性能优化、用户体验打磨

- [x] T020 处理边界情况:
  - 复制非纯文本内容时忽略（图片、文件等）
  - 复制超过 maxCharsPerItem 的文本不记录
  - 首次启动（历史记录为空）显示空状态提示
  - 快捷键与其他应用冲突时的处理
  - 搜索词包含特殊字符（Emoji、换行符）的正常处理
- [x] T021 用户体验打磨:
  - 空状态 UI（"暂无剪切板历史"）
  - 加载中/同步状态反馈
  - 搜索框 Cmd+F 快捷键聚焦
  - 窗口打开动画优化
  - 列表行 hover 效果
- [x] T022 性能验证（对应成功标准 SC-001~SC-004）:
  - SC-001 快捷键响应 ≤ 200ms: 使用 Date() 测量快捷键触发到窗口出现的间隔，重复 5 次取平均
  - SC-002 搜索 ≤ 3 秒（50+ 条）: 预置 50+ 条记录，输入关键词测量过滤完成时间（预期远 < 3 秒）
  - SC-003 100% 复制成功率: 手动测试 10 次"点击→粘贴"流程，验证内容完全一致
  - SC-004 内存 ≤ 50MB, CPU < 1%: 使用 macOS Activity Monitor 或 Xcode Instruments 监控 5 分钟后台运行资源占用
  - 按需加载 .txt 文件内容，不一次性加载所有记录
- [x] T023 代码清理: 审查代码风格、移除未使用代码、添加必要注释

---

## 依赖关系与执行顺序

### 阶段依赖关系

- **设置（阶段 1）**: 无依赖——可立即开始
- **基础（阶段 2）**: 依赖于设置完成——阻塞所有用户故事
- **用户故事（阶段 3-6）**: 都依赖于基础阶段完成，按优先级顺序执行
  - US1（P1）可在基础完成后开始
  - US2（P2）依赖于 US1 的基础 UI 组件
  - US3（P3）依赖于 US1 的 ViewModel 和列表
  - US4（P4）依赖于 US1 的 ViewModel 和列表
- **设置页面（阶段 7）**: 依赖于基础层完成
- **完善（阶段 8）**: 依赖于所有用户故事完成

### 用户故事依赖关系

- **US1 (P1)**: 可在基础（阶段 2）后开始——无故事依赖
- **US2 (P2)**: 可在 US1 后开始——复用 US1 的 UI 组件
- **US3 (P3)**: 可在 US1 后开始——复用 US1 的 ViewModel
- **US4 (P4)**: 可在 US1 后开始——复用 US1 的 ViewModel
- US2/US3/US4 之间相互独立，可在 US1 完成后按任意顺序实施

### 每个用户故事内部

- 模型/服务任务 → ViewModel 任务 → View 任务
- 设置任务无严格顺序，可并行（[P] 标记）
- 每个故事完成后才可移至下一个优先级

### 并行机会

- T004（ClipboardItem）+ T005（AppSettings）可并行（不同文件，无依赖）
- T007（ClipboardMonitor）+ T008（HotkeyManager）可并行（不同文件，无依赖）
- US2/US3/US4 可在 US1 完成后由不同开发者并行处理

---

## 并行示例: 基础阶段

```bash
# 并行实施基础阶段任务:
# Agent A: 数据模型
任务: "在 Models/ClipboardItem.swift 中实现 ClipboardItem 结构体" (T004)
任务: "在 Models/AppSettings.swift 中实现 AppSettings 结构体" (T005)

# Agent B: 存储服务
任务: "在 Services/StorageService.swift 中实现 StorageService" (T006)
```

## 并行示例: 用户故事 1

```bash
# 并行实施 US1 核心服务:
# Agent A: 剪切板监听
任务: "在 Services/ClipboardMonitor.swift 中实现 ClipboardMonitor 类" (T007)

# Agent B: 快捷键管理
任务: "在 Services/HotkeyManager.swift 中实现 HotkeyManager 类" (T008)

# 完成后整合:
任务: "在 ViewModels/ClipboardViewModel.swift 中实现 ClipboardViewModel" (T009)
任务: "在 Ditto4MacApp.swift 中实现应用入口" (T010)
```

---

## 实施策略

### 仅 MVP（仅用户故事 1）

1. 完成阶段 1: 设置
2. 完成阶段 2: 基础（关键——阻塞所有故事）
3. 完成阶段 3: 用户故事 1
4. **停止并验证**: 测试复制→快捷键弹出→选择复制
5. 如准备好则构建 .app 验证

### 增量交付

1. 完成设置 + 基础 → 数据层就绪
2. 添加用户故事 1 → 核心剪切板历史管理 → MVP 可用！
3. 添加用户故事 2 → 搜索能力 → 实用性大幅提升
4. 添加用户故事 3 → 固定片段 → 完整功能
5. 添加用户故事 4 → 删除功能 → 隐私完善
6. 添加设置页面 → 用户可配置
7. 完善打磨 → 产品级质量

### 推荐执行顺序（单人）

T001 → T002 → T003 → T004 + T005（并行）→ T006 → T007 + T008（并行）→ T009 → T010 → T011 → T012 → T013 → T014 → T015 → T016 → T017 → T018 → T019 → T020 → T021 → T022 → T023

---

## 注意事项

- [P] 任务 = 不同文件，无依赖关系
- [Story] 标签将任务映射到特定用户故事以实现可追溯性
- 每个用户故事应该独立可完成和可验证
- 在每个任务或逻辑组后提交
- 在任何检查点停止以独立验证故事
- 避免: 模糊任务、相同文件冲突、破坏独立性的跨故事依赖
