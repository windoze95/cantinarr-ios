import NukeUI
import SwiftUI

private struct TaglineHeightKeyRadarr: PreferenceKey {
    static var defaultValue: CGFloat = .zero
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct RadarrMovieDetailView: View {
    @StateObject private var viewModel: RadarrMovieDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var taglineHeight: CGFloat = .zero // For dynamic header height calculation
    @State private var showDeleteConfirmation = false

    init(movieId: Int, radarrService: RadarrAPIService) {
        _viewModel = StateObject(wrappedValue: RadarrMovieDetailViewModel(
            movieId: movieId,
            radarrService: radarrService
        ))
    }

    @ViewBuilder
    private var blurredBackground: some View {
        if let url = viewModel.movie?.fanartURL {
            LazyImage(url: url) { state in
                state.image?
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 40, opaque: true)
            }
            .overlay(Color.black.opacity(0.6)) // Darker overlay for better text contrast
            .ignoresSafeArea()
        } else {
            Color.black.opacity(0.8).ignoresSafeArea() // Dark fallback
        }
    }

    var body: some View {
        GeometryReader { rootGeo in
            blurredBackground

            let safeWidth = rootGeo.size.width - rootGeo.safeAreaInsets.leading - rootGeo.safeAreaInsets.trailing
            let safeHeight = rootGeo.size.height - rootGeo.safeAreaInsets.bottom

            if viewModel.isLoading && viewModel.movie == nil {
                ProgressView("Loading Movie...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .foregroundColor(.white) // Ensure visibility over dark background
            } else if let error = viewModel.error {
                VStack { // Simple error display, can be enhanced
                    Image(systemName: "exclamationmark.triangle.fill").font(.largeTitle).foregroundColor(.orange)
                    Text("Error Loading Movie").font(.title2).padding(.bottom, 5)
                    Text(error).font(.callout).multilineTextAlignment(.center).padding(.horizontal)
                    Button("Retry") { Task { await viewModel.loadMovieDetails() } }
                        .buttonStyle(.borderedProminent).padding(.top)
                }
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else if let movie = viewModel.movie {
                ScrollView(.vertical, showsIndicators: false) {
                    let headerMax = max(0, safeHeight - 100 - taglineHeight)
                    let headerMin = max(44, safeWidth - 200)

                    ShrinkOnScrollHeaderRadarr(maxHeight: headerMax, minHeight: headerMin) {
                        movieHeader(movie: movie)
                            .frame(width: safeWidth, alignment: .leading)
                    }
                    .frame(width: safeWidth, alignment: .leading)
                    .clipped()

                    // Main Content Section
                    VStack(alignment: .leading, spacing: 16) {
                        // Overview
                        Text(movie.overview ?? "No overview available.")
                            .font(.body)
                            .background(GeometryReader { tgGeo in // Use overview for height calculation if no tagline
                                Color.clear.preference(key: TaglineHeightKeyRadarr.self, value: tgGeo.size.height)
                            })
                            .padding(.bottom, 8) // Spacing after overview before details

                        Divider()

                        movieDetailsSection(movie: movie)

                        Divider().padding(.vertical, 8)

                        actionButtonsSection(movie: movie)
                    }
                    .padding() // Horizontal and some vertical padding for the content below header
                    .frame(maxWidth: safeWidth, alignment: .leading)
                }
                .coordinateSpace(name: "radarrScroll")
                .overlay(alignment: .topTrailing) { closeButton.padding(
                    .top,
                    rootGeo.safeAreaInsets.top > 0 ? rootGeo.safeAreaInsets.top : 20
                ) } // Adjust padding based on safe area
                .onPreferenceChange(TaglineHeightKeyRadarr.self) { taglineHeight = $0 }
                .alert(isPresented: $viewModel.showCommandStatusAlert) {
                    Alert(
                        title: Text("Radarr Command"),
                        message: Text(viewModel.commandStatusMessage ?? "Unknown status."),
                        dismissButton: .default(Text("OK"))
                    )
                }
            } else {
                // Case where movie is nil after loading (e.g., deleted then view not dismissed)
                Text("Movie data not available.")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            await viewModel.loadMovieDetails()
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .ignoresSafeArea(edges: .top)
    }

    @ViewBuilder
    private func movieHeader(movie: RadarrMovie) -> some View {
        ZStack(alignment: .bottomLeading) {
            // Gradient from bottom, less strong than fanart overlay
            LinearGradient(colors: [Color.black.opacity(0.5), Color.clear], startPoint: .bottom, endPoint: .center)

            HStack(alignment: .bottom, spacing: 16) {
                LazyImage(url: movie.posterURL) { state in
                    state.image?.resizable().scaledToFill()
                        .frame(width: 120, height: 180).cornerRadius(12).shadow(radius: 5)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(movie.title)
                        .font(.title2.weight(.bold))
                        .lineLimit(3)
                        .foregroundColor(.white)

                    HStack {
                        Text(String(movie.year))
                        Text("•")
                        Text(viewModel.formattedRuntime)
                    }
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))

                    HStack(spacing: 6) {
                        Circle().fill(viewModel.availabilityStatusColor).frame(width: 10, height: 10)
                        Text(viewModel.availabilityStatusText)
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
        .background { // Background for the header itself, fanart is part of main blurredBackground
            if let url = movie.fanartURL { // Show a less blurred fanart within header bounds
                LazyImage(url: url) { state in
                    state.image?.resizable().scaledToFill()
                        .overlay(Color.black.opacity(0.3)) // Slight dimming for header text
                }
            }
        }
        .clipped()
    }

    @ViewBuilder
    private func movieDetailsSection(movie: RadarrMovie) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            DetailRow(label: "Status", value: movie.status.capitalized)
            if let profileName = viewModel.qualityProfileName {
                DetailRow(label: "Quality Profile", value: profileName)
            }
            if movie.hasFile {
                DetailRow(label: "Size on Disk", value: viewModel.formattedSizeOnDisk)
            }
            if let path = movie.path, !path.isEmpty {
                DetailRow(label: "Path", value: path, lineLimit: 3)
            }

            HStack {
                if movie.imdbId != nil {
                    Button("IMDb") { viewModel.openIMDb() }
                        .buttonStyle(.bordered)
                }
                if movie.tmdbId != nil {
                    Button("TMDb") { viewModel.openTMDb() }
                        .buttonStyle(.bordered)
                }
            }
            .padding(.top, 5)
        }
    }

    @ViewBuilder
    private func actionButtonsSection(movie: RadarrMovie) -> some View {
        VStack(spacing: 12) {
            // Monitor/Unmonitor Button
            Button { Task { await viewModel.toggleMonitoring() } } label: {
                Label(movie.monitored ? "Unmonitor Movie" : "Monitor Movie",
                      systemImage: movie.monitored ? "bookmark.slash.fill" : "bookmark.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(movie.monitored ? .orange : .blue)

            // Search Button (if monitored and not downloaded)
            if movie.monitored && !movie.hasFile {
                Button { Task { await viewModel.triggerMovieSearch() } } label: {
                    Label("Search for Movie", systemImage: "magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            // TODO: Add Edit button (placeholder for now)
            // Button("Edit Movie Details") { /* Navigate to an edit screen */ }
            // .buttonStyle(.bordered)
            // .frame(maxWidth: .infinity)

            // Delete Button
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Delete Movie", systemImage: "trash.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .confirmationDialog("Delete \(movie.title)?",
                                isPresented: $showDeleteConfirmation,
                                titleVisibility: .visible)
            {
                Button("Delete Movie and Files", role: .destructive) {
                    Task { await viewModel.deleteMovie(alsoDeleteFiles: true) }
                }
                Button("Delete from Radarr (Keep Files)", role: .destructive) {
                    Task { await viewModel.deleteMovie(alsoDeleteFiles: false) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This action cannot be undone. Choose an option for file deletion.")
            }
        }
    }

    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.title) // Larger for easier tapping
                .foregroundColor(.white.opacity(0.7))
                .background(Circle().fill(Color.black.opacity(0.3))) // Slight background for better visibility
                .shadow(radius: 3)
        }
        .padding()
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

    // ShrinkOnScrollHeader adapted for this view
    private struct ShrinkOnScrollHeaderRadarr<Content: View>: View {
        let maxHeight: CGFloat
        let minHeight: CGFloat
        @ViewBuilder var content: Content

        var body: some View {
            GeometryReader { g in
                let safeMin = max(0, minHeight)
                let safeMax = max(safeMin, maxHeight)
                let offset = g.frame(in: .named("radarrScroll")).minY
                let height = max(safeMin, safeMax - offset)

                content
                    .frame(width: g.size.width, height: height)
                    .clipped()
                    .offset(y: offset < 0 ? -offset : 0)
            }
            .frame(height: max(0, maxHeight))
        }
    }
}

// Preview (might need a mock RadarrAPIService or settings)
// #if DEBUG
// struct RadarrMovieDetailView_Previews: PreviewProvider {
//     static var previews: some View {
//         // You'll need to mock RadarrSettings and RadarrAPIService for a live preview
//         // For now, this will likely fail or show a basic view.
//         let mockSettings = RadarrSettings(host: "demo", apiKey: "demo_key")
//         let mockService = RadarrAPIService(settings: mockSettings) // This needs a mock implementation for previews
//         return RadarrMovieDetailView(movieId: 1, radarrService: mockService)
//             .preferredColorScheme(.dark) // Good for testing contrast
//     }
// }
// #endif
