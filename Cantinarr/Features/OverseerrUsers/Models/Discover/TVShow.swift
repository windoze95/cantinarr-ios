import Foundation

struct TVShow: Codable, Identifiable {
    let id: Int
    let name: String
    let posterPath: String?
    let genreIds: [Int]?
}
