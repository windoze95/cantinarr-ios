// File: RadarrRevision.swift
// Purpose: Defines RadarrRevision component for Cantinarr

import Foundation

struct RadarrRevision: Codable, Hashable, Equatable {
    let version: Int?
    let real: Int?
    let isRepack: Bool?
}
