// File: RadarrModels.swift
// Purpose: Defines RadarrModels component for Cantinarr

import Foundation

// MARK: - Movie

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

struct RadarrImage: Codable, Hashable, Equatable {
    var coverType: String // "poster", "fanart", "banner"
    var url: URL? // This is often a local Radarr URL
    var remoteUrl: URL? // This is the external URL (preferred)
}

struct RadarrMovieFile: Codable, Identifiable, Hashable, Equatable {
    let id: Int
    let relativePath: String?
    let path: String?
    let size: Int64?
    let dateAdded: Date?
    let mediaInfo: RadarrMediaInfo?
}

struct RadarrMediaInfo: Codable, Hashable, Equatable {
    let audioBitrate: Int?
    let audioChannels: Double?
    let audioCodec: String?
    let audioLanguages: String?
    let audioStreamCount: Int?
    let videoBitDepth: Int?
    let videoBitrate: Int?
    let videoCodec: String?
    let videoFps: Double?
    let resolution: String?
    let runTime: String? // Timespan format "02:30:00"
    let scanType: String?
    let subtitles: String?
}

// MARK: - Quality Profile

struct RadarrQualityProfile: Codable, Identifiable {
    let id: Int
    let name: String
}

// MARK: - Root Folder

struct RadarrRootFolder: Codable, Identifiable {
    let id: Int
    let path: String?
    let freeSpace: Int64?
    let totalSpace: Int64?
    let unmappedFolders: [RadarrUnmappedFolder]?
}

struct RadarrUnmappedFolder: Codable, Hashable, Equatable {
    let name: String?
    let path: String?
}

// MARK: - System Status (for version check, etc.)

struct RadarrSystemStatus: Codable {
    let appName: String?
    let version: String
    let buildTime: Date?
}

// MARK: - Command Status (for search, add, etc.)

struct RadarrCommandResponse: Codable, Identifiable {
    let id: Int
    let name: String?
    let commandName: String?
    let message: String?
    let status: String? // "queued", "started", "completed", "failed"
    let startedOn: Date?
    let stateChangeTime: Date?
    let sendUpdatesToClient: Bool?
    let lastExecutionTime: Date?
}

// MARK: - Add Movie Options

struct RadarrAddOptions: Codable {
    let ignoreEpisodesWithFiles: Bool? // Typically for Sonarr, but good to have a similar structure
    let ignoreEpisodesWithoutFiles: Bool?
    let searchForMovie: Bool // Radarr specific: searchForMovie instead of searchForMissingEpisodes

    init(searchForMovie: Bool) {
        ignoreEpisodesWithFiles = false // Not directly applicable to Radarr movies in this way
        ignoreEpisodesWithoutFiles = false // Not directly applicable
        self.searchForMovie = searchForMovie
    }
}
