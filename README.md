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
bash scripts/run_tests.sh
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

Tests/
└── Ditto4MacTests/
    └── main.swift               # 独立测试入口（不依赖 XCTest）

scripts/
└── run_tests.sh                # 编译并运行独立测试
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

## 发布（GitHub Release 直装版）

推荐使用 `scripts/release.sh` 生成已签名、已公证、已 stapling 的 DMG 和 ZIP。
用户下载 DMG 后直接拖入 Applications 即可打开，无需右键或终端命令。

### 本地发布

需要准备：

- Apple Developer Program（付费）
- Developer ID Application 证书
- App 专用密码

```bash
export DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)"
export NOTARY_APPLE_ID="you@example.com"
export NOTARY_TEAM_ID="TEAMID"
export NOTARY_PASSWORD="app-specific-password"

bash scripts/release.sh 1.2.2
```

产物：

- `.build/release/Ditto4Mac-1.2.2.dmg`
- `.build/release/Ditto4Mac-1.2.2-app.zip`

### GitHub Actions 自动发布

在仓库 Secrets 中配置：

- `MACOS_CERTIFICATE_P12`：Developer ID Application 证书 `.p12` 的 base64
- `MACOS_CERTIFICATE_PASSWORD`：`.p12` 密码
- `KEYCHAIN_PASSWORD`：CI 临时 keychain 密码（随便设置一个强密码）
- `DEVELOPER_ID_APPLICATION`：证书完整名称
- `NOTARY_APPLE_ID`：Apple ID
- `NOTARY_TEAM_ID`：Team ID
- `NOTARY_PASSWORD`：App 专用密码

然后推送 tag：

```bash
git tag v1.2.2
git push origin v1.2.2
```

工作流会自动构建、签名、公证、staple，并上传 DMG/ZIP 到 GitHub Release。
