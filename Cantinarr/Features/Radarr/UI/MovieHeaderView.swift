import NukeUI
import Nuke
import SwiftUI

/// Header for the Radarr movie detail screen showing poster and basic info.
struct MovieHeaderView: View {
    let movie: RadarrMovie
    let runtimeText: String
    let availabilityText: String
    let availabilityColor: Color

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [Color.black.opacity(0.5), Color.clear],
                           startPoint: .bottom, endPoint: .center)

            HStack(alignment: .bottom, spacing: 16) {
                LazyImage(
                    request: ImageRequest(
                        url: movie.posterURL,
                        processors: [
                            ImageProcessors.Resize(
                                size: CGSize(width: 120, height: 180),
                                unit: .points
                            ),
                        ]
                    )
                ) { state in
                    state.image?.resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 180)
                        .cornerRadius(12)
                        .shadow(radius: 5)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(movie.title)
                        .font(.title2.weight(.bold))
                        .lineLimit(3)
                        .foregroundColor(.white)

                    HStack {
                        Text(String(movie.year))
                        Text("•")
                        Text(runtimeText)
                    }
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))

                    HStack(spacing: 6) {
                        Circle()
                            .fill(availabilityColor)
                            .frame(width: 10, height: 10)
                        Text(availabilityText)
                            .font(.caption.weight(.medium))
                            .foregroundColor(.white)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(6)
                }
                Spacer()
            }
            .padding()
        }
        .background {
            if let url = movie.fanartURL {
                GeometryReader { geo in
                    LazyImage(
                        request: ImageRequest(
                            url: url,
                            processors: [ImageProcessors.Resize(size: geo.size, unit: .points)]
                        )
                    ) { state in
                        state.image?.resizable()
                            .scaledToFill()
                            .overlay(Color.black.opacity(0.3))
                    }
                }
            }
        }
        .clipped()
    }
}

#if DEBUG
    struct MovieHeaderView_Previews: PreviewProvider {
        static var sampleMovie: RadarrMovie {
            RadarrMovie(
                id: 1,
                title: "Sample Movie",
                originalTitle: nil,
                sortTitle: "Sample Movie",
                sizeOnDisk: 5_000_000_000,
                status: "released",
                overview: "A sample movie overview.",
                inCinemas: nil,
                physicalRelease: nil,
                digitalRelease: nil,
                images: [
                    RadarrImage(
                        coverType: "poster",
                        url: URL(string: "https://example.com/poster.jpg"),
                        remoteUrl: nil
                    ),
                    RadarrImage(
                        coverType: "fanart",
                        url: URL(string: "https://example.com/fanart.jpg"),
                        remoteUrl: nil
                    ),
                ],
                website: nil,
                year: 2023,
                hasFile: true,
                path: "/movies/sample",
                qualityProfileId: 1,
                monitored: true,
                minimumAvailability: "released",
                runtime: 120,
                cleanTitle: nil,
                imdbId: "tt1234567",
                tmdbId: 100,
                titleSlug: nil,
                folderName: nil,
                movieFile: nil
            )
        }

        static var previews: some View {
            MovieHeaderView(
                movie: sampleMovie,
                runtimeText: "2h",
                availabilityText: "Downloaded",
                availabilityColor: .green
            )
            .previewLayout(.sizeThatFits)
            .preferredColorScheme(.dark)
        }
    }
#endif
