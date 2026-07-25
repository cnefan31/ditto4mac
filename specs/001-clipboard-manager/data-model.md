# 数据模型: macOS 剪切板管理器

## 实体定义

### ClipboardItem

表示一条剪切板记录，包含纯文本内容及其元数据。

**存储方式**:
- 文本内容：`{storagePath}/items/<id>.txt`
- 元数据：统一存储在 `{storagePath}/index.json`

**字段**:

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | `String` (UUID) | 唯一标识符，格式：`<timestamp>-<random 6 chars>`，例如 `1712345678-a3f2c1` |
| `text` | `String` | 纯文本内容（从 txt 文件读取），受 `maxCharsPerItem` 限制 |
| `createdAt` | `Date` | 捕获时间戳，用于排序和显示 |
| `isPinned` | `Bool` | 是否为固定片段，默认为 `false` |
| `pinnedAt` | `Date?` | 固定时间，用于在固定片段内排序（可选） |

**验证规则**:
- `text` 长度 ≤ `maxCharsPerItem`（默认 10,000），超过则不记录
- `text` 必须为非空纯文本（UTF-8）
- `id` 全局唯一

**状态转换**:
```
[新捕获] → isPinned=false → 普通历史
                              ↓ (用户固定操作)
                           isPinned=true → 固定片段
                              ↓ (用户取消固定)
                           isPinned=false → 普通历史
                              ↓ (用户删除 或 超出 maxItems 且非固定)
                           [已删除/清除]
```

### Settings

表示用户配置，存储在 `{storagePath}/settings.json`。

**字段**:

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `hotkeyModifiers` | `Int` | 13 (Cmd+Shift) | Carbon 修饰键标志位 |
| `hotkeyKeyCode` | `UInt32` | `kVK_ANSI_V` (9) | 虚拟键码 |
| `maxItems` | `Int` | 100 | 最大历史记录条数（不含固定片段） |
| `maxCharsPerItem` | `Int` | 10000 | 单条记录最大字符数 |
| `displayCount` | `Int` | 10 | 弹出窗口默认显示条数 |
| `storagePath` | `String` | `~/.ditto4mac` | 数据存储路径 |
| `pollingInterval` | `Double` | 0.5 | 剪切板轮询间隔（秒） |
| `launchAtLogin` | `Bool` | false | 是否开机自启 |

**验证规则**:
- `maxItems` ≥ 10 且 ≤ 10000
- `maxCharsPerItem` ≥ 100 且 ≤ 1000000
- `displayCount` ≥ 1 且 ≤ `maxItems`
- `pollingInterval` ≥ 0.1 且 ≤ 5.0

### Index

存储所有剪切板记录的元数据索引，文件位置 `{storagePath}/index.json`。

**结构**:
```json
{
  "version": 1,
  "items": [
    {
      "id": "1712345678-a3f2c1",
      "createdAt": "2026-04-13T10:30:00Z",
      "isPinned": false,
      "pinnedAt": null
    }
  ]
}
```

**注意**: 文本内容不存储在 index.json 中，而是存储在独立的 `{storagePath}/items/<id>.txt` 文件中。

**维护规则**:
- 新记录按时间倒序插入索引数组头部
- 超出 `maxItems` 时，从尾部移除最旧的非固定记录
- 删除记录时，同时删除 index.json 中的条目和对应的 .txt 文件

## 存储目录结构

```
~/.ditto4mac/                    # 默认存储根目录（可配置）
├── index.json                   # 元数据索引
├── settings.json                # 用户设置
└── items/                       # 文本内容目录
    ├── 1712345678-a3f2c1.txt    # 每条记录一个独立文件
    ├── 1712345680-b4e3d2.txt
    └── ...
```

## 数据流

```
[系统剪切板变化] 
    → ClipboardMonitor (AppKit, 轮询 changeCount)
    → 检测到纯文本 → ClipboardItem 创建
    → 写入 {storagePath}/items/<id>.txt
    → 更新 index.json
    → 通知 UI 刷新

[用户搜索/浏览]
    → 从 index.json 读取元数据
    → 按需加载 .txt 文件内容
    → 过滤/排序后展示

[用户点击复制]
    → NSPasteboard.setString(_:forType:)
    → 关闭窗口
```
