import SwiftUI

// MARK: – Horizontal scroll row

struct HorizontalMediaRow: View {
    let items: [OverseerrUsersViewModel.MediaItem]
    let isLoading: Bool
    let onAppear: (OverseerrUsersViewModel.MediaItem) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                if items.isEmpty && isLoading {
                    // show 5 shimmering placeholders
                    ForEach(0 ..< 5, id: \.self) { _ in
                        LoadingMediaCardView()
                    }
                } else {
                    ForEach(items) { item in
                        MediaCardView(id: item.id,
                                      mediaType: item.mediaType,
                                      title: item.title,
                                      posterPath: item.posterPath)
                            .frame(width: 110)
                            .onAppear { onAppear(item) } // Call the closure with the item
                    }
                    // at the end, if still loading more, show one more placeholder
                    if isLoading && !items.isEmpty { // Only show trailing loader if there are items
                        LoadingMediaCardView()
                    }
                }
            }
            .padding(.horizontal)
        }
        // It's good for HorizontalMediaRow to have a defined height if its content can vary
        // or if it's used in contexts where an intrinsic height isn't easily determined.
        // For example, if MediaCardView has a fixed height of ~180 (150 for image + text + spacing).
        .frame(height: 200) // Example height, adjust based on MediaCardView's content
    }
}

// MARK: – Keyword suggestion pills

struct KeywordPill: View {
    let keyword: OverseerrAPIService
        .Keyword // Ensure OverseerrAPIService.Keyword is Identifiable if used in ForEach directly

    var body: some View {
        Text(keyword.name)
            .font(.caption) // Slightly smaller for pills
            .padding(.vertical, 8) // Adjusted padding
            .padding(.horizontal, 14) // Adjusted padding
            .background(Capsule().fill(Color.accentColor.opacity(0.15))) // Slightly adjust opacity
            .foregroundColor(.accentColor) // Make text accent color for better theme fit
            .lineLimit(1)
    }
}

struct KeywordSuggestionRow: View {
    let keywords: [OverseerrAPIService.Keyword] // Ensure OverseerrAPIService.Keyword is Identifiable
    let choose: (OverseerrAPIService.Keyword) -> Void

    // Adjust rows based on desired density and KeywordPill height
    private let rows: [GridItem] = [
        GridItem(.flexible(minimum: 32, maximum: 40)), // Allow some flexibility
        GridItem(.flexible(minimum: 32, maximum: 40)),
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            // Using LazyHGrid for potentially many keywords
            LazyHGrid(rows: rows, spacing: 8) {
                ForEach(keywords) { kw in // Keyword must be Identifiable
                    KeywordPill(keyword: kw)
                        .onTapGesture { choose(kw) }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 4) // Padding for the content within the scroll view
        }
        // Define a reasonable maxHeight for the row.
        // Example: 2 rows of 40pt height + 8pt spacing + 8pt vertical padding = 40+8+40 + 8 = 96
        .frame(maxHeight: (40 * 2) + 8 + 8) // Calculate based on row height, spacing, and padding
    }
}

struct ActiveKeywordsView: View {
    @EnvironmentObject var vm: OverseerrUsersViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Explicitly provide the id for ForEach if compiler struggles.
                // Though vm.activeKeywords (if [OverseerrAPIService.Keyword]) should work directly
                // as Keyword is Identifiable. This is a safeguard.
                ForEach(vm.activeKeywords, id: \.id) { kw in
                    HStack(spacing: 4) {
                        Text(kw.name)
                            .font(.caption)
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .onTapGesture { vm.remove(keywordID: kw.id) }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.accentColor.opacity(0.25)))
                    .foregroundColor(Color.accentColor)
                }
            }
            .padding(.horizontal)
            .frame(height: 32)
        }
    }
}

struct LoadingMediaCardView: View {
    var body: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.1)) // Use secondary for placeholder bg
                .frame(height: 150)
                .shimmer()

            RoundedRectangle(cornerRadius: 4)
                .fill(Color.secondary.opacity(0.1))
                .frame(height: 12)
                .padding(.horizontal, 16)
                .shimmer()
        }
        .frame(width: 110)
    }
}
