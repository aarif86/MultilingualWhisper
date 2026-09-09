import Foundation

/// Reads and writes dictionary entries as text, so a user can bring a list from
/// Wispr Flow, Superwhisper, Aqua Voice, Willow, a spreadsheet, or a note, and get
/// the same list back out. Monologue made "import from the app you're leaving" a
/// headline switching feature; this is the deterministic core of that.
///
/// Accepted shapes (auto-detected, mixable line by line):
///
/// - `original,replacement` CSV, with or without a header. Header names are sniffed,
///   so `word,correction`, `misspelling,correct`, `heard,say`, `from,to` all work.
/// - Tab-separated, same rules.
/// - One term per line (a plain vocabulary list, which is what Wispr's Dictionary,
///   Superwhisper's Vocabulary and Aqua's bulk-add export). Each term becomes a
///   self-mapping - "Nasar" makes "nasar"/"NASAR" come out as "Nasar" - which is
///   the deterministic equivalent of "teach it this spelling".
/// - Arrow lines pasted from notes: `Nassar -> Nasar`, `Nassar => Nasar`,
///   `Nassar → Nasar`.
/// - Several spoken forms in one cell, separated by `|` or `;`:
///   `Nassar|Nasser|Nazar,Nasar`.
/// - Optional `whole_word` and `match_case` columns (our own export writes them).
///
/// Lines starting with `#` are comments. Blank lines and a leading BOM are ignored.
enum DictionaryImporter {
    struct ParsedEntry: Equatable {
        var spokenForms: [String]
        var replacement: String
        var matchWholeWord: Bool?
        var matchCase: Bool?
    }

    struct ParseResult: Equatable {
        var entries: [ParsedEntry]
        /// Non-blank, non-comment lines that could not be read as an entry.
        var invalidLineCount: Int
    }

    // MARK: - Parsing

    static func parse(_ raw: String) -> ParseResult {
        var text = raw
        if text.hasPrefix("\u{FEFF}") { text.removeFirst() }
        let lines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }

        guard !lines.isEmpty else { return ParseResult(entries: [], invalidLineCount: 0) }

        let delimiter = sniffDelimiter(lines)
        var columns = ColumnMap.positional
        var startIndex = 0
        let firstFields = delimiter.map { splitFields(lines[0], delimiter: $0) } ?? [lines[0]]
        if !hasArrow(lines[0]), let header = headerMap(firstFields) {
            columns = header
            startIndex = 1
        }

        var entries: [ParsedEntry] = []
        var invalid = 0
        var seen = Set<String>()

        for line in lines[startIndex...] {
            let parsed: ParsedEntry?
            if hasArrow(line) {
                // An arrow with a missing side is a malformed line, never a self-mapping.
                parsed = splitArrow(line).flatMap {
                    makeEntry(spokenCell: $0.left, replacement: $0.right, wholeWord: nil, matchCase: nil)
                }
            } else if let delimiter {
                let fields = splitFields(line, delimiter: delimiter)
                parsed = entry(from: fields, columns: columns)
            } else {
                parsed = makeEntry(spokenCell: line, replacement: line, wholeWord: nil, matchCase: nil)
            }
            guard let parsed else {
                invalid += 1
                continue
            }
            let key = parsed.replacement.lowercased() + "\u{0}" + parsed.spokenForms.map { $0.lowercased() }.sorted().joined(separator: "|")
            guard seen.insert(key).inserted else { continue }
            entries.append(parsed)
        }
        return ParseResult(entries: entries, invalidLineCount: invalid)
    }

    // MARK: - Export

    static let exportHeader = "original,replacement,whole_word,match_case"

    /// One row per spoken form, so any two-column importer (including other apps')
    /// reads it, with our two flags trailing for a lossless round-trip.
    static func exportCSV(_ entries: [DictionaryEntry]) -> String {
        var rows = [exportHeader]
        for entry in entries {
            for form in entry.spokenForms {
                rows.append([
                    csvField(form),
                    csvField(entry.replacement),
                    entry.matchWholeWord ? "true" : "false",
                    entry.matchCase ? "true" : "false",
                ].joined(separator: ","))
            }
        }
        return rows.joined(separator: "\n") + "\n"
    }

    static func csvField(_ value: String) -> String {
        let needsQuotes = value.contains(",") || value.contains("\"") || value.contains("\n") || value.hasPrefix(" ") || value.hasSuffix(" ")
        guard needsQuotes else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    // MARK: - Internals

    private struct ColumnMap {
        var spoken: Int
        var replacement: Int?
        var wholeWord: Int?
        var matchCase: Int?

        static let positional = ColumnMap(spoken: 0, replacement: 1, wholeWord: nil, matchCase: nil)
    }

    private static let spokenHeaders: Set<String> = [
        "original", "originals", "spoken", "spoken form", "spoken_form", "spokenform", "hears", "heard", "hear",
        "heard as", "misspelling", "misspellings", "incorrect", "wrong", "from", "phrase", "trigger", "term",
        "word", "text", "input", "source", "what whisper hears", "transcribed", "transcription",
    ]

    private static let replacementHeaders: Set<String> = [
        "replacement", "replace", "replace with", "correct", "correction", "corrected", "to", "say", "output",
        "written", "written form", "written_form", "target", "expansion", "canonical", "should say",
        "what it should say", "display",
    ]

    private static let wholeWordHeaders: Set<String> = ["whole_word", "wholeword", "whole word", "whole"]
    private static let matchCaseHeaders: Set<String> = ["match_case", "matchcase", "match case", "case", "case_sensitive", "case sensitive"]

    private static func headerMap(_ fields: [String]) -> ColumnMap? {
        let lowered = fields.map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
        var map = ColumnMap(spoken: -1, replacement: nil, wholeWord: nil, matchCase: nil)
        var recognised = 0
        for (index, name) in lowered.enumerated() {
            if spokenHeaders.contains(name), map.spoken == -1 {
                map.spoken = index; recognised += 1
            } else if replacementHeaders.contains(name), map.replacement == nil {
                map.replacement = index; recognised += 1
            } else if wholeWordHeaders.contains(name) {
                map.wholeWord = index; recognised += 1
            } else if matchCaseHeaders.contains(name) {
                map.matchCase = index; recognised += 1
            }
        }
        // A header row must be *entirely* made of names we know, otherwise it's data.
        guard recognised == lowered.count, recognised > 0 else { return nil }
        if map.spoken == -1 {
            // A single "replacement"-only list ("word" would have matched spoken) -
            // treat the recognised column as both.
            guard let replacement = map.replacement else { return nil }
            map.spoken = replacement
        }
        return map
    }

    private static func sniffDelimiter(_ lines: [String]) -> Character? {
        let sample = lines.prefix(20)
        if sample.contains(where: { $0.contains("\t") }) { return "\t" }
        // Arrow-only files have no delimiter; a comma inside an arrow line is content.
        let nonArrow = sample.filter { !hasArrow($0) }
        if nonArrow.contains(where: { $0.contains(",") }) { return "," }
        return nil
    }

    private static func hasArrow(_ line: String) -> Bool {
        arrows.contains { line.contains($0) }
    }

    private static func entry(from fields: [String], columns: ColumnMap) -> ParsedEntry? {
        guard columns.spoken < fields.count else { return nil }
        let spokenCell = fields[columns.spoken]
        let replacement: String
        if let replacementIndex = columns.replacement, replacementIndex < fields.count, !fields[replacementIndex].trimmingCharacters(in: .whitespaces).isEmpty {
            replacement = fields[replacementIndex]
        } else if fields.count == 1 || columns.replacement == columns.spoken {
            replacement = spokenCell
        } else if columns.replacement == nil {
            replacement = spokenCell
        } else {
            // Two-column shape but the replacement cell is empty: a self-mapping.
            replacement = spokenCell
        }
        return makeEntry(
            spokenCell: spokenCell,
            replacement: replacement,
            wholeWord: columns.wholeWord.flatMap { $0 < fields.count ? parseBool(fields[$0]) : nil },
            matchCase: columns.matchCase.flatMap { $0 < fields.count ? parseBool(fields[$0]) : nil }
        )
    }

    private static func makeEntry(spokenCell: String, replacement: String, wholeWord: Bool?, matchCase: Bool?) -> ParsedEntry? {
        let trimmedReplacement = replacement.trimmingCharacters(in: .whitespacesAndNewlines)
        var seen = Set<String>()
        let forms = spokenCell
            .split(whereSeparator: { $0 == "|" || $0 == ";" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { seen.insert($0.lowercased()).inserted }
        guard !trimmedReplacement.isEmpty, !forms.isEmpty else { return nil }
        return ParsedEntry(spokenForms: forms, replacement: trimmedReplacement, matchWholeWord: wholeWord, matchCase: matchCase)
    }

    private static let arrows = ["->", "=>", "→", "⇒"]

    private static func splitArrow(_ line: String) -> (left: String, right: String)? {
        for arrow in arrows {
            guard let range = line.range(of: arrow) else { continue }
            let left = String(line[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            let right = String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            guard !left.isEmpty, !right.isEmpty else { return nil }
            return (left, right)
        }
        return nil
    }

    private static func parseBool(_ value: String) -> Bool? {
        switch value.trimmingCharacters(in: .whitespaces).lowercased() {
        case "true", "yes", "y", "1", "on": return true
        case "false", "no", "n", "0", "off": return false
        default: return nil
        }
    }

    /// Minimal RFC 4180 field splitter: handles quoted fields, doubled quotes, and
    /// the delimiter inside quotes. Good enough for every export we've seen.
    static func splitFields(_ line: String, delimiter: Character) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var iterator = line.makeIterator()
        var pending: Character? = iterator.next()
        while let char = pending {
            let next = iterator.next()
            if inQuotes {
                if char == "\"" {
                    if next == "\"" {
                        current.append("\"")
                        pending = iterator.next()
                        continue
                    }
                    inQuotes = false
                } else {
                    current.append(char)
                }
            } else if char == "\"", current.trimmingCharacters(in: .whitespaces).isEmpty {
                inQuotes = true
                current = ""
            } else if char == delimiter {
                fields.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(char)
            }
            pending = next
        }
        fields.append(current.trimmingCharacters(in: .whitespaces))
        return fields
    }
}
