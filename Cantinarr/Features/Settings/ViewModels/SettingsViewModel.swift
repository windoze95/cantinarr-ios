// File: SettingsViewModel.swift
// Purpose: Defines SettingsViewModel component for Cantinarr

import Combine
import SwiftUI

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var drafts: [EnvironmentDraft] = []

    private let store: EnvironmentsStore
    private var cancellables = Set<AnyCancellable>()

    init(store: EnvironmentsStore) {
        self.store = store
        // Make a deep copy of drafts to avoid direct mutation issues with store's source
        drafts = store.environments.map { EnvironmentDraft($0) }

        // Propagate edits back to store
        $drafts
            .dropFirst() // Avoid initial sync
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main) // Debounce to avoid rapid saves
            .sink { [weak store] newDrafts in
                store?.environments = newDrafts.map { $0.toModel() }
            }
            .store(in: &cancellables)
    }

    func addEnvironment() {
        let newEnv = EnvironmentDraft(ServerEnvironment(name: "New Environment"))
        drafts.append(newEnv)
    }

    func deleteEnvironments(at offsets: IndexSet) {
        drafts.remove(atOffsets: offsets)
    }

    // New method to delete a service from a specific environment
    func deleteService(inEnvironment envID: UUID, at offsets: IndexSet) {
        guard let envIndex = drafts.firstIndex(where: { $0.id == envID }) else { return }
        drafts[envIndex].services.remove(atOffsets: offsets)
    }
}
