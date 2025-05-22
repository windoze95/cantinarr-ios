import Foundation

// MARK: – Media Discovery

extension OverseerrAPIService {
    // MARK: Watch Providers

    struct WatchProvider: Codable, Identifiable {
        let id: Int
        let name: String
    }

    func fetchWatchProviders(isMovie: Bool) async throws -> [WatchProvider] {
        let endpoint = isMovie ? "watchproviders/movies" : "watchproviders/tv"
        var comps = URLComponents(url: baseURL.appendingPathComponent(endpoint),
                                  resolvingAgainstBaseURL: false)!
        comps.queryItems = [.init(name: "watchRegion", value: Locale.current.regionCode ?? "US")]
        let (d, resp) = try await data(for: URLRequest(url: comps.url!))
        guard let http = resp as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        if http.statusCode == 401 || http.statusCode == 403 {
            throw AuthError.notAuthenticated
        }
        guard http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try jsonDecoder.decode([WatchProvider].self, from: d)
    }

    // MARK: Keywords

    struct Keyword: Codable, Identifiable {
        let id: Int
        let name: String
    }

    /// /search/keyword?query=foo
    func keywordSearch(query: String) async throws -> [Keyword] {
        guard !query.isEmpty else { return [] }
        var comps = URLComponents(
            url: baseURL.appendingPathComponent("search/keyword"),
            resolvingAgainstBaseURL: false
        )!
        comps.queryItems = [.init(name: "query", value: query)]
        let (data, resp) = try await data(for: URLRequest(url: comps.url!))
        guard let http = resp as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        if http.statusCode == 401 || http.statusCode == 403 {
            throw AuthError.notAuthenticated
        }
        guard http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let wrapper = try jsonDecoder.decode(DiscoverResponse<Keyword>.self, from: data)
        return wrapper.results
    }

    // MARK: Recommendations

    func movieRecommendations(for id: Int, page: Int = 1) async throws -> DiscoverResponse<Movie> {
        try await discover(endpoint: "movie/\(id)/recommendations",
                           providerIds: [], genreIds: [], page: page)
    }

    func tvRecommendations(for id: Int, page: Int = 1) async throws -> DiscoverResponse<TVShow> {
        try await discover(endpoint: "tv/\(id)/recommendations",
                           providerIds: [], genreIds: [], page: page)
    }

    // MARK: Discover

    struct DiscoverResponse<T: Codable>: Codable {
        let page: Int
        let totalPages: Int
        let results: [T]
    }

    struct Movie: Codable, Identifiable {
        let id: Int
        let title: String
        let posterPath: String?
        let genreIds: [Int]?
    }

    struct TVShow: Codable, Identifiable {
        let id: Int
        let name: String
        let posterPath: String?
        let genreIds: [Int]?
    }

    struct TrendingItem: Codable, Identifiable {
        let id: Int
        let mediaType: MediaType
        let title: String?
        let name: String?
        let posterPath: String?
    }

    struct SearchItem: Codable, Identifiable {
        let id: Int
        let mediaType: MediaType?
        let title: String?
        let name: String?
        let posterPath: String?
    }

    func search(query: String, page: Int) async throws -> DiscoverResponse<SearchItem> {
        var comps = URLComponents(
            url: baseURL.appendingPathComponent("search"),
            resolvingAgainstBaseURL: false
        )!
        comps.queryItems = [
            .init(name: "query", value: query),
            .init(name: "page", value: "\(page)"),
        ]
        let (data, resp) = try await data(for: URLRequest(url: comps.url!))
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try jsonDecoder.decode(DiscoverResponse<SearchItem>.self, from: data)
    }

    // MARK: Discover helpers

    private func discover<T: Codable>(
        endpoint: String,
        providerIds: [Int],
        genreIds: [Int],
        keywordIds: [Int] = [],
        page: Int
    ) async throws -> DiscoverResponse<T> {
        var comps = URLComponents(url: baseURL.appendingPathComponent(endpoint),
                                  resolvingAgainstBaseURL: false)!
        var q: [URLQueryItem] = [
            .init(name: "page", value: "\(page)"),
        ]
        if !providerIds.isEmpty {
            q.append(.init(name: "watchProviders",
                           value: providerIds.map(String.init).joined(separator: "|")))
        }
        if !genreIds.isEmpty {
            q.append(.init(name: "genre",
                           value: genreIds.map(String.init).joined(separator: ",")))
        }
        if !keywordIds.isEmpty {
            q.append(.init(name: "keywords",
                           value: keywordIds.map(String.init).joined(separator: ",")))
        }
        comps.queryItems = q

        let (d, resp) = try await data(for: URLRequest(url: comps.url!))
        guard let http = resp as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        if http.statusCode == 401 || http.statusCode == 403 {
            throw AuthError.notAuthenticated
        }
        guard http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        return try jsonDecoder.decode(DiscoverResponse<T>.self, from: d)
    }

    func fetchMovies(
        providerIds: [Int],
        genreIds: [Int],
        keywordIds: [Int] = [],
        page: Int
    ) async throws -> DiscoverResponse<Movie> {
        try await discover(
            endpoint: "discover/movies",
            providerIds: providerIds,
            genreIds: genreIds,
            keywordIds: keywordIds,
            page: page
        )
    }

    func fetchTV(
        providerIds: [Int],
        genreIds: [Int],
        keywordIds: [Int] = [],
        page: Int
    ) async throws -> DiscoverResponse<TVShow> {
        try await discover(
            endpoint: "discover/tv",
            providerIds: providerIds,
            genreIds: genreIds,
            keywordIds: keywordIds,
            page: page
        )
    }

    func fetchTrending(
        providerIds: [Int],
        page: Int
    ) async throws -> DiscoverResponse<TrendingItem> {
        try await discover(
            endpoint: "discover/trending",
            providerIds: providerIds,
            genreIds: [],
            page: page
        )
    }
}

// MARK: – Media Detail

extension OverseerrAPIService {
    struct MovieDetail: Codable {
        let id: Int
        let title: String
        let tagline, overview: String?
        let runtime: Int?
        let releaseDate: String?
        let posterPath, backdropPath: String?
        let mediaInfo: MediaInfo?
        let relatedVideos: [RelatedVideo]?
    }

    struct Season: Codable, Identifiable {
        let id: Int
        let seasonNumber: Int
        let episodeCount: Int
        var mediaInfo: MediaInfo?
    }

    struct TVDetail: Codable {
        let id: Int
        let name: String
        let tagline, overview: String?
        let posterPath, backdropPath: String?
        let seasons: [Season]
        let mediaInfo: MediaInfo?
        let relatedVideos: [RelatedVideo]?
    }

    struct MediaInfo: Codable {
        let status: MediaAvailability
        let plexUrl: URL?
    }

    struct RelatedVideo: Codable, Identifiable {
        let url: String?
        let key: String?
        let name: String?
        let size: Int?
        let type: String?
        let site: String?
        var id: String { key ?? UUID().uuidString }
    }

    struct MediaRequest: Codable, Identifiable {
        let id: Int
        let status: Int
        let is4k: Bool?
    }

    // MARK: Public fetchers

    func movieDetail(id: Int) async throws -> MovieDetail {
        try await fetch("movie/\(id)")
    }

    func tvDetail(id: Int) async throws -> TVDetail {
        try await fetch("tv/\(id)")
    }

    // MARK: Actions

    func request(mediaId id: Int, isMovie: Bool) async throws {
        let body = ["mediaType": isMovie ? "movie" : "tv", "mediaId": id] as [String: Any]
        try await post(endpoint: "request", body: body)
    }

    func reportIssue(mediaId id: Int, type: String, message: String) async throws {
        let body: [String: Any] = ["issueType": type, "message": message, "mediaId": id]
        try await post(endpoint: "issue", body: body)
    }

    // MARK: Helpers

    private func fetch<T: Decodable>(_ endpoint: String) async throws -> T {
        let url = baseURL.appendingPathComponent(endpoint)
        let (data, resp) = try await data(for: URLRequest(url: url))
        guard resp.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func post(endpoint: String, body: [String: Any]) async throws {
        var req = URLRequest(url: baseURL.appendingPathComponent(endpoint))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, resp) = try await data(for: req)
        guard resp.statusCode == 200 else { throw URLError(.badServerResponse) }
    }
}

