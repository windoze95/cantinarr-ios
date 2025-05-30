// File: RadarrQualityProfile.swift
// Purpose: Defines RadarrQualityProfile component for Cantinarr

import Foundation

struct RadarrQualityProfile: Codable, Identifiable {
    let id: Int
    let name: String
    let cutoff: Int?

    // TODO: include items array if later needed for editing profiles
}
