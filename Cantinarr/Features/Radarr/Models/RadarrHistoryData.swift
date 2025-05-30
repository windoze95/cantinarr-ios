// File: RadarrHistoryData.swift
// Purpose: Defines RadarrHistoryData component for Cantinarr

import Foundation

struct RadarrHistoryData: Codable {
    let nzbInfoUrl: String? // Note: Radarr's casing might vary
    let releaseGroup: String?
    let age: String? // Radarr often returns age as a string like "1d" or "1h"
    // ... other fields that might appear in the 'data' dictionary
    let message: String?
    let reason: String? // For failed events
    let downloadClient: String?
    let downloadClientName: String?

    enum CodingKeys: String, CodingKey {
        case nzbInfoUrl
        case releaseGroup
        case age
        case message
        case reason
        case downloadClient
        case downloadClientName
    }
}
