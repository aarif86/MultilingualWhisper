import Foundation

/// Turns a WhatsApp chat export into candidate vocabulary for
/// `UserLanguageKeywords`, and shows how the *real* `RuleBasedLanguageClassifier`
/// would label the messages today - both computed on-device, from the export
/// text only (never the sender's real conversation content leaves this type).
///
/// Built from the same approach used to find the SMS-shorthand gap behind
/// `Constants.malayKeywords`'s 2026-09-10 additions: word-frequency counting
/// over real messages surfaces exactly the vocabulary a user actually needs,
/// instead of hand-curating one household's words and hoping it generalizes.
enum ChatExportParser {
    struct ParsedMessage: Equatable {
        let sender: String
        let text: String
    }

    struct CandidateWord: Identifiable, Equatable {
        var id: String { word }
        let word: String
        let count: Int
    }

    struct ImportResult {
        let totalMessages: Int
        /// Frequency-ranked words not already recognized by the built-in
        /// lists or anything the user has already approved - what
        /// `ChatImportReviewView` actually shows.
        let candidates: [CandidateWord]
        /// How `RuleBasedLanguageClassifier` labels these same messages right
        /// now, keyed by its real `LanguageType` - the "before" picture,
        /// computed with the actual production classifier, not a reimplementation.
        let currentClassification: [LanguageType: Int]
    }

    // MARK: - WhatsApp

    // iOS export line: "[D/M/YY, H:MM:SS AM/PM] Sender: message" - a line that
    // doesn't match this pattern is a continuation of the previous message
    // (WhatsApp wraps a multi-line message across several physical lines).
    private static let whatsAppLineRegex = try! NSRegularExpression(
        pattern: #"^\[\d{1,2}/\d{1,2}/\d{2,4}, [^\]]+\] ([^:]+?): (.*)$"#
    )

    // Media placeholders and system lines WhatsApp's text export inserts in
    // place of actual content - never real vocabulary, always skipped.
    private static let skipSubstrings = [
        "Media omitted", "image omitted", "video omitted", "audio omitted",
        "sticker omitted", "GIF omitted", "document omitted", "Contact card omitted",
        "This message was deleted", "You deleted this message",
        "Missed voice call", "Missed video call", "<attached:",
        "Messages and calls are end-to-end encrypted", "created this group",
        "changed the subject", "changed this group's icon",
    ]

    static func parseWhatsApp(_ rawText: String) -> [ParsedMessage] {
        var messages: [ParsedMessage] = []
        var currentSender: String?
        var currentText = ""

        func flush() {
            guard let sender = currentSender else { return }
            let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty, !skipSubstrings.contains(where: { text.contains($0) }) else { return }
            messages.append(ParsedMessage(sender: sender, text: text))
        }

        rawText.enumerateLines { line, _ in
            let nsLine = line as NSString
            let fullRange = NSRange(location: 0, length: nsLine.length)
            if let match = whatsAppLineRegex.firstMatch(in: line, range: fullRange), match.numberOfRanges == 3 {
                flush()
                currentSender = nsLine.substring(with: match.range(at: 1))
                currentText = nsLine.substring(with: match.range(at: 2))
            } else if currentSender != nil {
                currentText += " " + line.trimmingCharacters(in: .whitespaces)
            }
        }
        flush()
        return messages
    }

    // MARK: - Word frequency

    /// Words common enough in plain English that they'd otherwise swamp the
    /// candidate list - not exhaustive, just enough to surface real Malay/
    /// Singlish/Arabic vocabulary instead of "the", "and", "is".
    static let commonEnglish: Set<String> = [
        "a", "about", "after", "again", "against", "all", "also", "am", "an", "and", "any",
        "are", "around", "as", "at", "back", "be", "because", "been", "before", "being",
        "below", "best", "better", "between", "both", "but", "by", "call", "came", "can",
        "cannot", "cant", "come", "could", "couldnt", "did", "didnt", "do", "does", "doesnt",
        "doing", "dont", "down", "during", "each", "either", "else", "even", "ever", "every",
        "for", "from", "get", "give", "go", "going", "gone", "gonna", "good", "got", "had",
        "hadnt", "has", "hasnt", "have", "havent", "having", "he", "hello", "her", "here",
        "hers", "herself", "him", "himself", "his", "how", "if", "im", "in", "into", "is",
        "isnt", "it", "its", "itself", "just", "know", "let", "lets", "like", "lol", "love",
        "me", "more", "most", "much", "must", "my", "myself", "need", "no", "nor", "not",
        "now", "of", "off", "ok", "okay", "on", "once", "one", "only", "or", "other", "our",
        "ours", "ourselves", "out", "over", "own", "really", "right", "said", "same", "say",
        "see", "she", "should", "shouldnt", "so", "some", "still", "such", "than", "that",
        "the", "their", "theirs", "them", "themselves", "then", "there", "these", "they",
        "this", "those", "through", "to", "too", "under", "until", "up", "us", "very", "was",
        "wasnt", "we", "were", "werent", "what", "when", "where", "which", "while", "who",
        "whom", "why", "will", "with", "without", "wont", "would", "wouldnt", "yeah", "yes",
        "yet", "you", "your", "yours", "yourself", "yourselves", "im", "ur", "ya", "yep",
        "nope", "hey", "hi", "oh", "ah", "um", "uh", "haha", "hahaha", "omg", "wow", "yea",
        "today", "tomorrow", "yesterday", "morning", "night", "day", "week", "month", "year",
        "baby", "mom", "mum", "dad", "check", "ask", "please", "free", "sorry", "coz",
        "plan", "think", "meeting", "send", "later", "thank", "confirm", "msg", "car",
    ]

    static func wordFrequency(_ messages: [ParsedMessage]) -> [(word: String, count: Int)] {
        var counts: [String: Int] = [:]
        for message in messages {
            for token in message.text.lowercased().split(whereSeparator: { !$0.isLetter }) {
                let word = String(token)
                guard word.count >= 2, !commonEnglish.contains(word) else { continue }
                counts[word, default: 0] += 1
            }
        }
        // Explicit parameter/return types and an if/else instead of one
        // compound boolean expression - Swift's type checker times out on
        // the terser `$0.value > $1.value || ($0.value == $1.value && ...)`
        // form here (confirmed via a real CI failure, not a style choice).
        let sorted = counts.sorted { (lhs: (key: String, value: Int), rhs: (key: String, value: Int)) -> Bool in
            if lhs.value != rhs.value { return lhs.value > rhs.value }
            return lhs.key < rhs.key
        }
        // Dictionary.Element's labels are (key, value), not (word, count) -
        // different labels make these different tuple types in Swift, so this
        // needs an explicit re-label, not just a return (confirmed via a real
        // CI type error).
        return sorted.map { (word: $0.key, count: $0.value) }
    }

    // MARK: - Putting it together

    static func analyze(
        rawWhatsAppText: String,
        alreadyKnown: Set<String>,
        classifier: LanguageClassifying,
        candidateLimit: Int = 80
    ) -> ImportResult {
        let messages = parseWhatsApp(rawWhatsAppText)
        let candidates = wordFrequency(messages)
            .filter { !alreadyKnown.contains($0.word) }
            .prefix(candidateLimit)
            .map { CandidateWord(word: $0.word, count: $0.count) }

        var classification: [LanguageType: Int] = [:]
        for message in messages {
            let tag = classifier.classify(text: message.text).languageTag
            classification[tag, default: 0] += 1
        }

        return ImportResult(totalMessages: messages.count, candidates: candidates, currentClassification: classification)
    }
}
