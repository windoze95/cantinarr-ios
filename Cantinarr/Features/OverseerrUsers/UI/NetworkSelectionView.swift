// File: NetworkSelectionView.swift
// Purpose: Defines NetworkSelectionView component for Cantinarr

import SwiftUI

/// A sheet that lists all watchProviders with checkmarks, letting the user tap to select/deselect.
struct NetworkSelectionView: View {
    @EnvironmentObject var vm: OverseerrUsersViewModel // get the providers & selected set
    @Environment(\.dismiss) var dismiss // to close the sheet

    var body: some View {
        NavigationView {
            List(vm.watchProviders) { provider in
                HStack {
                    Text(provider.name) // network name
                    Spacer()
                    if vm.selectedProviders.contains(provider.id) {
                        Image(systemName: "checkmark") // show checkmark if selected
                            .foregroundColor(.accentColor)
                    }
                }
                .contentShape(Rectangle()) // make full row tappable
                .onTapGesture {
                    // toggle selection
                    if vm.selectedProviders.contains(provider.id) {
                        vm.selectedProviders.remove(provider.id)
                    } else {
                        vm.selectedProviders.insert(provider.id)
                    }
                }
            }
            .navigationTitle("Select Networks")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                        Task { await vm.loadMedia(reset: true) }
                    }
                }
            }
        }
    }
}
