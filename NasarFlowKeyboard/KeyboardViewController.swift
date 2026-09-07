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
    /// compile time. `extensionContext.open(_:completionHandler:)` - confirmed
    /// against Apple's own current documentation, not just old forum threads -
    /// explicitly lists only the Today widget and iMessage extension points as
    /// supporting it; keyboard extensions aren't on that list, and indeed it
    /// compiles, runs, and does nothing when tried from one.
    ///
    /// The long-documented community workaround is walking the responder chain
    /// for something that responds to `openURL:` and invoking it dynamically -
    /// a first attempt at that (plain `perform(_:with:)`, passing the Swift
    /// `URL` as-is) *also* did nothing on a real device, with no crash and no
    /// error. Two changes here versus that attempt: explicitly bridging to
    /// `NSURL` before crossing into a fully-dynamic Objective-C call (Swift's
    /// automatic NSURL bridging is reliable for statically-typed calls, less
    /// certain through a boxed `Any` parameter), and deferring the call by one
    /// run loop tick via `perform(_:with:afterDelay:)` instead of calling
    /// synchronously from inside the SwiftUI button action, since a few
    /// real-world reports of this exact technique note the synchronous form
    /// can be silently dropped mid-gesture-handling. If this *still* doesn't
    /// launch the app, check the debug log for whether "found responder" even
    /// appears - that tells us whether the chain-walk itself is the dead end,
    /// or whether openURL: is being reached but is a no-op for this extension
    /// point specifically (which would mean this whole approach is a dead end
    /// on current iOS, not just this specific call).
    private func openURLViaResponderChain(_ url: URL) {
        let openURLSelector = NSSelectorFromString("openURL:")
        var responder: UIResponder? = self
        while let current = responder {
            if current.responds(to: openURLSelector) {
                DebugLogger.shared.log("found responder \(type(of: current)) for openURL:, invoking", category: "keyboard")
                current.perform(openURLSelector, with: url as NSURL, afterDelay: 0)
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
