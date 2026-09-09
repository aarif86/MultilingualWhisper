import Foundation

/// The pure, deterministic substitution engine behind the Custom Dictionary.
///
/// Semantics - documented here because users can only trust a replacement rule they
/// can predict (Superwhisper and VoiceInk both spell theirs out; MacWhisper ships only
/// this layer and is a well-regarded product on it):
///
/// 1. **Single pass.** All entries are compiled into one alternation and applied in one
///    sweep, so a replacement's *output* can never be re-matched by another entry.
/// 2. **Longest spoken form wins.** "Voice ink" beats "Voice" at the same position.
///    Ties keep the user's entry order.
/// 3. **Whole word by default.** Boundaries are script-aware (letters, digits, and
///    combining marks in any script count as "word"), not ASCII `\b`, so Arabic and
///    Jawi words get the same protection Latin ones do and entries that start or end
///    with punctuation ("@", ".com") still work. Per-entry opt-out.
/// 4. **Case-insensitive by default, output cased exactly as the replacement.**
///    Per-entry opt-in to case-sensitive matching.
/// 5. **Whitespace-flexible.** "insya Allah" in an entry matches "insya  Allah" and
///    "insya\nAllah" in a transcript.
/// 6. **Arabic-tolerant.** Matching ignores tashkeel (diacritics), treats the alef
///    variants (ا أ إ آ ٱ) as one letter, and treats ى/ي as one letter - the three
///    inconsistencies Whisper's Arabic output actually shows. The transcript itself is
///    never normalised; only the *match* is tolerant, so what the user said stays as
///    the model wrote it apart from the replaced span.
///
/// Pulled out of `CustomDictionaryService` as a dependency-free struct so it can be
/// unit tested directly - see `DictionaryMatcherTests`.
struct DictionaryMatcher {
    private struct Rule {
        let replacement: String
        let spokenForm: String
        let wholeWord: Bool
        let matchCase: Bool
    }

    private let regex: NSRegularExpression?
    private let rules: [Rule]

    init(entries: [DictionaryEntry]) {
        var collected: [Rule] = []
        for entry in entries {
            let replacement = entry.replacement
            guard !replacement.isEmpty else { continue }
            for form in entry.spokenForms {
                let trimmed = form.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                collected.append(Rule(
                    replacement: replacement,
                    spokenForm: trimmed,
                    wholeWord: entry.matchWholeWord,
                    matchCase: entry.matchCase
                ))
            }
        }
        // Longest first; stable for ties so the user's order breaks them.
        let sorted = collected.enumerated().sorted { lhs, rhs in
            let l = lhs.element.spokenForm.unicodeScalars.count
            let r = rhs.element.spokenForm.unicodeScalars.count
            return l != r ? l > r : lhs.offset < rhs.offset
        }
        rules = sorted.map { $0.element }

        let groups = rules.map { rule in
            Self.groupPattern(for: rule.spokenForm, wholeWord: rule.wholeWord, matchCase: rule.matchCase)
        }
        if groups.isEmpty {
            regex = nil
        } else {
            regex = try? NSRegularExpression(pattern: groups.joined(separator: "|"), options: [])
        }
    }

    var isEmpty: Bool { rules.isEmpty }

    func apply(to text: String) -> String {
        guard let regex, !rules.isEmpty, !text.isEmpty else { return text }
        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        guard !matches.isEmpty else { return text }

        var output = ""
        var cursor = 0
        for match in matches {
            let range = match.range
            guard range.location != NSNotFound, range.location >= cursor else { continue }
            if range.location > cursor {
                output += nsText.substring(with: NSRange(location: cursor, length: range.location - cursor))
            }
            if let ruleIndex = firstMatchedGroup(in: match) {
                output += rules[ruleIndex].replacement
            } else {
                output += nsText.substring(with: range)
            }
            cursor = range.location + range.length
        }
        if cursor < nsText.length {
            output += nsText.substring(from: cursor)
        }
        return output
    }

    // MARK: - Pattern building

    private func firstMatchedGroup(in match: NSTextCheckingResult) -> Int? {
        guard match.numberOfRanges > 1 else { return nil }
        for group in 1..<match.numberOfRanges where match.range(at: group).location != NSNotFound {
            return group - 1
        }
        return nil
    }

    /// Anything that is part of a word in any script: letters, digits, combining marks
    /// (Arabic tashkeel sits here), and the underscore. Deliberately not ASCII `\b`.
    private static let wordClass = "[\\p{L}\\p{N}\\p{M}_]"

    /// Arabic tashkeel and the superscript alef, all optional when matching.
    private static let arabicMarks = "[\u{064B}-\u{0652}\u{0670}]*"

    private static let alefVariants: Set<Unicode.Scalar> = ["\u{0627}", "\u{0623}", "\u{0625}", "\u{0622}", "\u{0671}"]
    private static let yaVariants: Set<Unicode.Scalar> = ["\u{064A}", "\u{0649}"]

    private static func isArabicMark(_ scalar: Unicode.Scalar) -> Bool {
        (0x064B...0x0652).contains(scalar.value) || scalar.value == 0x0670
    }

    private static func isArabicLetter(_ scalar: Unicode.Scalar) -> Bool {
        (0x0600...0x06FF).contains(scalar.value) && scalar.properties.isAlphabetic
    }

    static func groupPattern(for spokenForm: String, wholeWord: Bool, matchCase: Bool) -> String {
        let tokens = spokenForm.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        let body = tokens.map(tokenPattern).joined(separator: "\\s+")
        var inner = body
        if wholeWord {
            inner = "(?<!" + wordClass + ")" + inner + "(?!" + wordClass + ")"
        }
        if !matchCase {
            inner = "(?i:" + inner + ")"
        }
        return "(" + inner + ")"
    }

    private static func tokenPattern(_ token: String) -> String {
        var pattern = ""
        for scalar in token.unicodeScalars {
            if isArabicMark(scalar) {
                // The entry's own diacritics are optional too - drop them, the
                // `arabicMarks` tail after the preceding letter already allows them.
                continue
            }
            if alefVariants.contains(scalar) {
                pattern += "[\u{0627}\u{0623}\u{0625}\u{0622}\u{0671}]" + arabicMarks
            } else if yaVariants.contains(scalar) {
                pattern += "[\u{064A}\u{0649}]" + arabicMarks
            } else if isArabicLetter(scalar) {
                pattern += NSRegularExpression.escapedPattern(for: String(scalar)) + arabicMarks
            } else {
                pattern += NSRegularExpression.escapedPattern(for: String(scalar))
            }
        }
        return pattern
    }
}
