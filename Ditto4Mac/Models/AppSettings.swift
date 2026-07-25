import Foundation

/// 用户配置，存储在 settings.json 中
struct AppSettings: Codable {
    /// Carbon 修饰键标志位 (默认 Cmd+Shift = 256 + 512 = 768)
    var hotkeyModifiers: Int
    
    /// 虚拟键码 (默认 V = 9)
    var hotkeyKeyCode: UInt32
    
    /// 最大历史记录条数（不含固定片段），默认 100
    var maxItems: Int
    
    /// 单条记录最大字符数，默认 10000
    var maxCharsPerItem: Int
    
    /// 弹出窗口默认显示条数，默认 10
    var displayCount: Int
    
    /// 数据存储路径，默认 ~/.ditto4mac
    var storagePath: String
    
    /// 剪切板轮询间隔（秒），默认 0.5
    var pollingInterval: Double
    
    /// 是否开机自启，默认 false
    var launchAtLogin: Bool

    init(
        hotkeyModifiers: Int = 768,    // Cmd+Shift
        hotkeyKeyCode: UInt32 = 9,     // V key
        maxItems: Int = 100,
        maxCharsPerItem: Int = 10000,
        displayCount: Int = 10,
        storagePath: String = "~/.ditto4mac",
        pollingInterval: Double = 0.5,
        launchAtLogin: Bool = false
    ) {
        self.hotkeyModifiers = hotkeyModifiers
        self.hotkeyKeyCode = hotkeyKeyCode
        self.maxItems = maxItems
        self.maxCharsPerItem = maxCharsPerItem
        self.displayCount = displayCount
        self.storagePath = storagePath
        self.pollingInterval = pollingInterval
        self.launchAtLogin = launchAtLogin
    }
}
