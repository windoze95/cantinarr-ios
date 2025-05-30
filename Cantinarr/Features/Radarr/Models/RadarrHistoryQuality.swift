// File: RadarrHistoryQuality.swift
// Purpose: Defines RadarrHistoryQuality component for Cantinarr

import Foundation

struct RadarrHistoryQuality: Codable {
    let quality: RadarrQualityDetail?
    let revision: RadarrRevision?
}
