import Foundation

struct MediaRequest: Codable, Identifiable {
    let id: Int
    let status: Int
    let is4k: Bool?
}
