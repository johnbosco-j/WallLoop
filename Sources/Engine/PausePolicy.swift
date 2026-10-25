import Foundation
import os

/// Why WallLoop paused playback on its own.
enum PauseReason: Equatable, Sendable {
    case asleep, userSwitched, locked, lowPowerMode, onBattery, covered

    var title: String {
        switch self {
        case .asleep: "Display Asleep"
        case .userSwitched: "Another User Is Active"
        case .locked: "Screen Locked"
        case .lowPowerMode: "Low Power Mode"
        case .onBattery: "On Battery Power"
        case .covered: "Desktop Covered"
        }
    }
}

/// What the Mac is doing right now.
struct PauseConditions: Equatable, Sendable {
    var isAsleep = false
    var isUserSwitchedOut = false
    var isLocked = false
    var isLowPowerModeEnabled = false
    var isOnBattery = false
    var isCovered = false
}

/// The user's pause toggles from Settings.
struct PauseRules: Equatable, Sendable {
    var pauseInLowPowerMode = true
    var pauseOnBattery = true
    var pauseWhenCovered = true
}

extension PauseReason {
    /// The reason to pause, if any. Sleep, user switching and the lock screen
    /// always pause; the rest follow the user's settings. When several apply,
    /// the first in this order is reported.
    static func evaluate(_ conditions: PauseConditions, rules: PauseRules) -> PauseReason? {
        if conditions.isAsleep { return .asleep }
        if conditions.isUserSwitchedOut { return .userSwitched }
        if conditions.isLocked { return .locked }
        if rules.pauseInLowPowerMode, conditions.isLowPowerModeEnabled { return .lowPowerMode }
        if rules.pauseOnBattery, conditions.isOnBattery { return .onBattery }
        if rules.pauseWhenCovered, conditions.isCovered { return .covered }
        return nil
    }
}

/// Combines power, session and desktop visibility with the user's settings
/// into a single automatic pause reason.
@MainActor
final class PausePolicy {
    var onChange: ((PauseReason?) -> Void)?
    private(set) var reason: PauseReason?

    private let settings: SettingsStore
    private let power = PowerMonitor()
    private let session = SessionMonitor()
    private var isCovered = false
    private let log = Logger(subsystem: "com.johnbosco.wallloop", category: "pause")

    init(settings: SettingsStore) {
        self.settings = settings
        reason = PauseReason.evaluate(conditions, rules: rules)

        power.onChange = { [weak self] in self?.evaluate() }
        session.onChange = { [weak self] in self?.evaluate() }
        observe({ [settings.pauseOnBattery, settings.pauseInLowPowerMode, settings.pauseWhenCovered] }) { [weak self] _ in
            self?.evaluate()
        }
    }

    /// Reported by the engine when no wallpaper window is visible any more, or one is again.
    func setCovered(_ covered: Bool) {
        guard covered != isCovered else { return }
        isCovered = covered
        evaluate()
    }

    private var conditions: PauseConditions {
        PauseConditions(
            isAsleep: session.areDisplaysAsleep || session.isSystemAsleep,
            isUserSwitchedOut: session.isSessionInactive,
            isLocked: session.isLocked,
            isLowPowerModeEnabled: power.isLowPowerModeEnabled,
            isOnBattery: power.isOnBattery,
            isCovered: isCovered)
    }

    private var rules: PauseRules {
        PauseRules(pauseInLowPowerMode: settings.pauseInLowPowerMode,
                   pauseOnBattery: settings.pauseOnBattery,
                   pauseWhenCovered: settings.pauseWhenCovered)
    }

    private func evaluate() {
        let newReason = PauseReason.evaluate(conditions, rules: rules)
        guard newReason != reason else { return }
        reason = newReason
        log.info("Automatic pause: \(newReason?.title ?? "none", privacy: .public)")
        onChange?(newReason)
    }
}
