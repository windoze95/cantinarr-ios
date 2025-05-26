// File: LoadingCardView.swift
// Purpose: Placeholder card view with shimmer effect

import SwiftUI

/// Placeholder view resembling a media card with customizable size.
struct LoadingCardView: View {
    var width: CGFloat = 110
    var height: CGFloat = 150

    var body: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.1))
                .frame(height: height)
                .shimmer()

            RoundedRectangle(cornerRadius: 4)
                .fill(Color.secondary.opacity(0.1))
                .frame(height: 12)
                .padding(.horizontal, 16)
                .shimmer()
        }
        .frame(width: width)
    }
}

#if DEBUG
    struct LoadingCardView_Previews: PreviewProvider {
        static var previews: some View {
            LoadingCardView()
                .previewLayout(.sizeThatFits)
        }
    }
#endif
