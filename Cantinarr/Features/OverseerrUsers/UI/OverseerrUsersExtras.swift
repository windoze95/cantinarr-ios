// File: OverseerrUsersExtras.swift
// Purpose: Defines OverseerrUsersExtras component for Cantinarr

import SwiftUI

/// Convenience typealias used in this feature
typealias MediaItem = OverseerrUsersViewModel.MediaItem

// MARK: – Keyword suggestion pills

struct KeywordSuggestionRow: View {
    let keywords: [OverseerrAPIService.Keyword] // Ensure OverseerrAPIService.Keyword is Identifiable
    let choose: (OverseerrAPIService.Keyword) -> Void

    // Adjust rows based on desired density and pill height
    private let rows: [GridItem] = [
        GridItem(.flexible(minimum: 32, maximum: 40)), // Allow some flexibility
        GridItem(.flexible(minimum: 32, maximum: 40)),
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            // Using LazyHGrid for potentially many keywords
            LazyHGrid(rows: rows, spacing: 8) {
                ForEach(keywords) { kw in // Keyword must be Identifiable
                    PillView(item: kw, nameKeyPath: \.name)
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

