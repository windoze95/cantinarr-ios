// File: HorizontalItemRow.swift
// Purpose: Reusable horizontally scrolling item row for Cantinarr

import SwiftUI

/// Displays a horizontally scrolling row of items with optional loading placeholders.
struct HorizontalItemRow<Item: Identifiable, ItemView: View, PlaceholderView: View = EmptyView>: View {
    let items: [Item]
    let isLoading: Bool
    var onAppear: (Item) -> Void = { _ in }
    let itemView: (Item) -> ItemView
    var placeholderView: () -> PlaceholderView = { EmptyView() }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                if items.isEmpty && isLoading {
                    ForEach(0 ..< 5, id: \.self) { _ in
                        placeholderView()
                    }
                } else {
                    ForEach(items) { item in
                        itemView(item)
                            .onAppear { onAppear(item) }
                    }
                    if isLoading && !items.isEmpty {
                        placeholderView()
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

#if DEBUG
    struct HorizontalItemRow_Previews: PreviewProvider {
        struct Sample: Identifiable { let id: Int }
        static var previews: some View {
            HorizontalItemRow(items: [Sample(id: 1), Sample(id: 2)], isLoading: true, itemView: { _ in
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue)
                    .frame(width: 100, height: 150)
            }, placeholderView: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 100, height: 150)
            })
            .frame(height: 180)
        }
    }
#endif
