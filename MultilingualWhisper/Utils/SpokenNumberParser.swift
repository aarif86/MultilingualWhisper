import Foundation

/// Reads runs of spoken number words ("two hundred and five", "dua puluh lima") as
/// integers. English and Malay, chosen by the first word. Deliberately strict about
/// word order so "five twenty" is *not* 25 (it's two numbers, or a time) and "five
/// five" is two separate digits (a phone number), not a parse error.
///
/// Pure and dependency-free so `TranscriptFormatter`'s inverse text normalisation
/// can be unit tested without a model - see `SpokenNumberParserTests`.
enum SpokenNumberParser {
    struct Match: Equatable {
        let value: Int
        /// Number of tokens consumed, starting at `from`.
        let tokenCount: Int
    }

    /// `tokens` must already be lowercased and stripped of punctuation.
    static func parse(_ tokens: [String], from start: Int) -> Match? {
        guard start < tokens.count else { return nil }
        if let english = parseEnglish(tokens, from: start) { return english }
        return parseMalay(tokens, from: start)
    }

    static func isNumberWord(_ word: String) -> Bool {
        englishUnits[word] != nil || englishTeens[word] != nil || englishTens[word] != nil
            || word == "hundred" || englishBigScales[word] != nil
            || malayUnits[word] != nil || malaySpecials[word] != nil
    }

    /// Words that stand for an implicit "one" when they open a run ("a hundred").
    static func isLeadingScaleWord(_ word: String) -> Bool {
        word == "hundred" || englishBigScales[word] != nil
    }

    // MARK: - English

    private static let englishUnits: [String: Int] = [
        "zero": 0, "one": 1, "two": 2, "three": 3, "four": 4,
        "five": 5, "six": 6, "seven": 7, "eight": 8, "nine": 9,
    ]
    private static let englishTeens: [String: Int] = [
        "ten": 10, "eleven": 11, "twelve": 12, "thirteen": 13, "fourteen": 14,
        "fifteen": 15, "sixteen": 16, "seventeen": 17, "eighteen": 18, "nineteen": 19,
    ]
    private static let englishTens: [String: Int] = [
        "twenty": 20, "thirty": 30, "forty": 40, "fourty": 40, "fifty": 50,
        "sixty": 60, "seventy": 70, "eighty": 80, "ninety": 90,
    ]
    private static let englishBigScales: [String: Int] = [
        "thousand": 1_000, "million": 1_000_000, "billion": 1_000_000_000,
    ]

    private enum EnglishKind { case unit, teen, tens, hundred, big, and }

    private static func parseEnglish(_ tokens: [String], from start: Int) -> Match? {
        var i = start
        var total = 0
        var current = 0
        var last: EnglishKind?
        var largestBig = Int.max

        while i < tokens.count {
            let word = tokens[i]
            if let v = englishUnits[word] {
                guard last == nil || last == .tens || last == .hundred || last == .big || last == .and else { break }
                current += v
                last = .unit
            } else if let v = englishTeens[word] {
                guard last == nil || last == .hundred || last == .big || last == .and else { break }
                current += v
                last = .teen
            } else if let v = englishTens[word] {
                guard last == nil || last == .hundred || last == .big || last == .and else { break }
                current += v
                last = .tens
            } else if word == "hundred" {
                guard last == nil || last == .unit || last == .teen || last == .tens, current < 100 else { break }
                current = max(current, 1) * 100
                last = .hundred
            } else if let scale = englishBigScales[word] {
                guard last != .and, last != .big, scale < largestBig else { break }
                total += max(current, 1) * scale
                current = 0
                largestBig = scale
                last = .big
            } else if word == "and" {
                guard last == .hundred || last == .big, i + 1 < tokens.count else { break }
                let next = tokens[i + 1]
                guard englishUnits[next] != nil || englishTeens[next] != nil || englishTens[next] != nil else { break }
                last = .and
            } else {
                break
            }
            i += 1
        }

        let consumed = i - start
        guard consumed > 0, last != .and else { return nil }
        return Match(value: total + current, tokenCount: consumed)
    }

    // MARK: - Malay

    private static let malayUnits: [String: Int] = [
        "kosong": 0, "satu": 1, "dua": 2, "tiga": 3, "empat": 4,
        "lima": 5, "enam": 6, "tujuh": 7, "lapan": 8, "delapan": 8, "sembilan": 9,
    ]
    /// "se-" forms carry an implicit one.
    private static let malaySpecials: [String: Int] = [
        "sepuluh": 10, "sebelas": 11, "seratus": 100, "seribu": 1_000, "sejuta": 1_000_000,
    ]

    private static func parseMalay(_ tokens: [String], from start: Int) -> Match? {
        var i = start
        var total = 0
        var current = 0
        var onesTaken = false
        var tensTaken = false

        while i < tokens.count {
            let word = tokens[i]
            if let v = malaySpecials[word] {
                switch v {
                case 10, 11:
                    guard !tensTaken, !onesTaken else { return finish(start: start, end: i, total: total, current: current) }
                    current += v
                    tensTaken = true
                    onesTaken = true
                case 100:
                    guard current == 0 else { return finish(start: start, end: i, total: total, current: current) }
                    current = 100
                default:
                    guard current == 0 else { return finish(start: start, end: i, total: total, current: current) }
                    total += v
                }
                i += 1
                continue
            }
            guard let v = malayUnits[word] else { break }
            let next = i + 1 < tokens.count ? tokens[i + 1] : ""
            switch next {
            case "belas":
                guard !tensTaken, !onesTaken else { return finish(start: start, end: i, total: total, current: current) }
                current += 10 + v
                tensTaken = true
                onesTaken = true
                i += 2
            case "puluh":
                guard !tensTaken, !onesTaken else { return finish(start: start, end: i, total: total, current: current) }
                current += v * 10
                tensTaken = true
                i += 2
            case "ratus":
                guard current == 0 else { return finish(start: start, end: i, total: total, current: current) }
                current = v * 100
                tensTaken = false
                onesTaken = false
                i += 2
            case "ribu":
                total += (current + v) * 1_000
                current = 0
                tensTaken = false
                onesTaken = false
                i += 2
            case "juta":
                total += (current + v) * 1_000_000
                current = 0
                tensTaken = false
                onesTaken = false
                i += 2
            default:
                guard !onesTaken else { return finish(start: start, end: i, total: total, current: current) }
                current += v
                onesTaken = true
                i += 1
            }
        }
        return finish(start: start, end: i, total: total, current: current)
    }

    private static func finish(start: Int, end: Int, total: Int, current: Int) -> Match? {
        let consumed = end - start
        guard consumed > 0 else { return nil }
        return Match(value: total + current, tokenCount: consumed)
    }
}
