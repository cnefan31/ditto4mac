import AppKit

/// 通过轮询 NSPasteboard.changeCount 监听剪切板变化
@MainActor
final class ClipboardMonitor {
    private var timer: Timer?
    private var changeCount: Int
    private let pollingInterval: TimeInterval
    
    /// 当检测到新纯文本内容时回调
    var onNewContent: ((String) -> Void)?
    
    init(pollingInterval: TimeInterval = 0.5) {
        self.pollingInterval = pollingInterval
        self.changeCount = NSPasteboard.general.changeCount
    }
    
    func startMonitoring() {
        stopMonitoring()
        let timer = Timer(timeInterval: pollingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkForChanges()
            }
        }
        // 加入 common mode，避免菜单跟踪/窗口拖拽等场景下暂停轮询
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    /// 在检测到变化后调用，避免将自己写入的剪切板内容误判为外部复制
    func markOwnWrite() {
        changeCount = NSPasteboard.general.changeCount
    }
    
    private func checkForChanges() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != changeCount else { return }
        changeCount = pasteboard.changeCount
        
        // 只检测纯文本类型，不读取内容（避免 macOS 16+ 隐私弹窗）
        guard pasteboard.availableType(from: [.string]) == .string else { return }
        
        // 读取纯文本内容
        guard let text = pasteboard.string(forType: .string),
              !text.isEmpty else { return }
        
        onNewContent?(text)
    }
}
