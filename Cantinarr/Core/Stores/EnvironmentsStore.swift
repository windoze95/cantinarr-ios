// File: EnvironmentsStore.swift
// Purpose: Defines EnvironmentsStore component for Cantinarr

// This file relies on Combine and SwiftUI which are only available on Apple
// platforms. Guard its contents so the package can compile on Linux.
#if canImport(Combine) && canImport(SwiftUI)
import Combine
import Foundation
import SwiftUI

/// Where we save the single JSON blob by default.
private func defaultEnvironmentsFileURL() -> URL {
    // ~/Library/Application Support/Cantinarr/environments.json
    let dir = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        .appendingPathComponent("Cantinarr", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir,
                                             withIntermediateDirectories: true)
    return dir.appendingPathComponent("environments.json")
}

private let defaultFileURL = defaultEnvironmentsFileURL()

/// Global state: all servers + which one is selected
final class EnvironmentsStore: ObservableObject {
    private let fileURL: URL
    @Published var environments: [ServerEnvironment] {
        didSet { validateSelections() }
    }
    @Published var selectedEnvironmentID: ServerEnvironment.ID
    @Published var selectedServiceID: ServiceInstance.ID?

    private var saveCancellable: AnyCancellable?

    /// Used the first time the app launches.
    private static let sampleData: [ServerEnvironment] = {
        let overseerr = ServiceInstance(
            kind: .overseerrUsers,
            displayName: "Overseerr (Demo)",
            configuration: try? JSONEncoder().encode(
                OverseerrSettings(host: "192.168.35.150", port: "80", useSSL: false)
            )
        )
        return [ServerEnvironment(name: "Default", services: [overseerr])]
    }()

    init(fileURL: URL = defaultFileURL) {
        self.fileURL = fileURL
        // Load from disk or fall back to sample
        var envs = (try? Self.load(from: fileURL)) ?? Self.sampleData

        // Migrate Radarr API keys from stored configuration to Keychain
        for eIndex in envs.indices {
            for sIndex in envs[eIndex].services.indices {
                var svc = envs[eIndex].services[sIndex]
                if svc.kind == .radarr,
                   let data = svc.configuration,
                   let settings = try? JSONDecoder().decode(RadarrSettings.self, from: data),
                   let sanitized = try? JSONEncoder().encode(settings)
                {
                    // 'decode' already saved the API key to Keychain
                    svc.configuration = sanitized
                    envs[eIndex].services[sIndex] = svc
                }
            }
        }

        // Initial selections
        environments = envs
        selectedEnvironmentID = envs.first?.id ?? UUID()
        selectedServiceID = envs.first?.services.first?.id
        validateSelections()

        // Auto‑save whenever the list *or* the selection changes
        saveCancellable = Publishers
            .CombineLatest($environments, $selectedEnvironmentID)
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in // ① capture weak
                guard let self = self else { return } // ② unwrap
                try? self.save()
            }
    }

    private static func load(from url: URL) throws -> [ServerEnvironment] {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([ServerEnvironment].self, from: data)
    }

    @discardableResult
    private func save() throws -> URL {
        let data = try JSONEncoder().encode(environments)
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    /// Exposed for testing purposes to synchronously persist changes.
    @discardableResult
    func saveNow() throws -> URL {
        try save()
    }

    // MARK:  – Convenience

    var selectedEnvironment: ServerEnvironment {
        guard let env = environments.first(where: { $0.id == selectedEnvironmentID }) else {
            fatalError("selectedEnvironmentID not found in environments")
        }
        return env
    }

    var selectedServiceInstance: ServiceInstance? {
        selectedEnvironment.services.first { $0.id == selectedServiceID }
    }

    // MARK:  – Mutating helpers

    func select(environment env: ServerEnvironment) { selectedEnvironmentID = env.id }
    func select(service svc: ServiceInstance) { selectedServiceID = svc.id }

    /// Ensures current selections reference existing items.
    /// Falls back to the first available environment and service when needed.
    func validateSelections() {
        guard !environments.isEmpty else {
            selectedServiceID = nil
            return
        }

        // Environment
        if !environments.contains(where: { $0.id == selectedEnvironmentID }) {
            selectedEnvironmentID = environments.first!.id
        }

        // Service inside the selected environment
        if let env = environments.first(where: { $0.id == selectedEnvironmentID }) {
            if !env.services.contains(where: { $0.id == selectedServiceID }) {
                selectedServiceID = env.services.first?.id
            }
        } else {
            selectedServiceID = nil
        }
    }
}
#endif
