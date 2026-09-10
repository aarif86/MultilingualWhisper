import Foundation

/// Builds whisper's `initial_prompt` as a short, rotating glossary - the only form
/// in which the playbook re-enables prompting (§3.3): "a rotating 20–40 term
/// glossary with `carry_initial_prompt`, not a keyword dump". Every vendor caps
/// biasing at a short list and warns that long lists raise false positives;
/// whisper.cpp's decoder keeps only the last ~224 tokens of a prompt, so a long
/// one silently loses its start.
///
/// The Custom Dictionary is the source: its written forms are exactly the
/// spellings the decoder keeps getting wrong, and a name in the prompt nudges the
/// model towards that spelling *before* the dictionary has to fix it. Newest
/// entries first, so recent corrections are the ones that get the nudge.
enum GlossaryPrompt {
    static let maxTerms = 40
    /// Rough character budget for ~200 tokens across Latin, Jawi and Arabic.
    static let maxCharacters = 600

    /// nil when there is nothing worth prompting with.
    static func build(from entries: [DictionaryEntry], limit: Int = maxTerms, maxCharacters: Int = GlossaryPrompt.maxCharacters) -> String? {
        var seen = Set<String>()
        var terms: [String] = []
        var characters = 0
        for entry in entries.reversed() {
            let term = entry.replacement.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !term.isEmpty, !term.contains("\n") else { continue }
            let key = term.lowercased()
            guard !seen.contains(key) else { continue }
            guard terms.count < limit, characters + term.count + 2 <= maxCharacters else { break }
            seen.insert(key)
            terms.append(term)
            characters += term.count + 2
        }
        guard !terms.isEmpty else { return nil }
        return terms.joined(separator: ", ") + "."
    }
}
