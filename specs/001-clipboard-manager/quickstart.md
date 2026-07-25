# 快速开始: macOS 剪切板管理器

## 前置要求

- macOS 13 (Ventura) 或更高版本
- Xcode 15+ (支持 Swift 5.9+)
- 不需要任何第三方依赖

## 创建项目

1. 打开 Xcode，选择 **File → New → Project**
2. 选择 **macOS → App** 模板
3. 配置：
   - **Product Name**: `Ditto4Mac`
   - **Interface**: `SwiftUI`
   - **Language**: `Swift`
   - 取消勾选所有选项（Core Data, Unit Tests 等可后续添加）
4. 选择项目存储位置并创建

## 项目配置

### Info.plist 设置

在项目的 Info.plist 中添加以下键值：

| 键 | 值 | 说明 |
|----|------|------|
| `Application is agent (UIElement)` | `YES` | 隐藏 Dock 图标，仅显示菜单栏 |

### 签名设置

- Target → **Signing & Capabilities** → 启用 Automatic Signing
- 全局快捷键需要代码签名才能工作

### 最低部署版本

- Target → **General** → Deployment Target 设置为 **macOS 13.0**

## 构建核心模块

按以下顺序实现核心模块：

### 1. 数据层（`models/`）

```swift
// ClipboardItem.swift - 数据模型
struct ClipboardItem: Identifiable, Codable, Equatable {
    let id: String
    let createdAt: Date
    var isPinned: Bool
    var pinnedAt: Date?
    // text 从 .txt 文件加载，不序列化到 JSON
}

// Settings.swift - 用户设置
struct AppSettings: Codable {
    var hotkeyModifiers: Int = 13        // Cmd+Shift
    var hotkeyKeyCode: UInt32 = 9        // V key
    var maxItems: Int = 100
    var maxCharsPerItem: Int = 10000
    var displayCount: Int = 10
    var storagePath: String = "~/.ditto4mac"
    var pollingInterval: Double = 0.5
    var launchAtLogin: Bool = false
}
```

### 2. 存储层（`services/`）

```swift
// StorageService.swift - 文件存储
class StorageService {
    func loadItems() -> [ClipboardItem]
    func saveItem(_ item: ClipboardItem, text: String)
    func deleteItem(_ id: String)
    func updateItem(_ item: ClipboardItem)
    func loadSettings() -> AppSettings
    func saveSettings(_ settings: AppSettings)
    func searchItems(query: String) -> [ClipboardItem]
}
```

### 3. 剪切板监听（`services/`）

```swift
// ClipboardMonitor.swift - AppKit 剪切板监听
class ClipboardMonitor {
    func startMonitoring()
    func stopMonitoring()
    var onNewContent: ((String) -> Void)?
}
```

### 4. 快捷键管理（`services/`）

```swift
// HotkeyManager.swift - Carbon 快捷键
class HotkeyManager {
    func registerHotkey(modifiers: Int, keyCode: UInt32, action: @escaping () -> Void)
    func unregisterHotkey()
}
```

### 5. UI 层（`views/`）

```swift
// ClipboardListView.swift - 历史列表 + 搜索
// ClipboardItemRow.swift - 单行显示
// SettingsView.swift - 设置页面
```

### 6. 应用入口

```swift
@main
struct Ditto4MacApp: App {
    var body: some Scene {
        MenuBarExtra("Ditto4Mac", systemImage: "doc.on.clipboard") {
            ClipboardListView()
        }
        .menuBarExtraStyle(.window)
    }
}
```

## 运行与调试

1. **构建并运行**: `Cmd+R` 或在菜单栏选择 **Product → Run**
2. 应用启动后出现在系统菜单栏（顶部右侧），显示剪贴板图标
3. **测试剪切板捕获**: 复制任意文本，等待 0.5 秒后在菜单栏点击图标查看记录
4. **测试快捷键**: 按下 `Cmd+Shift+V` 应弹出历史记录窗口
5. **调试**: 由于应用无 Dock 图标，可在 Xcode 中直接调试

## 开发目录结构

```
Ditto4Mac/
├── Ditto4MacApp.swift           # @main 入口
├── Models/
│   ├── ClipboardItem.swift      # 数据模型
│   └── AppSettings.swift        # 设置模型
├── Services/
│   ├── ClipboardMonitor.swift   # 剪切板轮询监听
│   ├── HotkeyManager.swift      # 全局快捷键
│   └── StorageService.swift     # 文件存储
├── Views/
│   ├── ClipboardListView.swift  # 主列表 + 搜索
│   ├── ClipboardItemRow.swift   # 列表行视图
│   └── SettingsView.swift       # 设置页
└── Resources/
    └── Assets.xcassets            # 图标资源
```

## 测试

### 运行单元测试

```
Xcode: Cmd+U 或 Product → Test
```

### 测试要点

1. 剪切板监听：复制文本，验证新记录出现在历史中
2. 快捷键注册：按下 Cmd+Shift+V，验证窗口弹出
3. 文件持久化：重启应用，验证历史记录保留
4. 搜索：输入关键词，验证过滤正确
5. 固定/取消固定：操作后验证排序正确
6. 边界：复制超过 maxCharsPerItem 的文本，验证被忽略
