import Foundation

struct TrendingItem: Codable, Identifiable {
    let id: Int
    let mediaType: MediaType
    let title: String?
    let name: String?
    let posterPath: String?
}
