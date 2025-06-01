import SwiftUI

/// Displays a grid of seasons for a TV show.
struct SeasonGridView: View {
    let seasons: [Season]
    let requestAction: () -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 12)]) {
            ForEach(seasons) { s in
                Button(action: {
                    if s.mediaInfo?.status != .available {
                        requestAction()
                    }
                }) {
                    VStack(spacing: 4) {
                        Text("Season \(s.seasonNumber)")
                        Text("\(s.episodeCount) eps")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Label(s.mediaInfo?.status.label ?? "–", systemImage: "circle.fill")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(4)
                            .background(s.mediaInfo?.status.tint ?? .gray)
                            .cornerRadius(4)
                    }
                    .padding(8)
                    .background(
                        Material.ultraThin,
                        in: RoundedRectangle(cornerRadius: 8)
                    )
                    .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(
                    s.mediaInfo?.status != .available ?
                        "Request season \(s.seasonNumber)" :
                        "Season \(s.seasonNumber) available"
                ))
            }
        }
    }
}

#if DEBUG
    struct SeasonGridView_Previews: PreviewProvider {
        static var previews: some View {
            let mockSeason = Season(
                id: 1,
                seasonNumber: 1,
                episodeCount: 8,
                mediaInfo: .init(status: .available, plexUrl: nil)
            )
            SeasonGridView(seasons: [mockSeason], requestAction: {})
                .padding()
                .previewLayout(.sizeThatFits)
        }
    }
#endif
