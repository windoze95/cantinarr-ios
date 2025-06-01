import Foundation

/// Lightweight display model for movies and shows in lists.
struct MediaItem: Identifiable, Equatable {
    let id: Int
    let title: String
    let posterPath: String?
    let mediaType: MediaType
}
