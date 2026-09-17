import SwiftUI

/// 主弹出窗口：搜索框 + 历史列表
struct ClipboardListView: View {
    @ObservedObject var viewModel: ClipboardViewModel
    @FocusState private var searchFocused: Bool
    
    var onClose: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 0) {
            // 搜索框
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 13))
                
                TextField("搜索...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .focused($searchFocused)
                
                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 3)
            .padding(.horizontal, 5)
            .background(Color(nsColor: .textBackgroundColor))
            
            Divider()
            
            // 记录列表
            let displayItems = viewModel.filteredItems()
            
            if displayItems.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text(viewModel.searchText.isEmpty ? "暂无剪切板历史" : "无匹配结果")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(displayItems.enumerated()), id: \.element.id) { index, item in
                            let text = viewModel.loadText(for: item) ?? ""
                            ClipboardItemRow(
                                item: item,
                                text: text,
                                isPinned: item.isPinned,
                                searchText: viewModel.searchText,
                                relativeTime: viewModel.relativeTime(for: item.createdAt),
                                isEven: index.isMultiple(of: 2),
                                onTap: {
                                    viewModel.copyAndBumpToTop(item)
                                    onClose?()
                                },
                                onPin: { viewModel.pinItem(item) },
                                onUnpin: { viewModel.unpinItem(item) },
                                onDelete: { viewModel.deleteItem(item) }
                            )
                            .padding(.horizontal, 4)
                        }

                        if viewModel.canLoadMore {
                            Button {
                                viewModel.loadMore()
                            } label: {
                                Text("加载更多")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .frame(width: 380, height: contentHeight)
        .onAppear {
            searchFocused = true
        }
    }
    
    /// 窗口高度：搜索栏 + 记录列表，空状态时保留提示区域高度
    private var contentHeight: CGFloat {
        let searchBarHeight: CGFloat = 28
        let rowHeight: CGFloat = 42
        let loadMoreHeight: CGFloat = viewModel.canLoadMore ? 36 : 0
        let itemCount = viewModel.filteredItems().count
        if itemCount == 0 {
            return searchBarHeight + 120
        }
        return min(searchBarHeight + CGFloat(itemCount) * rowHeight + 4 + loadMoreHeight, 400)
    }
}
