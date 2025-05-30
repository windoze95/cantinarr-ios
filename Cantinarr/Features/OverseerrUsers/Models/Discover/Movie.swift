import Foundation

struct Movie: Codable, Identifiable {
    let id: Int
    let title: String
    let posterPath: String?
    let genreIds: [Int]?
}
