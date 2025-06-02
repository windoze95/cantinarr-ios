// File: RadarrSystemStatus.swift
// Purpose: Defines RadarrSystemStatus component for Cantinarr

import Foundation

struct RadarrSystemStatus: Codable {
    let appName: String?
    let version: String
    let buildTime: Date?
    let osName: String?
    let osVersion: String?
    let isDebug: Bool?

    // Additional fields like branch or runtimeVersion can be added if needed
}
