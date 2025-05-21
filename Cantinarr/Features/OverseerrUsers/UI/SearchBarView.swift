// File: SearchBarView.swift
// Purpose: Defines SearchBarView component for Cantinarr

import SwiftUI
import UIKit

/// A reusable search bar that can be dropped into any view.
struct SearchBarView: View {
    @Binding var text: String

    var focus: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search", text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused(focus)

            if !text.isEmpty {
                Button {
                    text = ""
                    focus.wrappedValue = false
                    UIApplication.shared.endEditing() // force-hide keyboard
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemGray5))
        )
        .animation(.default, value: text) // animate the clear‑button
    }
}
