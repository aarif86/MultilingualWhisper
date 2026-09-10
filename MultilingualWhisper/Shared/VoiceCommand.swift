import Foundation

/// The small, fixed set of editing commands the keyboard understands - the same
/// dozen every OS dictation ships (Apple, Windows Voice Access, Gboard; see
/// `docs/competitor-kb/apple-dictation-voice-control.md`), so muscle memory
/// transfers - plus a literal-text escape hatch (Talon's `escape <text>`).
///
/// The boundary is architectural, never guessed: commands are only interpreted
/// for an utterance the user started in *command mode* (long-press the keyboard
/// mic). In normal dictation the words "new line" are just words. That is the
/// design every reference implementation converged on and the failure Dragon
/// still has after a decade ("scratch that" typed into documents).
enum VoiceCommand: Hashable {
    case newLine
    case newParagraph
    case deleteThat
    case deleteWord
    case deleteLine
    case period
    case comma
    case questionMark
    case exclamationMark
    case capitaliseThat
    case allCapsThat
    case lowercaseThat
    /// "literally <text>" / "type <text>": insert the words as ordinary text
    /// even though they might look like a command.
    case literal(String)
    /// "change <target> to <replacement>" (Windows Voice Access "correct",
    /// Apple "change tea to T-E-E"): the last `target` before the cursor becomes
    /// `replacement`. A replacement spoken as letters ("T E E", "t-e-e") is
    /// joined, and its case copied from the word it replaces.
    case replace(target: String, replacement: String)
    /// "spell <letters>": the letters as one word, first letter capitalised -
    /// names are the common case; say "all caps that" for an acronym.
    case spell(String)

    var displayName: String {
        switch self {
        case .newLine: return "New line"
        case .newParagraph: return "New paragraph"
        case .deleteThat: return "Delete that"
        case .deleteWord: return "Delete word"
        case .deleteLine: return "Delete line"
        case .period: return "Full stop"
        case .comma: return "Comma"
        case .questionMark: return "Question mark"
        case .exclamationMark: return "Exclamation mark"
        case .capitaliseThat: return "Capitalise that"
        case .allCapsThat: return "All caps that"
        case .lowercaseThat: return "Lowercase that"
        case .literal(let text): return "Type \"\(text)\""
        case .replace(let target, let replacement): return "Change \"\(target)\" to \"\(replacement)\""
        case .spell(let word): return "Spell \"\(word)\""
        }
    }

    // MARK: - App Group transport

    /// Flat, Codable form for the App Group hand-off between app and keyboard.
    struct Payload: Codable, Equatable {
        var kind: String
        var argument: String?
        /// Second operand, only for `replace` - optional so older payloads decode.
        var argument2: String?

        /// The app heard an utterance in command mode but recognised no command.
        static func unrecognized(_ text: String) -> Payload {
            Payload(kind: "unrecognized", argument: text)
        }

        var isUnrecognized: Bool { kind == "unrecognized" }
    }

    var payload: Payload {
        switch self {
        case .newLine: return Payload(kind: "newLine", argument: nil)
        case .newParagraph: return Payload(kind: "newParagraph", argument: nil)
        case .deleteThat: return Payload(kind: "deleteThat", argument: nil)
        case .deleteWord: return Payload(kind: "deleteWord", argument: nil)
        case .deleteLine: return Payload(kind: "deleteLine", argument: nil)
        case .period: return Payload(kind: "period", argument: nil)
        case .comma: return Payload(kind: "comma", argument: nil)
        case .questionMark: return Payload(kind: "questionMark", argument: nil)
        case .exclamationMark: return Payload(kind: "exclamationMark", argument: nil)
        case .capitaliseThat: return Payload(kind: "capitaliseThat", argument: nil)
        case .allCapsThat: return Payload(kind: "allCapsThat", argument: nil)
        case .lowercaseThat: return Payload(kind: "lowercaseThat", argument: nil)
        case .literal(let text): return Payload(kind: "literal", argument: text)
        case .replace(let target, let replacement): return Payload(kind: "replace", argument: target, argument2: replacement)
        case .spell(let word): return Payload(kind: "spell", argument: word)
        }
    }

    init?(payload: Payload) {
        switch payload.kind {
        case "newLine": self = .newLine
        case "newParagraph": self = .newParagraph
        case "deleteThat": self = .deleteThat
        case "deleteWord": self = .deleteWord
        case "deleteLine": self = .deleteLine
        case "period": self = .period
        case "comma": self = .comma
        case "questionMark": self = .questionMark
        case "exclamationMark": self = .exclamationMark
        case "capitaliseThat": self = .capitaliseThat
        case "allCapsThat": self = .allCapsThat
        case "lowercaseThat": self = .lowercaseThat
        case "literal":
            guard let text = payload.argument else { return nil }
            self = .literal(text)
        case "replace":
            guard let target = payload.argument, let replacement = payload.argument2 else { return nil }
            self = .replace(target: target, replacement: replacement)
        case "spell":
            guard let word = payload.argument else { return nil }
            self = .spell(word)
        default:
            return nil
        }
    }
}

/// Turns a command-mode transcript into a `VoiceCommand`. Phrase-table matching
/// on a normalised string - no classifier, no fuzziness beyond what Whisper's own
/// punctuation and casing require.
///
/// Phrases are English, standard Malay and Modern Standard Arabic. Colloquial and
/// Singlish variants are deliberately absent until native speakers supply them
/// (see the project's dialect-authenticity rule); the table is a plain dictionary
/// so adding them is a one-line change per phrase.
enum VoiceCommandParser {
    static let phrases: [VoiceCommand: [String]] = [
        .newLine: ["new line", "newline", "line break", "next line",
                   "baris baru",
                   "سطر جديد"],
        .newParagraph: ["new paragraph", "paragraph", "next paragraph",
                        "perenggan baru", "paragraf baru",
                        "فقرة جديدة"],
        .deleteThat: ["delete that", "scratch that", "undo", "undo that", "remove that", "delete", "cancel that",
                      "padam itu", "padam", "buang itu", "buang", "batal", "batalkan",
                      "احذف ذلك", "احذف", "تراجع", "امسح", "امسح ذلك"],
        .deleteWord: ["delete word", "delete last word", "delete the last word", "delete previous word", "backspace",
                      "padam perkataan", "padam perkataan terakhir",
                      "احذف كلمة", "احذف الكلمة", "احذف آخر كلمة"],
        .deleteLine: ["delete line", "delete the line", "delete this line", "clear line",
                      "padam baris", "padam baris ini",
                      "احذف السطر", "امسح السطر"],
        .period: ["full stop", "period", "fullstop",
                  "noktah", "titik",
                  "نقطة"],
        .comma: ["comma",
                 "koma",
                 "فاصلة"],
        .questionMark: ["question mark",
                        "tanda soal", "tanda tanya",
                        "علامة استفهام"],
        .exclamationMark: ["exclamation mark", "exclamation point",
                           "tanda seru",
                           "علامة تعجب"],
        .capitaliseThat: ["capitalise that", "capitalize that", "cap that", "capital that", "capitalise", "capitalize",
                          "huruf besar"],
        .allCapsThat: ["all caps that", "all caps", "uppercase that", "upper case that", "all capitals",
                       "semua huruf besar"],
        .lowercaseThat: ["lowercase that", "lower case that", "lowercase", "no caps", "small letters",
                         "huruf kecil"],
    ]

    /// Words that turn the rest of the utterance into literal text.
    static let literalPrefixes = ["literally", "type", "insert", "just type", "write", "tulis", "taip", "اكتب"]

    /// "change X to Y" and its Malay / Arabic forms. Matched on the original text
    /// (case-insensitively) so the replacement keeps whatever capitals were said;
    /// the target is normalised later for matching.
    private static let replacePattern = try! NSRegularExpression(
        pattern: "^\\s*(?:change|correct|replace|swap|tukar|ganti|gantikan|\u{063A}\u{064A}\u{0631}|\u{0628}\u{062F}\u{0644}|\u{0627}\u{0633}\u{062A}\u{0628}\u{062F}\u{0644})[,\\s]+(.+?)[,\\s]+(?:to|with|for|into|kepada|ke|dengan|\u{0627}\u{0644}\u{0649}|\u{0625}\u{0644}\u{0649}|\u{0628})\\s+(.+?)[\\s.!?\u{061F}]*$",
        options: [.caseInsensitive]
    )
    private static let spellPattern = try! NSRegularExpression(
        pattern: "^\\s*(?:spell|eja|\u{062A}\u{0647}\u{062C}\u{0626}\u{0629})\\s+(.+?)[\\s.!?\u{061F}]*$",
        options: [.caseInsensitive]
    )

    static func parse(_ text: String) -> VoiceCommand? {
        let normalised = normalise(text)
        guard !normalised.isEmpty else { return nil }

        for prefix in literalPrefixes {
            if normalised == prefix { return nil }
            if normalised.hasPrefix(prefix + " ") {
                let rest = text.trimmingCharacters(in: .whitespacesAndNewlines)
                // Keep the user's own casing/punctuation for the literal part:
                // find the prefix in the original, case-insensitively.
                if let range = rest.range(of: prefix, options: [.caseInsensitive, .anchored]) {
                    let literal = rest[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
                    let cleaned = literal.trimmingCharacters(in: CharacterSet(charactersIn: ".,!?"))
                    return cleaned.isEmpty ? nil : .literal(cleaned)
                }
                let literal = String(normalised.dropFirst(prefix.count + 1))
                return literal.isEmpty ? nil : .literal(literal)
            }
        }

        if let replace = parseReplace(text) { return replace }
        if let spell = parseSpell(text) { return spell }

        for (command, variants) in phrases where variants.contains(where: { normalise($0) == normalised }) {
            return command
        }
        return nil
    }

    private static func parseReplace(_ text: String) -> VoiceCommand? {
        let ns = text as NSString
        guard let match = replacePattern.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return nil }
        let target = trimEdges(ns.substring(with: match.range(at: 1)))
        let spoken = trimEdges(ns.substring(with: match.range(at: 2)))
        guard !target.isEmpty, !spoken.isEmpty else { return nil }
        // Spelled letters come back upper-case from the decoder; a spelled word is
        // lower-case by default and the planner copies the target's capitals onto it.
        return .replace(target: target, replacement: joinSpelledLetters(spoken)?.lowercased() ?? spoken)
    }

    private static func parseSpell(_ text: String) -> VoiceCommand? {
        let ns = text as NSString
        guard let match = spellPattern.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return nil }
        let spoken = trimEdges(ns.substring(with: match.range(at: 1)))
        guard let letters = joinSpelledLetters(spoken) ?? (spoken.contains(" ") ? nil : spoken) else { return nil }
        return .spell(letters.prefix(1).uppercased() + letters.dropFirst().lowercased())
    }

    /// "T E E", "t-e-e", "T. E. E." -> "TEE" (case untouched). nil when the words
    /// are not all single letters.
    static func joinSpelledLetters(_ spoken: String) -> String? {
        let tokens = spoken.split(whereSeparator: { $0.isWhitespace || $0 == "-" || $0 == "." || $0 == "," })
        guard tokens.count >= 2, tokens.allSatisfy({ $0.count == 1 && $0.first!.isLetter }) else { return nil }
        return tokens.joined()
    }

    private static func trimEdges(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: ",.;:!?\u{060C}\u{061F}\"'"))
    }

    /// Lowercased, punctuation stripped, Arabic diacritics dropped and alef
    /// variants unified, whitespace collapsed - so "New line." and "سَطر جديد"
    /// both match their table entries.
    static func normalise(_ text: String) -> String {
        var scalars: [Unicode.Scalar] = []
        for scalar in text.lowercased().unicodeScalars {
            switch scalar {
            case "\u{064B}"..."\u{0652}", "\u{0670}":
                continue
            case "\u{0623}", "\u{0625}", "\u{0622}", "\u{0671}":
                scalars.append("\u{0627}")
            case "\u{0649}":
                scalars.append("\u{064A}")
            default:
                if CharacterSet.punctuationCharacters.contains(scalar) || CharacterSet.symbols.contains(scalar) {
                    scalars.append(" ")
                } else {
                    scalars.append(scalar)
                }
            }
        }
        var out = ""
        out.unicodeScalars.append(contentsOf: scalars)
        return out.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }
}
