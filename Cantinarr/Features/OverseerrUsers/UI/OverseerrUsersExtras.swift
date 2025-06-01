// File: OverseerrUsersExtras.swift
// Purpose: Defines OverseerrUsersExtras component for Cantinarr

import SwiftUI


// MARK: – Keyword suggestion pills

struct KeywordSuggestionRow: View {
    let keywords: [Keyword] // Ensure Keyword is Identifiable
    let choose: (Keyword) -> Void

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

