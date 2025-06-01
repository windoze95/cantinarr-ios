// File: ContentView.swift
// Purpose: Defines ContentView component for Cantinarr

import SwiftUI

/// Entrypoint view that loads ``RootShellView``.
struct ContentView: View {
    var body: some View {
        RootShellView()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(EnvironmentsStore())
            .environment(\.managedObjectContext,
                         PersistenceController.shared.container.viewContext)
    }
}
