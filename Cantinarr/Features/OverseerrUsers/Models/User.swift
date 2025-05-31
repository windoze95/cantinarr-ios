import Foundation

/// Represents an Overseerr user returned from `/auth/me`.
struct User: Codable {
    let id: Int
    let username: String?
    let email: String?
    let permissions: Int?
    let requestCount: Int?
    let avatar: String?
    let plexId: Int?
    let plexUsername: String?
    let userType: String?
    // Future fields: movieQuotaLimit, movieQuotaDays, etc.
    // Overseerr returns many more fields which we omit until needed
}
