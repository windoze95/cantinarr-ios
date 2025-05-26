import SwiftUI

/// Information section showing movie details like status and quality profile.
struct MovieDetailsSection: View {
    let movie: RadarrMovie
    let qualityProfileName: String?
    let formattedSizeOnDisk: String
    let openIMDb: () -> Void
    let openTMDb: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            DetailRow(label: "Status", value: movie.status.capitalized)
            if let profileName = qualityProfileName {
                DetailRow(label: "Quality Profile", value: profileName)
            }
            if movie.hasFile {
                DetailRow(label: "Size on Disk", value: formattedSizeOnDisk)
            }
            if let path = movie.path, !path.isEmpty {
                DetailRow(label: "Path", value: path, lineLimit: 3)
            }

            HStack {
                if movie.imdbId != nil {
                    Button("IMDb", action: openIMDb)
                        .buttonStyle(.bordered)
                }
                if movie.tmdbId != nil {
                    Button("TMDb", action: openTMDb)
                        .buttonStyle(.bordered)
                }
            }
            .padding(.top, 5)
        }
    }

    private struct DetailRow: View {
        let label: String
        let value: String
        var lineLimit: Int = 1

        var body: some View {
            VStack(alignment: .leading) {
                Text(label).font(.caption).foregroundColor(.secondary)
                Text(value).font(.callout).lineLimit(lineLimit)
            }
        }
    }
}

#if DEBUG
    struct MovieDetailsSection_Previews: PreviewProvider {
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
                images: [],
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
            MovieDetailsSection(
                movie: sampleMovie,
                qualityProfileName: "1080p",
                formattedSizeOnDisk: "5 GB",
                openIMDb: {},
                openTMDb: {}
            )
            .padding()
            .previewLayout(.sizeThatFits)
        }
    }
#endif
