import Foundation

struct DiscoverResponse<T: Codable>: Codable {
    let page: Int
    let totalPages: Int
    let results: [T]
}
