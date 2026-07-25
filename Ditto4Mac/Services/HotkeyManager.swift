import Carbon
import AppKit

/// 通过 Carbon RegisterEventHotKey API 注册全局快捷键
@MainActor
final class HotkeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private static var currentCallback: (() -> Void)?

    /// 快捷键触发时回调
    var onHotkeyTriggered: (() -> Void)?

    /// 注册全局快捷键
    /// - Parameters:
    ///   - modifiers: Carbon 修饰键标志位 (如 cmdKey|shiftKey = 768)
    ///   - keyCode: 虚拟键码 (如 kVK_ANSI_V = 9)
    func registerHotkey(modifiers: Int, keyCode: UInt32) {
        unregisterHotkey()

        // 将回调存储在静态变量中，避免通过 userData 传递栈上指针
        HotkeyManager.currentCallback = { [weak self] in
            Task { @MainActor in
                self?.onHotkeyTriggered?()
            }
        }

        let hotKeyID = EventHotKeyID(
            signature: Self.hotKeySignature,
            id: Self.hotKeyUniqueID
        )
        let status = RegisterEventHotKey(
            keyCode,
            UInt32(modifiers),
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )

        guard status == noErr else {
            print("[HotkeyManager] Failed to register hotkey: \(status)")
            return
        }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        // 使用静态 C 函数，避免 closure 生命周期和 userData 指针失效问题
        let handlerUPP: EventHandlerUPP = { _, event, _ in
            guard let event = event else { return OSStatus(eventNotHandledErr) }
            var hotKeyID = EventHotKeyID()
            let getErr = GetEventParameter(
                event,
                UInt32(kEventParamDirectObject),
                UInt32(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            guard getErr == noErr else { return OSStatus(eventNotHandledErr) }
            guard hotKeyID.signature == HotkeyManager.hotKeySignature,
                  hotKeyID.id == HotkeyManager.hotKeyUniqueID else {
                return OSStatus(eventNotHandledErr)
            }

            HotkeyManager.currentCallback?()
            return noErr
        }

        InstallEventHandler(
            GetEventDispatcherTarget(),
            handlerUPP,
            1,
            &eventType,
            nil,
            nil
        )
    }

    /// 注销全局快捷键
    func unregisterHotkey() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        HotkeyManager.currentCallback = nil
    }

    // MARK: - Private

    private static let hotKeySignature: FourCharCode = 0x44344D48 // "D4MH"
    private static let hotKeyUniqueID: UInt32 = 1
}
