// File: ManageMediaSheet.swift
// Purpose: Defines ManageMediaSheet component for Cantinarr

import SwiftUI

/// Placeholder sheet for future media management actions.
struct ManageMediaSheet: View {
    let mediaID: Int
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        Text("Manage media \(mediaID)")
            .padding()
            .toolbar { Button("Done") { dismiss() } }
    }
}
