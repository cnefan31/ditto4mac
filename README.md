# Ditto4Mac

macOS 菜单栏剪切板管理器 — 轻量、零依赖的剪贴板历史工具。

## 功能

- 自动捕获纯文本剪切板历史
- 全局快捷键呼出（默认 Cmd+Shift+V）
- 实时搜索过滤
- 单击记录 → 复制到剪切板并置顶
- 右键记录 → 固定 / 删除
- 右键菜单栏图标 → 关于 / 设置 / 退出
- 数据持久化至 `~/.ditto4mac/`，重启不丢失
- 可配置最大记录数、存储路径、字符限制

## 系统要求

- macOS 13 (Ventura)+
- Swift 5.9+ / CommandLineTools 或 Xcode

## 构建

```bash
# Debug
swift build
bash scripts/build_app.sh

# Release（发布包）
bash scripts/build_app.sh release
```

输出位置：`.build/release/Ditto4Mac.app`（576KB）

## 安装

```bash
cp -R .build/release/Ditto4Mac.app /Applications/
open /Applications/Ditto4Mac.app
```

首次运行需在 **系统设置 → 隐私与安全性 → 辅助功能** 中授权，以支持点击面板外自动隐藏。

## 项目结构

```
Ditto4Mac/
├── Ditto4MacApp.swift           # @main 入口 + AppDelegate（NSStatusBar + NSPanel）
├── Models/
│   ├── ClipboardItem.swift      # 记录数据模型（Codable）
│   └── AppSettings.swift        # 设置模型（热键、存储、条数等）
├── Services/
│   ├── ClipboardMonitor.swift   # NSPasteboard 轮询（0.5s 间隔）
│   ├── HotkeyManager.swift      # Carbon 全局热键（Cmd+Shift+V）
│   └── StorageService.swift     # JSON 索引 + 文本文件持久化
├── ViewModels/
│   └── ClipboardViewModel.swift # MVVM 状态管理（@MainActor）
├── Views/
│   ├── ClipboardListView.swift  # 主面板：搜索框 + 历史列表 + 斑马纹
│   ├── ClipboardItemRow.swift   # 单行记录（单击复制置顶）
│   ├── SettingsView.swift       # 设置窗口（热键、存储、最大条数）
│   └── AboutView.swift          # 关于窗口
├── Resources/                   # 资源文件
├── Sources/main.swift           # 未使用占位文件
└── Package.swift                # 内层清单（已废弃，参考 AGENTS.md）
```

## 数据存储

```
~/.ditto4mac/
├── index.json        # 元数据索引（ISO 8601 日期）
├── settings.json     # 用户设置
└── items/            # 每条记录独立文本
    └── <id>.txt
```

## 快捷键

| 操作 | 快捷键 |
|------|--------|
| 呼出历史 | Cmd+Shift+V（可自定义） |
| 打开设置 | 右键菜单栏图标 → 快捷键设置… |

## 许可证

MIT
