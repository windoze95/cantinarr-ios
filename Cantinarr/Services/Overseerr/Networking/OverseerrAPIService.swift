import Foundation
import Combine
import WebKit

/// Shared cookie store so that WKWebView and URLSession share authentication cookies.
fileprivate let sharedDataStore = WKWebsiteDataStore.default()

enum AuthError: Error {
  case notAuthenticated
}

struct User: Codable { // This struct should match the /auth/me response
    let id: Int
    let username: String?
    let email: String? // Add if present in /auth/me
    let permissions: Int? // Bitmask or specific permission flags
    let requestCount: Int? // Total requests made by user
    let avatar: String? // Add if present
    // Add other fields like 'movieQuotaLimit', 'movieQuotaDays', 'tvQuotaLimit', 'tvQuotaDays'
    // and 'movieRequestsRemaining', 'tvRequestsRemaining' if the API provides them directly.
}

@MainActor
class OverseerrAPIService {
    // MARK: – Configuration
    let host: String
    let port: String?
    let useSSL: Bool
    /// e.g. https://my‑server[:port]/api/v1
    let baseURL: URL
    /// URLSession that shares cookies with WKWebView
    private let session: URLSession
    
    private let jsonDecoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()
    
    // MARK: - Convenience initializer
    convenience init(settings: OverseerrSettings) {
        self.init(host: settings.host,
                  port: settings.port,
                  useSSL: settings.useSSL)
    }

    init(host: String, port: String?, useSSL: Bool) {
        self.host = host
        self.port = port
        self.useSSL = useSSL

        let scheme = useSSL ? "https" : "http"

        // pick scheme based on useSSL
        var comps = URLComponents()
        comps.scheme = scheme
        comps.host   = host
        if let p = port, !p.isEmpty {
            comps.port = Int(p)
        }
        comps.path   = "/api/v1"
        guard let url = comps.url else {
            fatalError("Invalid Overseerr base URL")
        }
        self.baseURL = url

        let cfg = URLSessionConfiguration.default
        cfg.httpCookieStorage      = HTTPCookieStorage.shared
        cfg.httpCookieAcceptPolicy = .always
        self.session = URLSession(configuration: cfg)
    }
    
    // MARK: – Authentication
    
    /// Checks if there is a valid login session (overseerr’s cookie-based `/auth/me`).
    func isAuthenticated() async -> Bool {
        let url = baseURL.appendingPathComponent("auth/me")
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        do {
            let (_, http) = try await data(for: req)  // ← unified path
            return http.statusCode == 200
        } catch {
            return false
        }
    }
    
    // MARK: – Watch Providers
    
    struct WatchProvider: Codable, Identifiable {
        let id: Int
        let name: String
    }

    func fetchWatchProviders(isMovie: Bool) async throws -> [WatchProvider] {
            let endpoint = isMovie ? "watchproviders/movies" : "watchproviders/tv"
            var comps = URLComponents(url: baseURL.appendingPathComponent(endpoint),
                                      resolvingAgainstBaseURL: false)!
            comps.queryItems = [ .init(name: "watchRegion",
                                       value: Locale.current.regionCode ?? "US") ]
            let (d, resp) = try await data(for: URLRequest(url: comps.url!))
        guard let http = resp as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        // If we get a 401 or 403, treat it as an authentication failure:
        if http.statusCode == 401 || http.statusCode == 403 {
            throw AuthError.notAuthenticated
        }
        guard http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
            return try jsonDecoder.decode([WatchProvider].self, from: d)
        }
    
    // MARK: – Keywords

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
        comps.queryItems = [ .init(name: "query", value: query) ]
        let (data, resp) = try await data(for: URLRequest(url: comps.url!))
        guard let http = resp as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        // If we get a 401 or 403, treat it as an authentication failure:
        if http.statusCode == 401 || http.statusCode == 403 {
            throw AuthError.notAuthenticated
        }
        guard http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        // Overseerr wraps Keyword results in a paged object
        let wrapper = try jsonDecoder.decode(DiscoverResponse<Keyword>.self, from: data)
        return wrapper.results
    }

    // MARK: – Recommendations

    func movieRecommendations(for id: Int, page: Int = 1)
      async throws -> DiscoverResponse<Movie> {

        try await discover(endpoint: "movie/\(id)/recommendations",
                           providerIds: [], genreIds: [], page: page)
    }

    func tvRecommendations(for id: Int, page: Int = 1)
      async throws -> DiscoverResponse<TVShow> {

        try await discover(endpoint: "tv/\(id)/recommendations",
                           providerIds: [], genreIds: [], page: page)
    }
    
    // MARK: – Discover
    
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

    // --- Trending mixed type ----
    struct TrendingItem: Codable, Identifiable {
        let id: Int
        let mediaType: MediaType
        let title: String?
        let name : String?
        let posterPath: String?
    }
    
    // ───────── SEARCH ─────────
    struct SearchItem: Codable, Identifiable {
        let id: Int
        let mediaType: MediaType?
        let title: String?
        let name : String?
        let posterPath: String?
    }

    func search(query: String, page: Int)
      async throws -> DiscoverResponse<SearchItem> {

        var comps = URLComponents(
            url: baseURL.appendingPathComponent("search"),
            resolvingAgainstBaseURL: false
        )!
        comps.queryItems = [
            .init(name: "query", value: query),
            .init(name: "page",  value: "\(page)")
        ]
        let (data, resp) = try await data(for: URLRequest(url: comps.url!))
        guard (resp as? HTTPURLResponse)?.statusCode == 200
        else { throw URLError(.badServerResponse) }

        return try jsonDecoder.decode(DiscoverResponse<SearchItem>.self, from: data)
    }

    // MARK: – Fetch helpers
    // MARK: – Discover helpers
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
            .init(name: "page", value: "\(page)")
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
        // If we get a 401 or 403, treat it as an authentication failure:
        if http.statusCode == 401 || http.statusCode == 403 {
            throw AuthError.notAuthenticated
        }
        guard http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        return try jsonDecoder.decode(DiscoverResponse<T>.self, from: d)
    }

    // MARK: – Public discover fetches
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

    // MARK: – Unified request helper
    @discardableResult
    func data(for req: URLRequest) async throws -> (Data, HTTPURLResponse) {
        // hit the network through the dedicated session
        let (data, response) = try await session.data(for: req, delegate: nil)

        // validate HTTP
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        // translate auth errors so callers & AuthManager can react
        if http.statusCode == 401 || http.statusCode == 403 {
            await AuthManager.shared.recoverFromAuthFailure()
            throw AuthError.notAuthenticated
        }

        return (data, http)
    }
    
    func fetchCurrentUser() async throws -> User { // Ensure User struct matches /auth/me response
        let (data, resp) = try await self.data(for: URLRequest(url: baseURL.appendingPathComponent("auth/me")))
        guard resp.statusCode == 200 else {
            throw URLError(.badServerResponse, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch current user. Status: \(resp.statusCode)"])
        }
        return try jsonDecoder.decode(User.self, from: data)
    }
}

// MARK: – Plex SSO helper
extension OverseerrAPIService {
    func plexSSORedirectURL() async throws -> URL {
        // 1) Build the correct URL: http or https + host/port + /api/v1/auth/plex
        let endpoint = baseURL.appendingPathComponent("auth/plex")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        
        // Add these two lines:
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Asend an empty JSON body so some servers see a non-nil body
        request.httpBody = Data()
        
        // Send it
        let (data, resp) = try await data(for: request)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "(empty)"
            print("🛑 /api/v1/auth/plex returned status \( (resp as? HTTPURLResponse)?.statusCode ?? -1 ):\n\(body)")
            throw URLError(.badServerResponse)
        }
        
        // Decode the JSON and return the Plex URL
        struct Redirect: Decodable { let url: String }
        let redirect = try JSONDecoder().decode(Redirect.self, from: data)
        guard let plexURL = URL(string: redirect.url) else { throw URLError(.badURL) }
        return plexURL
    }

    /// Exchange a Plex authToken for an Overseerr session.
    func loginWithPlexToken(_ plexToken: String) async throws {
        let url = baseURL.appendingPathComponent("auth/plex")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        // Required body:
        let body = ["authToken": plexToken]
        req.httpBody = try JSONEncoder().encode(body)

        let (data, resp) = try await data(for: req)
//          if let http = resp as? HTTPURLResponse {
//            let body = String(data: data, encoding: .utf8) ?? "<empty>"
//            print("🔹 [Overseerr Login] URL: \(req.url!.absoluteString)")
//            print("🔹 [Overseerr Login] Status: \(http.statusCode), Body: \(body)")
//          }
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.userAuthenticationRequired)
        }
        // URLSession.shared cookie storage holds the connect.sid cookie
    }
}

// Make OverseerrAPIService satisfy OverseerrUsersService
extension OverseerrAPIService: OverseerrUsersService {}
