// File: RadarrMovieDetailViewModel.swift
// Purpose: Defines RadarrMovieDetailViewModel component for Cantinarr

import Combine
import SwiftUI

@MainActor
/// View model for ``RadarrMovieDetailView`` responsible for loading and
/// mutating a single movie.
class RadarrMovieDetailViewModel: ObservableObject {
    @Published var movie: RadarrMovie?
    @Published var qualityProfileName: String?
    @Published var isLoading: Bool = false
    @Published var error: String?
    @Published var commandStatusMessage: String? // For feedback on actions like search
    @Published var showCommandStatusAlert: Bool = false

    private let radarrService: RadarrServiceType
    let movieId: Int

    private var cancellables = Set<AnyCancellable>()

    init(movieId: Int, radarrService: RadarrServiceType) {
        self.movieId = movieId
        self.radarrService = radarrService
    }

    func loadMovieDetails() async {
        // Avoid overlapping loads
        guard !isLoading else { return }
        isLoading = true
        error = nil
        commandStatusMessage = nil

        do {
            // Fetch movie details from Radarr
            let fetchedMovie = try await radarrService.getMovie(id: movieId)
            movie = fetchedMovie
            await fetchQualityProfileName(id: fetchedMovie.qualityProfileId)
        } catch let APIServiceError.apiError(message: message, statusCode: statusCode) {
            self.error = "Radarr API Error (\(statusCode)): \(message)"
        } catch {
            self.error = "Failed to load movie details: \(error.localizedDescription)"
        }
        isLoading = false
    }

    private func fetchQualityProfileName(id: Int) async {
        do {
            // Lookup the quality profile by ID. In a real app this could be cached.
            let profiles = try await radarrService.getQualityProfiles()
            qualityProfileName = profiles.first(where: { $0.id == id })?.name ?? "Unknown Profile (\(id))"
        } catch {
            print("🔴 Failed to fetch quality profile name: \(error.localizedDescription)")
            qualityProfileName = "Error (\(id))"
        }
    }

    var availabilityStatusText: String {
        guard let movie = movie else { return "Unknown" }
        if movie.hasFile { return "Downloaded" }
        if movie.monitored {
            switch movie.minimumAvailability.lowercased() {
            case "announced", "tba": return "Announced"
            case "incinemas": return "In Cinemas"
            case "released", "predb": return "Missing (Searching)"
            default: return "Monitored (\(movie.minimumAvailability))"
            }
        }
        return "Unmonitored"
    }

    var availabilityStatusColor: Color {
        guard let movie = movie else { return .gray }
        if movie.hasFile { return .green }
        if movie.monitored {
            switch movie.minimumAvailability.lowercased() {
            case "announced", "tba": return .gray
            case "incinemas": return .blue
            case "released", "predb": return .orange
            default: return .yellow
            }
        }
        return .purple
    }

    func toggleMonitoring() async {
        guard var movieToUpdate = movie else { return } // movieToUpdate is a mutable COPY
        movieToUpdate.monitored.toggle() // This will now work because 'monitored' is a 'var' in the struct

        do {
            // When sending movieToUpdate to radarrService.updateMovie,
            // ensure it's the complete, correct payload Radarr expects for an update.
            let updatedMovie = try await radarrService.updateMovie(movieToUpdate, moveFiles: false)
            movie = updatedMovie
            commandStatusMessage = movieToUpdate.monitored ? "Movie is now monitored." : "Movie is no longer monitored."
            showCommandStatusAlert = true
        } catch {
            commandStatusMessage = "Failed to update monitoring status: \(error.localizedDescription)"
            showCommandStatusAlert = true
            // Revert local state if API call failed
            // No need to toggle again here if the original self.movie wasn't changed yet
            // self.movie will still hold the state before the attempted API call if it failed early
            // or it will hold the 'updatedMovie' (which might be the old one if updateMovie re-fetches)
            // To be absolutely sure of reverting to the state *before* the local toggle:
            // You might need to store the original self.movie state before modification if complex logic.
            // For a simple toggle, if updateMovie fails, self.movie might not have changed yet.
            // However, if self.movie was updated optimistically *before* the API call, then revert.
            // Current structure: local movieToUpdate is modified, then API call. If API fails, self.movie is not yet
            // movieToUpdate.
            // So, the "revert" "movieToUpdate.monitored.toggle()" is not needed with current structure.
            // If you were to do:
            // self.movie?.monitored.toggle() // Optimistic UI update
            // then the revert would be necessary.
        }
    }

    func triggerMovieSearch() async {
        guard let currentMovie = movie, currentMovie.monitored, !currentMovie.hasFile else {
            commandStatusMessage = "Movie is already downloaded or not monitored for search."
            showCommandStatusAlert = true
            return
        }

        commandStatusMessage = "Searching for movie..." // Initial feedback

        do {
            let commandResponse = try await radarrService.searchForMovie(currentMovie.id)
            commandStatusMessage = commandResponse
                .message ?? "Search command sent. Status: \(commandResponse.status ?? "Unknown")"
            // Optionally, refresh movie details after a delay or based on command status
            // For now, just show the command response message.
        } catch {
            commandStatusMessage = "Failed to trigger movie search: \(error.localizedDescription)"
        }
        showCommandStatusAlert = true
    }

    func deleteMovie(alsoDeleteFiles: Bool) async {
        guard let movieToDelete = movie else { return }
        do {
            try await radarrService.deleteMovie(movieToDelete.id, deleteFiles: alsoDeleteFiles, addImportExclusion: false)
            commandStatusMessage = "Movie deleted successfully."
            showCommandStatusAlert = true
            // After deletion, the view should probably be dismissed or state cleared
            movie = nil // Clear the movie to indicate it's gone
        } catch {
            commandStatusMessage = "Failed to delete movie: \(error.localizedDescription)"
            showCommandStatusAlert = true
        }
    }

    var formattedSizeOnDisk: String {
        guard let size = movie?.sizeOnDisk, size > 0 else { return "N/A" }
        let bcf = ByteCountFormatter()
        bcf.allowedUnits = [.useGB, .useMB]
        bcf.countStyle = .file
        return bcf.string(fromByteCount: size)
    }

    var formattedRuntime: String {
        guard let runtime = movie?.runtime, runtime > 0 else { return "N/A" }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: TimeInterval(runtime * 60)) ?? "N/A"
    }

    func openIMDb() {
        guard let imdbId = movie?.imdbId, let url = URL(string: "https://www.imdb.com/title/\(imdbId)") else { return }
        UIApplication.shared.open(url)
    }

    func openTMDb() {
        guard let tmdbId = movie?.tmdbId,
              let url = URL(string: "https://www.themoviedb.org/movie/\(tmdbId)") else { return }
        UIApplication.shared.open(url)
    }
}
