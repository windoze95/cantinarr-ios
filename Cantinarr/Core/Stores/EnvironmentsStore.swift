import SwiftUI
import Combine
import Foundation

/// Where we save the single JSON blob.
private let environmentsFileURL: URL = {
    // ~/Library/Application Support/Cantinarr/environments.json
    let dir = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        .appendingPathComponent("Cantinarr", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir,
                                             withIntermediateDirectories: true)
    return dir.appendingPathComponent("environments.json")
}()

/// Global state: all servers + which one is selected
final class EnvironmentsStore: ObservableObject {
    @Published var environments: [ServerEnvironment]
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

    init() {
        // Load from disk or fall back to sample
        let envs = (try? Self.load()) ?? Self.sampleData

        // Initial selections
        self.environments          = envs
            self.selectedEnvironmentID = envs.first?.id ?? UUID()
            self.selectedServiceID     = envs.first?.services.first?.id

        // Auto‑save whenever the list *or* the selection changes
        saveCancellable = Publishers
            .CombineLatest($environments, $selectedEnvironmentID)
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in                    // ① capture weak
                guard let self = self else { return }   // ② unwrap
                try? self.save()
            }
    }
    
    private static func load() throws -> [ServerEnvironment] {
        let data = try Data(contentsOf: environmentsFileURL)
        return try JSONDecoder().decode([ServerEnvironment].self, from: data)
    }
    
    @discardableResult
    private func save() throws -> URL {
        let data = try JSONEncoder().encode(environments)
        try data.write(to: environmentsFileURL, options: .atomic)
        return environmentsFileURL
    }

    // MARK: – Convenience
    var selectedEnvironment: ServerEnvironment {
        environments.first { $0.id == selectedEnvironmentID }!
    }
    var selectedServiceInstance: ServiceInstance? {
        selectedEnvironment.services.first { $0.id == selectedServiceID }
    }

    // MARK: – Mutating helpers
    func select(environment env: ServerEnvironment) { selectedEnvironmentID = env.id }
    func select(service svc: ServiceInstance) { selectedServiceID     = svc.id }
}
