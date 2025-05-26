// File: KeywordPill.swift
// Purpose: Reusable keyword pill view for Cantinarr

import SwiftUI

/// Simple capsule-styled pill displaying provided text.
struct GenericKeywordPill<Keyword>: View {
    let keyword: Keyword
    var nameKeyPath: KeyPath<Keyword, String>

    var body: some View {
        Text(keyword[keyPath: nameKeyPath])
            .font(.caption)
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(Capsule().fill(Color.accentColor.opacity(0.15)))
            .foregroundColor(.accentColor)
            .lineLimit(1)
    }
}

#if DEBUG
    struct GenericKeywordPill_Previews: PreviewProvider {
        struct Example { let name: String }
        static var previews: some View {
            GenericKeywordPill(keyword: Example(name: "Action"), nameKeyPath: \Example.name)
                .padding()
                .previewLayout(.sizeThatFits)
        }
    }
#endif
