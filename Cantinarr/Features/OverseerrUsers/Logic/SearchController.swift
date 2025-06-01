#if canImport(Combine) && canImport(SwiftUI)
import Combine
import Foundation

@MainActor
final class SearchController: ObservableObject {

    // Published search state
    @Published var searchQuery: String = ""
    @Published var results: [MediaItem] = []
    @Published var keywordSuggestions: [Keyword] = []
    @Published var activeKeywords: [Keyword] = []
    @Published var movieRecs: [MediaItem] = []
    @Published var tvRecs: [MediaItem] = []

    @Published private var recBaseID: Int?
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingKeywords = false
    @Published private(set) var isLoadingMovieRecs = false
    @Published private(set) var isLoadingTvRecs = false
    var isLoadingSearch: Bool { isLoading && !searchQuery.isEmpty }

    // Combine publishers for observers
    var searchResultsPublisher: AnyPublisher<[MediaItem], Never> { $results.eraseToAnyPublisher() }
    var keywordSuggestionsPublisher: AnyPublisher<[Keyword], Never> {
        $keywordSuggestions.eraseToAnyPublisher()
    }

    private let service: OverseerrUsersService
    private let filters: FilterManager
    private let recoverAuth: () -> Void
    private let clearConnError: () -> Void
    private let setConnectionError: (String?) -> Void
    private let loadDiscover: (Bool) async -> Void
    let keywordActivatedSubject: PassthroughSubject<Void, Never>

    private var cancellables = Set<AnyCancellable>()
    private var loader = PagedLoader()
    private var movieRecLoader = PagedLoader()
    private var tvRecLoader = PagedLoader()
    private var connectionError: String? = nil

    init(
        service: OverseerrUsersService,
        filters: FilterManager,
        keywordActivatedSubject: PassthroughSubject<Void, Never>,
        recoverAuth: @escaping () -> Void,
        clearConnectionError: @escaping () -> Void,
        setConnectionError: @escaping (String?) -> Void,
        loadDiscover: @escaping (Bool) async -> Void
    ) {
        self.service = service
        self.filters = filters
        self.keywordActivatedSubject = keywordActivatedSubject
        self.recoverAuth = recoverAuth
        clearConnError = clearConnectionError
        self.setConnectionError = setConnectionError
        self.loadDiscover = loadDiscover

        $searchQuery
            .removeDuplicates()
            .debounce(for: .seconds(AppConfig.debounceInterval), scheduler: RunLoop.main)
            .sink { [weak self] text in
                guard let self = self else { return }
                Task { await self.handleSearchChange(text) }
            }
            .store(in: &cancellables)
    }

    // Reset all search related state
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

    private func handleSearchChange(_ text: String) async {
        if text.isEmpty {
            clearSearchResultsAndRecs()
            await loadDiscover(true)
            return
        }

        clearConnError()
        clearSearchResultsAndRecs()
        await searchMedia(reset: true)

        guard connectionError == nil else { return }
        await fetchKeywordSuggestions(for: text)

        if let first = results.first {
            await fetchRecommendations(for: first.id, mediaType: first.mediaType)
        }
    }

    private func searchMedia(reset: Bool = false) async {
        guard !isLoading else { return }
        if reset {
            loader.reset()
            results.removeAll()
            clearConnError()
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
            if loader.page == 1 { results = items } else { results.append(contentsOf: items) }
            loader.endLoading(next: resp.totalPages)
            clearConnError()
        } catch is OverseerrError {
            loader.cancelLoading(); recoverAuth()
        } catch {
            print("🔴 Search error: \(error.localizedDescription)")
            loader.cancelLoading()
            if loader.page == 1 || results.isEmpty {
                setConnectionError("Search failed. \(error.localizedDescription)")
                connectionError = "Search failed. \(error.localizedDescription)"
            }
        }
    }

    private func fetchKeywordSuggestions(for query: String) async {
        isLoadingKeywords = true
        var keywordFetchError: String? = nil
        do {
            let raw = try await service.keywordSearch(query: query)
            keywordSuggestions = await filterUsableKeywords(raw)
        } catch is OverseerrError {
            // handled in recover
        } catch {
            keywordSuggestions = []
            keywordFetchError = "Failed to load keyword suggestions. \(error.localizedDescription)"
            print("🔴 Keyword search error: \(error.localizedDescription)")
        }
        isLoadingKeywords = false
        if connectionError == nil, let err = keywordFetchError {
            setConnectionError(err)
            connectionError = err
        }
    }

    func activate(keyword k: Keyword) {
        guard !filters.activeKeywordIDs.contains(k.id) else { return }
        searchQuery = ""
        filters.activeKeywordIDs.insert(k.id)
        if !activeKeywords.contains(where: { $0.id == k.id }) {
            activeKeywords.append(k)
            activeKeywords.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
        clearSearchResultsAndRecs()
        keywordActivatedSubject.send()
        Task { await loadDiscover(true) }
    }

    func remove(keywordID: Int) {
        filters.activeKeywordIDs.remove(keywordID)
        activeKeywords.removeAll { $0.id == keywordID }
        if searchQuery.isEmpty {
            Task { await loadDiscover(true) }
        }
    }

    private func filterUsableKeywords(_ raw: [Keyword]) async -> [Keyword] {
        await withTaskGroup(of: Keyword?.self) { group in
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
                        self.recoverAuth()
                    } catch {
                        print("⚠️ Error probing keyword \(kw.name): \(error.localizedDescription)")
                    }
                    return nil
                }
            }
            var usable: [Keyword] = []
            for await maybe in group {
                if let kw = maybe { usable.append(kw) }
            }
            return usable.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    private func fetchRecommendations(for baseItemId: Int, mediaType _: MediaType) async {
        recBaseID = baseItemId
        movieRecLoader.reset(); tvRecLoader.reset()
        movieRecs.removeAll(); tvRecs.removeAll()

        isLoadingMovieRecs = true
        isLoadingTvRecs = true
        var movieFetchError: Error?
        var tvFetchError: Error?

        do {
            let resp = try await service.movieRecommendations(for: baseItemId, page: movieRecLoader.page)
            movieRecs = resp.results.map { MediaItem(
                id: $0.id,
                title: $0.title,
                posterPath: $0.posterPath,
                mediaType: .movie
            ) }
            movieRecLoader.endLoading(next: resp.totalPages)
        } catch let err as OverseerrError {
            movieFetchError = err
            if case .notAuthenticated = err {
                recoverAuth()
            } else {
                print("🔴 Movie recommendations error: \(err.localizedDescription)")
                movieRecs = []; movieRecLoader.reset()
            }
        } catch {
            movieFetchError = error
            print("🔴 Movie recommendations error: \(error.localizedDescription)")
            movieRecs = []; movieRecLoader.reset()
        }
        isLoadingMovieRecs = false

        do {
            let resp = try await service.tvRecommendations(for: baseItemId, page: tvRecLoader.page)
            tvRecs = resp.results
                .map { MediaItem(id: $0.id, title: $0.name, posterPath: $0.posterPath, mediaType: .tv) }
            tvRecLoader.endLoading(next: resp.totalPages)
        } catch let err as OverseerrError {
            tvFetchError = err
            if case .notAuthenticated = err {
                recoverAuth()
            } else {
                print("🔴 TV recommendations error: \(err.localizedDescription)")
                tvRecs = []; tvRecLoader.reset()
            }
        } catch {
            tvFetchError = error
            print("🔴 TV recommendations error: \(error.localizedDescription)")
            tvRecs = []; tvRecLoader.reset()
        }
        isLoadingTvRecs = false

        if let mvErr = movieFetchError, !(mvErr is OverseerrError), let tvErr = tvFetchError,
           !(tvErr is OverseerrError)
        {
            setConnectionError("Failed to load recommendations.")
            connectionError = "Failed to load recommendations."
        } else if connectionError == nil && (movieFetchError != nil || tvFetchError != nil) {
            if let mvErr = movieFetchError, !(mvErr is OverseerrError) {
                let msg = "Failed to load movie recommendations. \(mvErr.localizedDescription)"
                setConnectionError(msg)
                connectionError = msg
            } else if let tvErr = tvFetchError, !(tvErr is OverseerrError) {
                let msg = "Failed to load TV recommendations. \(tvErr.localizedDescription)"
                setConnectionError(msg)
                connectionError = msg
            }
        } else if connectionError == nil && movieFetchError == nil && tvFetchError == nil {
            clearConnError()
        }
    }

    func loadMoreIfNeeded(current item: MediaItem, within list: [MediaItem]) {
        let thresholdIndex = list.index(list.endIndex, offsetBy: -AppConfig.prefetchThreshold)
        guard let currentIndex = list.firstIndex(where: { $0.id == item.id }),
              currentIndex >= thresholdIndex else { return }
        Task {
            if !searchQuery.isEmpty { await searchMedia() }
            else { await loadDiscover(false) }
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
                movieRecLoader.cancelLoading(); recoverAuth()
            } catch {
                movieRecLoader.cancelLoading()
                print("🔴 Error loading more movie recommendations: \(error.localizedDescription)")
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
                tvRecLoader.cancelLoading(); recoverAuth()
            } catch {
                tvRecLoader.cancelLoading()
                print("🔴 Error loading more TV recommendations: \(error.localizedDescription)")
            }
        }
    }
}

#endif
