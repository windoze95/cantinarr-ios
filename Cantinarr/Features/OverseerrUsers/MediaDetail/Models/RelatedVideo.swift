import Foundation

struct RelatedVideo: Codable, Identifiable {
    let url: String?
    let key: String?
    let name: String?
    let size: Int?
    let type: String?
    let site: String?
    var id: String { key ?? UUID().uuidString }
}
