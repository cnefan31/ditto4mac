import SwiftUI
import AppKit

/// 设置窗口
struct SettingsView: View {
    @ObservedObject var viewModel: ClipboardViewModel
    @State private var settings: AppSettings
    
    init(viewModel: ClipboardViewModel) {
        self.viewModel = viewModel
        self._settings = State(initialValue: viewModel.getSettings())
    }
    
    var body: some View {
        Form {
            Section("快捷键") {
                HStack {
                    Text("弹出历史记录")
                    Spacer()
                    Text(formatHotkey(settings.hotkeyModifiers, settings.hotkeyKeyCode))
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                
                LabeledContent("修饰键") {
                    Picker("", selection: $settings.hotkeyModifiers) {
                        Text("⌘ Command").tag(256)
                        Text("⌥ Option").tag(512)
                        Text("⇧ Shift").tag(131072)
                        Text("⌃ Control").tag(65536)
                        Text("⌘⇧ Cmd+Shift").tag(768)
                        Text("⌘⌥ Cmd+Option").tag(768)
                    }
                    .onChange(of: settings.hotkeyModifiers, perform: { _ in saveAndRestartHotkey() })
                }
                
                LabeledContent("键码 (V=9, C=8, Space=49)") {
                    TextField("", value: $settings.hotkeyKeyCode, formatter: NumberFormatter())
                        .frame(width: 80)
                        .onChange(of: settings.hotkeyKeyCode, perform: { _ in saveAndRestartHotkey() })
                }
            }
            
            Section("存储") {
                LabeledContent("存储路径") {
                    HStack {
                        TextField("", text: $settings.storagePath)
                            .onChange(of: settings.storagePath, perform: { _ in
                                viewModel.updateSettings(settings)
                            })
                        Button("默认") {
                            settings.storagePath = "~/.ditto4mac"
                            viewModel.updateSettings(settings)
                        }
                    }
                }
                
                LabeledContent("最大存储条数") {
                    Stepper("\(settings.maxItems)", value: $settings.maxItems, in: 10...10000)
                        .onChange(of: settings.maxItems, perform: { _ in viewModel.updateSettings(settings) })
                }
                
                LabeledContent("单条最大字符数") {
                    Stepper("\(settings.maxCharsPerItem)", value: $settings.maxCharsPerItem, in: 100...1000000)
                        .onChange(of: settings.maxCharsPerItem, perform: { _ in viewModel.updateSettings(settings) })
                }
                
                LabeledContent("默认显示条数") {
                    Stepper("\(settings.displayCount)", value: $settings.displayCount, in: 1...settings.maxItems)
                        .onChange(of: settings.displayCount, perform: { _ in viewModel.updateSettings(settings) })
                }
            }
            
            Section("启动") {
                LabeledContent("开机自启") {
                    Toggle("", isOn: $settings.launchAtLogin)
                        .onChange(of: settings.launchAtLogin, perform: { _ in
                            viewModel.updateSettings(settings)
                            setLaunchAtLogin(settings.launchAtLogin)
                        })
                }
            }
        }
        .padding()
        .frame(width: 400)
    }
    
    private func saveAndRestartHotkey() {
        viewModel.updateSettings(settings)
    }
    
    private func formatHotkey(_ modifiers: Int, _ keyCode: UInt32) -> String {
        let keyNames: [UInt32: String] = [
            8: "C", 9: "V", 49: "Space", 0: "A", 1: "S", 2: "D", 3: "F",
            5: "G", 6: "H", 7: "J", 40: "K", 37: "L", 11: "P", 13: "N",
            15: "R", 36: "Enter"
        ]
        let keyName = keyNames[keyCode] ?? String(format: "0x%02X", keyCode)
        return "\(keyName)"
    }
    
    private func setLaunchAtLogin(_ enabled: Bool) {
        // 简化的开机自启实现
        let path = Bundle.main.bundlePath
        let plistPath = "/Library/LaunchAgents/com.ditto4mac.plist"
        if enabled {
            let plist = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
                <key>Label</key>
                <string>com.ditto4mac</string>
                <key>Program</key>
                <string>\(path)/Contents/MacOS/Ditto4Mac</string>
                <key>RunAtLoad</key>
                <true/>
            </dict>
            </plist>
            """
            try? plist.write(to: URL(fileURLWithPath: plistPath), atomically: true, encoding: .utf8)
        } else {
            try? FileManager.default.removeItem(atPath: plistPath)
        }
    }
}
