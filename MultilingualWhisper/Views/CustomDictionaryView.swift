import SwiftUI

struct CustomDictionaryView: View {
    let dictionaryService: CustomDictionaryService
    @State private var showingAddSheet = false

    var body: some View {
        List {
            if dictionaryService.entries.isEmpty {
                ContentUnavailableView(
                    "No Corrections Yet",
                    systemImage: "textformat.abc",
                    description: Text("Add a word Whisper keeps getting wrong, and what it should say instead.")
                )
            } else {
                ForEach(dictionaryService.entries) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.original)
                            .strikethrough()
                            .foregroundStyle(.secondary)
                        Text(entry.replacement)
                            .font(.headline)
                    }
                }
                .onDelete(perform: dictionaryService.remove)
            }
        }
        .navigationTitle("Custom Dictionary")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddSheet = true
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddDictionaryEntrySheet(dictionaryService: dictionaryService)
        }
    }
}

/// Every correction applies as soon as it's saved - no separate "enable" step, and no
/// language/model picker, because the substitution runs on the final text after any
/// model has already produced it (see `WhisperService.joined(_:)`).
private struct AddDictionaryEntrySheet: View {
    let dictionaryService: CustomDictionaryService
    @Environment(\.dismiss) private var dismiss
    @State private var original = ""
    @State private var replacement = ""

    private var canSave: Bool {
        !original.trimmingCharacters(in: .whitespaces).isEmpty
            && !replacement.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What Whisper hears", text: $original)
                        .autocorrectionDisabled()
                    TextField("What it should say", text: $replacement)
                        .autocorrectionDisabled()
                } footer: {
                    Text("Case-insensitive, whole word - e.g. \"Nassar\" corrected to \"Nasar\".")
                }
            }
            .navigationTitle("New Correction")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        dictionaryService.add(original: original, replacement: replacement)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}
