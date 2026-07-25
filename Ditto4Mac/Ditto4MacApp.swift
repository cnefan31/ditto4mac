import SwiftUI
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var clipboardPanel: NSPanel?
    private var settingsWindow: NSWindow?
    private var aboutWindow: NSWindow?
    private var eventMonitor: Any?
    let viewModel = ClipboardViewModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "list.clipboard",
                accessibilityDescription: "Ditto4Mac"
            )
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.action = #selector(statusBarButtonClicked(_:))
            button.target = self
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(toggleClipboardPanel),
            name: .ditto4macHotkeyTriggered,
            object: nil
        )

        // 全局鼠标监听：点击面板外部时自动隐藏
        eventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            guard let self, let panel = self.clipboardPanel, panel.isVisible else { return }
            // 使用 panel.frame（屏幕坐标）判断点击是否在面板外部，包含标题栏
            if !panel.frame.contains(event.locationInWindow) {
                DispatchQueue.main.async { panel.orderOut(nil) }
            }
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(autoHidePanel),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    @objc private func autoHidePanel() {
        guard let panel = clipboardPanel, panel.isVisible else { return }
        panel.orderOut(nil)
    }

    // MARK: - 菜单栏

    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            toggleClipboardPanel()
        }
    }

    // MARK: - 剪贴板面板（居中）

    @objc private func toggleClipboardPanel() {
        if let panel = clipboardPanel, panel.isVisible {
            panel.orderOut(nil)
            return
        }

        if clipboardPanel == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 380, height: 440),
                styleMask: [.titled, .closable, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.title = "Ditto4Mac"
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle]
            panel.isReleasedWhenClosed = false
            panel.contentViewController = NSHostingController(
                rootView: ClipboardListView(viewModel: viewModel, onClose: { [weak self] in
                    self?.clipboardPanel?.orderOut(nil)
                })
            )
            clipboardPanel = panel
        }

        clipboardPanel?.center()
        clipboardPanel?.makeKeyAndOrderFront(nil)
    }

    // MARK: - 右键菜单

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(
            title: "关于 Ditto4Mac",
            action: #selector(openAbout),
            keyEquivalent: ""
        ))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "快捷键设置…",
            action: #selector(openSettings),
            keyEquivalent: ","
        ))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "退出 Ditto4Mac",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    // MARK: - 设置窗口

    @objc private func openSettings() {
        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 440),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Ditto4Mac 设置"
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(
            rootView: SettingsView(viewModel: viewModel)
        )
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }

    // MARK: - 关于窗口

    @objc private func openAbout() {
        if let window = aboutWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 280),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "关于 Ditto4Mac"
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: AboutView())
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        aboutWindow = window
    }
}

extension Notification.Name {
    static let ditto4macHotkeyTriggered = Notification.Name("ditto4macHotkeyTriggered")
}

@main
struct Ditto4MacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
