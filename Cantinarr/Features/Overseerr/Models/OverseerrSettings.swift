import Foundation

/// Service‑specific configuration blob for an Overseerr instance.
struct OverseerrSettings: Codable {
    var host: String
    var port: String?
    var useSSL: Bool = true
}
