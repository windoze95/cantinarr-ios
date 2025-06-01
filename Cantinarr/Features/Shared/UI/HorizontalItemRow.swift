import SwiftUI

/// A generic horizontally scrolling row that can show loading placeholders.
struct HorizontalItemRow<Item: Identifiable, ItemView: View, PlaceholderView: View>: View {
    let items: [Item]
    let isLoading: Bool
    /// Called when an item near the end of the list appears. Use to prefetch more content.
    let onAppear: (Item) -> Void
    let content: (Item) -> ItemView
    let placeholder: () -> PlaceholderView
    let prefetchThreshold: Int

    init(items: [Item],
         isLoading: Bool,
         prefetchThreshold: Int = AppConfig.prefetchThreshold,
         onAppear: @escaping (Item) -> Void,
         @ViewBuilder content: @escaping (Item) -> ItemView,
         @ViewBuilder placeholder: @escaping () -> PlaceholderView)
    {
        self.items = items
        self.isLoading = isLoading
        self.prefetchThreshold = prefetchThreshold
        self.onAppear = onAppear
        self.content = content
        self.placeholder = placeholder
    }
}

extension HorizontalItemRow where PlaceholderView == EmptyView {
    init(items: [Item],
         isLoading: Bool,
         prefetchThreshold: Int = AppConfig.prefetchThreshold,
         onAppear: @escaping (Item) -> Void,
         @ViewBuilder content: @escaping (Item) -> ItemView)
    {
        self.init(items: items,
                  isLoading: isLoading,
                  prefetchThreshold: prefetchThreshold,
                  onAppear: onAppear,
                  content: content,
                  placeholder: { EmptyView() })
    }
}

extension HorizontalItemRow {
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                if items.isEmpty && isLoading {
                    ForEach(0 ..< 5, id: \.self) { _ in
                        placeholder()
                    }
                } else {
                    ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                        content(item)
                            .onAppear {
                                if idx >= items.count - prefetchThreshold {
                                    onAppear(item)
                                }
                            }
                    }
                    if isLoading && !items.isEmpty {
                        placeholder()
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

#if DEBUG
    private struct HorizontalItemRow_Previews: PreviewProvider {
        struct ExampleItem: Identifiable { let id: Int; let title: String }
        static var previews: some View {
            HorizontalItemRow(
                items: [ExampleItem(id: 1, title: "One"), ExampleItem(id: 2, title: "Two")],
                isLoading: true,
                onAppear: { _ in }
            ) { item in
                Text(item.title)
                    .frame(width: 100, height: 80)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(8)
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 100, height: 80)
                    .shimmer()
            }
            .frame(height: 100)
            .previewLayout(.sizeThatFits)
        }
    }
#endif
