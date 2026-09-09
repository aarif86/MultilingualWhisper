import Foundation

/// Decides exactly what string to hand to `textDocumentProxy.insertText` so a
/// dictation lands in the host app's text field the way a typed continuation
/// would: a space before it when the cursor sits at the end of a word, a capital
/// after a full stop or an opening quote, no capital mid-sentence for ordinary
/// words, a space after it when there is a word immediately to the right.
///
/// This is the "unwanted leading space / missing space / wrong capital" class of
/// bug that tops the issue trackers of every open-source voice IME
/// (`docs/competitor-kb/android-ime-voice-input.md`: Transcribro #96) and that
/// Apple's own dictation gets right silently. Pure and dependency-free so it is
/// unit tested on the Simulator with no keyboard, no host app and no device -
/// see `InsertionPolicyTests`. Compiled into both the app and the keyboard.
enum InsertionPolicy {
    struct Plan: Equatable {
        /// The exact string to insert. Empty means "insert nothing".
        let text: String
        /// True when the host field has a selection that this insert replaces -
        /// `insertText` already replaces the selection, so callers only need this
        /// to decide what "undo" should mean.
        let replacesSelection: Bool
    }

    /// - Parameters:
    ///   - raw: the transcript (already dictionary-corrected and formatted).
    ///   - before: `documentContextBeforeInput` - text left of the cursor, or nil.
    ///   - after: `documentContextAfterInput` - text right of the cursor, or nil.
    ///   - selected: `selectedText`, or nil when nothing is selected.
    static func plan(inserting raw: String, before: String?, after: String?, selected: String? = nil) -> Plan {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let replacesSelection = !(selected ?? "").isEmpty
        guard !text.isEmpty else { return Plan(text: "", replacesSelection: replacesSelection) }

        let leftContext = before ?? ""
        let rightContext = after ?? ""
        let body = applyCase(to: text, leftContext: leftContext)

        var result = ""
        if needsLeadingSpace(leftContext: leftContext, body: body) { result += " " }
        result += body
        if needsTrailingSpace(rightContext: rightContext, body: body) { result += " " }
        return Plan(text: result, replacesSelection: replacesSelection)
    }

    // MARK: - Spacing

    /// Unambiguous openers: no space after them, and text after them starts a sentence.
    private static let openers: Set<Character> = ["(", "[", "{", "“", "‘", "«"]
    /// Unambiguous closers: a space is wanted after them; they are skipped when
    /// looking back for a sentence end.
    private static let closers: Set<Character> = [")", "]", "}", "”", "’", "»"]
    /// Prefix symbols the dictation attaches to directly.
    private static let prefixSymbols: Set<Character> = ["/", "@", "#", "$", "-", "—"]
    /// Punctuation the dictation itself may start with; no space goes before it.
    private static let noSpaceBefore: Set<Character> = [".", ",", ";", ":", "!", "?", ")", "]", "}", "…", "،", "؛", "؟"]
    /// Straight quotes open or close depending on what precedes them.
    private static let straightQuotes: Set<Character> = ["\"", "'"]
    private static let sentenceEnders: Set<Character> = [".", "!", "?", "؟", "…"]

    static func needsLeadingSpace(leftContext: String, body: String) -> Bool {
        guard let last = leftContext.last, let first = body.first else { return false }
        if last.isWhitespace || last.isNewline { return false }
        if noSpaceBefore.contains(first) { return false }
        if straightQuotes.contains(last) { return !isOpeningQuote(endOf: leftContext) }
        if openers.contains(last) || prefixSymbols.contains(last) { return false }
        return true
    }

    static func needsTrailingSpace(rightContext: String, body: String) -> Bool {
        guard let next = rightContext.first, let last = body.last else { return false }
        if next.isWhitespace || next.isNewline || last.isNewline { return false }
        if noSpaceBefore.contains(next) { return false }
        return next.isLetter || next.isNumber
    }

    /// A straight quote at the end of `context` opens a quotation when nothing, a
    /// space, or another opener precedes it; otherwise it closes one.
    private static func isOpeningQuote(endOf context: String) -> Bool {
        guard let beforeQuote = context.dropLast().last else { return true }
        return beforeQuote.isWhitespace || beforeQuote.isNewline || openers.contains(beforeQuote)
    }

    // MARK: - Case

    /// Words that are only ever capitalised at a sentence start. When the cursor is
    /// mid-sentence and the dictation begins with one of these in sentence case, it
    /// is lowercased so "I think" + "We go makan" reads "I think we go makan". Names
    /// and everything else are left alone - wrongly lowercasing "Nasar" is worse than
    /// an occasional stray capital. English plus common Malay function words.
    static let sentenceOnlyCapitalWords: Set<String> = [
        "a", "an", "the", "and", "but", "or", "so", "if", "then", "because", "when", "while", "also", "just", "not",
        "we", "you", "they", "he", "she", "it", "me", "us", "them", "my", "your", "our", "their", "his", "her", "its",
        "is", "are", "was", "were", "be", "been", "have", "has", "had", "do", "does", "did", "can", "will", "would",
        "should", "could", "may", "might", "must", "to", "of", "in", "on", "at", "for", "with", "from", "by", "about",
        "this", "that", "these", "those", "there", "here", "what", "which", "who", "how", "why", "where",
        "please", "maybe", "okay", "ok", "yes", "no",
        "saya", "kita", "kami", "awak", "kau", "dia", "mereka", "dan", "atau", "tapi", "tetapi", "kalau", "jika",
        "ini", "itu", "ada", "tak", "tidak", "boleh", "jangan", "sudah", "belum", "nanti", "sekarang", "lepas",
        "nak", "mahu", "hendak", "pergi", "balik", "makan", "minum", "buat", "tolong", "juga", "lagi", "sangat",
        "dengan", "untuk", "dari", "daripada", "kepada", "pada", "di", "ke", "yang", "macam", "sebab",
    ]

    /// True when text typed at the end of `leftContext` begins a sentence: the
    /// field is empty, the last significant character ends a sentence, a newline
    /// precedes, or an opening quote/bracket was just typed.
    static func startsNewSentence(leftContext: String) -> Bool {
        var index = leftContext.endIndex
        while index > leftContext.startIndex {
            let previous = leftContext.index(before: index)
            let char = leftContext[previous]
            if char.isNewline { return true }
            if char.isWhitespace || closers.contains(char) {
                index = previous
                continue
            }
            if openers.contains(char) { return true }
            if straightQuotes.contains(char) {
                if isOpeningQuote(endOf: String(leftContext[..<index])) { return true }
                index = previous
                continue
            }
            return sentenceEnders.contains(char)
        }
        return true
    }

    static func applyCase(to body: String, leftContext: String) -> String {
        guard let first = body.first else { return body }
        if startsNewSentence(leftContext: leftContext) {
            guard first.isCased, first.isLowercase else { return body }
            return first.uppercased() + body.dropFirst()
        }
        guard first.isCased, first.isUppercase else { return body }
        let firstWord = body.prefix { $0.isLetter || $0 == "'" || $0 == "’" }
        let rest = firstWord.dropFirst()
        guard rest.allSatisfy({ !$0.isUppercase }) else { return body }
        let lowered = firstWord.lowercased()
        guard sentenceOnlyCapitalWords.contains(lowered) else { return body }
        return lowered + body.dropFirst(firstWord.count)
    }
}
