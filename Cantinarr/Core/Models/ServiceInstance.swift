// File: ServiceInstance.swift
// Purpose: Defines ServiceInstance model for Cantinarr

import Foundation

/// A concrete configured integration (e.g. “Overseerr – Basement Plex”)
struct ServiceInstance: Identifiable, Codable {
    let id: UUID
    var kind: ServiceKind
    var displayName: String // user‑editable
    var configuration: Data? // JSON‑encoded, service‑specific blob

    init(id: UUID = UUID(),
         kind: ServiceKind,
         displayName: String,
         configuration: Data? = nil)
    {
        self.id = id
        self.kind = kind
        self.displayName = displayName
        self.configuration = configuration
    }
}

// MARK: - Convenience JSON‑decode helper

extension ServiceInstance {
    /// Attempts to decode the `configuration` blob into the requested `Decodable` type.
    /// Returns `nil` if the blob is missing or cannot be decoded.
    func decode<T: Decodable>(_: T.Type) -> T? {
        guard let data = configuration else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
