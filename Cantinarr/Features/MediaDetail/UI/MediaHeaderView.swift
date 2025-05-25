import SwiftUI
import NukeUI

/// Header displaying poster, title and action buttons.
struct MediaHeaderView: View {
    let posterURL: URL?
    let backdropURL: URL?
    let title: String
    let availability: MediaAvailability
    let trailerVideoID: String?
    let youtubeEmbedURL: URL?
    @Binding var showTrailerPlayer: Bool
    @Binding var showReport: Bool

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [Color.black.opacity(0.6), Color.clear],
                           startPoint: .bottom, endPoint: .top)
            HStack(alignment: .bottom, spacing: 16) {
                if let url = posterURL {
                    LazyImage(url: url) { state in
                        state.image?.resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 180)
                            .cornerRadius(12)
                            .shadow(radius: 5)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title.weight(.semibold))
                        .lineLimit(3)
                        .truncationMode(.tail)
                    Label(availability.label, systemImage: "circle.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(6)
                        .background(availability.tint)
                        .cornerRadius(6)
                    buttonRow
                }
                Spacer()
            }
            .padding()
        }
        .background {
            if let url = backdropURL {
                LazyImage(url: url) { state in
                    state.image?.resizable()
                        .scaledToFill()
                        .overlay(Color.black.opacity(0.25))
                }
            }
        }
        .clipped()
    }

    @ViewBuilder private var buttonRow: some View {
        VStack(alignment: .center, spacing: 10) {
            HStack(spacing: 12) {
                watchTrailerBtn.frame(maxWidth: .infinity)
            }
            if availability == .available || availability == .partiallyAvailable {
                reportBtn
            }
        }
    }

    private var watchTrailerBtn: some View {
        Button {
            if trailerVideoID != nil {
                showTrailerPlayer = true
            } else {
                guard !title.isEmpty,
                      let query = "\(title) trailer".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                      let url = URL(string: "https://www.youtube.com/results?search_query=\(query)")
                else { return }
                UIApplication.shared.open(url)
            }
        } label: {
            Label("Watch Trailer", systemImage: "video")
        }
        .buttonStyle(.bordered)
        .sheet(isPresented: $showTrailerPlayer) {
            if let url = youtubeEmbedURL {
                TrailerPlayerView(url: url)
            } else {
                VStack {
                    Text("Trailer is unavailable at the moment.")
                    Button("Dismiss") { showTrailerPlayer = false }.padding()
                }
            }
        }
    }

    private var reportBtn: some View {
        Button { showReport.toggle() } label: {
            Image(systemName: "exclamationmark.triangle.fill")
        }
        .buttonStyle(.bordered)
        .tint(.yellow)
    }
}

#if DEBUG
struct MediaHeaderView_Previews: PreviewProvider {
    @State static var showTrailer = false
    @State static var showReport = false

    static var previews: some View {
        MediaHeaderView(
            posterURL: URL(string: "https://example.com/poster.jpg"),
            backdropURL: URL(string: "https://example.com/backdrop.jpg"),
            title: "Example Movie Title That Is Quite Long",
            availability: .available,
            trailerVideoID: "abc123",
            youtubeEmbedURL: URL(string: "https://www.youtube.com/embed/abc123"),
            showTrailerPlayer: $showTrailer,
            showReport: $showReport
        )
        .preferredColorScheme(.dark)
    }
}
#endif

