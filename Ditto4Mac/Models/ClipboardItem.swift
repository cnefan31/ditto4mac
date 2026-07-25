import Foundation

/// 代表一次纯文本复制操作的记录
struct ClipboardItem: Identifiable, Codable, Equatable {
    let id: String
    var createdAt: Date
    var isPinned: Bool
    var pinnedAt: Date?

    init(id: String = Self.generateId(), createdAt: Date = Date(), isPinned: Bool = false, pinnedAt: Date? = nil) {
        self.id = id
        self.createdAt = createdAt
        self.isPinned = isPinned
        self.pinnedAt = pinnedAt
    }

    /// 生成唯一 ID: <timestamp>-<random 6 chars>
    private static func generateId() -> String {
        let timestamp = String(Int(Date().timeIntervalSince1970))
        let chars = "abcdefghijklmnopqrstuvwxyz0123456789"
        let random = String((0..<6).map { _ in chars.randomElement()! })
        return "\(timestamp)-\(random)"
    }

    /// 文本文件路径相对名
    var textFilename: String {
        "\(id).txt"
    }
}
