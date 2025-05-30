// File: OverseerrUsersService.swift
// Purpose: Defines OverseerrUsersService component for Cantinarr

import Foundation

/// Abstraction for services that expose Overseerr's user‑facing API.
@MainActor
protocol OverseerrUsersService {
    // Check login state
    func isAuthenticated() async -> Bool

    // Login with a Plex token
    func loginWithPlexToken(_ token: String) async throws

    // Fetch watch providers (movie vs tv)
    func fetchWatchProviders(isMovie: Bool) async throws -> [WatchProvider]

    // Discover endpoints
    func fetchMovies(
        providerIds: [Int],
        genreIds: [Int],
        keywordIds: [Int],
        page: Int
    ) async throws -> DiscoverResponse<Movie>

    func fetchTV(
        providerIds: [Int],
        genreIds: [Int],
        keywordIds: [Int],
        page: Int
    ) async throws -> DiscoverResponse<TVShow>

    // Keyword search
    func keywordSearch(query: String) async throws -> [Keyword]

    // Recommendations
    func movieRecommendations(for id: Int, page: Int) async throws
        -> DiscoverResponse<Movie>

    func tvRecommendations(for id: Int, page: Int) async throws
        -> DiscoverResponse<TVShow>

    // Search
    func search(query: String, page: Int) async throws -> DiscoverResponse<SearchItem>
}
