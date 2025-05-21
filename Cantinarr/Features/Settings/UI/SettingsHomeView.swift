// File: SettingsHomeView.swift
// Purpose: Defines SettingsHomeView component for Cantinarr

import SwiftUI

struct SettingsHomeView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var vm: SettingsViewModel
    @State private var editingEnv: EnvironmentDraft?
    @State private var editingService: ServiceDraft?
    @State private var currentEnvID: UUID?

    var body: some View {
        List {
            ForEach(vm.drafts) { env in
                Section {
                    HStack {
                        Text(env.name)
                        Spacer()
                        Button("Edit") { editingEnv = env }
                    }
                    ForEach(env.services) { svc in
                        HStack {
                            Text(svc.displayName)
                            Spacer()
                            Text(svc.kind.rawValue).foregroundColor(.secondary)
                            Button("Edit") { editingService = svc }
                        }
                    }
                    Button {
                        currentEnvID = env.id
                        editingService = ServiceDraft(
                            ServiceInstance(kind: .overseerrUsers,
                                            displayName: "",
                                            configuration: nil)
                        )
                    } label: {
                        Label("Add Service…", systemImage: "plus")
                    }
                } header: { Text(env.name) }
            }
            .onDelete { vm.deleteEnvironments(at: $0) }
        }
        .navigationTitle("Environments")
        .toolbar { Button("Add") { vm.addEnvironment() } }
        .sheet(item: $editingEnv) { draft in
            NavigationStack {
                EnvironmentEditorView(draft: draft) { newDraft in
                    if let idx = vm.drafts.firstIndex(of: draft) {
                        vm.drafts[idx] = newDraft // write‑back
                    }
                }
            }
        }
        .sheet(item: $editingService) { draft in
            NavigationStack {
                ServiceEditorView(draft: draft) { new in
                    // Locate the environment that opened the sheet
                    if let eIdx = vm.drafts.firstIndex(where: { $0.id == currentEnvID }) {
                        // Is this an edit (already exists) … ?
                        if let sIdx = vm.drafts[eIdx].services.firstIndex(of: draft) {
                            vm.drafts[eIdx].services[sIdx] = new // ▸ update
                        } else {
                            // … or a brand‑new service?
                            vm.drafts[eIdx].services.append(new) // ▸ insert
                        }
                    }
                }
            }
        }
    }
}
