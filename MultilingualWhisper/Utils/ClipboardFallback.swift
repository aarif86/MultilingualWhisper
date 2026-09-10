import UIKit
import UniformTypeIdentifiers

/// The universal fallback every dictation product keeps (Dragon's Dictation Box,
/// Monologue's "Copied" state, Wispr's Paste button): the transcript also goes on
/// the clipboard, so even if the keyboard hand-off fails the words are one paste
/// away. Two things make this less of a privacy and clipboard-hygiene problem
/// than a plain `UIPasteboard.general.string = text`:
///
/// - it **expires** after `lifetime`, so a dictation does not sit on the clipboard
///   for days waiting to be pasted into the wrong place;
/// - it is **local only**, never handed to other devices via Universal Clipboard.
///
/// Restoring whatever was on the clipboard before is not possible without a
/// system "Allow Paste" prompt (reading the pasteboard is what triggers it), so
/// expiry is the honest substitute. Explicit "Copy" buttons in the app still copy
/// permanently - there the user asked for it.
enum ClipboardFallback {
    static let lifetime: TimeInterval = 120

    static func place(_ text: String, now: Date = Date()) {
        guard !text.isEmpty else { return }
        UIPasteboard.general.setItems(
            [[UTType.utf8PlainText.identifier: text]],
            options: [.localOnly: true, .expirationDate: now.addingTimeInterval(lifetime)]
        )
    }
}
