import SwiftUI
import UniformTypeIdentifiers

/// Manages words the classifier treats as evidence of Malay/Singlish beyond
/// its own built-in list - see `UserLanguageKeywords` and `ChatExportParser`.
/// Deliberately a separate screen from `CustomDictionaryView`: a dictionary
/// entry corrects how a word is spelled after decoding, this decides whether
/// a word counts as evidence a language is being spoken at all, before
/// decoding even finishes - different question, different data, different UI.
struct LanguageKeywordsView: View {
    let languageKeywords: UserLanguageKeywords

    @State private var showingFileImporter = false
    @State private var pendingResult: ChatExportParser.ImportResult?
    @State private var importError: String?

    private var sortedMalay: [String] { languageKeywords.malay.sorted() }
    private var sortedSinglish: [String] { languageKeywords.singlish.sorted() }

    var body: some View {
        List {
            Section {
                Button {
                    showingFileImporter = true
                } label: {
                    Label("Import Chat History\u{2026}", systemImage: "square.and.arrow.down")
                }
            } footer: {
                Text("Pick a WhatsApp chat export (Settings > Export Chat > Without Media, saved to Files). Read entirely on this device to suggest words for review, then never kept - nothing is uploaded anywhere.")
            }

            if !sortedMalay.isEmpty {
                Section("Malay") {
                    ForEach(sortedMalay, id: \.self) { Text($0) }
                        .onDelete { removeMalay(at: $0) }
                }
            }

            if !sortedSinglish.isEmpty {
                Section("Singlish") {
                    ForEach(sortedSinglish, id: \.self) { Text($0) }
                        .onDelete { removeSinglish(at: $0) }
                }
            }

            if sortedMalay.isEmpty && sortedSinglish.isEmpty {
                ContentUnavailableView(
                    "No Words Added Yet",
                    systemImage: "text.bubble",
                    description: Text("Import a chat export to teach Nasar Flow words you actually use that it doesn't recognize yet.")
                )
            }
        }
        .navigationTitle("Language Words")
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.zip, .plainText, .text],
            allowsMultipleSelection: false
        ) { handleFileImport($0) }
        .sheet(isPresented: Binding(get: { pendingResult != nil }, set: { if !$0 { pendingResult = nil } })) {
            if let pendingResult {
                ChatImportReviewView(result: pendingResult, languageKeywords: languageKeywords) {}
            }
        }
        .alert("Couldn't Import", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
            Button("OK", role: .cancel) { importError = nil }
        } message: {
            Text(importError ?? "")
        }
    }

    private func removeMalay(at offsets: IndexSet) {
        for index in offsets { languageKeywords.remove(sortedMalay[index]) }
    }

    private func removeSinglish(at offsets: IndexSet) {
        for index in offsets { languageKeywords.remove(sortedSinglish[index]) }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            importError = error.localizedDescription
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let text = try ChatImportService.extractChatText(from: url)
                let alreadyKnown = Constants.malayKeywords
                    .union(Constants.singlishMarkers)
                    .union(Constants.romanizedArabicMarkers)
                    .union(languageKeywords.malay)
                    .union(languageKeywords.singlish)
                // Seeded with whatever's already been approved, so the "how
                // would this be classified today" stat reflects the app's
                // real current state, not just its factory-default vocabulary.
                let classifier = RuleBasedLanguageClassifier(
                    additionalMalayKeywords: languageKeywords.malay,
                    additionalSinglishMarkers: languageKeywords.singlish
                )
                pendingResult = ChatExportParser.analyze(rawWhatsAppText: text, alreadyKnown: alreadyKnown, classifier: classifier)
            } catch {
                importError = error.localizedDescription
            }
        }
    }
}
