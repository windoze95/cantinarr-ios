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

    // TODO: include additional fields like branch, runtimeVersion if needed
}
