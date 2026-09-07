import SwiftUI
import UIKit

/// Custom keyboard extension entry point. This deliberately does none of the
/// actual recording/transcription work itself - see DictationHandoff.swift for
/// why (Apple blocks microphone access from keyboard extensions entirely).
/// It's a thin UI: a "Dictate" button that launches the main app, and an
/// "Insert" row that appears once the main app has dropped a finished
/// transcription into the shared App Group container.
final class KeyboardViewController: UIInputViewController {

    private var hostingController: UIHostingController<KeyboardView>?
    // Bumped from 216 to fit the new manual-fallback caption under the Dictate
    // button without crowding the pending-result row when both show at once.
    private static let preferredHeight: CGFloat = 240

    override func viewDidLoad() {
        super.viewDidLoad()
        setupHostedView()
        setupNextKeyboardButton()

        let heightConstraint = view.heightAnchor.constraint(equalToConstant: Self.preferredHeight)
        heightConstraint.priority = .defaultHigh
        view.addConstraint(heightConstraint)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refresh()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        // Called on selection/context changes too - a reasonable proxy for
        // "the keyboard is visible again", e.g. after switching back from the
        // main app, so the pending-insert row shows up without extra plumbing.
        refresh()
    }

    private func setupHostedView() {
        let hosting = UIHostingController(rootView: makeView())
        hostingController = hosting

        addChild(hosting)
        view.addSubview(hosting.view)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -36),
        ])
        hosting.didMove(toParent: self)
    }

    /// Apple requires every custom keyboard to offer a way to switch keyboards.
    /// `handleInputModeList(from:with:)` (inherited from UIInputViewController)
    /// handles both a tap (advance to next keyboard) and a long-press (show the
    /// keyboard picker) - wiring a plain UIButton to it via `.allTouchEvents` is
    /// Apple's own documented pattern for this.
    private func setupNextKeyboardButton() {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "globe"), for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
        view.addSubview(button)
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            button.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -6),
            button.widthAnchor.constraint(equalToConstant: 32),
            button.heightAnchor.constraint(equalToConstant: 32),
        ])
    }

    private func refresh() {
        hostingController?.rootView = makeView()
    }

    // Opening the main app is now handled inside KeyboardView itself via
    // SwiftUI's `\.openURL` environment action - see the comment on
    // `dictateButton` there for why (two UIKit-level attempts here, confirmed
    // on-device, both silently did nothing).
    private func makeView() -> KeyboardView {
        KeyboardView(
            hasFullAccess: hasFullAccess,
            pending: DictationHandoff.pending(),
            onInsert: { [weak self] text in self?.insert(text) }
        )
    }

    private func insert(_ text: String) {
        textDocumentProxy.insertText(text)
        DictationHandoff.clearPending()
        refresh()
    }
}
