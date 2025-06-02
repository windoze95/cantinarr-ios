// File: RadarrMovieFile.swift
// Purpose: Defines RadarrMovieFile component for Cantinarr

import Foundation

struct RadarrMovieFile: Codable, Identifiable, Hashable, Equatable {
    let id: Int
    let relativePath: String?
    let path: String?
    let size: Int64?
    let dateAdded: Date?
    let mediaInfo: RadarrMediaInfo?
    let movieId: Int?
    let quality: RadarrHistoryQuality?

    // Additional fields like sceneName and indexerFlags can be added if needed
}
