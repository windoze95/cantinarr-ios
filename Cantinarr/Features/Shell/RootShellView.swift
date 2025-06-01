// File: RootShellView.swift
// Purpose: Defines RootShellView component for Cantinarr

#if canImport(SwiftUI)
import SwiftUI

/// The global frame: a slide‑out sidebar on the left + a detail pane.
struct RootShellView: View {
    @EnvironmentObject private var envStore: EnvironmentsStore

    // Drawer & sheet state
    @State private var isMenuOpen = false
    @State private var showSettingsSheet = false

    /// Width of the invisible edge used to detect swipe-from-edge gestures.
    private let edgeWidth: CGFloat = 24

    /// Provides drag and tap gestures for the side menu.
    /// The thresholds are defined in ``SideMenuGestureManager``.
    private var menuGestures: SideMenuGestureManager {
        SideMenuGestureManager(
            openMenu: { withAnimation { isMenuOpen = true } },
            closeMenu: { withAnimation { isMenuOpen = false } }
        )
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // Main content
            NavigationStack {
                detailContent
                    .navigationTitle(envStore.selectedEnvironment.name)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button {
                                withAnimation { isMenuOpen = true }
                            } label: {
                                Image(systemName: "line.3.horizontal")
                            }
                        }
                    }
            }
            .offset(x: isMenuOpen ? 260 : 0)
            .animation(.easeOut(duration: 0.25), value: isMenuOpen)
            // ───── Shield overlay while the drawer is open ─────
            .overlay {
                if isMenuOpen {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { menuGestures.closeMenu() }
                        .gesture(menuGestures.closeDragGesture())
                        .ignoresSafeArea()
                }
            }
            // Gesture to close menu by swiping left on content area
            .gesture(menuGestures.closeDragGesture())
            // Overlay for edge swipe to open menu
            .overlay(alignment: .leading) {
                if !isMenuOpen {
                    Color.clear
                        .frame(width: edgeWidth)
                        .contentShape(Rectangle())
                        .gesture(menuGestures.openDragGesture())
                        .ignoresSafeArea(.container, edges: [.vertical])
                }
            }

            // Drawer
            if isMenuOpen {
                SideMenuView(
                    closeMenu: { withAnimation { isMenuOpen = false } },
                    openSettings: {
                        // When opening settings from the general SideMenu,
                        // we don't pre-select a specific service for editing.
                        openGeneralSettings()
                    }
                )
                .transition(.move(edge: .leading))
                .zIndex(1)
            }
        }
        // Settings sheet ↓
        .sheet(isPresented: $showSettingsSheet) {
            NavigationStack {
                SettingsHomeView(vm: SettingsViewModel(store: envStore))
                    .navigationBarTitle("Settings", displayMode: .inline)
            }
            .presentationDetents([.medium, .large])
        }
        // Ensure a service is pre‑selected on env switch
        .onChange(of: envStore.selectedEnvironmentID) { _ in
            envStore.selectedServiceID = envStore.selectedEnvironment.services.first?.id
        }
    }

    /// Opens the general settings sheet.
    func openGeneralSettings() {
        showSettingsSheet = true
    }

    // MARK: – Detail

    @ViewBuilder
    private var detailContent: some View {
        if let svcID = envStore.selectedServiceID,
           let selectedServiceInstance = envStore.selectedServiceInstance
        { // Get the full instance to check its kind
            switch selectedServiceInstance.kind {
            case .overseerrUsers:
                if let overseerrSettings = selectedServiceInstance.decode(OverseerrSettings.self) {
                    OverseerrUsersHomeEntry(
                        settings: overseerrSettings,
                        openSettingsSheetForCurrentService: {
                            self.showSettingsSheet = true
                        }
                    )
                    .id(svcID) // Recreate the view when the service ID changes
                } else {
                    // This case should ideally not happen if selection implies valid settings
                    Text("Error: Could not load Overseerr settings for \(selectedServiceInstance.displayName).")
                        .foregroundColor(.red)
                }

            case .radarr:
                if let radarrSettings = selectedServiceInstance.decode(RadarrSettings.self) {
                    RadarrHomeEntry(
                        settings: radarrSettings,
                        openSettingsSheetForCurrentService: {
                            self.showSettingsSheet = true
                        }
                    )
                    .id(svcID) // Recreate the view when the service ID changes
                } else {
                    Text("Error: Could not load Radarr settings for \(selectedServiceInstance.displayName).")
                        .foregroundColor(.red)
                }
            }

        } else {
            // Placeholder when no service is selected or no services configured
            VStack {
                Spacer()
                Text(envStore.selectedEnvironment.services
                    .isEmpty ? "No services configured for this environment." : "Select a service from the menu.")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                if envStore.selectedEnvironment.services.isEmpty {
                    Button("Add Service in Settings") {
                        openGeneralSettings()
                    }
                    .padding(.top)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
#endif
