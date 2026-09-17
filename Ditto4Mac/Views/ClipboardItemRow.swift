import SwiftUI

/// 单行剪切板记录视图
struct ClipboardItemRow: View {
    let item: ClipboardItem
    let text: String
    let isPinned: Bool
    let searchText: String
    let relativeTime: String
    let isEven: Bool

    let onTap: () -> Void
    let onPin: () -> Void
    let onUnpin: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                if isPinned {
                    Image(systemName: "pin.fill")
                        .foregroundStyle(.blue)
                        .font(.system(size: 11))
                        .frame(width: 14)
                }

                VStack(alignment: .leading, spacing: 1) {
                    if searchText.isEmpty {
                        Text(truncatedText)
                            .font(.system(size: 15, design: .monospaced))
                            .lineLimit(1)
                    } else {
                        highlightedText
                            .font(.system(size: 15, design: .monospaced))
                            .lineLimit(1)
                    }

                    Text(relativeTime)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .background(isEven ? Color.clear : Color(nsColor: .quaternaryLabelColor).opacity(0.3))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            if isPinned {
                Button("取消固定") { onUnpin() }
            } else {
                Button("固定片段") { onPin() }
            }
            Divider()
            Button("删除") { onDelete() }
        }
    }
    
    private var truncatedText: String {
        let maxChars = 120
        if text.count > maxChars {
            return String(text.prefix(maxChars)) + "…"
        }
        return text
    }
    
    @ViewBuilder
    private var highlightedText: some View {
        let lowerText = text.lowercased()
        let lowerSearch = searchText.lowercased()
        if let range = lowerText.range(of: lowerSearch) {
            let startIndex = text.distance(from: text.startIndex, to: range.lowerBound)
            let endIndex = text.distance(from: text.startIndex, to: range.upperBound)
            
            let before = text.prefix(startIndex)
            let match = text[text.index(text.startIndex, offsetBy: startIndex)..<text.index(text.startIndex, offsetBy: endIndex)]
            let after = text[text.index(text.startIndex, offsetBy: endIndex)...]
            
            Text(before) +
            Text(match).fontWeight(.bold).foregroundColor(.blue) +
            Text(after)
        } else {
            Text(truncatedText)
        }
    }
}
