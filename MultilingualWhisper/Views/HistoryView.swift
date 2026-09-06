import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transcription.date, order: .reverse) private var transcriptions: [Transcription]
    @State private var viewModel = HistoryViewModel()
    @State private var showDeleteAllConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                let filtered = viewModel.filtered(transcriptions)
                ForEach(viewModel.grouped(filtered), id: \.label) { section in
                    Section(section.label) {
                        ForEach(section.items) { transcription in
                            row(for: transcription)
                        }
                    }
                }

                if transcriptions.isEmpty {
                    ContentUnavailableView(
                        "No transcriptions yet",
                        systemImage: "waveform",
                        description: Text("Recordings you transcribe will show up here.")
                    )
                } else if filtered.isEmpty {
                    ContentUnavailableView.search(text: viewModel.searchText)
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "Search transcriptions")
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    toolbarMenu
                }
            }
            .confirmationDialog(
                "Delete all transcriptions? This can't be undone.",
                isPresented: $showDeleteAllConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete All", role: .destructive) {
                    viewModel.deleteAll(transcriptions, context: modelContext)
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private var toolbarMenu: some View {
        Menu {
            Picker("Language", selection: $viewModel.languageFilter) {
                Text("All Languages").tag(LanguageType?.none)
                ForEach(LanguageType.allCases) { language in
                    Text(language.rawValue).tag(Optional(language))
                }
            }

            ShareLink(item: HistoryViewModel.exportText(transcriptions)) {
                Label("Export All", systemImage: "square.and.arrow.up")
            }
            .disabled(transcriptions.isEmpty)

            Button(role: .destructive) {
                showDeleteAllConfirmation = true
            } label: {
                Label("Delete All", systemImage: "trash")
            }
            .disabled(transcriptions.isEmpty)
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    private func row(for transcription: Transcription) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(transcription.text)
                .lineLimit(3)

            HStack(spacing: 6) {
                Text(transcription.date, format: .dateTime.hour().minute())
                Text("· \(Int(transcription.duration))s ·")
                LanguageBadge(language: transcription.languageUsed)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .swipeActions {
            Button("Delete", role: .destructive) {
                viewModel.delete(transcription, context: modelContext)
            }
        }
        .contextMenu {
            Button {
                UIPasteboard.general.string = transcription.text
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            ShareLink(item: transcription.text) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            Button(role: .destructive) {
                viewModel.delete(transcription, context: modelContext)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
