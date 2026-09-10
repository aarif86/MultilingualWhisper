import SwiftUI

/// Shown right after picking a WhatsApp export - nothing from
/// `ChatExportParser`'s candidates reaches `UserLanguageKeywords` without the
/// user actively assigning each word here first. Every word - whether
/// surfaced by the frequency scan or typed in manually - goes through the
/// exact same Skip/Malay/Singlish choice, so there's one interaction model,
/// not two.
struct ChatImportReviewView: View {
    @Environment(\.dismiss) private var dismiss
    let result: ChatExportParser.ImportResult
    let languageKeywords: UserLanguageKeywords
    /// Called once the user leaves this screen, however they leave it - lets
    /// the caller delete the imported file now that it's no longer needed.
    /// This view never touches the filesystem itself.
    let onFinish: () -> Void

    private enum Assignment: Equatable {
        case skip
        case malay
        case singlish
    }

    @State private var candidates: [ChatExportParser.CandidateWord]
    @State private var assignments: [String: Assignment] = [:]
    @State private var manualWord = ""

    init(result: ChatExportParser.ImportResult, languageKeywords: UserLanguageKeywords, onFinish: @escaping () -> Void) {
        self.result = result
        self.languageKeywords = languageKeywords
        self.onFinish = onFinish
        _candidates = State(initialValue: result.candidates)
    }

    private var approvedCount: Int {
        assignments.values.filter { $0 != .skip }.count
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    summaryCard
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

                Section {
                    HStack {
                        TextField("A word not in the list below", text: $manualWord)
                            .autocorrectionDisabled()
                        Button("Add") { addManualWord() }
                            .disabled(manualWord.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: {
                    Text("Add your own word")
                } footer: {
                    Text("Missed something the frequency scan didn't catch? Add it here, then tag it below like any other word.")
                }

                Section {
                    ForEach(candidates) { candidate in
                        candidateRow(candidate)
                    }
                } header: {
                    Text("Words we don't recognize yet")
                } footer: {
                    Text("Seen this many times in your export. Tag each as Malay or Singlish so it counts as evidence of that language next time - or leave it on Skip.")
                }
            }
            .navigationTitle("Review Import")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { finish() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(approvedCount == 0 ? "Done" : "Add \(approvedCount)") {
                        commit()
                    }
                }
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(result.totalMessages) messages analyzed")
                .font(.headline)
            if let summary = classificationSummary {
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: Constants.cornerRadius))
    }

    /// The honest "before" picture - computed by the real classifier
    /// (`ChatExportParser.analyze`), not a guess, so it can only ever say what
    /// today's app actually does with these exact messages.
    private var classificationSummary: String? {
        guard result.totalMessages > 0 else { return nil }
        let englishFallback = result.currentClassification[.english] ?? 0
        guard englishFallback > 0 else {
            return "None of these fall back to a plain English label today."
        }
        let percent = Int((Double(englishFallback) / Double(result.totalMessages) * 100).rounded())
        return "Today, \(percent)% of these would be labeled English by default - approving words below teaches the app to recognize them instead."
    }

    private func candidateRow(_ candidate: ChatExportParser.CandidateWord) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(candidate.word)
                    .font(.body.monospaced())
                if candidate.count > 0 {
                    Text("seen \(candidate.count)\u{d7}")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Picker("", selection: assignmentBinding(for: candidate.word)) {
                Text("Skip").tag(Assignment.skip)
                Text("Malay").tag(Assignment.malay)
                Text("Singlish").tag(Assignment.singlish)
            }
            .pickerStyle(.segmented)
            .fixedSize()
        }
    }

    private func assignmentBinding(for word: String) -> Binding<Assignment> {
        Binding(
            get: { assignments[word] ?? .skip },
            set: { assignments[word] = $0 }
        )
    }

    private func addManualWord() {
        let word = manualWord.trimmingCharacters(in: .whitespaces).lowercased()
        manualWord = ""
        guard !word.isEmpty, !candidates.contains(where: { $0.word == word }) else { return }
        candidates.insert(ChatExportParser.CandidateWord(word: word, count: 0), at: 0)
    }

    private func commit() {
        let malayWords = assignments.filter { $0.value == .malay }.map(\.key)
        let singlishWords = assignments.filter { $0.value == .singlish }.map(\.key)
        if !malayWords.isEmpty { languageKeywords.addMalay(malayWords) }
        if !singlishWords.isEmpty { languageKeywords.addSinglish(singlishWords) }
        finish()
    }

    private func finish() {
        onFinish()
        dismiss()
    }
}

#Preview {
    ChatImportReviewView(
        result: .init(
            totalMessages: 17370,
            candidates: [
                .init(word: "dorg", count: 167),
                .init(word: "sibuk", count: 42),
                .init(word: "kejap", count: 12),
            ],
            currentClassification: [.english: 13934, .malay: 2061, .singlish: 818]
        ),
        languageKeywords: UserLanguageKeywords(defaults: UserDefaults(suiteName: "preview")!),
        onFinish: {}
    )
}
