// File: RadarrMovieHistoryRecord.swift
// Purpose: Defines RadarrMovieHistoryRecord component for Cantinarr

import Foundation

struct RadarrMovieHistoryRecord: Codable, Identifiable {
    let id: Int
    let movieId: Int
    let sourceTitle: String?
    let quality: RadarrHistoryQuality?
    let qualityCutoffNotMet: Bool?
    let date: Date?
    let eventType: String? // e.g. "grabbed", "downloadFolderImported", "downloadFailed"
    let data: RadarrHistoryData?
}
