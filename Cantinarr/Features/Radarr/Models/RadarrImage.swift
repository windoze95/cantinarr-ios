// File: RadarrImage.swift
// Purpose: Defines RadarrImage component for Cantinarr

import Foundation

struct RadarrImage: Codable, Hashable, Equatable {
    var coverType: String // "poster", "fanart", "banner"
    var url: URL? // This is often a local Radarr URL
    var remoteUrl: URL? // This is the external URL (preferred)
}
