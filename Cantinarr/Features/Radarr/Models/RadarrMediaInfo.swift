// File: RadarrMediaInfo.swift
// Purpose: Defines RadarrMediaInfo component for Cantinarr

import Foundation

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
