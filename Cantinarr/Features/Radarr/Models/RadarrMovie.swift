// File: RadarrMovie.swift
// Purpose: Defines RadarrMovie component for Cantinarr

import Foundation

/// Primary movie representation returned by Radarr's API.
struct RadarrMovie: Codable, Identifiable, Hashable {
    let id: Int
    let title: String
    let originalTitle: String?
    let sortTitle: String
    let sizeOnDisk: Int64?
    let status: String // e.g., "monitored", "released" (use for availability)
    let overview: String?
    let inCinemas: Date?
    let physicalRelease: Date?
    let digitalRelease: Date?
    var images: [RadarrImage] // Made var if you intend to modify images locally
    let website: String?
    let year: Int
    let hasFile: Bool
    let path: String?
    var qualityProfileId: Int // Made var as this is often editable
    var monitored: Bool // CHANGED to var
    var minimumAvailability: String // e.g. "announced", "inCinemas", "released", "tba"
    let runtime: Int
    let cleanTitle: String?
    let imdbId: String?
    let tmdbId: Int?
    var titleSlug: String? // Made var if it can be regenerated/edited
    var folderName: String? // Made var if editable
    let movieFile: RadarrMovieFile?

    var posterURL: URL? {
        images.first(where: { $0.coverType == "poster" })?.remoteUrl ??
            images.first(where: { $0.coverType == "poster" })?.url // Fallback for older Radarr versions
    }

    var fanartURL: URL? {
        images.first(where: { $0.coverType == "fanart" })?.remoteUrl ??
            images.first(where: { $0.coverType == "fanart" })?.url
    }
}
