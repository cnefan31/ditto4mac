import SwiftUI
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
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
            // NSEvent.mouseLocation 明确是屏幕坐标，panel.frame 也使用屏幕坐标。
            // frame 包含标题栏，因此拖动或点击标题栏不会触发隐藏。
            if !panel.frame.contains(NSEvent.mouseLocation) {
                DispatchQueue.main.async { panel.orderOut(nil) }
            }
        }

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
            panel.isMovableByWindowBackground = true
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
        let window: NSWindow
        if let existing = settingsWindow {
            window = existing
        } else {
            let newWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 440),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            newWindow.title = "Ditto4Mac 设置"
            newWindow.isReleasedWhenClosed = false
            newWindow.delegate = self
            newWindow.contentViewController = NSHostingController(
                rootView: SettingsView(viewModel: viewModel)
            )
            settingsWindow = newWindow
            window = newWindow
        }

        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - 关于窗口

    @objc private func openAbout() {
        let window: NSWindow
        if let existing = aboutWindow {
            window = existing
        } else {
            let newWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 360, height: 280),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            newWindow.title = "关于 Ditto4Mac"
            newWindow.isReleasedWhenClosed = false
            newWindow.delegate = self
            newWindow.contentViewController = NSHostingController(rootView: AboutView())
            aboutWindow = newWindow
            window = newWindow
        }

        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        // 设置/关于窗口全部关闭后，恢复菜单栏应用的 accessory 模式，避免残留 Dock 图标
        if settingsWindow?.isVisible != true && aboutWindow?.isVisible != true {
            NSApp.setActivationPolicy(.accessory)
        }
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
