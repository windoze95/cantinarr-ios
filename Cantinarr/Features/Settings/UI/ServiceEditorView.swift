// File: ServiceEditorView.swift
// Purpose: Defines ServiceEditorView component for Cantinarr

import SwiftUI

/// Sheet for configuring a single ServiceInstance inside an Environment.
struct ServiceEditorView: View {
    @State private var draft: ServiceDraft
    let onSave: (ServiceDraft) -> Void
    @Environment(\.dismiss) private var dismiss

    // ───────── Validation helpers
    private var isDisplayNameOK: Bool {
        !draft.displayName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var isJSONValid: Bool {
        guard let data = draft.configurationJSON.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: data)) != nil
    }

    init(draft: ServiceDraft,
         onSave: @escaping (ServiceDraft) -> Void)
    {
        _draft = State(initialValue: draft)
        self.onSave = onSave
    }

    var body: some View {
        Form {
            Section("Kind") {
                Picker("Kind", selection: $draft.kind) {
                    ForEach(ServiceKind.allCases) { kind in
                        Text(kind.rawValue).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Display name") {
                TextField("e.g. “Overseerr – Basement Plex”", text: $draft.displayName)
            }

            Section("Configuration (JSON)") {
                ZStack {
                    TextEditor(text: $draft.configurationJSON)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 160)
                        // Red border if JSON invalid
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isJSONValid ? Color.clear : Color.red, lineWidth: 2)
                        )
                }
            }
        }
        .navigationTitle(draft.displayName.isEmpty ? "New Service"
            : "Edit Service")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    onSave(draft)
                    dismiss()
                }
                .disabled(!(isDisplayNameOK && isJSONValid))
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }
}
