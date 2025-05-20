import AuthenticationServices
import Combine
import SwiftUI

@MainActor
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

    @Published private(set) var authState: AuthState = .unknown
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
        Task { await AuthManager.shared.recoverFromAuthFailure() }
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
    private let authContext = AuthContextProvider()
    private var tokenKey: String { "plexAuthToken-\(settingsKey)" }
    private var authCancellable: AnyCancellable?
    let keywordActivatedSubject = PassthroughSubject<Void, Never>()

    // ─────────────────────────────────────────────

    // MARK: – Init

    // ─────────────────────────────────────────────
    init(service: OverseerrUsersService, settingsKey: String, onKeywordActivated _: (() -> Void)? = nil) {
        // Added callback
        self.service = service
        self.settingsKey = settingsKey

        loadSavedFilters()
        AuthHelper.shared.delegate = self

        $searchQuery
            .removeDuplicates()
            .debounce(for: .seconds(AppConfig.debounceInterval), scheduler: RunLoop.main)
            .sink { [weak self] text in
                guard let self = self else { return }
                Task { await self.handleSearchChange(text) }
            }
            .store(in: &cancellables)

        authCancellable = AuthManager.shared.publisher
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
        Task { await AuthManager.shared.ensureAuthenticated() }
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
        } catch is AuthError {
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
        // This loads "Discover" results, filtered by active keywords if present.
        guard !isLoading else { return }
        if reset {
            loader.reset()
            results.removeAll() // Clear previous results (could be search or discover)
            clearConnectionError()
        }

        guard loader.beginLoading() else { return }
        isLoading = true
        defer { isLoading = false; loader.endLoading(next: loader.totalPages) }

        let pids = Array(selectedProviders)
        let gids = Array(selectedGenres)
        let kwds = Array(activeKeywordIDs) // Use active keywords here

        do {
            let fetchedItems: [MediaItem]
            let responsePage: Int
            let responseTotalPages: Int

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

            if loader.page == 1 { results = fetchedItems }
            else { results.append(contentsOf: fetchedItems) }
            loader.endLoading(next: responseTotalPages)

            if !watchProviders.isEmpty { clearConnectionError() }
        } catch is AuthError {
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
        // This performs a text search, IGNORING active keywords.
        guard !isLoading else { return }
        if reset {
            loader.reset()
            results.removeAll() // Clear previous results (could be search or discover)
            clearConnectionError()
        }

        guard loader.beginLoading() else { return }
        isLoading = true
        defer { isLoading = false; loader.endLoading(next: loader.totalPages) }

        do {
            let resp = try await service.search(query: searchQuery, page: loader.page)
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
        } catch is AuthError {
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
        isLoadingKeywords = true
        var keywordFetchError: String? = nil
        do {
            let raw = try await service.keywordSearch(query: query)
            keywordSuggestions = await filterUsableKeywords(raw)
        } catch is AuthError {
            // Handled by recoverFromAuthFailure
        } catch {
            keywordSuggestions = []
            keywordFetchError = "Failed to load keyword suggestions. \(error.localizedDescription)"
            print("🔴 Keyword search error: \(error.localizedDescription)")
        }
        isLoadingKeywords = false
        if connectionError == nil && keywordFetchError != nil {
            connectionError = keywordFetchError
        }
    }

    // MARK: – Keyword Activation

    func activate(keyword k: OverseerrAPIService.Keyword) {
        guard !activeKeywordIDs.contains(k.id) else { return }
        // Activating a keyword takes precedence over search.
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
                    } catch is AuthError {
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
        } catch is AuthError {
            recoverFromAuthFailure(); movieFetchError = AuthError.notAuthenticated
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
        } catch is AuthError {
            recoverFromAuthFailure(); tvFetchError = AuthError.notAuthenticated
        } catch {
            tvFetchError = error; print("🔴 TV recommendations error: \(error.localizedDescription)")
            tvRecs = []; tvRecLoader.reset()
        }
        isLoadingTvRecs = false

        // Error Reporting
        if let mvErr = movieFetchError, !(mvErr is AuthError),
           let tvErr = tvFetchError, !(tvErr is AuthError)
        {
            connectionError = "Failed to load recommendations."
        } else if connectionError == nil && (movieFetchError != nil || tvFetchError != nil) {
            if let mvErr = movieFetchError,
               !(mvErr is AuthError)
            {
                connectionError = "Failed to load movie recommendations. \(mvErr.localizedDescription)"
            } else if let tvErr = tvFetchError,
                      !(tvErr is AuthError)
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
            } catch is AuthError {
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
            } catch is AuthError {
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

    private func saveTokenToKeychain(_ token: String) {
        if let data = token.data(using: .utf8) {
            KeychainHelper.save(key: tokenKey, data: data)
        }
    }

    private func loadTokenFromKeychain() -> String? {
        guard let data = KeychainHelper.load(key: tokenKey),
              let token = String(data: data, encoding: .utf8)
        else { return nil }
        return token
    }

    private func deleteTokenFromKeychain() {
        KeychainHelper.delete(key: tokenKey)
        sessionToken = nil
    }

    // MARK: – Plex SSO - Unchanged

    private let clientID: String = {
        let key = "PlexClientID"
        if let existing = UserDefaults.standard.string(forKey: key) { return existing }
        let uuid = UUID().uuidString
        UserDefaults.standard.set(uuid, forKey: key)
        return uuid
    }()

    private let productName = "Cantinarr"

    func startPlexSSO(host _: String, port _: String?) {
        Task {
            do {
                let pin = try await fetchPlexPIN()
                let plexURL = buildPlexOAuthURL(code: pin.code)
                let web = ASWebAuthenticationSession(url: plexURL, callbackURLScheme: nil) { callbackURL, error in
                    print(
                        "ASWebAuthenticationSession completed. URL: \(callbackURL?.absoluteString ?? "nil"), Error: \(error?.localizedDescription ?? "nil")"
                    )
                }
                web.presentationContextProvider = authContext
                web.prefersEphemeralWebBrowserSession = true
                web.start()

                let authToken = try await pollForPlexToken(pinID: pin.id, code: pin.code)

                try await service.loginWithPlexToken(authToken)
                saveTokenToKeychain(authToken)
                sessionToken = authToken

                await AuthManager.shared.probeSession()

            } catch {
                print("🔴 Plex SSO failed: \(error.localizedDescription)")
                self.connectionError = "Plex login failed. Please try again. (\(error.localizedDescription))"
                self.authState = .unauthenticated
            }
        }
    }

    private struct PlexPIN: Decodable { let id: Int; let code: String; let authToken: String? }

    private func fetchPlexPIN() async throws -> PlexPIN {
        var req = URLRequest(url: URL(string: "https://plex.tv/api/v2/pins?strong=true")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue(productName, forHTTPHeaderField: "X-Plex-Product")
        req.setValue(clientID, forHTTPHeaderField: "X-Plex-Client-Identifier")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 201 else {
            throw URLError(
                .badServerResponse,
                userInfo: [
                    NSLocalizedDescriptionKey: "Failed to fetch Plex PIN (status: \((resp as? HTTPURLResponse)?.statusCode ?? 0))",
                ]
            )
        }
        return try JSONDecoder().decode(PlexPIN.self, from: data)
    }

    private func pollForPlexToken(pinID: Int, code _: String) async throws -> String {
        for _ in 0 ..< 120 {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            let url = URL(string: "https://plex.tv/api/v2/pins/\(pinID)")!
            var req = URLRequest(url: url)
            req.setValue("application/json", forHTTPHeaderField: "Accept")
            req.setValue(clientID, forHTTPHeaderField: "X-Plex-Client-Identifier")
            req.setValue(productName, forHTTPHeaderField: "X-Plex-Product")

            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else { continue }
            if http.statusCode == 404 { throw URLError(
                .cancelled,
                userInfo: [NSLocalizedDescriptionKey: "Plex PIN expired or invalid."]
            ) }
            guard http.statusCode == 200 else { continue }

            guard let status = try? JSONDecoder().decode(PlexPIN.self, from: data) else { continue }
            if let token = status.authToken, !token.isEmpty { return token }
        }
        throw URLError(.timedOut, userInfo: [NSLocalizedDescriptionKey: "Plex login timed out."])
    }

    private func buildPlexOAuthURL(code: String) -> URL {
        let params = [
            "clientID": clientID,
            "code": code,
            "context[device][product]": productName,
        ]
        let frag = params.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        return URL(string: "https://app.plex.tv/auth#?\(frag)")!
    }
}

extension OverseerrUsersViewModel: PlexSSODelegate {
    func didReceivePlexToken(_ token: String) {
        print("⚠️ Received Plex Token via delegate (Legacy/Unexpected): \(token)")
    }
}
