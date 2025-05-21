// File: RadarrMoviesView.swift
// Purpose: Defines RadarrMoviesView component for Cantinarr

import SwiftUI

/// Lists movies available in Radarr.
struct RadarrMoviesView: View {
    @StateObject var viewModel: RadarrMoviesViewModel

    // Extracted View for Loading State
    @ViewBuilder
    private var loadingView: some View {
        ProgressView("Loading Movies...")
    }

    // Extracted View for Error State
    @ViewBuilder
    private func errorView(error: String) -> some View {
        VStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundColor(.red)
            Text("Error")
                .font(.headline)
            Text(error)
                .font(.caption)
                .multilineTextAlignment(.center)
                .padding()
            Button("Retry") {
                Task { await viewModel.loadContent() }
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    // Extracted View for Empty State
    @ViewBuilder
    private var emptyMoviesView: some View {
        Text("No movies found in Radarr.")
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center) // Ensure it can take up space
    }

    // Extracted View for Movie List
    @ViewBuilder
    private var moviesListView: some View {
        List {
            ForEach(viewModel.movies) { movie in
                // Use NavigationLink(value:label:) with navigationDestination for cleaner navigation
                NavigationLink(value: movie) { // Value type must be Hashable (RadarrMovie is Identifiable)
                    RadarrMovieListItemView(
                        movie: movie,
                        qualityProfileName: viewModel.getQualityProfileName(for: movie.qualityProfileId)
                    )
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .refreshable {
            await viewModel.loadContent()
        }
    }

    var body: some View {
        // The NavigationView should ideally be higher up in the hierarchy,
        // for example, in RadarrHomeEntry or even RootShellView if Radarr
        // doesn't have its own TabView managing navigation.
        // If RadarrHomeEntry has a TabView, each tab can indeed have its own NavigationView.
        NavigationView {
            Group { // This Group might still be okay, but the inner content is now simpler
                if viewModel.isLoading && viewModel.movies.isEmpty {
                    loadingView
                } else if let error = viewModel.connectionError {
                    errorView(error: error)
                } else if viewModel.movies.isEmpty {
                    emptyMoviesView
                } else {
                    moviesListView
                }
            }
            .navigationTitle("Movies")
            // Modern navigation using .navigationDestination
            .navigationDestination(for: RadarrMovie.self) { movie in
                RadarrMovieDetailView(
                    movieId: movie.id,
                    radarrService: viewModel.service // Pass the service instance from the ViewModel
                )
            }
        }
        .task {
            if viewModel.movies.isEmpty {
                await viewModel.loadContent()
            }
        }
        // .sheet(item: $showingMovieDetail) { movie in // Alternative presentation for detail
        //     NavigationView {
        //         RadarrMovieDetailView(movieId: movie.id, radarrService: viewModel.service)
        //     }
        // }
    }
}
