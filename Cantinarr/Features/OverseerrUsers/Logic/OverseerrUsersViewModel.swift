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

    private struct SavedFilters: Codable {
        let mediaType: MediaType
        let providerIds: [Int]
        let genreIds: [Int]
    }

    // ─────────────────────────────────────────────

    // MARK: – Published state

    // ─────────────────────────────────────────────
    @Published var selectedMedia: MediaType = .movie {
        didSet {
            guard oldValue != selectedMedia else { return }
            saveFilters()
            // Reload discover media based on the new type, respecting keywords if active
            Task { await loadMedia(reset: true) }
        }
    }

    @Published var watchProviders: [OverseerrAPIService.WatchProvider] = []
    @Published var selectedProviders: Set<Int> = [] {
        didSet {
            guard oldValue != selectedProviders else { return }
            saveFilters()
            Task { await loadMedia(reset: true) }
        }
    }

    @Published var selectedGenres: Set<Int> = [] {
        didSet {
            guard oldValue != selectedGenres else { return }
            saveFilters()
            Task { await loadMedia(reset: true) }
        }
    }

    @Published var results: [MediaItem] = [] // Discover or Search results
    @Published var keywordSuggestions: [OverseerrAPIService.Keyword] = []
    @Published var activeKeywordIDs: Set<Int> = [] // Filter state
    @Published var activeKeywords: [OverseerrAPIService.Keyword] = [] // Display state for pills
    @Published var movieRecs: [MediaItem] = []
    @Published var tvRecs: [MediaItem] = []

    @Published private(set) var authState: OverseerrAuthState = .unknown
    @Published var connectionError: String? = nil

    @Published var sessionToken: String? = nil
    @Published var searchQuery: String = ""
    @Published private var recBaseID: Int?

    // Loading states
    @Published private(set) var isLoading: Bool = false // General loading (Discover/Search)
    @Published private(set) var isLoadingKeywords = false
    @Published private(set) var isLoadingMovieRecs = false
    @Published private(set) var isLoadingTvRecs = false
    var isLoadingSearch: Bool { isLoading && !searchQuery.isEmpty }

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
    private var movieRecLoader = PagedLoader()
    private var tvRecLoader = PagedLoader()

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
        self.plexSSOHandler = PlexSSOHandler(
            service: service,
            settingsKey: settingsKey,
            authContext: authContext
        )

        loadSavedFilters()
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

        $searchQuery
            .removeDuplicates()
            .debounce(for: .seconds(AppConfig.debounceInterval), scheduler: RunLoop.main)
            .sink { [weak self] text in
                guard let self = self else { return }
                Task { await self.handleSearchChange(text) }
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
        results.removeAll()
        keywordSuggestions.removeAll()
        movieRecs.removeAll()
        tvRecs.removeAll()
        recBaseID = nil
        loader.reset()
        movieRecLoader.reset()
        tvRecLoader.reset()
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

            if selectedProviders.isEmpty && !watchProviders.isEmpty {
                selectedProviders = Set(watchProviders.map(\.id))
                saveFilters()
            }
            clearConnectionError()
            if case .authenticated = authState, results.isEmpty && searchQuery.isEmpty && activeKeywordIDs.isEmpty {
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

        let pids = Array(selectedProviders)
        let gids = Array(selectedGenres)
        let kwds = Array(activeKeywordIDs) // Use active keywords here

        do {
            let fetchedItems: [MediaItem]
            let responsePage: Int
            let responseTotalPages: Int

            // Call the appropriate API based on the selected media type
            switch selectedMedia {
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
                print("⚠️ Unsupported media type for discover: \(selectedMedia)")
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
            print("🔴 Media load error (\(selectedMedia)): \(error.localizedDescription)")
            loader.cancelLoading()
            if loader.page == 1 || results.isEmpty {
                connectionError = "Failed to load \(selectedMedia.displayName). \(error.localizedDescription)"
            }
        }
    }

    // ─────────────────────────────────────────────

    // MARK: – Search Handling

    // ─────────────────────────────────────────────
    private func handleSearchChange(_ text: String) async {
        if text.isEmpty {
            // Search cleared. Reload the Discover view, respecting active keywords.
            // Don't clear keywords here.
            clearSearchResultsAndRecs() // Clear previous search results/recs
            await loadMedia(reset: true) // Reload discover (will use active keywords if present)
            return
        }

        // --- Start New Text Search ---
        // Text search is active. Keywords remain *in memory* but search results take display precedence.
        clearConnectionError()
        clearSearchResultsAndRecs() // Clear old results/recs

        // Perform text search (ignores keywords)
        await searchMedia(reset: true)

        guard connectionError == nil else { return } // Stop if search failed

        // Fetch keyword suggestions for the text
        await fetchKeywordSuggestions(for: text)

        // Fetch recommendations based on the first search result
        if let firstResultItem = results.first {
            await fetchRecommendations(for: firstResultItem.id, mediaType: firstResultItem.mediaType)
        }
    }

    private func searchMedia(reset: Bool = false) async {
        // Perform a text search that ignores keyword filters.
        // Bail out if another request is already running.
        guard !isLoading else { return }
        if reset {
            loader.reset()
            results.removeAll() // Clear previous results (could be search or discover)
            clearConnectionError()
        }

        // Guard ensures we don't fetch past the last page
        guard loader.beginLoading() else { return }
        isLoading = true
        defer { isLoading = false; loader.endLoading(next: loader.totalPages) }

        do {
            // Query Overseerr for matching movies/TV shows
            let resp = try await service.search(query: searchQuery, page: loader.page)
            // Drop any search results that aren't movies or TV
            let items = resp.results.compactMap { raw -> MediaItem? in
                guard let kind = raw.mediaType, kind == .movie || kind == .tv else { return nil }
                return MediaItem(
                    id: raw.id,
                    title: raw.title ?? raw.name ?? "Untitled",
                    posterPath: raw.posterPath,
                    mediaType: kind
                )
            }

            if loader.page == 1 { results = items }
            else { results.append(contentsOf: items) }
            loader.endLoading(next: resp.totalPages)

            if !watchProviders.isEmpty { clearConnectionError() }
        } catch is OverseerrError {
            loader.cancelLoading(); recoverFromAuthFailure()
        } catch {
            print("🔴 Search error: \(error.localizedDescription)")
            loader.cancelLoading()
            if loader.page == 1 || results.isEmpty {
                connectionError = "Search failed. \(error.localizedDescription)"
            }
        }
    }

    // MARK: – Keyword Fetching & Filtering - (Unchanged from previous correct version)

    private func fetchKeywordSuggestions(for query: String) async {
        // Kick off a keyword autocomplete query
        isLoadingKeywords = true
        var keywordFetchError: String? = nil
        do {
            let raw = try await service.keywordSearch(query: query)
            keywordSuggestions = await filterUsableKeywords(raw)
        } catch is OverseerrError {
            // Handled by recoverFromAuthFailure
        } catch {
            keywordSuggestions = []
            keywordFetchError = "Failed to load keyword suggestions. \(error.localizedDescription)"
            print("🔴 Keyword search error: \(error.localizedDescription)")
        }
        isLoadingKeywords = false
        // Surface any error only if another error isn't already shown
        if connectionError == nil && keywordFetchError != nil {
            connectionError = keywordFetchError
        }
    }

    // MARK: – Keyword Activation

    func activate(keyword k: OverseerrAPIService.Keyword) {
        // Ignore if already active
        guard !activeKeywordIDs.contains(k.id) else { return }
        // Activating a keyword takes precedence over any text search
        searchQuery = "" // Clear search field binding
        activeKeywordIDs.insert(k.id)
        // Avoid duplicate display names if somehow added twice
        if !activeKeywords.contains(where: { $0.id == k.id }) {
            activeKeywords.append(k)
            activeKeywords.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
        clearSearchResultsAndRecs() // Clear previous results
//        // Signal the UI to switch to the Advanced tab
//        onKeywordActivated?() // <<< CALL THE CALLBACK
        // ** Send signal via subject instead of calling callback **
        keywordActivatedSubject.send()
        // Load discover results filtered by the new keyword set
        Task { await loadMedia(reset: true) }
    }

    func remove(keywordID: Int) {
        // Remove keyword from both the ID set and display list
        activeKeywordIDs.remove(keywordID)
        activeKeywords.removeAll { $0.id == keywordID }
        // If search is active, removing keyword doesn't change search results immediately.
        // If search is *not* active, reload the discover view with updated keywords.
        if searchQuery.isEmpty {
            Task { await loadMedia(reset: true) }
        }
    }

    private func filterUsableKeywords(
        _ raw: [OverseerrAPIService.Keyword]
    ) async -> [OverseerrAPIService.Keyword] {
        // Probe each keyword in parallel by attempting a quick discover search.
        await withTaskGroup(of: OverseerrAPIService.Keyword?.self) { group in
            for kw in raw {
                group.addTask { [weak self] in
                    guard let self = self else { return nil }
                    do {
                        let movies = try await self.service.fetchMovies(
                            providerIds: [],
                            genreIds: [],
                            keywordIds: [kw.id],
                            page: 1
                        )
                        if !movies.results.isEmpty { return kw }
                        let tv = try await self.service.fetchTV(
                            providerIds: [],
                            genreIds: [],
                            keywordIds: [kw.id],
                            page: 1
                        )
                        if !tv.results.isEmpty { return kw }
                    } catch is OverseerrError {
                        await self.recoverFromAuthFailure()
                    } catch {
                        print("⚠️ Error probing keyword \(kw.name): \(error.localizedDescription)")
                    }
                    return nil
                }
            }
            var usable: [OverseerrAPIService.Keyword] = []
            for await maybe in group {
                if let kw = maybe { usable.append(kw) }
            }
            // Sort alphabetically for stable presentation
            return usable.sorted(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending })
        }
    }

    // MARK: – Recommendation Fetching - (Unchanged from previous correct version)

    private func fetchRecommendations(for baseItemId: Int, mediaType _: MediaType) async {
        recBaseID = baseItemId
        movieRecLoader.reset(); tvRecLoader.reset()
        movieRecs.removeAll(); tvRecs.removeAll()

        isLoadingMovieRecs = true
        isLoadingTvRecs = true
        var movieFetchError: Error?
        var tvFetchError: Error?

        // Fetch Movie Recs
        do {
            let resp = try await service.movieRecommendations(for: baseItemId, page: movieRecLoader.page)
            movieRecs = resp.results.map { MediaItem(
                id: $0.id,
                title: $0.title,
                posterPath: $0.posterPath,
                mediaType: .movie
            ) }
            movieRecLoader.endLoading(next: resp.totalPages)
        } catch is OverseerrError {
            recoverFromAuthFailure(); movieFetchError = OverseerrError.notAuthenticated
        } catch {
            movieFetchError = error; print("🔴 Movie recommendations error: \(error.localizedDescription)")
            movieRecs = []; movieRecLoader.reset()
        }
        isLoadingMovieRecs = false

        // Fetch TV Recs
        do {
            let resp = try await service.tvRecommendations(for: baseItemId, page: tvRecLoader.page)
            tvRecs = resp.results
                .map { MediaItem(id: $0.id, title: $0.name, posterPath: $0.posterPath, mediaType: .tv) }
            tvRecLoader.endLoading(next: resp.totalPages)
        } catch is OverseerrError {
            recoverFromAuthFailure(); tvFetchError = OverseerrError.notAuthenticated
        } catch {
            tvFetchError = error; print("🔴 TV recommendations error: \(error.localizedDescription)")
            tvRecs = []; tvRecLoader.reset()
        }
        isLoadingTvRecs = false

        // Error Reporting
        if let mvErr = movieFetchError, !(mvErr is OverseerrError),
           let tvErr = tvFetchError, !(tvErr is OverseerrError)
        {
            connectionError = "Failed to load recommendations."
        } else if connectionError == nil && (movieFetchError != nil || tvFetchError != nil) {
            if let mvErr = movieFetchError,
               !(mvErr is OverseerrError)
            {
                connectionError = "Failed to load movie recommendations. \(mvErr.localizedDescription)"
            } else if let tvErr = tvFetchError,
                      !(tvErr is OverseerrError)
            {
                connectionError = "Failed to load TV recommendations. \(tvErr.localizedDescription)"
            }
        } else if connectionError == nil && movieFetchError == nil && tvFetchError == nil {
            clearConnectionError()
        }
    }

    // MARK: – Pagination Logic (Discover/Search, Recs) - (Unchanged from previous correct version)

    func loadMoreIfNeeded(current item: MediaItem, within list: [MediaItem]) {
        let thresholdIndex = list.index(list.endIndex, offsetBy: -AppConfig.prefetchThreshold)
        guard let currentIndex = list.firstIndex(where: { $0.id == item.id }),
              currentIndex >= thresholdIndex else { return }

        Task {
            if !searchQuery.isEmpty { await searchMedia() }
            else { await loadMedia() }
        }
    }

    func loadMoreMovieRecsIfNeeded(current item: MediaItem) {
        guard let baseID = recBaseID else { return }
        guard movieRecLoader.page <= movieRecLoader.totalPages, !isLoadingMovieRecs else { return }
        let thresholdIndex = movieRecs.index(movieRecs.endIndex, offsetBy: -AppConfig.prefetchThreshold)
        guard let currentIndex = movieRecs.firstIndex(where: { $0.id == item.id }),
              currentIndex >= thresholdIndex else { return }
        guard movieRecLoader.beginLoading() else { return }

        isLoadingMovieRecs = true
        Task {
            defer { isLoadingMovieRecs = false; movieRecLoader.endLoading(next: movieRecLoader.totalPages) }
            do {
                let resp = try await service.movieRecommendations(for: baseID, page: movieRecLoader.page)
                let more = resp.results.map { MediaItem(
                    id: $0.id,
                    title: $0.title,
                    posterPath: $0.posterPath,
                    mediaType: .movie
                ) }
                movieRecs.append(contentsOf: more)
                movieRecLoader.endLoading(next: resp.totalPages)
            } catch is OverseerrError {
                movieRecLoader.cancelLoading(); recoverFromAuthFailure()
            } catch {
                movieRecLoader
                    .cancelLoading(); print("🔴 Error loading more movie recommendations: \(error.localizedDescription)")
            }
        }
    }

    func loadMoreTvRecsIfNeeded(current item: MediaItem) {
        guard let baseID = recBaseID else { return }
        guard tvRecLoader.page <= tvRecLoader.totalPages, !isLoadingTvRecs else { return }
        let thresholdIndex = tvRecs.index(tvRecs.endIndex, offsetBy: -AppConfig.prefetchThreshold)
        guard let currentIndex = tvRecs.firstIndex(where: { $0.id == item.id }),
              currentIndex >= thresholdIndex else { return }
        guard tvRecLoader.beginLoading() else { return }

        isLoadingTvRecs = true
        Task {
            defer { isLoadingTvRecs = false; tvRecLoader.endLoading(next: tvRecLoader.totalPages) }
            do {
                let resp = try await service.tvRecommendations(for: baseID, page: tvRecLoader.page)
                let more = resp.results.map { MediaItem(
                    id: $0.id,
                    title: $0.name,
                    posterPath: $0.posterPath,
                    mediaType: .tv
                ) }
                tvRecs.append(contentsOf: more)
                tvRecLoader.endLoading(next: resp.totalPages)
            } catch is OverseerrError {
                tvRecLoader.cancelLoading(); recoverFromAuthFailure()
            } catch {
                tvRecLoader
                    .cancelLoading(); print("🔴 Error loading more TV recommendations: \(error.localizedDescription)")
            }
        }
    }

    // MARK: – Persistence (Filters, Token) - Unchanged

    private func loadSavedFilters() {
        let key = "discoverFilters-\(settingsKey)"
        guard let data = UserDefaults.standard.data(forKey: key),
              let saved = try? JSONDecoder().decode(SavedFilters.self, from: data)
        else { return }
        _selectedMedia = Published(initialValue: saved.mediaType)
        _selectedProviders = Published(initialValue: Set(saved.providerIds))
        _selectedGenres = Published(initialValue: Set(saved.genreIds))
    }

    private func saveFilters() {
        let saved = SavedFilters(
            mediaType: selectedMedia,
            providerIds: Array(selectedProviders),
            genreIds: Array(selectedGenres)
        )
        if let data = try? JSONEncoder().encode(saved) {
            UserDefaults.standard.set(data, forKey: "discoverFilters-\(settingsKey)")
        }
    }

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
