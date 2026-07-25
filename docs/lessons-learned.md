# Ditto4Mac 开发经验总结

本文档记录从零构建一个 macOS 菜单栏剪切板管理器过程中遇到的典型问题和解决方案，供后续项目参考。

## 一、Swift 工具链与编译

### 1.1 CommandLineTools 的 PackageDescription 问题

**现象**：`swift build` 报错 `Undefined symbols: Package.__allocating_init`。

**原因**：系统只安装了 CommandLineTools（无 Xcode），其 `libPackageDescription.dylib` 不完整，缺少 `Package.init` 等符号。

**解决**：重装 CommandLineTools 解决 SDK/编译器版本不匹配问题（`6.0.3.1.5` vs `6.0.3.1.10`）。`sudo rm -rf /Library/Developer/CommandLineTools && xcode-select --install`。

**教训**：优先用 `xcrun swift build` 验证工具链一致性；只装 CommandLineTools 可能出现兼容性问题。

---

### 1.2 内层 Package.swift 污染编译

**现象**：`Ditto4Mac/Package.swift` 被 SPM 当作源码编译，`import PackageDescription` 报错 `no such module`。

**原因**：根 `Package.swift` 的 `path: "Ditto4Mac"` 会递归包含所有 `.swift` 文件。

**解决**：在根 `Package.swift` 中 `exclude: ["Package.swift", "Sources", ".idea"]`。

**教训**：SPM 的 `path` 参数会递归扫描目录；多余的 `Package.swift` 必须排除或删除。

---

### 1.3 Swift 6 严格模式适配

**现象**：C 函数指针闭包报错 `a C function pointer cannot be formed from a closure that captures context`；实例属性访问要求显式 `self`。

**解决**：
- C 回调中引用的常量改为 `static let`（静态成员不捕获上下文）
- 闭包参数用 `[weak self]` 并显式 `self.` 访问

**教训**：Swift 6 对 C 互操作的约束更严格，涉及 `EventHandlerUPP` 等 Carbon API 时需特别处理。

---

## 二、macOS API 版本兼容

### 2.1 SwiftUI View Modifier 版本

| API | 最低版本 | 替代方案 |
|-----|---------|---------|
| `.foregroundStyle()` | macOS 14 | `.foregroundColor()` |
| `.onChange(of:initial:_:)` | macOS 14 | `.onChange(of:perform:)` |
| `MenuBarExtra(.window)` | macOS 13 ✓ | — |

**教训**：target macOS 13 时，优先使用旧版 API；用 `@available` 或直接替换确保兼容。

---

### 2.2 字典键重复

**现象**：`SettingsView` 中碳键码字典 `[UInt32: String]` 有重复键（`8: "C"` 和 `8: "K"`）。

**原因**：键码硬编码错误（`kVK_ANSI_K = 40`，不是 8）。

**教训**：手工构建大型字典时用 `static let` 常量名代替裸值，避免无意重复。

---

## 三、菜单栏应用架构

### 3.1 MenuBarExtra 的局限性

`MenuBarExtra(.window)` 的限制：
- **不支持右键菜单**：只能左键弹出窗口
- **窗口位置固定在菜单栏下方**：无法居中显示
- **`NSPopover` 内手势不可靠**：`onTapGesture(count: 2)` 不触发

**解决**：放弃 `MenuBarExtra`，使用原生 `NSStatusBar + NSStatusItem`：
- `button.sendAction(on: [.leftMouseUp, .rightMouseUp])` 区分左/右键
- 左键 → `NSPanel`（居中浮动面板）
- 右键 → `NSMenu`（设置 / 关于 / 退出）

---

### 3.2 NSPanel 风格选择

| 风格 | 效果 |
|------|------|
| `.nonactivatingPanel` | 不激活 App、不抢焦点，但无法成为 key window |
| `.utilityWindow` | 小标题栏，但在 `LSUIElement` 应用中**不显示** |
| 无特殊标志 | 会激活 App、显示 Dock 图标（与 `LSUIElement` 冲突） |

**最终选择**：`.nonactivatingPanel` + `.titled` + `.closable`。面板始终浮动在最前，不干扰当前应用。

---

### 3.3 面板自动隐藏

**演变过程**：

1. `windowDidResignKey` → **失败**：`.nonactivatingPanel` 从不会成为 key
2. `NSWorkspace.didActivateApplicationNotification` + bundleID 比较 → **失败**：比较了错误的类型（`NSApp` vs `NSRunningApplication`），且切换**已激活应用**时不会触发通知
3. **最终方案**：双保险
   - `NSEvent.addGlobalMonitorForEvents` → 监听全局鼠标点击，判断是否在面板外（需辅助功能权限）
   - `NSWorkspace.didActivateApplicationNotification` → 不检查 bundle ID，收到即隐藏（因为 `.nonactivatingPanel` 永远不会激活本 App）

**教训**：必须理解 `LSUIElement` + `.nonactivatingPanel` 组合下 App 的激活行为——App 永不在前台，任何激活通知都意味着用户去了别处。

---

### 3.4 热键弹窗居中 vs 图标弹窗

**需求**：菜单栏图标点击 → 面板靠近图标；热键触发 → 面板屏幕居中。

**最终简化**：统一使用居中 `NSPanel`，热键和图标点击走同一个面板切换逻辑，`panel.center()` 确保位置一致。

---

## 四、数据持久化

### 4.1 临时文件未重命名

**现象**：`saveIndex()` 写入 `index.json.tmp`，但从未 rename 到 `index.json`，数据全丢了。

**解决**：直接用 `data.write(to: indexURL, options: .atomic)`。`.atomic` 内部自动写临时文件并原子 rename。

**教训**：Code review 时重点检查文件 I/O 的完整路径——临时文件必须有对应的 rename/替换逻辑。

---

### 4.2 编解码日期策略不一致（关键 Bug）

**现象**：程序每次启动历史记录都为空，`index.json` 被覆盖为 `{"items":[]}`。

**原因**：
- 保存：`JSONEncoder.dateEncodingStrategy = .iso8601` → `"2026-07-25T01:09:14Z"`
- 加载：`JSONDecoder()` 默认策略 → 期望 Unix 时间戳 → **解码失败** → 走 else 分支 → 创建空索引并保存 → 覆盖原有数据

**解决**：加载时也设置 `decoder.dateDecodingStrategy = .iso8601`。

**教训**：
> **编解码策略必须成对配置。** 只配 encoder 不配 decoder 是经典的静默数据丢失模式。建议封装 `makeEncoder/makeDecoder` 工厂方法或使用测试用例覆盖序列化往返。

---

## 五、SwiftUI 与 AppKit 混用

### 5.1 SwiftUI App 生命周期与 AppDelegate 的时序

**现象**：`SettingsView(viewModel: (NSApp.delegate as! AppDelegate).viewModel)` 崩溃，`viewModel` 为 nil。

**原因**：SwiftUI `App.body` 的求值可能早于 `applicationDidFinishLaunching` 回调。

**解决**：`viewModel` 用 `let` 在属性声明时内联初始化，不从 `applicationDidFinishLaunching` 延迟赋值。

**教训**：SwiftUI `@NSApplicationDelegateAdaptor` 不保证回调时序。依赖 `AppDelegate` 提供的数据应使用 `let`（常量属性）而非 `var` + 延迟赋值。

---

### 5.2 @MainActor 隔离

**现象**：`let viewModel = ClipboardViewModel()` 在 `AppDelegate`（非 MainActor）中报错 `call to main actor-isolated initializer in a synchronous nonisolated context`。

**解决**：给 `AppDelegate` 加 `@MainActor`。所有 `NSApplicationDelegate` 方法实际都在主线程执行。

---

### 5.3 Popover 内手势与 Button

**现象**：`NSPopover` 内 `onTapGesture(count: 2)` 双击不触发。

**解决**：改用 `Button(action:)` 包裹行内容 + `.buttonStyle(.plain)`。Button 的点击在任何上下文中都可靠。

---

## 六、UI 细节

### 6.1 SearchBar 过度留白

**现象**：搜索框高度远大于字体高度，视觉不协调。

**优化过程**：
1. `.padding(6)` → `.padding(.vertical, 2)`
2. `.font(.callout)` → `.font(.system(size: 12))`
3. 去掉多余元素（`+`按钮、竖线 `Divider`）
4. HStack 间距 `8` → `4`

**最终高度**：26px（含 padding + 字体行高 + 分割线）。

### 6.2 斑马纹

`background(isEven ? Color.clear : Color(nsColor: .quaternaryLabelColor).opacity(0.3))`，用 `ForEach(Array(items.enumerated()), id: \.element.id)` 获取 index。

---

## 七、发布打包

### 7.1 .app Bundle 构建

关键组件：
```
Ditto4Mac.app/Contents/
├── MacOS/Ditto4Mac         # 可执行文件
├── Resources/AppIcon.icns  # 应用图标
└── Info.plist              # LSUIElement=true, LSMinimumSystemVersion=13.0
```

### 7.2 app 图标生成

Python + Pillow 绘制剪贴板图标（512x512 PNG），`iconutil -c icns` 转换为 `.icns`。

```bash
python3 scripts/generate_icon.py
iconutil -c icns scripts/icon.iconset -o scripts/AppIcon.icns
bash scripts/build_app.sh release
```

---

## 八、经验清单

- [ ] JSON 编解码的 `dateEncodingStrategy` / `dateDecodingStrategy` 必须成对配置
- [ ] Swift 6 中 C 函数指针不能捕获任何上下文，用 `static let` 替代
- [ ] `LSUIElement` + `.nonactivatingPanel` 组合：App 永不激活，面板永不在前
- [ ] SwiftUI `App.body` 可能在 `applicationDidFinishLaunching` 之前求值
- [ ] `NSPopover` 内避免依赖手势识别器，用 `Button` 替代
- [ ] SPM `path` 参数递归扫描，多余的 `.swift` 文件必须 exclude
- [ ] CommandLineTools 版本不匹配时，删掉重装比排查更快
- [ ] 文件 I/O 操作避免手写 temp→rename 模式，用 `.atomic` 选项
