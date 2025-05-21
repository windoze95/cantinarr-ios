// File: RadarrSettings.swift
// Purpose: Defines RadarrSettings component for Cantinarr

import Foundation

struct RadarrSettings: Codable {
    var host: String // e.g., "radarr.example.com" or "192.168.1.100"
    var port: String? // e.g., "7878"
    var apiKey: String // API key generated in Radarr
    var useSSL: Bool = false
    var urlBase: String? // Optional URL base, e.g., "/radarr"
    var isPrimary: Bool = false
}
