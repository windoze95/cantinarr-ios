import Foundation

extension OverseerrAPIService {
    struct MovieDetail: Codable {
        let id: Int
        let title: String
        let tagline: String?
        let overview: String?
        let runtime: Int?
        let releaseDate: String?
        let posterPath: String?
        let backdropPath: String?
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
        let tagline: String?
        let overview: String?
        let posterPath: String?
        let backdropPath: String?
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

    // MARK: - Detail fetchers
    func movieDetail(id: Int) async throws -> MovieDetail {
        try await fetchJSON("movie/\(id)")
    }

    func tvDetail(id: Int) async throws -> TVDetail {
        try await fetchJSON("tv/\(id)")
    }

    // MARK: - Actions
    func request(mediaId id: Int, isMovie: Bool) async throws {
        let body: [String: Any] = ["mediaType": isMovie ? "movie" : "tv", "mediaId": id]
        try await post(endpoint: "request", body: body)
    }

    func reportIssue(mediaId id: Int, type: String, message: String) async throws {
        let body: [String: Any] = ["issueType": type, "message": message, "mediaId": id]
        try await post(endpoint: "issue", body: body)
    }

    // MARK: - Helpers
    private func fetchJSON<T: Decodable>(_ endpoint: String) async throws -> T {
        let url = baseURL.appendingPathComponent(endpoint)
        let (data, resp) = try await data(for: URLRequest(url: url))
        guard resp.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try jsonDecoder.decode(T.self, from: data)
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
