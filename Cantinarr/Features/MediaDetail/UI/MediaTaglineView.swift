import SwiftUI

/// Preference key used to report the tagline height up the view hierarchy.
struct TaglineHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = .zero
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// Displays the media tagline and reports its height with a preference.
struct MediaTaglineView: View {
    let tagline: String

    var body: some View {
        Text(tagline)
            .font(.title3.italic())
            .opacity(0.8)
            .background(
                GeometryReader { g in
                    Color.clear.preference(key: TaglineHeightKey.self,
                                            value: g.size.height)
                }
            )
    }
}

#if DEBUG
struct MediaTaglineView_Previews: PreviewProvider {
    static var previews: some View {
        MediaTaglineView(tagline: "A thrilling tale of adventure.")
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
#endif

