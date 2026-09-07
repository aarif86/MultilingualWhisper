import Foundation

/// Cross-process signaling between the main app and the keyboard extension -
/// each is a genuinely separate OS process with its own sandbox, so ordinary
/// Swift callbacks/closures can't cross that boundary. Darwin notifications
/// are the standard, documented mechanism apps and their extensions use to
/// poke each other (as opposed to App Group UserDefaults/files, which are for
/// sharing *data*, not for *waking up* the other process the instant
/// something happens). System-wide by name, so names are namespaced by
/// bundle ID below to avoid colliding with anything else on the device.
enum DarwinNotification {
    static func post(_ name: String) {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(name as CFString),
            nil, nil, true
        )
    }

    /// Keep the returned `Observer` alive for as long as you want to keep
    /// listening - it removes itself in `deinit`, so letting it go silently
    /// stops delivery instead of crashing (no separate "remove" call needed).
    static func observe(_ name: String, _ handler: @escaping () -> Void) -> Observer {
        Observer(name: name, handler: handler)
    }

    final class Observer {
        private let handler: () -> Void

        fileprivate init(name: String, handler: @escaping () -> Void) {
            self.handler = handler
            let observer = Unmanaged.passUnretained(self).toOpaque()
            CFNotificationCenterAddObserver(
                CFNotificationCenterGetDarwinNotifyCenter(),
                observer,
                { _, observerPointer, _, _, _ in
                    guard let observerPointer else { return }
                    Unmanaged<Observer>.fromOpaque(observerPointer).takeUnretainedValue().handler()
                },
                name as CFString,
                nil,
                .deliverImmediately
            )
        }

        deinit {
            CFNotificationCenterRemoveObserver(
                CFNotificationCenterGetDarwinNotifyCenter(),
                Unmanaged.passUnretained(self).toOpaque(),
                nil, nil
            )
        }
    }
}
