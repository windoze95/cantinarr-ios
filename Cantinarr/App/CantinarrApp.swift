// File: CantinarrApp.swift
// Purpose: Defines CantinarrApp component for Cantinarr

import SwiftUI

/// Main application entry point.
@main
struct CantinarrApp: App {
    // If you still need Core Data elsewhere, you can keep this.
    let persistenceController = PersistenceController.shared

    @StateObject private var environmentsStore = EnvironmentsStore()
    @StateObject private var userSession = UserSession()

    init() {
        // Bootstrap OverseerrAuthManager once.
        // The demo environment always has at least one service:
        if let demoSvc = EnvironmentsStore().selectedServiceInstance?
            .decode(OverseerrSettings.self)
        {
            let svc = OverseerrAPIService(settings: demoSvc)
            Task { await OverseerrAuthManager.shared.configure(service: svc) }
        }
    }

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            ContentView()
                // Only include this if you actually need the Core Data context in your views.
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(environmentsStore)
                .environmentObject(userSession)
        }
    }
}
