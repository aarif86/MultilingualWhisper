import Foundation

/// Works out what the user corrected by hand after a dictation was inserted, so
/// the Custom Dictionary can learn it without a settings trip.
///
/// This is Wispr Flow's "correct a word during dictation and it's added to your
/// dictionary" behaviour (`docs/competitor-kb/wispr-flow.md`), rebuilt for a
/// keyboard extension that can only see the host field's text, never the user's
/// keystrokes: compare the text the keyboard inserted with what the field holds
/// where it was inserted, and treat *similar-looking* word swaps as spelling
/// corrections. Rewrites that change the word entirely ("go" → "come") are
/// content edits, not corrections, and are ignored.
///
/// Pure and dependency-free so it is unit tested on the Simulator - see
/// `CorrectionLearnerTests`. Compiled into both the app and the keyboard.
enum CorrectionLearner {
    struct Correction: Equatable, Hashable, Codable {
        /// What the model wrote (the future spoken form).
        let heard: String
        /// What the user changed it to (the future written form).
        let corrected: String
    }

    /// - Parameters:
    ///   - inserted: the exact text the keyboard inserted.
    ///   - context: the host field's text up to the cursor (`documentContextBeforeInput`).
    static func corrections(inserted: String, context: String) -> [Correction] {
        let insertedWords = words(inserted)
        let contextWords = words(context)
        guard !insertedWords.isEmpty, !contextWords.isEmpty else { return [] }
        if insertedWords.map(\.text) == Array(contextWords.suffix(insertedWords.count)).map(\.text) { return [] }

        let tail = Array(contextWords.suffix(insertedWords.count * 2 + 4))
        let window = bestWindow(for: insertedWords, in: tail)
        guard !window.isEmpty else { return [] }

        var found: [Correction] = []
        var seen = Set<Correction>()
        func record(_ heard: String, _ corrected: String) {
            let correction = Correction(heard: heard, corrected: corrected)
            guard heard != corrected, seen.insert(correction).inserted else { return }
            found.append(correction)
        }

        // Case-only changes on words the alignment matched.
        let alignment = lcsPairs(insertedWords.map(\.key), window.map(\.key))
        for (i, j) in alignment {
            let heard = insertedWords[i].text
            let corrected = window[j].text
            guard heard != corrected, heard.lowercased() == corrected.lowercased() else { continue }
            // Sentence-initial capitalisation is the formatter's or the insertion
            // policy's doing, not the user's - in either direction.
            let onlyFirstLetterDiffers = i == 0 && heard.dropFirst() == corrected.dropFirst()
            guard !onlyFirstLetterDiffers else { continue }
            record(heard, corrected)
        }

        // Substitutions in the gaps between matched words.
        var previousI = -1
        var previousJ = -1
        for (i, j) in alignment + [(insertedWords.count, window.count)] {
            let heardGap = Array(insertedWords[(previousI + 1)..<i])
            let correctedGap = Array(window[(previousJ + 1)..<j])
            previousI = i
            previousJ = j
            guard !heardGap.isEmpty, !correctedGap.isEmpty, heardGap.count <= 3, correctedGap.count <= 3 else { continue }
            if heardGap.count == correctedGap.count {
                for (h, c) in zip(heardGap, correctedGap) where isSpellingCorrection(h.text, c.text) {
                    record(h.text, c.text)
                }
            } else {
                let heard = heardGap.map(\.text).joined(separator: " ")
                let corrected = correctedGap.map(\.text).joined(separator: " ")
                if isSpellingCorrection(heard, corrected) { record(heard, corrected) }
            }
        }
        return found
    }

    // MARK: - Similarity

    /// Two words are a spelling correction of each other when they share at least
    /// half their letters in order, both are real words (two or more letters), and
    /// neither is just a number.
    static func isSpellingCorrection(_ heard: String, _ corrected: String) -> Bool {
        guard heard != corrected else { return false }
        let a = letters(heard)
        let b = letters(corrected)
        guard a.count >= 2, b.count >= 2 else { return false }
        guard heard.contains(where: \.isLetter), corrected.contains(where: \.isLetter) else { return false }
        // Same letters, different spacing or case ("insya Allah" -> "insyaAllah").
        if a == b { return true }
        let distance = levenshtein(Array(a), Array(b))
        let longest = max(a.count, b.count)
        // Short words flip meaning with one letter ("five" / "nine"), so they must
        // be a single edit apart; longer words get a proportional allowance.
        if longest <= 4 { return distance <= 1 }
        return 1 - Double(distance) / Double(longest) >= 0.6
    }

    static func levenshtein(_ a: [Character], _ b: [Character]) -> Int {
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var previous = Array(0...b.count)
        var current = [Int](repeating: 0, count: b.count + 1)
        for i in 1...a.count {
            current[0] = i
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
            }
            swap(&previous, &current)
        }
        return previous[b.count]
    }

    // MARK: - Words and alignment

    struct Word: Equatable {
        let text: String
        var key: String { text.lowercased() }
    }

    private static let edgePunctuation = CharacterSet.punctuationCharacters.union(.symbols)

    static func words(_ text: String) -> [Word] {
        text.split(whereSeparator: { $0.isWhitespace }).compactMap { raw in
            var scalars = Array(raw.unicodeScalars)
            while let first = scalars.first, edgePunctuation.contains(first) { scalars.removeFirst() }
            while let last = scalars.last, edgePunctuation.contains(last) { scalars.removeLast() }
            guard !scalars.isEmpty else { return nil }
            var word = ""
            word.unicodeScalars.append(contentsOf: scalars)
            return Word(text: word)
        }
    }

    private static func letters(_ text: String) -> String {
        String(text.lowercased().filter { $0.isLetter || $0.isNumber })
    }

    /// The slice of `tail` that best lines up with `inserted`: the window with the
    /// most words in common, or - when nothing matches at all, as with a single
    /// misspelled word - simply the last `inserted.count` words.
    private static func bestWindow(for inserted: [Word], in tail: [Word]) -> [Word] {
        let n = inserted.count
        let keys = inserted.map(\.key)
        var best: (score: Int, window: [Word]) = (0, [])
        for size in max(1, n - 2)...(n + 2) where size <= tail.count {
            for start in 0...(tail.count - size) {
                let window = Array(tail[start..<(start + size)])
                let score = lcsPairs(keys, window.map(\.key)).count
                // On a tie prefer the wider window: extra unmatched words at its
                // edges are harmless, but a narrow window can cut off the very
                // words the user corrected.
                if score > best.score || (score == best.score && score > 0 && size > best.window.count) {
                    best = (score, window)
                }
            }
        }
        if best.score > 0 { return best.window }
        return Array(tail.suffix(n))
    }

    /// Index pairs of a longest common subsequence, in order.
    static func lcsPairs(_ a: [String], _ b: [String]) -> [(Int, Int)] {
        guard !a.isEmpty, !b.isEmpty else { return [] }
        var table = [[Int]](repeating: [Int](repeating: 0, count: b.count + 1), count: a.count + 1)
        for i in 1...a.count {
            for j in 1...b.count {
                table[i][j] = a[i - 1] == b[j - 1] ? table[i - 1][j - 1] + 1 : max(table[i - 1][j], table[i][j - 1])
            }
        }
        var pairs: [(Int, Int)] = []
        var i = a.count
        var j = b.count
        while i > 0, j > 0 {
            if a[i - 1] == b[j - 1] {
                pairs.append((i - 1, j - 1))
                i -= 1
                j -= 1
            } else if table[i - 1][j] >= table[i][j - 1] {
                i -= 1
            } else {
                j -= 1
            }
        }
        return pairs.reversed()
    }
}
