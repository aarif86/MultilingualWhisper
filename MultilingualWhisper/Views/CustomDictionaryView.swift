import SwiftUI
import UniformTypeIdentifiers

struct CustomDictionaryView: View {
    let dictionaryService: CustomDictionaryService

    @State private var editorMode: DictionaryEditorMode?
    @State private var showingPasteSheet = false
    @State private var showingFileImporter = false
    @State private var importSummary: CustomDictionaryService.ImportSummary?
    @State private var importError: String?
    @State private var exportFile: ExportFile?
    @State private var searchText = ""

    private var filteredEntries: [DictionaryEntry] {
        let needle = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return dictionaryService.entries }
        return dictionaryService.entries.filter { entry in
            entry.replacement.lowercased().contains(needle)
                || entry.spokenForms.contains { $0.lowercased().contains(needle) }
        }
    }

    var body: some View {
        Group {
            if dictionaryService.entries.isEmpty {
                emptyState
            } else {
                entryList
            }
        }
        .navigationTitle("Custom Dictionary")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showingPasteSheet = true
                    } label: {
                        Label("Paste a List…", systemImage: "doc.on.clipboard")
                    }
                    Button {
                        showingFileImporter = true
                    } label: {
                        Label("Import from File…", systemImage: "square.and.arrow.down")
                    }
                    Button {
                        exportFile = ExportFile.write(dictionaryService.exportCSV())
                    } label: {
                        Label("Export CSV", systemImage: "square.and.arrow.up")
                    }
                    .disabled(dictionaryService.entries.isEmpty)
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
                Button {
                    editorMode = .add
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
        }
        .sheet(item: $editorMode) { mode in
            DictionaryEntryEditor(mode: mode, dictionaryService: dictionaryService)
        }
        .sheet(isPresented: $showingPasteSheet) {
            PasteListSheet { text in
                importSummary = dictionaryService.importText(text)
            }
        }
        .sheet(item: $exportFile) { file in
            ExportSheet(file: file)
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.commaSeparatedText, .tabSeparatedText, .plainText, .text],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .alert("Import Finished", isPresented: Binding(get: { importSummary != nil }, set: { if !$0 { importSummary = nil } })) {
            Button("OK", role: .cancel) { importSummary = nil }
        } message: {
            if let importSummary {
                Text(Self.describe(importSummary))
            }
        }
        .alert("Couldn't Import", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
            Button("OK", role: .cancel) { importError = nil }
        } message: {
            Text(importError ?? "")
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Corrections Yet", systemImage: "textformat.abc")
        } description: {
            Text("Add a word Whisper keeps getting wrong and what it should say instead. Or paste a list from another dictation app.")
        } actions: {
            Button("Add a Correction") { editorMode = .add }
                .buttonStyle(.borderedProminent)
            Button("Paste a List") { showingPasteSheet = true }
        }
    }

    private var entryList: some View {
        List {
            Section {
                ForEach(filteredEntries) { entry in
                    Button {
                        editorMode = .edit(entry)
                    } label: {
                        DictionaryEntryRow(entry: entry)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { offsets in
                    let ids = offsets.map { filteredEntries[$0].id }
                    for id in ids { dictionaryService.remove(id: id) }
                }
            } footer: {
                Text("Corrections apply to every transcript, with every model, in one pass. Longer phrases win, and each spoken form belongs to one correction only.")
            }
        }
        .searchable(text: $searchText, prompt: "Search corrections")
        .overlay {
            if filteredEntries.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            importError = error.localizedDescription
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            do {
                let text = try Self.readText(at: url)
                importSummary = dictionaryService.importText(text)
            } catch {
                importError = error.localizedDescription
            }
        }
    }

    static func readText(at url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        if let utf8 = String(data: data, encoding: .utf8) { return utf8 }
        if let utf16 = String(data: data, encoding: .utf16) { return utf16 }
        if let latin1 = String(data: data, encoding: .isoLatin1) { return latin1 }
        throw CocoaError(.fileReadInapplicableStringEncoding)
    }

    static func describe(_ summary: CustomDictionaryService.ImportSummary) -> String {
        var parts: [String] = []
        parts.append("\(summary.added) added")
        if summary.updated > 0 { parts.append("\(summary.updated) updated with new spoken forms") }
        if summary.skipped > 0 { parts.append("\(summary.skipped) already present") }
        if summary.invalid > 0 { parts.append("\(summary.invalid) line\(summary.invalid == 1 ? "" : "s") couldn't be read") }
        return parts.joined(separator: ", ") + "."
    }
}

// MARK: - Row

private struct DictionaryEntryRow: View {
    let entry: DictionaryEntry

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.replacement)
                    .font(.headline)
                Text("Heard as: " + entry.spokenForms.joined(separator: ", "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            if !entry.matchWholeWord || entry.matchCase {
                HStack(spacing: 4) {
                    if !entry.matchWholeWord {
                        Image(systemName: "text.word.spacing")
                            .accessibilityLabel("Matches inside words")
                    }
                    if entry.matchCase {
                        Image(systemName: "textformat")
                            .accessibilityLabel("Case sensitive")
                    }
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Editor

enum DictionaryEditorMode: Identifiable {
    case add
    case edit(DictionaryEntry)

    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let entry): return entry.id.uuidString
        }
    }
}

/// Every correction applies as soon as it's saved - no separate "enable" step, and no
/// language/model picker, because the substitution runs on the final text after any
/// model has already produced it (see `WhisperService.joined(_:)`).
struct DictionaryEntryEditor: View {
    let mode: DictionaryEditorMode
    let dictionaryService: CustomDictionaryService

    @Environment(\.dismiss) private var dismiss
    @State private var replacement: String
    @State private var spokenForms: [SpokenFormField]
    @State private var matchWholeWord: Bool
    @State private var matchCase: Bool
    @State private var showingDeleteConfirm = false

    private struct SpokenFormField: Identifiable {
        let id = UUID()
        var text: String
    }

    init(mode: DictionaryEditorMode, dictionaryService: CustomDictionaryService) {
        self.mode = mode
        self.dictionaryService = dictionaryService
        switch mode {
        case .add:
            _replacement = State(initialValue: "")
            _spokenForms = State(initialValue: [SpokenFormField(text: "")])
            _matchWholeWord = State(initialValue: true)
            _matchCase = State(initialValue: false)
        case .edit(let entry):
            _replacement = State(initialValue: entry.replacement)
            _spokenForms = State(initialValue: entry.spokenForms.map { SpokenFormField(text: $0) })
            _matchWholeWord = State(initialValue: entry.matchWholeWord)
            _matchCase = State(initialValue: entry.matchCase)
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var cleanedForms: [String] {
        spokenForms
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var canSave: Bool {
        !replacement.trimmingCharacters(in: .whitespaces).isEmpty && !cleanedForms.isEmpty
    }

    /// A spoken form that another correction already owns - shown as a warning, and
    /// dropped on save, so one thing Whisper says only ever becomes one thing.
    private var conflicts: [String] {
        let ownID: UUID?
        if case .edit(let entry) = mode { ownID = entry.id } else { ownID = nil }
        return cleanedForms.filter { form in
            guard let owner = dictionaryService.owner(ofSpokenForm: form) else { return false }
            return owner.id != ownID
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What it should say", text: $replacement)
                        .autocorrectionDisabled()
                } header: {
                    Text("Write it as")
                } footer: {
                    Text("Exactly as you want it to appear, including capital letters.")
                }

                Section {
                    ForEach($spokenForms) { $field in
                        TextField("What Whisper hears", text: $field.text)
                            .autocorrectionDisabled()
                    }
                    .onDelete { offsets in
                        spokenForms.remove(atOffsets: offsets)
                        if spokenForms.isEmpty { spokenForms = [SpokenFormField(text: "")] }
                    }
                    Button {
                        spokenForms.append(SpokenFormField(text: ""))
                    } label: {
                        Label("Add another way it's heard", systemImage: "plus.circle")
                    }
                } header: {
                    Text("Heard as")
                } footer: {
                    if conflicts.isEmpty {
                        Text("Add every misspelling you've seen. Spaces inside a phrase are flexible.")
                    } else {
                        Text("Already used by another correction and will be skipped: " + conflicts.joined(separator: ", "))
                            .foregroundStyle(.orange)
                    }
                }

                Section {
                    Toggle("Whole word only", isOn: $matchWholeWord)
                    Toggle("Match case", isOn: $matchCase)
                } footer: {
                    Text("Whole word: \"Cat\" won't change \"Caterpillar\". Turn it off for word endings or attached particles. Match case: only replace when the capital letters match too.")
                }

                if isEditing {
                    Section {
                        Button("Delete Correction", role: .destructive) {
                            showingDeleteConfirm = true
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Correction" : "New Correction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .confirmationDialog("Delete this correction?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if case .edit(let entry) = mode {
                        dictionaryService.remove(id: entry.id)
                    }
                    dismiss()
                }
            }
        }
    }

    private func save() {
        switch mode {
        case .add:
            dictionaryService.add(DictionaryEntry(
                replacement: replacement,
                spokenForms: cleanedForms,
                matchWholeWord: matchWholeWord,
                matchCase: matchCase
            ))
        case .edit(let entry):
            var updated = entry
            updated.replacement = replacement
            updated.spokenForms = cleanedForms
            updated.matchWholeWord = matchWholeWord
            updated.matchCase = matchCase
            dictionaryService.update(updated)
        }
    }
}

// MARK: - Paste a list

private struct PasteListSheet: View {
    let onImport: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("One correction per line. Any of these work:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Nassar -> Nasar")
                    Text("Nassar, Nasar")
                    Text("Nassar|Nasser|Nazar, Nasar")
                    Text("Nasar   (just a word teaches its spelling)")
                }
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                TextEditor(text: $text)
                    .font(.body.monospaced())
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .frame(minHeight: 200)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.3))
                    )
            }
            .padding()
            .navigationTitle("Paste a List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        onImport(text)
                        dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - Export

struct ExportFile: Identifiable {
    let id = UUID()
    let url: URL

    /// Writes the CSV to a temp file named for today so the share sheet offers a real
    /// `.csv` attachment, not a blob of text.
    static func write(_ csv: String) -> ExportFile? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let name = "nasar-flow-dictionary-\(formatter.string(from: Date())).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try csv.data(using: .utf8)?.write(to: url, options: .atomic)
            return ExportFile(url: url)
        } catch {
            return nil
        }
    }
}

private struct ExportSheet: View {
    let file: ExportFile
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "doc.text")
                    .font(.system(size: 44))
                    .foregroundStyle(.secondary)
                Text(file.url.lastPathComponent)
                    .font(.headline)
                Text("A plain CSV: one line per spoken form, with the written form beside it. Any dictation app that imports CSV can read it, and Nasar Flow reads it back with your matching options intact.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                ShareLink(item: file.url) {
                    Label("Share CSV", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("Export Dictionary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
