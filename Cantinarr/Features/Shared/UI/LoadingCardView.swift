import SwiftUI

/// Simple skeleton card used while loading content.
struct LoadingCardView: View {
    let width: CGFloat
    let imageHeight: CGFloat
    let lineHeight: CGFloat

    init(width: CGFloat = 110, imageHeight: CGFloat = 150, lineHeight: CGFloat = 12) {
        self.width = width
        self.imageHeight = imageHeight
        self.lineHeight = lineHeight
    }

    var body: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.1))
                .frame(height: imageHeight)
                .shimmer()

            RoundedRectangle(cornerRadius: 4)
                .fill(Color.secondary.opacity(0.1))
                .frame(height: lineHeight)
                .padding(.horizontal, 16)
                .shimmer()
        }
        .frame(width: width)
    }
}

#if DEBUG
private struct LoadingCardView_Previews: PreviewProvider {
    static var previews: some View {
        LoadingCardView()
            .previewLayout(.sizeThatFits)
    }
}
#endif
