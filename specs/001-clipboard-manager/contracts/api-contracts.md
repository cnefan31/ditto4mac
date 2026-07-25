# 应用接口契约: macOS 剪切板管理器

## 系统剪切板接口

### 读取剪切板

- **输入**: `NSPasteboard.general`
- **检测方式**: `availableType(from: [.string]) == .string`
- **读取方式**: `string(forType: .string)`
- **输出**: `String?`（纯文本内容）
- **约束**: 仅读取 `.string` 类型，忽略富文本、图片、文件 URL 等其他类型

### 写入剪切板

- **输入**: `String`（纯文本）
- **写入方式**: `NSPasteboard.general.setString(text, forType: .string)`
- **输出**: 无返回值
- **约束**: 写入后立即调用 `changeCount` 更新，确保下次轮询不会误判为自己的写入

## 文件系统接口

### 存储路径

- **根路径**: 由 `Settings.storagePath` 定义，默认 `~/.ditto4mac`
- **权限**: 需要对当前用户主目录的读写权限
- **创建**: 首次启动时自动创建目录结构

### 文件读写契约

| 文件 | 格式 | 读/写 | 说明 |
|------|------|-------|------|
| `index.json` | JSON | 读写 | 元数据索引，启动时加载，每次变更时写入 |
| `settings.json` | JSON | 读写 | 用户设置，启动时加载，修改时写入 |
| `items/<id>.txt` | UTF-8 纯文本 | 读写 | 单条记录文本内容，创建/删除时操作 |

### 读写原子性

- `index.json` 和 `settings.json` 写入采用临时文件 + 重命名策略，避免写入中断导致数据损坏
- 单条 `.txt` 文件较小，直接写入即可

## 快捷键接口

### 注册

- **API**: Carbon `RegisterEventHotKey`
- **输入**: 
  - `keyCode`: `UInt32`（虚拟键码，如 `kVK_ANSI_V = 9`）
  - `modifiers`: `UInt32`（Carbon 修饰键标志：`cmdKey = 256`, `shiftKey = 512`）
- **触发**: 回调中执行 `showClipboardWindow()`
- **约束**: 应用需代码签名，macOS 13+ 正常工作

### 注销

- **API**: `UnregisterEventHotKey`
- **时机**: 应用退出或用户修改快捷键时

## 弹出窗口接口

### 窗口行为

| 操作 | 触发条件 | 预期行为 |
|------|---------|---------|
| 打开 | 全局快捷键 | 显示最近 N 条记录，搜索框自动聚焦 |
| 关闭 | Escape 键 / 点击窗口外 | 窗口隐藏 |
| 选择记录 | 点击/回车 | 内容写入系统剪切板，窗口关闭 |
| 搜索 | 输入文字 | 实时过滤列表 |
| 固定记录 | 右键菜单 → 固定 | 标记为 `isPinned=true` |
| 取消固定 | 右键菜单 → 取消固定 | 标记为 `isPinned=false` |
| 删除记录 | 右键菜单 → 删除 / Delete 键 | 删除元数据和文本文件 |

### 键盘导航

| 按键 | 行为 |
|------|------|
| ↑ / ↓ | 上下移动选择 |
| Enter / Return | 选择当前高亮项，复制并关闭 |
| Escape | 关闭窗口 |
| Delete / Backspace | 删除当前高亮项（需确认） |
| Cmd+F | 聚焦搜索框 |

## 数据管理接口

### 新增记录

```
输入: String (纯文本)
校验: 文本长度 ≤ maxCharsPerItem
检查: 是否与非空历史重复（去重）
存储: items/<id>.txt + index.json 更新
清理: 如果非固定记录数 > maxItems，删除最旧的
输出: ClipboardItem? (成功返回新记录，失败返回 nil)
```

### 删除记录

```
输入: ClipboardItem.id
操作: 删除 items/<id>.txt + 从 index.json 移除条目
输出: Bool (成功/失败)
```

### 搜索记录

```
输入: String (搜索关键词，不区分大小写)
过滤: items 中 text 包含关键词的记录（固定片段不受搜索影响，始终显示）
输出: [ClipboardItem] (按时间倒序)
```

### 更新设置

```
输入: Settings 部分字段
校验: 字段值在有效范围内
存储: settings.json 更新
副作用: 如果修改了存储路径，迁移现有数据
输出: Bool (成功/失败)
```
