// File: ServiceKind.swift
// Purpose: Defines ServiceKind model for Cantinarr

import Foundation

/// Every service we *could* support goes here.
enum ServiceKind: String, CaseIterable, Identifiable, Codable {
    case overseerrUsers = "Overseerr for Users"
    case radarr = "Radarr"
//    case sonarr            = "Sonarr"
    var id: String { rawValue }
}
