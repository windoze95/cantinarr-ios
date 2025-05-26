import SwiftUI

/// Action buttons allowing monitoring toggles, search and deletion.
struct ActionButtonsSection: View {
    let movie: RadarrMovie
    let toggleMonitoring: () async -> Void
    let triggerSearch: () async -> Void
    let deleteMovie: (_ alsoDeleteFiles: Bool) async -> Void

    @State private var showDeleteConfirmation = false

    var body: some View {
        VStack(spacing: 12) {
            Button {
                Task { await toggleMonitoring() }
            } label: {
                Label(movie.monitored ? "Unmonitor Movie" : "Monitor Movie",
                      systemImage: movie.monitored ? "bookmark.slash.fill" : "bookmark.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(movie.monitored ? .orange : .blue)

            if movie.monitored && !movie.hasFile {
                Button {
                    Task { await triggerSearch() }
                } label: {
                    Label("Search for Movie", systemImage: "magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            Button(role: .destructive) { showDeleteConfirmation = true } label: {
                Label("Delete Movie", systemImage: "trash.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .confirmationDialog("Delete \(movie.title)?",
                                isPresented: $showDeleteConfirmation,
                                titleVisibility: .visible)
            {
                Button("Delete Movie and Files", role: .destructive) {
                    Task { await deleteMovie(true) }
                }
                Button("Delete from Radarr (Keep Files)", role: .destructive) {
                    Task { await deleteMovie(false) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This action cannot be undone. Choose an option for file deletion.")
            }
        }
    }
}

#if DEBUG
    struct ActionButtonsSection_Previews: PreviewProvider {
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
                hasFile: false,
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
            ActionButtonsSection(
                movie: sampleMovie,
                toggleMonitoring: {},
                triggerSearch: {},
                deleteMovie: { _ in }
            )
            .padding()
            .previewLayout(.sizeThatFits)
        }
    }
#endif
