// File: ServiceEditorView.swift
// Purpose: Defines ServiceEditorView component for Cantinarr

import SwiftUI

/// Sheet for configuring a single ServiceInstance inside an Environment.
struct ServiceEditorView: View {
    @State private var draft: ServiceDraft
    let onSave: (ServiceDraft) -> Void
    @Environment(\.dismiss) private var dismiss

    // Typed configurations for supported service kinds
    @State private var radarrSettings: RadarrSettings =
        .init(host: "", apiKey: "")
    @State private var overseerrSettings: OverseerrSettings =
        .init(host: "", port: nil)

    // ───────── Validation helpers
    private var isDisplayNameOK: Bool {
        !draft.displayName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var isConfigurationValid: Bool {
        switch draft.kind {
        case .radarr:
            return !radarrSettings.host.trimmingCharacters(in: .whitespaces).isEmpty &&
                !radarrSettings.apiKey.isEmpty
        case .overseerrUsers:
            return !overseerrSettings.host.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    init(draft: ServiceDraft,
         onSave: @escaping (ServiceDraft) -> Void)
    {
        _draft = State(initialValue: draft)
        self.onSave = onSave

        if draft.kind == .radarr,
           let data = draft.configurationJSON.data(using: .utf8),
           let settings = try? JSONDecoder().decode(RadarrSettings.self, from: data)
        {
            _radarrSettings = State(initialValue: settings)
        }

        if draft.kind == .overseerrUsers,
           let data = draft.configurationJSON.data(using: .utf8),
           let settings = try? JSONDecoder().decode(OverseerrSettings.self, from: data)
        {
            _overseerrSettings = State(initialValue: settings)
        }
    }

    var body: some View {
        Form {
            Section("Kind") {
                Picker("Kind", selection: $draft.kind) {
                    ForEach(ServiceKind.allCases) { kind in
                        Text(kind.rawValue).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Display name") {
                TextField("e.g. “Overseerr – Basement Plex”", text: $draft.displayName)
            }

            Section("Configuration") {
                switch draft.kind {
                case .radarr:
                    TextField("Host", text: $radarrSettings.host)
                        .textInputAutocapitalization(.none)
                        .autocorrectionDisabled()
                    TextField(
                        "Port",
                        text: Binding(
                            get: { radarrSettings.port ?? "" },
                            set: { radarrSettings.port = $0.isEmpty ? nil : $0 }
                        )
                    )
                    Toggle("Use SSL", isOn: $radarrSettings.useSSL)
                    TextField(
                        "URL Base",
                        text: Binding(
                            get: { radarrSettings.urlBase ?? "" },
                            set: { radarrSettings.urlBase = $0.isEmpty ? nil : $0 }
                        )
                    )
                    SecureField("API Key", text: $radarrSettings.apiKey)
                    Toggle("Primary Instance", isOn: $radarrSettings.isPrimary)
                case .overseerrUsers:
                    TextField("Host", text: $overseerrSettings.host)
                        .textInputAutocapitalization(.none)
                        .autocorrectionDisabled()
                    TextField(
                        "Port",
                        text: Binding(
                            get: { overseerrSettings.port ?? "" },
                            set: { overseerrSettings.port = $0.isEmpty ? nil : $0 }
                        )
                    )
                    Toggle("Use SSL", isOn: $overseerrSettings.useSSL)
                }
            }
        }
        .navigationTitle(draft.displayName.isEmpty ? "New Service"
            : "Edit Service")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    var outgoing = draft
                    switch draft.kind {
                    case .radarr:
                        let settings = radarrSettings
                        if let apiData = settings.apiKey.data(using: .utf8) {
                            KeychainHelper.save(
                                key: RadarrSettings.keychainKey(host: settings.host, port: settings.port),
                                data: apiData
                            )
                        }
                        if let sanitized = try? JSONEncoder().encode(settings),
                           let jsonString = String(data: sanitized, encoding: .utf8)
                        {
                            outgoing.configurationJSON = jsonString
                        }
                    case .overseerrUsers:
                        let settings = overseerrSettings
                        if let sanitized = try? JSONEncoder().encode(settings),
                           let jsonString = String(data: sanitized, encoding: .utf8)
                        {
                            outgoing.configurationJSON = jsonString
                        }
                    }
                    onSave(outgoing)
                    dismiss()
                }
                .disabled(!(isDisplayNameOK && isConfigurationValid))
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }
}
