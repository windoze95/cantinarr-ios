import Foundation

struct MediaInfo: Codable {
    let status: MediaAvailability
    let plexUrl: URL?
}
