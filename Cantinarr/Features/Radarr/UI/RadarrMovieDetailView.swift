// File: RadarrMovieDetailView.swift
// Purpose: Defines RadarrMovieDetailView component for Cantinarr

import NukeUI
import SwiftUI

private struct TaglineHeightKeyRadarr: PreferenceKey {
    static var defaultValue: CGFloat = .zero
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// Displays detailed information about a single Radarr movie.
struct RadarrMovieDetailView: View {
    @StateObject private var viewModel: RadarrMovieDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var taglineHeight: CGFloat = .zero // For dynamic header height calculation

    init(movieId: Int, radarrService: RadarrServiceType) {
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
                        MovieHeaderView(
                            movie: movie,
                            runtimeText: viewModel.formattedRuntime,
                            availabilityText: viewModel.availabilityStatusText,
                            availabilityColor: viewModel.availabilityStatusColor
                        )
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

                        MovieDetailsSection(
                            movie: movie,
                            qualityProfileName: viewModel.qualityProfileName,
                            formattedSizeOnDisk: viewModel.formattedSizeOnDisk,
                            openIMDb: viewModel.openIMDb,
                            openTMDb: viewModel.openTMDb
                        )

                        Divider().padding(.vertical, 8)

                        ActionButtonsSection(
                            movie: movie,
                            toggleMonitoring: { await viewModel.toggleMonitoring() },
                            triggerSearch: { await viewModel.triggerMovieSearch() },
                            deleteMovie: { await viewModel.deleteMovie(alsoDeleteFiles: $0) }
                        )
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
