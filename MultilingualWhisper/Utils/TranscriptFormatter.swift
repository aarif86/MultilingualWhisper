import Foundation

/// How much the app tidies a transcript after the model and the Custom Dictionary
/// have had their say. Named and exposed to the user because every product in
/// `docs/competitor-kb/` that does cleanup silently gets "it rewrote what I said"
/// complaints; a visible dial plus an always-available Raw is the fix (Wispr
/// Light/Medium/High, AudioPen Low/Medium/High, Monologue "Blazing Fast").
enum CleanupLevel: String, CaseIterable, Identifiable, Codable {
    case raw = "Raw"
    case light = "Light"
    case full = "Full"

    var id: String { rawValue }

    var detail: String {
        switch self {
        case .raw: return "Exactly what the model heard."
        case .light: return "Removes um and uh, fixes spacing and capital letters."
        case .full: return "Light, plus numbers, prices, times and web addresses written the way you'd type them."
        }
    }
}

/// Deterministic, rule-based transcript cleanup. No model, no network, no
/// guessing at meaning - the layer every engine vendor recommends running *before*
/// any LLM pass (`docs/competitor-kb/engine-best-practices.md`), and the only
/// cleanup layer this app has.
///
/// Passes, in order:
/// 1. **Fillers** - a short English list (Deepgram's canonical set minus the ones that
///    carry meaning like "uh-huh"). Singlish particles are never on it: "lah", "leh",
///    "lor", "meh", "ah", "eh", "hor", "sia", "one" are grammar, not noise, and this
///    formatter must never strip them. Malay and Arabic filler lists are intentionally
///    empty until native speakers supply them.
/// 2. **Inverse text normalisation** (Full only) - spoken numbers, prices, percentages,
///    times, decimals, phone numbers, web addresses, emails and hashtags into their
///    typed form. Single small numbers ("two cats") are left as words, as every ITN
///    system does.
/// 3. **Punctuation spacing** - no space before commas/periods, one space after
///    commas, collapse doubles, trim. Arabic comma and question mark included.
/// 4. **Capitalisation** - first letter of the text and of each sentence, and a lone
///    "i". Only touches letters that have case, so Arabic and Jawi pass through.
///
/// Pure and dependency-free so it can be unit tested directly - see
/// `TranscriptFormatterTests`.
enum TranscriptFormatter {
    struct Options: Equatable {
        var removeFillers: Bool
        var inverseTextNormalization: Bool
        var normalizePunctuation: Bool
        var capitalizeSentences: Bool
        var fillerWords: [String]

        static let raw = Options(removeFillers: false, inverseTextNormalization: false, normalizePunctuation: false, capitalizeSentences: false, fillerWords: [])
        static let light = Options(removeFillers: true, inverseTextNormalization: false, normalizePunctuation: true, capitalizeSentences: true, fillerWords: defaultFillerWords)
        static let full = Options(removeFillers: true, inverseTextNormalization: true, normalizePunctuation: true, capitalizeSentences: true, fillerWords: defaultFillerWords)

        static func forLevel(_ level: CleanupLevel) -> Options {
            switch level {
            case .raw: return .raw
            case .light: return .light
            case .full: return .full
            }
        }
    }

    /// English only. "uh-huh", "mm-hmm", "nuh-uh" are answers, not fillers, and are
    /// protected by the hyphen check in the pattern.
    static let defaultFillerWords = ["uh", "um", "uhm", "umm", "uhh", "uhhh", "erm", "hmm", "hm", "mmm"]

    static func format(_ text: String, level: CleanupLevel) -> String {
        format(text, options: .forLevel(level))
    }

    /// The level's passes with a `DictationStyle`'s overrides on top, then the
    /// style's finishing touches (trailing full stop, spaces). A forced switch runs
    /// even at Raw: "Exact" in an email field has to join the address whatever the
    /// Cleanup setting says, and `.standard` changes nothing at any level.
    static func format(_ text: String, level: CleanupLevel, profile: StyleProfile) -> String {
        var options = Options.forLevel(level)
        switch profile.numbers {
        case .force: options.inverseTextNormalization = true
        case .suppress: options.inverseTextNormalization = false
        case .inherit: break
        }
        switch profile.capitalise {
        case .force: options.capitalizeSentences = true
        case .suppress: options.capitalizeSentences = false
        case .inherit: break
        }
        return finish(format(text, options: options), profile: profile)
    }

    // MARK: - 5. Style finishing

    private static let sentenceTerminators = CharacterSet(charactersIn: ".!?\u{061F}")
    private static let closers = CharacterSet(charactersIn: "\"'\u{201D}\u{2019})]\u{00BB}")

    private static func endsSecondSentence(_ text: String) -> Bool {
        var previousWasTerminator = false
        for scalar in text.dropLast().unicodeScalars {
            if previousWasTerminator, scalar == " " || scalar == "\n" { return true }
            previousWasTerminator = sentenceTerminators.contains(scalar)
        }
        return false
    }

    /// Applies the parts of a style that act on the finished text rather than on
    /// the passes: the trailing full stop rule and whitespace stripping.
    static func finish(_ text: String, profile: StyleProfile) -> String {
        guard profile != .standard else { return text }
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else { return result }

        switch profile.trailingPeriod {
        case .keep:
            break
        case .drop:
            // Only a lone full stop closing a single sentence: "see you there." ->
            // "see you there". A second sentence, "?", "!" or "..." all stay. A
            // terminator counts as a sentence break only when a space follows it,
            // so "flow.nasar.sg." and "at 3.5." still lose their closing stop.
            if result.hasSuffix("."), !result.hasSuffix(".."), !endsSecondSentence(result) {
                result = String(result.dropLast())
            }
        case .ensure:
            let body = result.unicodeScalars.reversed().drop { closers.contains($0) }
            if let last = body.first, !sentenceTerminators.contains(last), last != ",", last != ":", last != ";" {
                result += "."
            }
        }

        if profile.stripWhitespace {
            result = result.split(whereSeparator: { $0.isWhitespace }).joined()
        }
        return result
    }

    static func format(_ text: String, options: Options) -> String {
        guard !text.isEmpty, options != .raw else { return text }
        var result = text
        if options.removeFillers { result = removeFillers(result, words: options.fillerWords) }
        if options.inverseTextNormalization { result = normalizeNumbers(result) }
        if options.normalizePunctuation { result = normalizePunctuation(result) }
        if options.capitalizeSentences { result = capitalizeSentences(result) }
        return result
    }

    // MARK: - 1. Fillers

    static func removeFillers(_ text: String, words: [String]) -> String {
        let cleaned = words.map { $0.trimmingCharacters(in: .whitespaces).lowercased() }.filter { !$0.isEmpty }
        guard !cleaned.isEmpty else { return text }
        let alternation = cleaned.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|")
        let pattern = "(?<![\\p{L}\\p{M}\\-'’])(?:" + alternation + ")(?![\\p{L}\\p{M}\\-'’]),?\\s*"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return text }
        let stripped = replace(regex, in: text) { _, _ in "" }
        return collapseWhitespace(stripped)
    }

    // MARK: - 2. Inverse text normalisation

    private static let unitWords: Set<String> = [
        // decimals ("three point five")
        "point", "perpuluhan",
        // percent
        "percent", "peratus",
        // currency
        "dollar", "dollars", "bucks", "cents", "cent", "ringgit", "sen", "rupiah", "dirham", "dirhams", "riyal", "riyals",
        "singapore", "sing", "sg", "us",
        // measures
        "kg", "kilo", "kilos", "kilogram", "kilograms", "gram", "grams", "g", "km", "kilometre", "kilometres", "kilometer", "kilometers",
        "metre", "metres", "meter", "meters", "m", "cm", "mm", "litre", "litres", "liter", "liters", "ml", "degrees", "degree",
        // time
        "am", "pm", "a.m", "p.m", "o'clock", "oclock", "minute", "minutes", "min", "mins", "hour", "hours", "hr", "hrs",
        "second", "seconds", "sec", "secs", "minit", "jam", "saat",
        // Days/weeks/months/years are deliberately absent: "one day", "satu hari"
        // read better as words, and every ITN vendor leaves them.
        // multiples
        "times",
    ]

    private static let hyphenatedTensPattern = try! NSRegularExpression(
        pattern: "\\b(twenty|thirty|forty|fourty|fifty|sixty|seventy|eighty|ninety)-(one|two|three|four|five|six|seven|eight|nine)\\b",
        options: [.caseInsensitive]
    )
    private static let tokenPattern = try! NSRegularExpression(pattern: "\\S+")
    private static let decimalPattern = try! NSRegularExpression(pattern: "\\b(\\d+)\\s+(?:point|perpuluhan)\\s+(\\d+)\\b", options: [.caseInsensitive])
    private static let percentPattern = try! NSRegularExpression(pattern: "\\b(\\d+(?:\\.\\d+)?)\\s*(?:percent|per cent|peratus)(?![\\p{L}])", options: [.caseInsensitive])
    private static let singaporeDollarPattern = try! NSRegularExpression(pattern: "\\b(\\d+(?:\\.\\d+)?)\\s+(?:singapore|sing|sg|s)\\s+dollars?(?![\\p{L}])", options: [.caseInsensitive])
    private static let dollarPattern = try! NSRegularExpression(pattern: "\\b(\\d+(?:\\.\\d+)?)\\s+(?:us\\s+)?(?:dollars?|bucks)(?![\\p{L}])", options: [.caseInsensitive])
    private static let ringgitPattern = try! NSRegularExpression(pattern: "\\b(\\d+(?:\\.\\d+)?)\\s+ringgit(?![\\p{L}])", options: [.caseInsensitive])
    private static let timePattern = try! NSRegularExpression(pattern: "\\b(\\d{1,2})(?:\\s*[:.]\\s*(\\d{2})|\\s+(\\d{2}))?\\s*([ap])\\.?\\s?m\\.?(?![\\p{L}])", options: [.caseInsensitive])
    private static let phonePattern = try! NSRegularExpression(pattern: "(?<!\\d)(\\d(?: \\d){5,})(?!\\d)")
    private static let wwwPattern = try! NSRegularExpression(pattern: "\\bwww\\s+dot\\s+", options: [.caseInsensitive])
    private static let dotTLDPattern = try! NSRegularExpression(pattern: "(?<=\\S)\\s+dot\\s+(com|net|org|sg|my|io|ai|co|edu|gov|info|app|dev|me|uk|id)(?![\\p{L}])", options: [.caseInsensitive])
    /// "flow dot nasar.sg" -> "flow.nasar.sg": a spoken "dot" whose right side already
    /// ends in a resolved domain.
    private static let dotSubdomainPattern = try! NSRegularExpression(pattern: "(?<=\\S)\\s+dot\\s+(?=[\\p{L}\\d-]+\\.)", options: [.caseInsensitive])
    private static let emailPattern = try! NSRegularExpression(pattern: "\\b([\\p{L}\\d._-]+)\\s+at\\s+([\\p{L}\\d-]+(?:\\.[\\p{L}\\d-]+)*\\.(?:com|net|org|sg|my|io|ai|co|edu|gov|me|uk|id))(?![\\p{L}])", options: [.caseInsensitive])
    private static let hashtagPattern = try! NSRegularExpression(pattern: "\\bhashtag\\s+([\\p{L}\\d_]+)", options: [.caseInsensitive])

    static func normalizeNumbers(_ text: String) -> String {
        var result = replace(hyphenatedTensPattern, in: text) { m, ns in group(m, 1, ns) + " " + group(m, 2, ns) }
        result = convertSpokenNumbers(result)
        result = replace(decimalPattern, in: result) { m, ns in group(m, 1, ns) + "." + group(m, 2, ns) }
        result = replace(percentPattern, in: result) { m, ns in group(m, 1, ns) + "%" }
        result = replace(singaporeDollarPattern, in: result) { m, ns in "S$" + group(m, 1, ns) }
        result = replace(dollarPattern, in: result) { m, ns in "$" + group(m, 1, ns) }
        result = replace(ringgitPattern, in: result) { m, ns in "RM" + group(m, 1, ns) }
        result = replace(timePattern, in: result) { m, ns in
            let hour = group(m, 1, ns)
            guard let h = Int(hour), (1...12).contains(h) else { return ns.substring(with: m.range) }
            let minutes = m.range(at: 2).location != NSNotFound ? group(m, 2, ns) : (m.range(at: 3).location != NSNotFound ? group(m, 3, ns) : "")
            let suffix = group(m, 4, ns).lowercased() + "m"
            return minutes.isEmpty ? "\(h)\(suffix)" : "\(h):\(minutes)\(suffix)"
        }
        result = replace(phonePattern, in: result) { m, ns in group(m, 1, ns).replacingOccurrences(of: " ", with: "") }
        result = replace(wwwPattern, in: result) { _, _ in "www." }
        for _ in 0..<4 {
            var next = replace(dotTLDPattern, in: result) { m, ns in "." + group(m, 1, ns).lowercased() }
            next = replace(dotSubdomainPattern, in: next) { _, _ in "." }
            if next == result { break }
            result = next
        }
        result = replace(emailPattern, in: result) { m, ns in group(m, 1, ns) + "@" + group(m, 2, ns) }
        result = replace(hashtagPattern, in: result) { m, ns in "#" + group(m, 1, ns) }
        return result
    }

    private struct Token {
        var gapBefore: String
        var leading: String
        var core: String
        var trailing: String
        var lowered: String { core.lowercased() }
        var isDigits: Bool { !core.isEmpty && core.unicodeScalars.allSatisfy { CharacterSet.decimalDigits.contains($0) } }
    }

    private static let edgePunctuation = CharacterSet.punctuationCharacters.union(.symbols)
    private static let runBreakingPunctuation = CharacterSet(charactersIn: ".,;:!?،؛؟")

    private static func tokenize(_ text: String) -> [Token] {
        let ns = text as NSString
        var tokens: [Token] = []
        var cursor = 0
        for match in tokenPattern.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            let gap = ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            let word = ns.substring(with: match.range)
            cursor = match.range.location + match.range.length
            var scalars = Array(word.unicodeScalars)
            var leading = ""
            while let first = scalars.first, edgePunctuation.contains(first), scalars.count > 1 {
                leading.unicodeScalars.append(first)
                scalars.removeFirst()
            }
            var trailing = ""
            var trailingScalars: [Unicode.Scalar] = []
            while let last = scalars.last, edgePunctuation.contains(last), scalars.count > 1 {
                trailingScalars.insert(last, at: 0)
                scalars.removeLast()
            }
            trailing.unicodeScalars.append(contentsOf: trailingScalars)
            var core = ""
            core.unicodeScalars.append(contentsOf: scalars)
            tokens.append(Token(gapBefore: gap, leading: leading, core: core, trailing: trailing))
        }
        return tokens
    }

    /// Replaces runs of number words with digits when they are clearly numeric:
    /// multi-word, ten or more, next to another number, or attached to a unit.
    private static func convertSpokenNumbers(_ text: String) -> String {
        let tokens = tokenize(text)
        guard !tokens.isEmpty else { return text }
        var output = ""
        var i = 0
        var previousWasNumeric = false
        var pendingGap: String? = nil

        while i < tokens.count {
            let token = tokens[i]
            let lowered = token.lowered

            // "a hundred", "an hour"-style articles before a bare scale word.
            if (lowered == "a" || lowered == "an"), token.leading.isEmpty, token.trailing.isEmpty,
               i + 1 < tokens.count, tokens[i + 1].leading.isEmpty,
               SpokenNumberParser.isLeadingScaleWord(tokens[i + 1].lowered) {
                pendingGap = (pendingGap ?? "") + token.gapBefore
                i += 1
                continue
            }

            // Build the window of cores this run may span: stops at punctuation.
            var window: [String] = []
            var j = i
            while j < tokens.count, window.count < 12 {
                if j > i, !tokens[j].leading.isEmpty { break }
                window.append(tokens[j].lowered)
                if endsRun(tokens[j]) { break }
                j += 1
            }

            // When an article was swallowed, its own gap stands in for the number's.
            let gap = pendingGap ?? token.gapBefore

            guard let match = SpokenNumberParser.parse(window, from: 0) else {
                output += gap + token.leading + token.core + token.trailing
                pendingGap = nil
                previousWasNumeric = token.isDigits && !endsRun(token)
                i += 1
                continue
            }

            let last = tokens[i + match.tokenCount - 1]
            let nextIndex = i + match.tokenCount
            let next = nextIndex < tokens.count ? tokens[nextIndex] : nil
            let nextIsNumeric = next.map { $0.isDigits || SpokenNumberParser.parse([$0.lowered], from: 0) != nil } ?? false
            let nextIsUnit = next.map { unitWords.contains($0.lowered) } ?? false
            let articleConsumed = pendingGap != nil && SpokenNumberParser.isLeadingScaleWord(window[0])
            let shouldConvert = match.tokenCount > 1 || match.value >= 10 || nextIsNumeric || nextIsUnit || previousWasNumeric || articleConsumed

            if shouldConvert {
                output += gap + token.leading + String(match.value) + last.trailing
                previousWasNumeric = !endsRun(last)
            } else {
                output += gap + token.leading + token.core + token.trailing
                previousWasNumeric = false
            }
            pendingGap = nil
            i += match.tokenCount
        }
        return output
    }

    private static func endsRun(_ token: Token) -> Bool {
        token.trailing.unicodeScalars.contains { runBreakingPunctuation.contains($0) }
    }

    // MARK: - 3. Punctuation

    private static let spaceBeforePunctuation = try! NSRegularExpression(pattern: "\\s+(?=[,.;:!?،؛؟])")
    private static let doubledCommas = try! NSRegularExpression(pattern: "([,،])(?:\\s*[,،])+")
    private static let commaWithoutSpace = try! NSRegularExpression(pattern: "([,،])(?=[\\p{L}])")
    private static let sentenceWithoutSpace = try! NSRegularExpression(pattern: "([.!?؟])(?=\\p{Lu}\\p{Ll})")
    private static let multipleSpaces = try! NSRegularExpression(pattern: "[ \\t]{2,}")

    static func normalizePunctuation(_ text: String) -> String {
        var result = replace(spaceBeforePunctuation, in: text) { _, _ in "" }
        result = replace(doubledCommas, in: result) { m, ns in group(m, 1, ns) }
        result = replace(commaWithoutSpace, in: result) { m, ns in group(m, 1, ns) + " " }
        result = replace(sentenceWithoutSpace, in: result) { m, ns in group(m, 1, ns) + " " }
        return collapseWhitespace(result)
    }

    // MARK: - 4. Capitalisation

    private static let sentenceStart = try! NSRegularExpression(pattern: "(^|[.!?؟][\"'”’)]*\\s+)(\\p{Ll})")
    private static let lonePronounI = try! NSRegularExpression(pattern: "(?<![\\p{L}\\p{M}'’])i(?![\\p{L}\\p{M}])(?=$|[\\s,.!?;:'’])")

    static func capitalizeSentences(_ text: String) -> String {
        var result = replace(sentenceStart, in: text) { m, ns in group(m, 1, ns) + group(m, 2, ns).uppercased() }
        result = replace(lonePronounI, in: result) { _, _ in "I" }
        return result
    }

    // MARK: - Helpers

    private static func collapseWhitespace(_ text: String) -> String {
        replace(multipleSpaces, in: text) { _, _ in " " }.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func group(_ match: NSTextCheckingResult, _ index: Int, _ ns: NSString) -> String {
        let range = match.range(at: index)
        return range.location == NSNotFound ? "" : ns.substring(with: range)
    }

    private static func replace(_ regex: NSRegularExpression, in text: String, _ transform: (NSTextCheckingResult, NSString) -> String) -> String {
        let ns = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return text }
        var result = ""
        var cursor = 0
        for match in matches {
            let range = match.range
            guard range.location >= cursor else { continue }
            result += ns.substring(with: NSRange(location: cursor, length: range.location - cursor))
            result += transform(match, ns)
            cursor = range.location + range.length
        }
        result += ns.substring(from: cursor)
        return result
    }
}
