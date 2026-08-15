import Foundation

/// JSON 索引文件结构
struct IndexData: Codable {
    var version: Int
    var items: [ClipboardItem]
}

/// 文件存储服务
class StorageService {
    private var storageURL: URL
    private var indexURL: URL
    private var settingsURL: URL
    private var itemsDirURL: URL

    /// 当前内存中的索引缓存
    private var index: IndexData

    /// 当前设置缓存
    private var settings: AppSettings

    /// 文本内容缓存，避免搜索/列表时频繁读取磁盘
    private let textCache = NSCache<NSString, NSString>()

    init(storagePath: String? = nil) {
        let path = storagePath ?? AppSettings().storagePath
        storageURL = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        indexURL = storageURL.appendingPathComponent("index.json")
        settingsURL = storageURL.appendingPathComponent("settings.json")
        itemsDirURL = storageURL.appendingPathComponent("items")

        // 确保目录存在
        try? FileManager.default.createDirectory(at: itemsDirURL, withIntermediateDirectories: true)

        // 初始化默认值
        settings = AppSettings()
        index = IndexData(version: 1, items: [])

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // 加载或初始化设置；若文件损坏则先备份再重建
        if let data = try? Data(contentsOf: settingsURL) {
            if let decoded = try? decoder.decode(AppSettings.self, from: data) {
                settings = decoded
            } else {
                backupCorruptedFile(at: settingsURL)
                saveSettingsInternal()
            }
        } else {
            saveSettingsInternal()
        }

        // 加载或初始化索引；若文件损坏则先备份再重建
        if let data = try? Data(contentsOf: indexURL) {
            if let decoded = try? decoder.decode(IndexData.self, from: data) {
                index = decoded
            } else {
                backupCorruptedFile(at: indexURL)
                saveIndex()
            }
        } else {
            saveIndex()
        }
    }

    private func backupCorruptedFile(at url: URL) {
        let backupURL = url.appendingPathExtension("bak")
        try? FileManager.default.removeItem(at: backupURL)
        try? FileManager.default.copyItem(at: url, to: backupURL)
    }

    // MARK: - 读取

    func loadItems() -> [ClipboardItem] {
        index.items.sorted { item1, item2 in
            if item1.isPinned != item2.isPinned {
                return item1.isPinned
            }
            if item1.isPinned, let d1 = item1.pinnedAt, let d2 = item2.pinnedAt {
                return d1 > d2
            }
            return item1.createdAt > item2.createdAt
        }
    }

    func loadText(for item: ClipboardItem) -> String? {
        let key = item.id as NSString
        if let cached = textCache.object(forKey: key) {
            return cached as String
        }

        let fileURL = itemsDirURL.appendingPathComponent(item.textFilename)
        guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return nil
        }
        textCache.setObject(text as NSString, forKey: key)
        return text
    }

    func loadSettings() -> AppSettings {
        settings
    }

    // MARK: - 写入

    /// 保存新剪切板项及其文本内容
    func saveItem(_ item: ClipboardItem, text: String) {
        index.items.append(item)
        let fileURL = itemsDirURL.appendingPathComponent(item.textFilename)
        try? text.write(to: fileURL, atomically: true, encoding: .utf8)
        textCache.setObject(text as NSString, forKey: item.id as NSString)
        saveIndex()
        enforceMaxItems()
    }

    /// 更新已有项（如固定状态变更）
    func updateItem(_ item: ClipboardItem) {
        if let idx = index.items.firstIndex(where: { $0.id == item.id }) {
            index.items[idx] = item
            saveIndex()
        }
    }

    /// 删除项及其文本文件
    func deleteItem(_ id: String) {
        let fileURL = itemsDirURL.appendingPathComponent("\(id).txt")
        try? FileManager.default.removeItem(at: fileURL)
        textCache.removeObject(forKey: id as NSString)
        index.items.removeAll { $0.id == id }
        saveIndex()
    }

    func saveSettings(_ settings: AppSettings) {
        self.settings = settings
        saveSettingsInternal()
    }

    // MARK: - 搜索

    func searchItems(query: String) -> [ClipboardItem] {
        guard !query.isEmpty else { return loadItems() }

        // 固定片段始终显示（不受搜索影响）
        let pinnedItems = index.items.filter { $0.isPinned }

        // 普通记录按搜索词过滤
        let lowerQuery = query.lowercased()
        let filteredItems = index.items.filter { !$0.isPinned }.compactMap { item -> ClipboardItem? in
            guard let text = loadText(for: item) else { return nil }
            return text.lowercased().contains(lowerQuery) ? item : nil
        }

        // 合并: 固定在前，普通在后
        let pinnedSorted = pinnedItems.sorted { i1, i2 in
            (i1.pinnedAt ?? i1.createdAt) > (i2.pinnedAt ?? i2.createdAt)
        }
        let normalSorted = filteredItems.sorted { $0.createdAt > $1.createdAt }
        return pinnedSorted + normalSorted
    }

    // MARK: - 内部方法

    private func saveIndex() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(index) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }

    private func saveSettingsInternal() {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(settings) else { return }
        try? data.write(to: settingsURL, options: .atomic)
    }

    /// 当非固定记录数超过 maxItems 时，删除最旧的非固定记录
    private func enforceMaxItems() {
        let maxItems = settings.maxItems
        let unpinned = index.items.filter { !$0.isPinned }
        if unpinned.count > maxItems {
            let sorted = unpinned.sorted { $0.createdAt < $1.createdAt }
            let toRemove = sorted.prefix(unpinned.count - maxItems)
            let removeIds = Set(toRemove.map { $0.id })
            for item in toRemove {
                let fileURL = itemsDirURL.appendingPathComponent(item.textFilename)
                try? FileManager.default.removeItem(at: fileURL)
                textCache.removeObject(forKey: item.id as NSString)
            }
            index.items.removeAll { removeIds.contains($0.id) }
            saveIndex()
        }
    }

    // MARK: - 存储路径迁移

    func migrateStorage(to newPath: String) -> Bool {
        let newURL = URL(fileURLWithPath: (newPath as NSString).expandingTildeInPath).standardizedFileURL
        let oldURL = storageURL.standardizedFileURL
        guard newURL != oldURL else {
            // 同一路径的不同写法也统一更新 settings 中的 storagePath
            if settings.storagePath != newPath {
                settings.storagePath = newPath
                saveSettingsInternal()
            }
            return true
        }

        let newIndexURL = newURL.appendingPathComponent("index.json")
        let newSettingsURL = newURL.appendingPathComponent("settings.json")
        let newItemsDirURL = newURL.appendingPathComponent("items")

        // 防止覆盖已有数据；目标路径若已存在索引或设置，拒绝迁移
        guard !FileManager.default.fileExists(atPath: newIndexURL.path),
              !FileManager.default.fileExists(atPath: newSettingsURL.path) else {
            return false
        }

        do {
            try FileManager.default.createDirectory(at: newItemsDirURL,
                                                     withIntermediateDirectories: true)

            try FileManager.default.copyItem(at: indexURL, to: newIndexURL)
            try FileManager.default.copyItem(at: settingsURL, to: newSettingsURL)

            let items = try FileManager.default.contentsOfDirectory(at: itemsDirURL,
                                                                    includingPropertiesForKeys: nil)
            for itemURL in items {
                let destination = newItemsDirURL.appendingPathComponent(itemURL.lastPathComponent)
                if !FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.copyItem(at: itemURL, to: destination)
                }
            }

            // 更新内部 URL 后再更新 settings 中的 storagePath
            storageURL = newURL
            indexURL = newIndexURL
            settingsURL = newSettingsURL
            itemsDirURL = newItemsDirURL

            settings.storagePath = newPath
            saveSettingsInternal()

            // 仅在新旧目录互不为祖先关系时清理旧目录，避免误删迁移目标
            let oldPath = oldURL.path
            let newPathStandard = newURL.path
            let isNewInsideOld = newPathStandard.hasPrefix(oldPath + "/")
            let isOldInsideNew = oldPath.hasPrefix(newPathStandard + "/")
            if !isNewInsideOld && !isOldInsideNew {
                try? FileManager.default.removeItem(at: oldURL)
            }

            return true
        } catch {
            return false
        }
    }
}
