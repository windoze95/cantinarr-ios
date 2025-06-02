// File: RadarrQualityProfile.swift
// Purpose: Defines RadarrQualityProfile component for Cantinarr

import Foundation

struct RadarrQualityProfile: Codable, Identifiable {
    let id: Int
    let name: String
    let cutoff: Int?

    // Items array omitted; add it if editing profiles requires it later
}
