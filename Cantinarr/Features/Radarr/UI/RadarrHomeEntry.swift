// File: RadarrHomeEntry.swift
// Purpose: Defines RadarrHomeEntry component for Cantinarr

import SwiftUI

/// Entry point that hosts all Radarr-related tabs.
struct RadarrHomeEntry: View {
    let settings: RadarrSettings
    var openSettingsSheetForCurrentService: () -> Void

    // The Radarr service instance doesn't need to be a @StateObject if it doesn't
    // have @Published properties that this view observes. It's created once and
    // passed to ViewModels that ARE @StateObjects.
    private let radarrServiceInstance: RadarrServiceType

    @State private var initialConnectionError: String? = nil
    @State private var isLoadingInitialCheck: Bool = true

    // ViewModels for each tab ARE @StateObjects
    @StateObject private var moviesVM: RadarrMoviesViewModel
    // Add other ViewModels for Upcoming, Missing etc. later

    init(settings: RadarrSettings, openSettingsSheetForCurrentService: @escaping () -> Void) {
        self.settings = settings
        self.openSettingsSheetForCurrentService = openSettingsSheetForCurrentService

        let service = RadarrAPIService(settings: settings)
        radarrServiceInstance = service // Store the instance
        _moviesVM = StateObject(wrappedValue: RadarrMoviesViewModel(service: service))
        // Initialize other VMs here using the same 'service' instance
    }

    private func performInitialCheckAndLoad() async {
        isLoadingInitialCheck = true
        initialConnectionError = nil
        do {
            // Use the stored instance for the check
            _ = try await radarrServiceInstance.getSystemStatus()
        } catch let APIServiceError.apiError(message: message, statusCode: statusCode) {
            self.initialConnectionError = "Radarr API Error (\(statusCode)): \(message). Please check your network connection or edit the service settings."
        } catch {
            initialConnectionError = "Could not connect to Radarr: \(error.localizedDescription). Please check your network connection or edit the service settings."
        }
        isLoadingInitialCheck = false
    }

    var body: some View {
        Group {
            if isLoadingInitialCheck {
                ProgressView("Connecting to Radarr...")
                    .task { await performInitialCheckAndLoad() }
            } else if let error = initialConnectionError {
                ServiceConnectionErrorView(
                    serviceName: settings.host, // Or a more friendly name from EnvironmentsStore if available
                    errorMessage: error,
                    onRetry: { Task { await performInitialCheckAndLoad() } },
                    onEditSettings: openSettingsSheetForCurrentService
                )
            } else {
                TabView {
                    RadarrMoviesView(viewModel: moviesVM)
                        .tabItem {
                            Label("Movies", systemImage: "film")
                        }

                    // Placeholder for Upcoming
                    Text("Upcoming (Radarr)")
                        .tabItem {
                            Label("Upcoming", systemImage: "calendar.badge.clock")
                        }

                    // Placeholder for Missing
                    Text("Missing (Radarr)")
                        .tabItem {
                            Label("Missing", systemImage: "questionmark.folder")
                        }

                    // Placeholder for More
                    Text("More Options (Radarr)")
                        .tabItem {
                            Label("More", systemImage: "ellipsis.circle")
                        }
                }
                .accentColor(.cantinarrAccent) // Use your app's accent color
            }
        }
    }
}
