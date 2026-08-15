# AGENTS.md

## Build & Run

- **Swift 5.9+ required** — `swift build` works with CommandLineTools (tested with 6.1.2).
- Open `Package.swift` in Xcode as fallback.
- macOS 13 (Ventura)+ deployment target.
- Zero third-party dependencies.

```bash
swift build                    # debug
swift build -c release         # release
bash scripts/build_app.sh      # package as .app (debug)
bash scripts/build_app.sh release  # package as .app (release)
```

## Architecture

```
Ditto4Mac/
├── Ditto4MacApp.swift    # @main + AppDelegate (NSStatusBar, NSPanel, NSMenu)
├── Models/               # ClipboardItem, AppSettings
├── Services/             # ClipboardMonitor, HotkeyManager, StorageService
├── ViewModels/           # ClipboardViewModel (@MainActor, ObservableObject)
└── Views/                # ClipboardListView, ClipboardItemRow, SettingsView, AboutView
```

**Root `Package.swift`** is the build entry (targets `Ditto4Mac/`, excludes `.idea/`).

App uses **NSStatusBar + NSPanel** (not SwiftUI MenuBarExtra) for full control over left-click (popup) / right-click (menu).

## Key Behaviors

- **User data** → `~/.ditto4mac/` — `index.json` + `settings.json` (ISO 8601 dates) + `items/<id>.txt`.
- **Hotkey** → Carbon `RegisterEventHotKey` (signature `0x44344D48`). Default: Cmd+Shift+V.
- **Clipboard polling** → `NSPasteboard.general.changeCount` at 0.5s, self-writes skipped.
- **Auto-hide** → global mouse event monitor + workspace activation notification.
- **Panel** → centered floating `NSPanel` (`.nonactivatingPanel`), closes on outside click.
- **Data persistence** → `JSONEncoder/Decoder` with `.iso8601` date strategy (encoder AND decoder must match).
- All ViewModels, AppDelegate are `@MainActor`.

## Conventions

- Speckit workflow: `specs/<NNN-feature-name>/` with `spec.md`, `plan.md`, `tasks.md`.
- Feature branches, conventional commits.

## Known Issues

- CommandLineTools 环境没有 XCTest，因此不提供 SPM test target；运行 `bash scripts/run_tests.sh` 执行独立测试。
- Notification uses `ditto4macHotkeyTriggered` custom name — imported in `Ditto4MacApp.swift`.
- `AppDelegate.viewModel` is `let` (initialized eagerly) to avoid nil-crash in Settings scene.
