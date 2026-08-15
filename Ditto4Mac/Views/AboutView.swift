import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.clipboard")
                .font(.system(size: 48))
                .foregroundStyle(.blue)

            Text("Ditto4Mac")
                .font(.title)
                .fontWeight(.bold)

            Text("菜单栏剪切板管理器")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Label("Cmd+Shift+V 呼出剪切板历史", systemImage: "command")
                Label("单击记录 复制到剪切板并置顶", systemImage: "hand.point.up.left")
                Label("右键记录 固定 / 删除", systemImage: "contextualmenu.and.cursorarrow")
                Label("右键菜单栏图标 设置 / 退出", systemImage: "gearshape")
                Label("数据自动保存至 ~/.ditto4mac/", systemImage: "folder")
            }
            .font(.callout)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)

            Spacer()

            Text("v1.1.0 · 纯 SwiftUI 构建 · 零第三方依赖")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(24)
        .frame(width: 360, height: 280)
    }
}
