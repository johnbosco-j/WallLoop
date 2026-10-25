import AppKit
import os

/// Tracks when nobody can see the desktop: the screen is locked, the displays
/// or the whole Mac are asleep, or another user is using the Mac.
@MainActor
final class SessionMonitor: NSObject {
    var onChange: (() -> Void)?

    private(set) var isLocked = SessionMonitor.readIsLocked()
    private(set) var areDisplaysAsleep = false
    private(set) var isSystemAsleep = false
    private(set) var isSessionInactive = false

    private let log = Logger(subsystem: "com.johnbosco.wallloop", category: "session")

    override init() {
        super.init()

        let distributed = DistributedNotificationCenter.default()
        distributed.addObserver(self, selector: #selector(screenLocked),
                                name: Notification.Name("com.apple.screenIsLocked"), object: nil)
        distributed.addObserver(self, selector: #selector(screenUnlocked),
                                name: Notification.Name("com.apple.screenIsUnlocked"), object: nil)

        let workspace = NSWorkspace.shared.notificationCenter
        let observations: [(Notification.Name, Selector)] = [
            (NSWorkspace.screensDidSleepNotification, #selector(displaysSlept)),
            (NSWorkspace.screensDidWakeNotification, #selector(displaysWoke)),
            (NSWorkspace.willSleepNotification, #selector(systemWillSleep)),
            (NSWorkspace.didWakeNotification, #selector(systemDidWake)),
            (NSWorkspace.sessionDidResignActiveNotification, #selector(sessionResigned)),
            (NSWorkspace.sessionDidBecomeActiveNotification, #selector(sessionBecameActive)),
        ]
        for (name, selector) in observations {
            workspace.addObserver(self, selector: selector, name: name, object: nil)
        }
    }

    @objc private func screenLocked() { set(\.isLocked, true) }
    @objc private func screenUnlocked() { set(\.isLocked, false) }
    @objc private func displaysSlept() { set(\.areDisplaysAsleep, true) }
    @objc private func displaysWoke() { set(\.areDisplaysAsleep, false) }
    @objc private func systemWillSleep() { set(\.isSystemAsleep, true) }
    @objc private func systemDidWake() { set(\.isSystemAsleep, false) }
    @objc private func sessionResigned() { set(\.isSessionInactive, true) }
    @objc private func sessionBecameActive() { set(\.isSessionInactive, false) }

    private func set(_ keyPath: ReferenceWritableKeyPath<SessionMonitor, Bool>, _ value: Bool) {
        guard self[keyPath: keyPath] != value else { return }
        self[keyPath: keyPath] = value
        log.info("Session changed: locked \(self.isLocked), displays asleep \(self.areDisplaysAsleep), system asleep \(self.isSystemAsleep), inactive \(self.isSessionInactive)")
        onChange?()
    }

    /// Whether the screen is already locked at launch, e.g. when launched at login
    /// behind the lock screen.
    private nonisolated static func readIsLocked() -> Bool {
        guard let session = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
        return session["CGSSessionScreenIsLocked"] as? Bool ?? false
    }
}
