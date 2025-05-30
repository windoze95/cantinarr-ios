import Foundation

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
