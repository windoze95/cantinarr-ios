import SwiftUI

/// Sheet used from `SettingsHomeView` to create / rename / delete an Environment.
struct EnvironmentEditorView: View {
    // Pass‑in a *copy* of the draft so we can cancel without side‑effects.
    @State private var draft: EnvironmentDraft
    let onSave: (EnvironmentDraft) -> Void // caller mutates its array
    @Environment(\.dismiss) private var dismiss

    init(draft: EnvironmentDraft,
         onSave: @escaping (EnvironmentDraft) -> Void)
    {
        _draft = State(initialValue: draft)
        self.onSave = onSave
    }

    var body: some View {
        Form {
            Section("Name") {
                TextField("Environment name", text: $draft.name)
                    .textInputAutocapitalization(.words)
            }
        }
        .navigationTitle(draft.name.isEmpty ? "New Environment"
            : "Edit Environment")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    onSave(draft)
                    dismiss()
                }
                .disabled(draft.name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }
}
