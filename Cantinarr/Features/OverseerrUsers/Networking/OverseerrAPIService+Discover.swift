import Foundation

extension OverseerrAPIService {
    // MARK: - Watch Providers

    // Models moved to Features/OverseerrUsers/Models/Discover

    func fetchWatchProviders(isMovie: Bool) async throws -> [WatchProvider] {
        let endpoint = isMovie ? "watchproviders/movies" : "watchproviders/tv"
        var comps = URLComponents(url: baseURL.appendingPathComponent(endpoint), resolvingAgainstBaseURL: false)!
        comps.queryItems = [.init(name: "watchRegion", value: Locale.current.regionCode ?? "US")]
        let (d, _) = try await data(for: URLRequest(url: comps.url!))
        return try jsonDecoder.decode([WatchProvider].self, from: d)
    }

    // MARK: - Keywords

    // Keyword model moved to Features/OverseerrUsers/Models/Discover

    func keywordSearch(query: String) async throws -> [Keyword] {
        guard !query.isEmpty else { return [] }
        var comps = URLComponents(
            url: baseURL.appendingPathComponent("search/keyword"),
            resolvingAgainstBaseURL: false
        )!
        comps.queryItems = [.init(name: "query", value: query)]
        let (data, _) = try await data(for: URLRequest(url: comps.url!))
        let wrapper = try jsonDecoder.decode(DiscoverResponse<Keyword>.self, from: data)
        return wrapper.results
    }

    // MARK: - Recommendations

    func movieRecommendations(for id: Int, page: Int = 1) async throws -> DiscoverResponse<Movie> {
        try await discover(endpoint: "movie/\(id)/recommendations", providerIds: [], genreIds: [], page: page)
    }

    func tvRecommendations(for id: Int, page: Int = 1) async throws -> DiscoverResponse<TVShow> {
        try await discover(endpoint: "tv/\(id)/recommendations", providerIds: [], genreIds: [], page: page)
    }

    // MARK: - Discover

    // Discover models moved to Features/OverseerrUsers/Models/Discover

    func search(query: String, page: Int) async throws -> DiscoverResponse<SearchItem> {
        var comps = URLComponents(url: baseURL.appendingPathComponent("search"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            .init(name: "query", value: query),
            .init(name: "page", value: "\(page)"),
        ]
        let (data, _) = try await data(for: URLRequest(url: comps.url!))
        return try jsonDecoder.decode(DiscoverResponse<SearchItem>.self, from: data)
    }

    // MARK: - Discover helpers

    private func discover<T: Codable>(
        endpoint: String,
        providerIds: [Int],
        genreIds: [Int],
        keywordIds: [Int] = [],
        page: Int
    ) async throws -> DiscoverResponse<T> {
        var comps = URLComponents(url: baseURL.appendingPathComponent(endpoint), resolvingAgainstBaseURL: false)!
        var q: [URLQueryItem] = [.init(name: "page", value: "\(page)")]
        if !providerIds.isEmpty {
            q.append(.init(name: "watchProviders", value: providerIds.map(String.init).joined(separator: "|")))
        }
        if !genreIds.isEmpty {
            q.append(.init(name: "genre", value: genreIds.map(String.init).joined(separator: ",")))
        }
        if !keywordIds.isEmpty {
            q.append(.init(name: "keywords", value: keywordIds.map(String.init).joined(separator: ",")))
        }
        comps.queryItems = q

        let (d, _) = try await data(for: URLRequest(url: comps.url!))
        return try jsonDecoder.decode(DiscoverResponse<T>.self, from: d)
    }

    // MARK: - Public discover fetches

    func fetchMovies(providerIds: [Int], genreIds: [Int], keywordIds: [Int] = [],
                     page: Int) async throws -> DiscoverResponse<Movie>
    {
        try await discover(
            endpoint: "discover/movies",
            providerIds: providerIds,
            genreIds: genreIds,
            keywordIds: keywordIds,
            page: page
        )
    }

    func fetchTV(providerIds: [Int], genreIds: [Int], keywordIds: [Int] = [],
                 page: Int) async throws -> DiscoverResponse<TVShow>
    {
        try await discover(
            endpoint: "discover/tv",
            providerIds: providerIds,
            genreIds: genreIds,
            keywordIds: keywordIds,
            page: page
        )
    }

    func fetchTrending(providerIds: [Int], page: Int) async throws -> DiscoverResponse<TrendingItem> {
        try await discover(endpoint: "discover/trending", providerIds: providerIds, genreIds: [], page: page)
    }
}
