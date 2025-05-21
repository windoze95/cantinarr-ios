// File: MediaAvailability.swift
// Purpose: Defines MediaAvailability component for Cantinarr

import SwiftUI

enum MediaAvailability: Int, Codable {
    case unknown = 1
    case pending = 2
    case processing = 3
    case partiallyAvailable = 4
    case available = 5
    case deleted = 6

    var label: String {
        switch self {
        case .unknown: "Unknown"
        case .pending: "Requested"
        case .processing: "Processing"
        case .partiallyAvailable: "Partially Available"
        case .available: "Available"
        case .deleted: "Deleted"
        }
    }

    /// Brand colours that match Overseerr’s UI.
    var tint: Color {
        switch self {
        case .unknown: .gray
        case .pending: .orange
        case .processing: .blue
        case .partiallyAvailable: .mint
        case .available: .green
        case .deleted: .red
        }
    }
}
