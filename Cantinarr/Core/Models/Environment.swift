// File: Environment.swift
// Purpose: Defines Environment component for Cantinarr

import Foundation

/// A logical grouping of services – comparable to an NZB360 “Server”.
struct ServerEnvironment: Identifiable, Codable {
    let id: UUID
    var name: String

    /// A collection of user‑added service instances (Overseerr, Radarr …).
    var services: [ServiceInstance]

    init(id: UUID = UUID(),
         name: String,
         services: [ServiceInstance] = [])
    {
        self.id = id
        self.name = name
        self.services = services
    }

    // Handy access in upcoming UI work
    func service<T>(of kind: ServiceKind, as type: T.Type = T.self) -> T? where T: Decodable {
        services.first { $0.kind == kind }
            .flatMap { instance in
                guard let data = instance.configuration else { return nil }
                return try? JSONDecoder().decode(type, from: data)
            }
    }
}

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

/// Every service we *could* support goes here.
enum ServiceKind: String, CaseIterable, Identifiable, Codable {
    case overseerrUsers = "Overseerr for Users"
    case radarr = "Radarr"
//    case sonarr            = "Sonarr"
    var id: String { rawValue }
}

// MARK: - Convenience JSON‑decode helper on ServiceInstance

extension ServiceInstance {
    /// Attempts to decode the `configuration` blob into the requested `Decodable` type.
    /// Returns `nil` if the blob is missing or cannot be decoded.
    func decode<T: Decodable>(_: T.Type) -> T? {
        guard let data = configuration else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
