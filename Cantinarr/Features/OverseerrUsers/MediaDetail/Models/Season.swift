import Foundation

struct Season: Codable, Identifiable {
    let id: Int
    let seasonNumber: Int
    let episodeCount: Int
    var mediaInfo: MediaInfo?
}
