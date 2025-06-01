// File: MediaDetailViewModel.swift
// Purpose: Defines MediaDetailViewModel component for Cantinarr

import SwiftUI

@MainActor
final class MediaDetailViewModel: ObservableObject {
    /// The Overseerr/TMDB identifier of the media currently displayed.
    public private(set) var id: Int
    @Published private(set) var mediaType: MediaType
    @Published private(set) var availability: MediaAvailability = .unknown
    @Published var title = ""
    @Published var tagline = ""
    @Published var overview = ""
    @Published var posterURL: URL?
    @Published var backdropURL: URL?
    @Published var seasons: [Season] = []
    @Published var isLoading = false
    @Published var error: String?

    @Published var trailerVideoID: String?
    @Published var showTrailerPlayer: Bool = false

    //    private let id: Int
    private let service: OverseerrServiceType

    init(id: Int,
         mediaType: MediaType,
         service: OverseerrServiceType)
    {
        self.id = id
        self.mediaType = mediaType
        self.service = service
    }

    // MARK: – bootstrap

    func load() async {
        isLoading = true; defer { isLoading = false }
        trailerVideoID = nil // Reset trailer ID on new load
        do {
            if mediaType == .movie {
                let d = try await service.movieDetail(id: id)
                availability = d.mediaInfo?.status ?? .unknown
                title = d.title
                tagline = d.tagline ?? ""
                overview = d.overview ?? ""
                posterURL = URL.tmdb(path: d.posterPath, width: 500)
                backdropURL = URL.tmdb(path: d.backdropPath, width: 780)
                // Extract trailer video ID from relatedVideos
                if let videos = d.relatedVideos {
                    // Find the first video that is a "Trailer" and from "YouTube"
                    let officialTrailer = videos.first { video in
                        video.type?.lowercased() == "trailer" && video.site?.lowercased() == "youtube" && video
                            .key != nil
                    }
                    trailerVideoID = officialTrailer?.key
                    // Optional: If no "Trailer" type, you could look for "Teaser" or other types as a fallback.
                    if trailerVideoID == nil {
                        trailerVideoID = videos.first { video in
                            video.site?.lowercased() == "youtube" && video
                                .key != nil // Any YouTube video if no specific trailer
                        }?.key
                    }
                }
            } else {
                let d = try await service.tvDetail(id: id)
                availability = d.mediaInfo?.status ?? .unknown
                title = d.name
                tagline = d.tagline ?? ""
                overview = d.overview ?? ""
                posterURL = URL.tmdb(path: d.posterPath, width: 500)
                backdropURL = URL.tmdb(path: d.backdropPath, width: 780)
                seasons = d.seasons
                if let videos = d.relatedVideos { // Assuming TVDetail now has relatedVideos
                    let officialTrailer = videos.first { video in
                        video.type?.lowercased() == "trailer" && video.site?.lowercased() == "youtube" && video
                            .key != nil
                    }
                    trailerVideoID = officialTrailer?.key
                    if trailerVideoID == nil {
                        trailerVideoID = videos.first { video in
                            video.site?.lowercased() == "youtube" && video.key != nil
                        }?.key
                    }
                }
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    var youtubeEmbedURL: URL? {
        guard let videoID = trailerVideoID else { return nil }
        var comps = URLComponents()
        comps.scheme = "https"
        comps.host = "www.youtube.com"
        comps.path = "/embed/\(videoID)"
        comps.queryItems = [
            .init(name: "playsinline", value: "1"),
            .init(name: "autoplay", value: "1"),
        ]
        return comps.url
    }

    // MARK: – user actions

    func request() async { try? await service.request(mediaId: id, isMovie: mediaType == .movie) }
    func report(issue type: String, message: String) async {
        try? await service.reportIssue(mediaId: id, type: type, message: message)
    }
}

private extension URL {
    /// Convenience builder for TMDB images.
    static func tmdb(path: String?, width: Int) -> URL? {
        guard let p = path else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w\(width)\(p)")
    }
}
