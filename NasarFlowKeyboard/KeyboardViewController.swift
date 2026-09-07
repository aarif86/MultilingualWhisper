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
    private static let preferredHeight: CGFloat = 216

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

    private func makeView() -> KeyboardView {
        KeyboardView(
            hasFullAccess: hasFullAccess,
            pending: DictationHandoff.pending(),
            onDictate: { [weak self] in self?.openMainAppToDictate() },
            onInsert: { [weak self] text in self?.insert(text) }
        )
    }

    private func openMainAppToDictate() {
        guard hasFullAccess else {
            DebugLogger.shared.log("Dictate tapped without full access - ignoring", category: "keyboard")
            return
        }
        DebugLogger.shared.log("Dictate tapped, opening \(DictationHandoff.launchURL)", category: "keyboard")
        openURLViaResponderChain(DictationHandoff.launchURL)
    }

    /// `UIApplication.shared.open` is unavailable to app extension targets at
    /// compile time, and `extensionContext.open(_:completionHandler:)` -
    /// despite compiling and running with no error - is documented as being
    /// for Today widgets specifically. Using it from a keyboard extension is
    /// unsupported and, confirmed on a real device, does not actually launch
    /// the containing app. The long-standing technique that actually works
    /// (used by essentially every shipping third-party keyboard that needs
    /// this) is to walk the responder chain until something in it responds to
    /// `openURL:`, then invoke it dynamically via `perform(_:with:)` - a
    /// runtime call the compiler can't flag as extension-unavailable, unlike
    /// a direct `UIApplication.shared.open` call or even `#selector(...)`.
    private func openURLViaResponderChain(_ url: URL) {
        let openURLSelector = NSSelectorFromString("openURL:")
        var responder: UIResponder? = self
        while let current = responder {
            if current.responds(to: openURLSelector) {
                DebugLogger.shared.log("found responder \(type(of: current)) for openURL:", category: "keyboard")
                current.perform(openURLSelector, with: url)
                return
            }
            responder = current.next
        }
        DebugLogger.shared.log("no responder in the chain responds to openURL: - hand-off failed", category: "keyboard")
    }

    private func insert(_ text: String) {
        textDocumentProxy.insertText(text)
        DictationHandoff.clearPending()
        refresh()
    }
}
