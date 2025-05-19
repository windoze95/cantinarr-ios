import Foundation

/// Mutable wrapper used only inside the Settings editor UI
struct EnvironmentDraft: Identifiable, Hashable {
    var id: UUID
    var name: String
    var services: [ServiceDraft]

    init(_ env: ServerEnvironment) {
        id = env.id
        name = env.name
        services = env.services.map(ServiceDraft.init)
    }

    func toModel() -> ServerEnvironment {
        ServerEnvironment(id: id,
                    name: name,
                    services: services.map { $0.toModel() })
    }
}

struct ServiceDraft: Identifiable, Hashable {
    var id: UUID
    var kind: ServiceKind
    var displayName: String
    var configurationJSON: String        // raw editable json string

    init(_ svc: ServiceInstance) {
        id = svc.id
        kind = svc.kind
        displayName = svc.displayName
        configurationJSON = svc.configuration
            .flatMap { String(data:$0,encoding:.utf8) } ?? "{}"
    }

    func toModel() -> ServiceInstance {
        ServiceInstance(id: id,
                        kind: kind,
                        displayName: displayName,
                        configuration: configurationJSON.data(using: .utf8))
    }
}
