// File: RadarrCommandResponse.swift
// Purpose: Defines RadarrCommandResponse component for Cantinarr

import Foundation

struct RadarrCommandResponse: Codable, Identifiable {
    let id: Int
    let name: String?
    let commandName: String?
    let message: String?
    let status: String? // "queued", "started", "completed", "failed"
    let startedOn: Date?
    let stateChangeTime: Date?
    let sendUpdatesToClient: Bool?
    let lastExecutionTime: Date?
}
