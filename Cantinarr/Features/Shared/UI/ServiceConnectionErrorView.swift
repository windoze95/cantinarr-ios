// File: ServiceConnectionErrorView.swift
// Purpose: Defines ServiceConnectionErrorView component for Cantinarr

import SwiftUI

/// Generic error view shown when a service can't be reached.
struct ServiceConnectionErrorView: View {
    let serviceName: String
    let errorMessage: String
    let onRetry: () -> Void
    let onEditSettings: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "wifi.exclamationmark")
                .font(.largeTitle)
                .imageScale(.large)
                .foregroundColor(.orange)

            Text("Cannot Connect to \(serviceName)")
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)

            Text(errorMessage)
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: onRetry) {
                Label("Retry", systemImage: "arrow.clockwise")
                    .padding(.horizontal)
                    .frame(minWidth: 150)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)

            Button(action: onEditSettings) {
                Text("Edit Service Settings")
                    .frame(minWidth: 150)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(Color(.systemGroupedBackground).edgesIgnoringSafeArea(.all)) // Or your app's background
    }
}

#if DEBUG
    struct ServiceConnectionErrorView_Previews: PreviewProvider {
        static var previews: some View {
            ServiceConnectionErrorView(
                serviceName: "Demo Overseerr",
                errorMessage: "The server at 192.168.1.100:5055 could not be reached. Please check your network connection and the service settings.",
                onRetry: { print("Retry tapped") },
                onEditSettings: { print("Edit Settings tapped") }
            )
        }
    }
#endif
