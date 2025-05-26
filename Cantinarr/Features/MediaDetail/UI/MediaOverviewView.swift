import SwiftUI

/// Displays the overview text for a media item.
struct MediaOverviewView: View {
    let overview: String

    var body: some View {
        Text(overview)
            .font(.body)
    }
}

#if DEBUG
    struct MediaOverviewView_Previews: PreviewProvider {
        static var previews: some View {
            MediaOverviewView(overview: "This is a mock overview of the movie used for SwiftUI previews.")
                .padding()
                .previewLayout(.sizeThatFits)
        }
    }
#endif
