import SwiftUI
import UIKit

/// Custom keyboard extension entry point. This deliberately does none of the
/// actual recording/transcription work itself - see DictationHandoff.swift for
/// why (Apple blocks microphone access from keyboard extensions entirely).
///
/// Two ways this keyboard gets text typed for it, mirroring Wispr Flow's own
/// flow: (1) no Flow session active - a "Start Flow" button hands off to the
/// main app once to activate one (FlowSessionEngine keeps its audio engine
/// running continuously in the background afterwards - see that type's doc
/// comment for why that's necessary, not just nice-to-have), or (2) a session
/// is active - this keyboard's own mic button posts Darwin notifications
/// (start/stop) that the backgrounded main app acts on directly, no further
/// app-switching needed per utterance. Either way, results still arrive via
/// the same DictationHandoff App Group hand-off as before.
final class KeyboardViewController: UIInputViewController {

    /// Local-only states layered on top of the shared FlowSessionState -
    /// "the app hasn't confirmed yet" and "waiting on a transcription result"
    /// aren't worth persisting across processes, they only ever matter to
    /// this one keyboard instance's UI.
    private enum FlowPhase: Equatable {
        case idle
        case awaitingStart
        case awaitingResult
        case failed
    }

    private var hostingController: UIHostingController<KeyboardView>?
    // What insert() last typed, so a bad dictation ("that's not what I said")
    // can be removed with one tap without ever leaving this keyboard. Cleared
    // once used; a stale value just means the undo row shows one insert too
    // long, never a wrong deletion, since undo always deletes exactly this
    // many characters regardless of what's shown.
    private var lastInsertedText: String?
    private var flowPhase: FlowPhase = .idle
    private var tickTimer: Timer?
    private var phaseTimeoutTimer: Timer?
    private var stateChangedObserver: DarwinNotification.Observer?
    // Bumped from 216 to fit the manual-fallback caption / listening button
    // without crowding the pending-result row when both show at once.
    private static let preferredHeight: CGFloat = 240

    override func viewDidLoad() {
        super.viewDidLoad()
        autoInsertPendingResult()
        setupHostedView()
        setupNextKeyboardButton()

        let heightConstraint = view.heightAnchor.constraint(equalToConstant: Self.preferredHeight)
        heightConstraint.priority = .defaultHigh
        view.addConstraint(heightConstraint)

        // The app posts this every time isActive/isRecording/a result
        // changes, so this keyboard reflects a Flow session's state
        // immediately instead of only on the next incidental
        // viewWillAppear/textDidChange.
        stateChangedObserver = DarwinNotification.observe(FlowSessionState.stateChanged) { [weak self] in
            DispatchQueue.main.async { self?.handleStateChanged() }
        }
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
        autoInsertPendingResult()
        hostingController?.rootView = makeView()
    }

    private func makeView() -> KeyboardView {
        KeyboardView(
            hasFullAccess: hasFullAccess,
            lastInsertedText: lastInsertedText,
            flowState: currentFlowUIState(),
            onStartListening: { [weak self] in self?.startListening() },
            onStopListening: { [weak self] in self?.stopListening() },
            onUndoInsert: { [weak self] in self?.undoLastInsert() }
        )
    }

    /// A finished dictation used to sit as a "Tap to insert" row until the
    /// user tapped it - an extra step that only ever had one right answer
    /// (insert it), since a wrong result already has its own fix: the
    /// undo row below inserts-then-lets-you-remove instead of asking for
    /// confirmation before typing anything at all. Draining pending here
    /// covers every path that can make a fresh result relevant (initial
    /// load, tick, Darwin notification, viewWillAppear/textDidChange) since
    /// they all funnel through refresh() or this same call in viewDidLoad.
    private func autoInsertPendingResult() {
        guard let pending = DictationHandoff.pending() else { return }
        insert(pending.text)
    }

    // MARK: - Flow session UI state

    /// Shared FlowSessionState.isRecording (confirmed by the app) always
    /// wins when true; the local phase only fills in the two gaps shared
    /// state doesn't cover - "just asked, not confirmed yet" and "asked it
    /// to stop, waiting on a transcription result".
    private func currentFlowUIState() -> KeyboardView.FlowUIState {
        guard FlowSessionState.isActive else { return .inactive }
        if FlowSessionState.isRecording, let startedAt = FlowSessionState.utteranceStartedAt {
            return .listening(elapsed: Date().timeIntervalSince(startedAt))
        }
        switch flowPhase {
        case .awaitingStart: return .listening(elapsed: 0)
        case .awaitingResult: return .transcribing
        case .failed: return .failed
        case .idle: return .readyToListen
        }
    }

    /// Checks whether shared state has moved on without us hearing about it
    /// via a pushed stateChanged notification, and self-corrects if so. Called
    /// both from that push AND from the tick timer - the tick is what makes
    /// this robust even if a particular notification never actually arrives
    /// at this process (unconfirmed either way for the app-to-keyboard
    /// direction specifically, as opposed to keyboard-to-app, which is
    /// confirmed working).
    private func reconcilePhase() {
        if FlowSessionState.isRecording {
            // Confirmed - stop locally overriding, currentFlowUIState() now
            // reads the real elapsed time straight from shared state.
            flowPhase = .idle
            phaseTimeoutTimer?.invalidate()
        } else if flowPhase == .awaitingResult {
            if DictationHandoff.pending() != nil {
                flowPhase = .idle
                stopTicking()
                phaseTimeoutTimer?.invalidate()
            } else if FlowSessionState.lastFailureAt != nil {
                DebugLogger.shared.log("Flow: transcription failure signaled by app", category: "keyboard")
                flowPhase = .failed
                stopTicking()
                phaseTimeoutTimer?.invalidate()
            }
        }
    }

    private func handleStateChanged() {
        reconcilePhase()
        refresh()
    }

    private func startListening() {
        DebugLogger.shared.log("Flow: startListening tapped", category: "keyboard")
        FlowSessionState.lastFailureAt = nil
        flowPhase = .awaitingStart
        startTicking()
        DarwinNotification.post(FlowSessionState.startUtterance)
        // If the app doesn't confirm within a couple of seconds, it's most
        // likely not actually alive in the background any more (the one
        // genuinely unverified assumption this whole feature rests on - see
        // FlowSessionEngine) - fail back to "ready" rather than sitting on a
        // fake "Listening" state forever with nothing actually being captured.
        schedulePhaseTimeout(seconds: 2.5) { [weak self] in
            guard let self, self.flowPhase == .awaitingStart else { return }
            DebugLogger.shared.log("Flow: startUtterance not confirmed within timeout", category: "keyboard")
            self.flowPhase = .idle
            self.stopTicking()
            self.refresh()
        }
        refresh()
    }

    private func stopListening() {
        DebugLogger.shared.log("Flow: stopListening tapped", category: "keyboard")
        flowPhase = .awaitingResult
        // Kept running (not stopped) through the wait for a result - this is
        // what lets reconcilePhase() self-heal via polling even if the app's
        // stateChanged push never reaches this process, rather than betting
        // everything on that one notification arriving.
        startTicking()
        DarwinNotification.post(FlowSessionState.stopUtterance)
        schedulePhaseTimeout(seconds: 20) { [weak self] in
            guard let self, self.flowPhase == .awaitingResult else { return }
            DebugLogger.shared.log("Flow: no transcription result within timeout after stop", category: "keyboard")
            self.flowPhase = .failed
            self.stopTicking()
            self.refresh()
        }
        refresh()
    }

    private func startTicking() {
        tickTimer?.invalidate()
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.reconcilePhase()
            self?.refresh()
        }
    }

    private func stopTicking() {
        tickTimer?.invalidate()
        tickTimer = nil
    }

    private func schedulePhaseTimeout(seconds: TimeInterval, _ action: @escaping () -> Void) {
        phaseTimeoutTimer?.invalidate()
        phaseTimeoutTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { _ in
            action()
        }
    }

    // MARK: - Insert / undo

    // Deliberately does NOT call advanceToNextInputMode() here - an earlier
    // version did, on the theory that it'd help editing, but on-device that
    // just meant switching back to Nasar Flow again before every next
    // dictation. Staying put plus a one-tap undo (below) covers "that's not
    // what I said" without penalizing dictating several messages in a row.
    private func insert(_ text: String) {
        // Spacing and capitalisation relative to the cursor - see InsertionPolicy.
        // The undo below removes exactly plan.text, spaces included.
        let plan = InsertionPolicy.plan(
            inserting: text,
            before: textDocumentProxy.documentContextBeforeInput,
            after: textDocumentProxy.documentContextAfterInput,
            selected: textDocumentProxy.selectedText
        )
        if !plan.text.isEmpty {
            textDocumentProxy.insertText(plan.text)
            lastInsertedText = plan.text
        }
        DictationHandoff.clearPending()
        refresh()
    }

    // textDocumentProxy has no "undo" of its own - deleteBackward() one
    // character at a time, exactly as this keyboard's own backspace key
    // would, is the standard way any keyboard extension removes text it
    // just inserted.
    private func undoLastInsert() {
        guard let text = lastInsertedText else { return }
        text.forEach { _ in textDocumentProxy.deleteBackward() }
        lastInsertedText = nil
        refresh()
    }
}
