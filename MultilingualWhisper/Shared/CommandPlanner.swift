import Foundation

/// Turns a `VoiceCommand` into the exact `UITextDocumentProxy` operations that
/// carry it out, given what sits before the cursor. Pure, so every command is
/// unit-tested against real text contexts - see `CommandPlannerTests`.
///
/// "That" means the last thing this keyboard inserted when it is still at the
/// cursor (Talon/Dragon's "last phrase" unit), otherwise the last word.
enum CommandPlanner {
    enum EditOp: Equatable {
        case deleteBackward(Int)
        /// Insert exactly this string (newlines, punctuation).
        case insertRaw(String)
        /// Insert through the normal dictation path, so `InsertionPolicy` handles
        /// spacing and capitals.
        case insertDictation(String)
    }

    static func plan(_ command: VoiceCommand, contextBefore: String, lastInserted: String?) -> [EditOp] {
        switch command {
        case .newLine:
            return [.insertRaw("\n")]
        case .newParagraph:
            return [.insertRaw("\n\n")]
        case .deleteThat:
            if let count = lastInsertCount(contextBefore: contextBefore, lastInserted: lastInserted) {
                return [.deleteBackward(count)]
            }
            return deleteWord(contextBefore)
        case .deleteWord:
            return deleteWord(contextBefore)
        case .deleteLine:
            return deleteLine(contextBefore)
        case .period:
            return punctuation(".", contextBefore: contextBefore)
        case .comma:
            return punctuation(",", contextBefore: contextBefore)
        case .questionMark:
            return punctuation("?", contextBefore: contextBefore)
        case .exclamationMark:
            return punctuation("!", contextBefore: contextBefore)
        case .capitaliseThat:
            return recase(contextBefore: contextBefore, lastInserted: lastInserted) { capitaliseFirst($0) }
        case .allCapsThat:
            return recase(contextBefore: contextBefore, lastInserted: lastInserted) { $0.uppercased() }
        case .lowercaseThat:
            return recase(contextBefore: contextBefore, lastInserted: lastInserted) { $0.lowercased() }
        case .literal(let text):
            return text.isEmpty ? [] : [.insertDictation(text)]
        case .spell(let word):
            return word.isEmpty ? [] : [.insertDictation(word)]
        case .replace(let target, let replacement):
            return replace(target, with: replacement, contextBefore: contextBefore)
        }
    }

    // MARK: - Replace

    /// Rewrites the last whole-word, case-insensitive occurrence of `target`
    /// before the cursor. The proxy can only delete backwards and insert at the
    /// cursor, so everything from the match to the cursor is deleted and retyped
    /// with the replacement in place - deterministic, unlike moving the cursor
    /// (`adjustTextPosition` updates the context lazily). Empty when not found.
    static func replace(_ target: String, with replacement: String, contextBefore: String) -> [EditOp] {
        guard let range = lastWholeWordRange(of: target, in: contextBefore) else { return [] }
        let found = String(contextBefore[range])
        let tail = String(contextBefore[range.upperBound...])
        let recased = matchCase(of: found, onto: replacement)
        return [.deleteBackward(contextBefore.distance(from: range.lowerBound, to: contextBefore.endIndex)), .insertRaw(recased + tail)]
    }

    /// The last occurrence of `target` (case- and diacritic-insensitive) whose
    /// neighbours are not letters or digits.
    static func lastWholeWordRange(of target: String, in text: String) -> Range<String.Index>? {
        let needle = target.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return nil }
        var searchRange = text.startIndex..<text.endIndex
        var best: Range<String.Index>?
        while let range = text.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive], range: searchRange) {
            let before = range.lowerBound > text.startIndex ? text[text.index(before: range.lowerBound)] : nil
            let after = range.upperBound < text.endIndex ? text[range.upperBound] : nil
            if !(before?.isLetter ?? false), !(before?.isNumber ?? false), !(after?.isLetter ?? false), !(after?.isNumber ?? false) {
                best = range
            }
            guard range.upperBound < text.endIndex else { break }
            searchRange = text.index(after: range.lowerBound)..<text.endIndex
        }
        return best
    }

    /// Copies the case shape of the word being replaced onto the replacement:
    /// all-caps stays all-caps (MRT -> LRT), a leading capital stays (Tampines ->
    /// Tampines), anything else is left as spoken.
    static func matchCase(of original: String, onto replacement: String) -> String {
        let letters = original.filter(\.isLetter)
        guard let first = letters.first, first.isCased else { return replacement }
        if letters.count > 1, letters.allSatisfy(\.isUppercase) {
            return replacement.uppercased()
        }
        if first.isUppercase, let head = replacement.first, head.isCased, head.isLowercase {
            return head.uppercased() + replacement.dropFirst()
        }
        return replacement
    }

    // MARK: - Targets

    /// Character count of the last insert when it is still exactly at the cursor.
    private static func lastInsertCount(contextBefore: String, lastInserted: String?) -> Int? {
        guard let lastInserted, !lastInserted.isEmpty, contextBefore.hasSuffix(lastInserted) else { return nil }
        return lastInserted.count
    }

    /// The last word with its surrounding spaces on this line: trailing spaces,
    /// the word itself, and the one space before it - so deleting the span from
    /// "hello world" leaves "hello", not "hello ". Never crosses a newline.
    static func lastWordSpan(_ context: String) -> Int {
        guard let bounds = lastWordBounds(context) else { return 0 }
        var span = bounds.word.count + bounds.trailing.count
        let beforeWord = context.dropLast(span)
        if let separator = beforeWord.last, separator.isWhitespace, !separator.isNewline { span += 1 }
        return span
    }

    /// Splits the end of `context` into (last word, trailing spaces), stopping at
    /// a newline. nil when there is no word on the current line.
    static func lastWordBounds(_ context: String) -> (word: String, trailing: String)? {
        var trailing = ""
        var index = context.endIndex
        while index > context.startIndex {
            let previous = context.index(before: index)
            let char = context[previous]
            if char.isNewline || !char.isWhitespace { break }
            trailing.insert(char, at: trailing.startIndex)
            index = previous
        }
        var word = ""
        while index > context.startIndex {
            let previous = context.index(before: index)
            let char = context[previous]
            if char.isWhitespace || char.isNewline { break }
            word.insert(char, at: word.startIndex)
            index = previous
        }
        return word.isEmpty ? nil : (word, trailing)
    }

    private static func deleteWord(_ context: String) -> [EditOp] {
        let span = lastWordSpan(context)
        return span > 0 ? [.deleteBackward(span)] : []
    }

    private static func deleteLine(_ context: String) -> [EditOp] {
        guard !context.isEmpty else { return [] }
        var count = 0
        var index = context.endIndex
        while index > context.startIndex {
            let previous = context.index(before: index)
            if context[previous].isNewline { break }
            count += 1
            index = previous
        }
        // An empty line: remove the newline itself so the cursor joins the previous line.
        if count == 0 { return [.deleteBackward(1)] }
        return [.deleteBackward(count)]
    }

    private static func punctuation(_ mark: String, contextBefore: String) -> [EditOp] {
        let trailingSpaces = contextBefore.reversed().prefix { $0 == " " }.count
        var ops: [EditOp] = []
        if trailingSpaces > 0 { ops.append(.deleteBackward(trailingSpaces)) }
        ops.append(.insertRaw(mark))
        return ops
    }

    private static func recase(contextBefore: String, lastInserted: String?, _ transform: (String) -> String) -> [EditOp] {
        let target: String
        let replaced: String
        if let lastInserted, !lastInserted.isEmpty, contextBefore.hasSuffix(lastInserted) {
            target = lastInserted
            replaced = transform(lastInserted)
        } else {
            guard let bounds = lastWordBounds(contextBefore) else { return [] }
            target = bounds.word + bounds.trailing
            replaced = transform(bounds.word) + bounds.trailing
        }
        guard replaced != target else { return [] }
        return [.deleteBackward(target.count), .insertRaw(replaced)]
    }

    private static func capitaliseFirst(_ text: String) -> String {
        guard let first = text.first(where: { $0.isLetter }), first.isCased, first.isLowercase,
              let index = text.firstIndex(where: { $0.isLetter }) else { return text }
        return String(text[..<index]) + first.uppercased() + text[text.index(after: index)...]
    }
}
