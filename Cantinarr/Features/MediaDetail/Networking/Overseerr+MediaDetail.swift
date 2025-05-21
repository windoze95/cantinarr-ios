// File: Overseerr+MediaDetail.swift
// Purpose: Defines Overseerr+MediaDetail component for Cantinarr

import Foundation

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
        let url: String? // Full YouTube URL (e.g., https://www.youtube.com/watch?v=VIDEO_ID)
        let key: String? // The YouTube video ID
        let name: String?
        let size: Int?
        let type: String? // e.g., "Trailer", "Teaser", "Clip"
        let site: String? // e.g., "YouTube"
        var id: String { key ?? UUID().uuidString } // Use key as ID, fallback if key is nil
    }

    struct MediaRequest: Codable, Identifiable {
        let id: Int
        let status: Int // 1=PENDING, 2=APPROVED, 3=DECLINED, 4=PROCESSING, 5=AVAILABLE (check Overseerr docs for exact
        // mapping)
        // Add other relevant fields from `mediaInfo.requests[]` if needed, e.g., is4k, requestedBy
        let is4k: Bool?
    }

    // MARK: – public fetchers

    func movieDetail(id: Int) async throws -> MovieDetail {
        try await fetch("movie/\(id)")
    }

    func tvDetail(id: Int) async throws -> TVDetail {
        try await fetch("tv/\(id)")
    }

    // ───────── Actions ─────────
    /// POST /request
    func request(mediaId id: Int, isMovie: Bool) async throws {
        let body = ["mediaType": isMovie ? "movie" : "tv", "mediaId": id] as [String: Any]
        try await post(endpoint: "request", body: body)
    }

    /// POST /issue
    func reportIssue(mediaId id: Int, type: String, message: String) async throws {
        let body: [String: Any] = [
            "issueType": type, "message": message, "mediaId": id,
        ]
        try await post(endpoint: "issue", body: body)
    }

    // MARK: – tiny helpers

    private var apiBaseURL: URL {
        var comps = URLComponents()
        comps.scheme = useSSL ? "https" : "http"
        comps.host = host
        if let p = port, !p.isEmpty { comps.port = Int(p) }
        comps.path = "/api/v1"
        return comps.url!
    }

    private func fetch<T: Decodable>(_ endpoint: String) async throws -> T {
        let url = apiBaseURL.appendingPathComponent(endpoint)
        let (data, resp) = try await data(for: URLRequest(url: url))
        guard resp.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func post(endpoint: String, body: [String: Any]) async throws {
        var req = URLRequest(url: apiBaseURL.appendingPathComponent(endpoint))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, resp) = try await data(for: req)
        guard resp.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
    }
}
