// File: OverseerrUsersViewModel.swift
// Purpose: Defines OverseerrUsersViewModel component for Cantinarr

import AuthenticationServices
import Combine
import SwiftUI
import WebKit

@MainActor
/// Main view model driving Overseerr's user interface.
class OverseerrUsersViewModel: ObservableObject {
    // ─────────────────────────────────────────────

    // MARK: – Nested types

    // ─────────────────────────────────────────────
    struct MediaItem: Identifiable {
        let id: Int
        let title: String
        let posterPath: String?
        let mediaType: MediaType
    }

    @Published var filters: FilterManager

    // ─────────────────────────────────────────────

    // MARK: – Published state

    // ─────────────────────────────────────────────
    // Filter state handled by `filters`
    @Published var watchProviders: [OverseerrAPIService.WatchProvider] = []

    lazy var searchController: SearchController = {
        let controller = SearchController(
            service: service,
            filters: filters,
            keywordActivatedSubject: keywordActivatedSubject,
            recoverAuth: { [weak self] in self?.recoverFromAuthFailure() },
            clearConnectionError: { [weak self] in self?.clearConnectionError() },
            setConnectionError: { [weak self] msg in self?.connectionError = msg },
            loadDiscover: { [weak self] reset in await self?.loadMedia(reset: reset) }
        )
        controller.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        return controller
    }()

    @Published private(set) var authState: OverseerrAuthState = .unknown
    @Published var connectionError: String? = nil

    @Published var sessionToken: String? = nil
    @Published private(set) var isLoading: Bool = false // Discover loading
    var searchQuery: String { get { searchController.searchQuery } set { searchController.searchQuery = newValue } }
    private(set) var results: [MediaItem] {
        get { searchController.results }
        set { searchController.results = newValue }
    }
    private(set) var keywordSuggestions: [OverseerrAPIService.Keyword] {
        get { searchController.keywordSuggestions }
        set { searchController.keywordSuggestions = newValue }
    }
    private(set) var activeKeywords: [OverseerrAPIService.Keyword] {
        get { searchController.activeKeywords }
        set { searchController.activeKeywords = newValue }
    }
    private(set) var movieRecs: [MediaItem] {
        get { searchController.movieRecs }
        set { searchController.movieRecs = newValue }
    }
    private(set) var tvRecs: [MediaItem] {
        get { searchController.tvRecs }
        set { searchController.tvRecs = newValue }
    }
    var isLoadingSearch: Bool { searchController.isLoadingSearch }
    var isLoadingKeywords: Bool { searchController.isLoadingKeywords }
    var isLoadingMovieRecs: Bool { searchController.isLoadingMovieRecs }
    var isLoadingTvRecs: Bool { searchController.isLoadingTvRecs }

    private var cancellables = Set<AnyCancellable>()

    // MARK: – Auth recovery helper

    private func recoverFromAuthFailure() {
        if authState == .unknown { return }
        authState = .unknown
        Task { await OverseerrAuthManager.shared.recoverFromAuthFailure() }
    }

    // ─────────────────────────────────────────────

    // MARK: – Paging Helpers

    // ─────────────────────────────────────────────
    private var loader = PagedLoader()

    // ─────────────────────────────────────────────

    // MARK: – Dependencies & Callbacks

    // ─────────────────────────────────────────────
    var service: OverseerrUsersService
    private let settingsKey: String
    private let authContext = OverseerrAuthContextProvider()
    private let plexSSOHandler: PlexSSOHandler
    private var authCancellable: AnyCancellable?
    private var plexSSOTask: Task<Void, Never>?
    let keywordActivatedSubject = PassthroughSubject<Void, Never>()

    // ─────────────────────────────────────────────

    // MARK: – Init

    // ─────────────────────────────────────────────
    init(service: OverseerrUsersService, settingsKey: String, onKeywordActivated _: (() -> Void)? = nil) {
        // Added callback
        self.service = service
        self.settingsKey = settingsKey
        self.filters = FilterManager()
        self.plexSSOHandler = PlexSSOHandler(
            service: service,
            settingsKey: settingsKey,
            authContext: authContext
        )

        if let savedToken = plexSSOHandler.loadTokenFromKeychain() {
            sessionToken = savedToken
            Task {
                do {
                    try await service.loginWithPlexToken(savedToken)
                    await OverseerrAuthManager.shared.probeSession()
                } catch {
                    print("Failed to restore Plex token: \(error.localizedDescription)")
                    plexSSOHandler.deleteTokenFromKeychain()
                }
            }
        }
        OverseerrAuthHelper.shared.delegate = self

        filters.$selectedMedia
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] _ in
                Task { await self?.loadMedia(reset: true) }
            }
            .store(in: &cancellables)

        filters.$selectedProviders
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] _ in
                Task { await self?.loadMedia(reset: true) }
            }
            .store(in: &cancellables)

        filters.$selectedGenres
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] _ in
                Task { await self?.loadMedia(reset: true) }
            }
            .store(in: &cancellables)

        authCancellable = OverseerrAuthManager.shared.publisher
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                guard let self = self else { return }
                let previousState = self.authState
                self.authState = state
                let wasAuthenticated = { if case .authenticated = previousState { return true } else { return false }
                }()
                let isAuthenticatedNow = { if case .authenticated = state { return true } else { return false } }()
                if !wasAuthenticated && isAuthenticatedNow { Task { await self.loadAllBasics() } }
            }
    }

    // ─────────────────────────────────────────────

    // MARK: – View life‑cycle / Entry Points

    // ─────────────────────────────────────────────
    func onAppear() {
        Task { await OverseerrAuthManager.shared.ensureAuthenticated() }
    }

    private func clearConnectionError() {
        if connectionError != nil { connectionError = nil }
    }

    func clearSearchResultsAndRecs() {
        searchController.clearSearchResultsAndRecs()
    }

    func activate(keyword k: OverseerrAPIService.Keyword) {
        searchController.activate(keyword: k)
    }

    func remove(keywordID: Int) {
        searchController.remove(keywordID: keywordID)
    }

    // ─────────────────────────────────────────────

    // MARK: – Initial data load (Providers, etc.)

    // ─────────────────────────────────────────────
    func loadAllBasics() async {
        clearConnectionError()
        do {
            async let movieProviders = service.fetchWatchProviders(isMovie: true)
            async let tvProviders = service.fetchWatchProviders(isMovie: false)
            let combined = try await(movieProviders + tvProviders)
            let unique = Dictionary(grouping: combined, by: \.id).compactMap { $0.value.first }
            watchProviders = unique
                .sorted(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending })

            if filters.selectedProviders.isEmpty && !watchProviders.isEmpty {
                filters.selectedProviders = Set(watchProviders.map(\.id))
            }
            clearConnectionError()
            if case .authenticated = authState, results.isEmpty && searchQuery.isEmpty && filters.activeKeywordIDs.isEmpty {
                await loadMedia(reset: true)
            }
        } catch is OverseerrError {
            recoverFromAuthFailure()
        } catch {
            print("🔴 Provider load error: \(error.localizedDescription)")
            connectionError = "Failed to load service configuration. \(error.localizedDescription)"
            watchProviders = []
        }
    }

    // ─────────────────────────────────────────────

    // MARK: – Media fetching (Discover - respects active keywords)

    // ─────────────────────────────────────────────
    func loadMedia(reset: Bool = false) async {
        // Load "Discover" results, applying any active keyword filters.
        // Skip if a request is already underway.
        guard !isLoading else { return }
        if reset {
            loader.reset()
            results.removeAll() // Clear previous results (could be search or discover)
            clearConnectionError()
        }

        // Begin the next page fetch. `beginLoading` returns false when there are
        // no more pages to load or another load is active.
        guard loader.beginLoading() else { return }
        isLoading = true
        // Ensure counters and state are updated no matter how we exit.
        defer { isLoading = false; loader.endLoading(next: loader.totalPages) }

        let pids = Array(filters.selectedProviders)
        let gids = Array(filters.selectedGenres)
        let kwds = Array(filters.activeKeywordIDs) // Use active keywords here

        do {
            let fetchedItems: [MediaItem]
            let responsePage: Int
            let responseTotalPages: Int

            // Call the appropriate API based on the selected media type
            switch filters.selectedMedia {
            case .movie:
                let rawResp = try await service.fetchMovies(
                    providerIds: pids,
                    genreIds: gids,
                    keywordIds: kwds,
                    page: loader.page
                )
                fetchedItems = rawResp.results.map { MediaItem(
                    id: $0.id,
                    title: $0.title,
                    posterPath: $0.posterPath,
                    mediaType: .movie
                ) }
                responsePage = rawResp.page; responseTotalPages = rawResp.totalPages
            case .tv:
                let rawResp = try await service.fetchTV(
                    providerIds: pids,
                    genreIds: gids,
                    keywordIds: kwds,
                    page: loader.page
                )
                fetchedItems = rawResp.results.map { MediaItem(
                    id: $0.id,
                    title: $0.name,
                    posterPath: $0.posterPath,
                    mediaType: .tv
                ) }
                responsePage = rawResp.page; responseTotalPages = rawResp.totalPages
            case .person, .collection, .unknown:
                print("⚠️ Unsupported media type for discover: \(filters.selectedMedia)")
                loader.cancelLoading(); return
            }

            // Merge the new page results with existing content
            if loader.page == 1 { results = fetchedItems }
            else { results.append(contentsOf: fetchedItems) }
            loader.endLoading(next: responseTotalPages)

            if !watchProviders.isEmpty { clearConnectionError() }
        } catch is OverseerrError {
            loader.cancelLoading(); recoverFromAuthFailure()
        } catch {
            print("🔴 Media load error (\(filters.selectedMedia)): \(error.localizedDescription)")
            loader.cancelLoading()
            if loader.page == 1 || results.isEmpty {
                connectionError = "Failed to load \(filters.selectedMedia.displayName). \(error.localizedDescription)"
            }
        }
    }

    // ─────────────────────────────────────────────

    // MARK: – Search Handling

    // ─────────────────────────────────────────────
    // MARK: – Pagination Logic (Discover/Search, Recs) - (Unchanged from previous correct version)

    func loadMoreIfNeeded(current item: MediaItem, within list: [MediaItem]) {
        searchController.loadMoreIfNeeded(current: item, within: list)
    }

    func loadMoreMovieRecsIfNeeded(current item: MediaItem) {
        searchController.loadMoreMovieRecsIfNeeded(current: item)
    }

    func loadMoreTvRecsIfNeeded(current item: MediaItem) {
        searchController.loadMoreTvRecsIfNeeded(current: item)
    }

    // MARK: – Persistence handled by FilterManager

    /// Log out the current user, clearing session cookies and stored token.
    func logout() {
        plexSSOHandler.deleteTokenFromKeychain()
        sessionToken = nil
        // Remove all cookies from shared storage
        let cookieStore = HTTPCookieStorage.shared
        cookieStore.cookies?.forEach { cookieStore.deleteCookie($0) }

        let wkStore = WKWebsiteDataStore.default().httpCookieStore
        wkStore.getAllCookies { cookies in
            for c in cookies { wkStore.delete(c) }
        }

        Task { await OverseerrAuthManager.shared.probeSession() }
    }

    // MARK: – Plex SSO

    func startPlexSSO(host _: String, port _: String?) {
        plexSSOTask?.cancel()
        plexSSOTask = Task {
            do {
                let token = try await plexSSOHandler.startLogin()
                sessionToken = token
                await OverseerrAuthManager.shared.probeSession()
                plexSSOTask = nil
            } catch is CancellationError {
                plexSSOTask = nil
            } catch {
                if case .authenticated = OverseerrAuthManager.shared.value {
                    return
                }
                print("🔴 Plex SSO failed: \(error.localizedDescription)")
                self.connectionError = "Plex login failed. Please try again. (\(error.localizedDescription))"
                self.authState = .unauthenticated
                plexSSOTask = nil
            }
        }
    }

}

extension OverseerrUsersViewModel: OverseerrPlexSSODelegate {
    func didReceivePlexToken(_ token: String) {
        print("⚠️ Received Plex Token via delegate (Legacy/Unexpected): \(token)")
    }
}
