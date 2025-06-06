// File: RadarrMoviesViewModel.swift
// Purpose: Defines RadarrMoviesViewModel component for Cantinarr

import Combine
import SwiftUI

/// Handles fetching and displaying the user's Radarr movie library.
@MainActor
class RadarrMoviesViewModel: ObservableObject {
    @Published var movies: [RadarrMovie] = []
    @Published var isLoading: Bool = false
    @Published var connectionError: String? = nil
    @Published var qualityProfiles: [Int: String] = [:] // [ID: Name]

    let service: RadarrServiceType
    private var pageLoader =
        PagedLoader() // If Radarr movie list is paginated server-side (often it's not, but good for consistency)

    init(service: RadarrServiceType) {
        self.service = service
    }

    func loadContent() async {
        guard !isLoading else { return }
        isLoading = true
        connectionError = nil

        // Fetch quality profiles first to map names
        if qualityProfiles.isEmpty {
            await fetchQualityProfiles()
        }

        do {
            movies = try await service.getMovies()
        } catch let APIServiceError.apiError(message: message, statusCode: statusCode) {
            self.connectionError = "Radarr API Error (\(statusCode)): \(message). Check your network connection or Radarr configuration."
        } catch {
            connectionError = "Failed to load movies: \(error.localizedDescription). Check your network connection or Radarr configuration."
            debugLog("🔴 Radarr Movies VM Error: \(error)")
        }
        isLoading = false
    }

    private func fetchQualityProfiles() async {
        do {
            let profiles = try await service.getQualityProfiles()
            var profileMap: [Int: String] = [:]
            for profile in profiles {
                profileMap[profile.id] = profile.name
            }
            qualityProfiles = profileMap
        } catch {
            debugLog("🔴 Failed to load Radarr quality profiles: \(error.localizedDescription)")
            // Non-critical, list view can show IDs or "N/A" for profile names
        }
    }

    // Placeholder for future pagination or filtering
    func loadMoreIfNeeded(currentMovie _: RadarrMovie) {
        // Radarr's /movie endpoint typically returns all movies.
        // If server-side pagination were used, implement logic here.
    }

    func getQualityProfileName(for id: Int) -> String? {
        return qualityProfiles[id]
    }
}
