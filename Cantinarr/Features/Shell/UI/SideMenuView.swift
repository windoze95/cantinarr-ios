// File: SideMenuView.swift
// Purpose: Defines SideMenuView component for Cantinarr

import SwiftUI

/// Drawer content: gear, services, utilities, env‑picker.
struct SideMenuView: View {
    @EnvironmentObject private var envStore: EnvironmentsStore

    /// Callbacks for host container
    var closeMenu: () -> Void
    var openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ───── Gear row
            Button {
                closeMenu() // close drawer
                openSettings()
            } label: {
                Label("Settings", systemImage: "gearshape")
                    .font(.headline)
                    .padding()
            }
            .accessibilityIdentifier("settingsRow")
            .padding(.vertical, 80)

            Divider()

            // ───── Services
            Text("Services")
                .font(.caption).padding(.horizontal)
            ForEach(envStore.selectedEnvironment.services) { svc in
                Button {
                    envStore.select(service: svc)
                    closeMenu()
                } label: {
                    HStack {
                        Text(svc.displayName)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal)
                }
            }

            Spacer()

            // ───── Environment picker bottom‑sticky
            Picker("Environment", selection: $envStore.selectedEnvironmentID) {
                ForEach(envStore.environments) { env in Text(env.name).tag(env.id) }
            }
            .pickerStyle(.segmented)
            .padding()
        }
        .frame(maxWidth: 260, alignment: .leading) // drawer width
        .background(Material.ultraThin)
        .edgesIgnoringSafeArea(.all)
        .highPriorityGesture( // wins over button taps
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    if value.translation.width < -80 { // swipe left ≥ 80 pts
                        closeMenu() // supplied callback
                    }
                }
        )
    }
}
