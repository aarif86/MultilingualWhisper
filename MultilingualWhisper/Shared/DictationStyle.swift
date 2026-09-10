import Foundation
import UIKit

/// A formatting preset chosen for the *destination* of a dictation - the same
/// idea as Wispr's Personal/Work/Email, Willow's Casual Messaging/Email/Notes and
/// Superwhisper's Message/Email/Note modes (`docs/competitor-kb/`), minus the LLM:
/// every preset here is a handful of deterministic `TranscriptFormatter` switches,
/// so it costs nothing and never rewrites a word.
///
/// `auto` is the default and picks a preset from what the text field says about
/// itself (`HostFieldHint`): a Send key means chat, an email or URL keyboard means
/// exact text, and so on. The keyboard shows the resolved preset in its style pill
/// and one tap overrides it - "pick the style before you speak" (Cleft), and
/// switchable mid-session (the Superwhisper complaint) because it is read fresh
/// for every utterance.
enum DictationStyle: String, CaseIterable, Codable, Identifiable {
    case auto
    case messaging
    case email
    case notes
    case exact

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .messaging: return "Chat"
        case .email: return "Email"
        case .notes: return "Notes"
        case .exact: return "Exact"
        }
    }

    var symbolName: String {
        switch self {
        case .auto: return "wand.and.stars"
        case .messaging: return "message"
        case .email: return "envelope"
        case .notes: return "note.text"
        case .exact: return "textformat.abc.dottedunderline"
        }
    }

    var detail: String {
        switch self {
        case .auto: return "Picks a style from the field you're typing in."
        case .messaging: return "Casual: no full stop at the end of a one-line message."
        case .email: return "Tidy: numbers as digits, sentences capitalised and closed."
        case .notes: return "Your Cleanup setting, nothing more."
        case .exact: return "No capitals, no trailing full stop - for addresses, code and search boxes."
        }
    }

    /// The next preset when the keyboard's pill is tapped; wraps around.
    var next: DictationStyle {
        let all = DictationStyle.allCases
        let index = all.firstIndex(of: self) ?? 0
        return all[(index + 1) % all.count]
    }

    /// What `auto` settles on for a given field. Explicit picks are returned as-is.
    static func resolve(_ style: DictationStyle, hint: HostFieldHint) -> DictationStyle {
        guard style == .auto else { return style }
        switch hint {
        case .messaging, .search: return .messaging
        case .address, .code: return .exact
        case .general: return .notes
        }
    }

    /// The formatter switches this style flips for a field.
    func profile(hint: HostFieldHint) -> StyleProfile {
        switch DictationStyle.resolve(self, hint: hint) {
        case .messaging:
            return StyleProfile(numbers: .inherit, capitalise: .inherit, trailingPeriod: .drop, stripWhitespace: false)
        case .email:
            return StyleProfile(numbers: .force, capitalise: .force, trailingPeriod: .ensure, stripWhitespace: false)
        case .exact:
            // An email or URL field cannot hold spaces at all; a code field or a
            // search box can, it just doesn't want capitals or a closing period.
            return StyleProfile(numbers: .force, capitalise: .suppress, trailingPeriod: .drop, stripWhitespace: hint == .address)
        case .notes, .auto:
            return .standard
        }
    }
}

/// What a text field tells the keyboard about itself, reduced to the four cases
/// that change how a dictation should be formatted. Derived from
/// `UITextInputTraits`, which is all a keyboard extension can see - iOS exposes no
/// host app identity to keyboards, so this is the mobile equivalent of the
/// per-app presets desktop tools bind to a bundle ID.
enum HostFieldHint: String, Codable, CaseIterable {
    /// The return key says Send: a chat composer.
    case messaging
    /// Search or Go: a query, not prose.
    case search
    /// Email, URL, phone or number keyboards, and password fields: exact characters, no spaces.
    case address
    /// The field asked for no auto-capitalisation: code, usernames, terminals.
    case code
    case general

    init(returnKey: UIReturnKeyType, keyboard: UIKeyboardType, autocapitalization: UITextAutocapitalizationType, isSecure: Bool) {
        if isSecure {
            self = .address
            return
        }
        switch keyboard {
        case .emailAddress, .URL, .phonePad, .namePhonePad, .numberPad, .decimalPad, .asciiCapableNumberPad:
            self = .address
            return
        case .webSearch:
            self = .search
            return
        default:
            break
        }
        switch returnKey {
        case .send:
            self = .messaging
        case .search, .go:
            self = .search
        default:
            self = autocapitalization == .none ? .code : .general
        }
    }
}

/// The concrete formatter switches a resolved style asks for. Kept separate from
/// `DictationStyle` so the formatter (main app) and the keyboard never need to
/// agree on anything but this small, Codable value.
struct StyleProfile: Equatable, Codable {
    enum Override: String, Codable {
        /// Leave it to the user's Cleanup level.
        case inherit
        case force
        case suppress
    }

    enum TrailingPeriod: String, Codable {
        case keep
        /// Remove a lone full stop at the end of a single sentence - the texting
        /// convention where "ok." reads as curt.
        case drop
        /// Close the last sentence if it is left open.
        case ensure
    }

    var numbers: Override
    var capitalise: Override
    var trailingPeriod: TrailingPeriod
    /// Remove every space - for fields that cannot contain any.
    var stripWhitespace: Bool

    static let standard = StyleProfile(numbers: .inherit, capitalise: .inherit, trailingPeriod: .keep, stripWhitespace: false)
}
