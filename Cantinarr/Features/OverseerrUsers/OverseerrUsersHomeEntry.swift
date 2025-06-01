// File: OverseerrUsersHomeEntry.swift
// Purpose: Defines OverseerrUsersHomeEntry component for Cantinarr

import Combine // Import Combine
import SwiftUI

/// Enum to represent the tabs in the Overseerr section.
enum OverseerrTab {
    case home
    case advanced
}

/// Thin wrapper that creates the two view‑models and injects them.
/// Manages switching between Home and Advanced views for Overseerr via a TabView.
/// Also handles displaying connection errors for the selected service **based on OverseerrAuthState**.
struct OverseerrUsersHomeEntry: View {
    let settings: OverseerrSettings
    // State to manage the selected tab
    @State private var selectedTab: OverseerrTab = .home

    // ViewModels are created here and their lifecycle is tied to this entry point.
    @StateObject private var trendingVM: TrendingViewModel
    @StateObject private var overseerrUsersVM: OverseerrUsersViewModel

    // EnvironmentObject to get service display name
    @EnvironmentObject private var envStore: EnvironmentsStore

    // Callback to open the settings sheet for the current service
    var openSettingsSheetForCurrentService: () -> Void

    init(settings: OverseerrSettings, openSettingsSheetForCurrentService: @escaping () -> Void) {
        self.settings = settings
        self.openSettingsSheetForCurrentService = openSettingsSheetForCurrentService

        // Create the API service instance once
        let apiService = OverseerrAPIService(settings: settings)

        // Initialize ViewModels
        _trendingVM = StateObject(wrappedValue: TrendingViewModel(service: apiService))
        _overseerrUsersVM = StateObject(wrappedValue: OverseerrUsersViewModel(
            service: apiService,
            settingsKey: settings.host + (settings.port ?? "")
        ))
    }

    var body: some View {
        // Main view structure driven by authentication state
        switch overseerrUsersVM.authState {
        case .unknown:
            ProgressView("Checking session…")
                .task { await overseerrUsersVM.onAppear() } // Trigger auth check
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .unauthenticated:
            // Show login view when not authenticated.
            OverseerrLoginView(
                onLoginTap: {
                    if let s = envStore.selectedServiceInstance?.decode(OverseerrSettings.self) {
                        overseerrUsersVM.startPlexSSO(host: s.host, port: s.port)
                    }
                },
                onEditSettings: openSettingsSheetForCurrentService // Allow editing settings from login view
            )
            .task { await overseerrUsersVM.onAppear() } // Re-check auth if view appears again

        case .authenticated:
            // User is authenticated: Show TabView with Home and Advanced views
            TabView(selection: $selectedTab) {
                OverseerrUsersHomeView(
                    trendingVM: trendingVM,
                    overseerrUsersVM: overseerrUsersVM
                )
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(OverseerrTab.home) // Tag for selection binding

                OverseerrUsersAdvancedView(
                    viewModel: overseerrUsersVM
                )
                .tabItem {
                    Label("Advanced", systemImage: "slider.horizontal.3")
                }
                .tag(OverseerrTab.advanced) // Tag for selection binding
            }
            .onReceive(overseerrUsersVM.keywordActivatedSubject) { _ in
                // When the subject sends a value, switch the tab
                selectedTab = .advanced
            }
            // Ensure basic configurations (like providers) are loaded upon authentication
            .task {
                if overseerrUsersVM.watchProviders.isEmpty && overseerrUsersVM.connectionError == nil {
                    await overseerrUsersVM.loadAllBasics()
                }
            }
        }
    }

    // Extracted Login View (remains the same)
    struct OverseerrLoginView: View {
        var onLoginTap: () -> Void
        var onEditSettings: () -> Void

        var body: some View {
            VStack(spacing: 15) {
                Spacer()
                Image(systemName: "link.icloud.fill") // Example icon
                    .font(.largeTitle)
                    .imageScale(.large)
                    .foregroundColor(.blue)
                    .padding(.bottom)
                Text("Login Required")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.bottom, 5)
                Text("Please login with your Plex account to access Overseerr features.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button(action: onLoginTap) {
                    Label("Login with Plex", systemImage: "arrow.right.to.line")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.orange) // Plex orange
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .padding(.horizontal)

                Button("Edit Service Settings", action: onEditSettings)
                    .buttonStyle(.bordered)
                    .padding(.top, 5)

                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground).edgesIgnoringSafeArea(.all))
        }
    }
}
