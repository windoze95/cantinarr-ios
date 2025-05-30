import Foundation

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
