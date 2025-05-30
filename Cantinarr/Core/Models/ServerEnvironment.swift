// File: ServerEnvironment.swift
// Purpose: Defines ServerEnvironment model for Cantinarr

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
