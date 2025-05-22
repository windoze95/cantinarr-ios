// File: TrendingViewModel.swift
// Purpose: Defines TrendingViewModel component for Cantinarr

import SwiftUI

@MainActor
/// Fetches and caches trending movies/TV shows from Overseerr.
final class TrendingViewModel: ObservableObject {
    typealias MediaItem = OverseerrUsersViewModel.MediaItem // reuse struct

    // Dependencies
    private let service: OverseerrServiceType

    // Paging helper
    private var loader = PagedLoader()

    // Published state
    @Published private(set) var items: [MediaItem] = []
    @Published private(set) var isLoading = false
    @Published var connectionError: String? = nil

    // MARK: – Init

    init(service: OverseerrServiceType) {
        self.service = service
    }

    // MARK: – Public API

    func bootstrap() async { // first load
        connectionError = nil // Reset on new attempt
        items.removeAll() // Clear old items
        loader.reset()
        await fetchNextPage()
    }

    func loadMoreIfNeeded(current item: MediaItem) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }),
              idx >= items.index(items.endIndex,
                                 offsetBy: -AppConfig.prefetchThreshold)
        else { return }
        Task { await fetchNextPage() }
    }

    // MARK: – Internals

    private func fetchNextPage() async {
        // Guard against multiple simultaneous loads and end when no more pages
        guard loader.beginLoading() else { return }
        isLoading = true
        // Ensure loading flag is cleared even if we early‑return
        defer { isLoading = false }

        do {
            // Ask the service for the next trending page. Provider filter is
            // empty here which means "all" providers.
            let resp = try await service.fetchTrending(
                providerIds: [],
                page: loader.page
            )

            // Map raw DTOs into display models used by the view
            let mapped = resp.results.map {
                MediaItem(id: $0.id,
                          title: $0.title ?? $0.name ?? "Untitled",
                          posterPath: $0.posterPath,
                          mediaType: $0.mediaType)
            }
            items += mapped
            // Update paging counters with totalPages from the API
            loader.endLoading(next: resp.totalPages)
            // Clear any stale error message once we have data
            if loader.page == 2 {
                connectionError = nil
            }
        } catch is OverseerrError { // More specific: catch OverseerrError
            // Auth errors are primarily handled by OverseerrUsersViewModel's authState
            // and AuthManager. This VM doesn't need to set connectionError for this.
            loader.cancelLoading()
            print("Trending fetch failed due to OverseerrError.")
        } catch {
            loader.cancelLoading()
            // Only set error if items are empty, otherwise it might be a pagination error
            // and some content is still visible. Or, always show if it's a significant failure.
            if items.isEmpty {
                connectionError = "Failed to load trending items. \(error.localizedDescription)"
            }
            print("Trending fetch failed: \(error)")
        }
    }
}
