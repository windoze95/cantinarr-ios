// File: RadarrSystemStatus.swift
// Purpose: Defines RadarrSystemStatus component for Cantinarr

import Foundation

struct RadarrSystemStatus: Codable {
    let appName: String?
    let version: String
    let buildTime: Date?
}
