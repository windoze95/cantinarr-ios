// File: RadarrHistoryQuality.swift
// Purpose: Defines RadarrHistoryQuality component for Cantinarr

import Foundation

struct RadarrHistoryQuality: Codable, Hashable, Equatable {
    let quality: RadarrQualityDetail?
    let revision: RadarrRevision?
}
