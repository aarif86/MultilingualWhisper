import UIKit

/// The keyboard's compact letter layer (Willow's answer to Wispr's most-cited iOS
/// complaint: fixing one word should not mean switching keyboards). Pure helpers
/// for the parts worth testing - which key rows to show and when a typed letter
/// should be capitalised - compiled into both the app and the keyboard.
enum KeyboardTyping {
    enum Layer: Equatable {
        case voice
        case letters
        case symbols
    }

    static let letterRows: [[String]] = [
        ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
        ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
        ["z", "x", "c", "v", "b", "n", "m"],
    ]

    static let symbolRows: [[String]] = [
        ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
        ["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""],
        ["?", "!", "'", "\u{2019}", "%", "+", "="],
    ]

    /// Whether the next typed letter is capitalised: the one-shot shift key wins,
    /// then the field's own auto-capitalisation rule against the text before the
    /// cursor - sentences via `InsertionPolicy.startsNewSentence`, words after a
    /// space, everything for all-caps fields, never for fields that opted out.
    static func shouldCapitalise(
        shiftOn: Bool,
        contextBefore: String?,
        autocapitalization: UITextAutocapitalizationType
    ) -> Bool {
        if shiftOn { return true }
        let context = contextBefore ?? ""
        switch autocapitalization {
        case .allCharacters:
            return true
        case .words:
            guard let last = context.last else { return true }
            return last.isWhitespace || last.isNewline
        case .sentences:
            return InsertionPolicy.startsNewSentence(leftContext: context)
        case .none:
            return false
        @unknown default:
            return false
        }
    }
}
