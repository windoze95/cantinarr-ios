import Foundation

extension OverseerrAPIService {
    // Detail models moved to Features/OverseerrUsers/MediaDetail/Models

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
        let (data, _) = try await data(for: URLRequest(url: url))
        return try jsonDecoder.decode(T.self, from: data)
    }

    private func post(endpoint: String, body: [String: Any]) async throws {
        var req = URLRequest(url: baseURL.appendingPathComponent(endpoint))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        _ = try await data(for: req)
    }
}
