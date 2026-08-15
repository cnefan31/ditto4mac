import SwiftUI
import AppKit

@MainActor
final class ClipboardViewModel: ObservableObject {
    @Published var items: [ClipboardItem] = []
    @Published var searchText: String = ""
    @Published var selectedItemId: String?
    
    private let storage: StorageService
    private var monitor: ClipboardMonitor
    private let hotkey: HotkeyManager
    
    private var cachedSettings: AppSettings
    
    init(storage: StorageService? = nil) {
        self.storage = storage ?? StorageService()
        self.cachedSettings = self.storage.loadSettings()
        self.monitor = ClipboardMonitor(pollingInterval: self.cachedSettings.pollingInterval)
        self.hotkey = HotkeyManager()
        
        // 加载已有记录
        items = self.storage.loadItems()
        
        // 设置剪切板监听
        configureMonitor()
        
        // 设置快捷键回调
        hotkey.onHotkeyTriggered = { [weak self] in
            NotificationCenter.default.post(name: .ditto4macHotkeyTriggered, object: nil)
        }
        
        startMonitoring()
    }
    
    // MARK: - 公开方法
    
    /// 新复制内容处理
    func handleNewContent(_ text: String) {
        guard !text.isEmpty else { return }
        guard text.count <= cachedSettings.maxCharsPerItem else { return }
        
        // 去重: 如果最近一条记录内容完全相同，跳过
        if let last = items.first(where: { !$0.isPinned }),
           let lastText = storage.loadText(for: last),
           lastText == text {
            return
        }
        
        let item = ClipboardItem()
        storage.saveItem(item, text: text)
        items = storage.loadItems()
    }
    
    /// 将指定记录写入系统剪切板
    func selectItem(_ item: ClipboardItem) {
        guard let text = storage.loadText(for: item) else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        monitor.markOwnWrite()
        selectedItemId = item.id
    }
    
    /// 将指定记录写入系统剪切板并置顶
    func copyAndBumpToTop(_ item: ClipboardItem) {
        guard let text = storage.loadText(for: item) else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        monitor.markOwnWrite()
        selectedItemId = item.id

        var updated = item
        updated.createdAt = Date()
        storage.updateItem(updated)
        items = storage.loadItems()
    }

    /// 固定片段
    func pinItem(_ item: ClipboardItem) {
        var updated = item
        updated.isPinned = true
        updated.pinnedAt = Date()
        storage.updateItem(updated)
        items = storage.loadItems()
    }
    
    /// 取消固定
    func unpinItem(_ item: ClipboardItem) {
        var updated = item
        updated.isPinned = false
        updated.pinnedAt = nil
        storage.updateItem(updated)
        items = storage.loadItems()
    }
    
    /// 手动添加固定片段
    func addPinnedItem(text: String) {
        guard !text.isEmpty, text.count <= cachedSettings.maxCharsPerItem else { return }
        let item = ClipboardItem(isPinned: true, pinnedAt: Date())
        storage.saveItem(item, text: text)
        items = storage.loadItems()
    }
    
    /// 删除记录
    func deleteItem(_ item: ClipboardItem) {
        storage.deleteItem(item.id)
        items = storage.loadItems()
    }
    
    /// 搜索（由 View 层调用，使用 searchText）
    func filteredItems() -> [ClipboardItem] {
        if searchText.isEmpty {
            return displayItems
        }
        return storage.searchItems(query: searchText)
    }
    
    /// 获取当前设置
    func getSettings() -> AppSettings {
        cachedSettings
    }
    
    /// 加载指定项的文本内容
    func loadText(for item: ClipboardItem) -> String? {
        storage.loadText(for: item)
    }
    
    /// 更新设置；返回是否全部应用成功（存储路径迁移失败时会回滚）
    @discardableResult
    func updateSettings(_ newSettings: AppSettings) -> Bool {
        let oldSettings = cachedSettings
        cachedSettings = newSettings
        storage.saveSettings(newSettings)

        // 存储路径变化时先执行迁移；失败则回滚设置缓存和已保存的 settings
        if oldSettings.storagePath != newSettings.storagePath {
            guard storage.migrateStorage(to: newSettings.storagePath) else {
                cachedSettings = oldSettings
                storage.saveSettings(oldSettings)
                return false
            }
        }

        // 热键变化时立即重新注册
        if oldSettings.hotkeyModifiers != newSettings.hotkeyModifiers ||
           oldSettings.hotkeyKeyCode != newSettings.hotkeyKeyCode {
            hotkey.registerHotkey(
                modifiers: newSettings.hotkeyModifiers,
                keyCode: newSettings.hotkeyKeyCode
            )
        }

        // 轮询间隔变化时重建并重启 monitor
        if abs(oldSettings.pollingInterval - newSettings.pollingInterval) > 0.01 {
            monitor.stopMonitoring()
            monitor = ClipboardMonitor(pollingInterval: newSettings.pollingInterval)
            configureMonitor()
            monitor.startMonitoring()
        }

        return true
    }

    // MARK: - 私有方法

    private func configureMonitor() {
        monitor.onNewContent = { [weak self] text in
            Task { @MainActor [weak self] in
                self?.handleNewContent(text)
            }
        }
    }
    
    /// 启动监控
    func startMonitoring() {
        monitor.startMonitoring()
        let settings = storage.loadSettings()
        hotkey.registerHotkey(
            modifiers: settings.hotkeyModifiers,
            keyCode: settings.hotkeyKeyCode
        )
    }
    
    /// 停止监控
    func stopMonitoring() {
        monitor.stopMonitoring()
        hotkey.unregisterHotkey()
    }
    
    // MARK: - 计算属性
    
    /// 显示用的记录列表（前 displayCount 条）
    var displayItems: [ClipboardItem] {
        let count = cachedSettings.displayCount
        let sorted = storage.loadItems()
        return Array(sorted.prefix(count))
    }
    
    /// 总记录数（用于判断是否需要"加载更多"）
    var totalCount: Int {
        items.count
    }
}
