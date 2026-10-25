import Foundation
import Observation

/// User preferences, persisted in `UserDefaults`. Views bind to it directly;
/// the engine and scheduler observe it.
@MainActor
@Observable
final class SettingsStore {
    enum Key {
        static let shuffleInterval = "shuffleInterval"
        static let playbackOrder = "playbackOrder"
        static let fitMode = "fitMode"
        static let displayMode = "displayMode"
        static let pauseOnBattery = "pauseOnBattery"
        static let pauseInLowPowerMode = "pauseInLowPowerMode"
        static let pauseWhenCovered = "pauseWhenCovered"
        static let favorites = "favorites"
        static let favoritesOnly = "favoritesOnly"
    }

    @ObservationIgnored private let defaults: UserDefaults

    var shuffleInterval: ShuffleInterval {
        didSet { defaults.set(shuffleInterval.rawValue, forKey: Key.shuffleInterval) }
    }
    var playbackOrder: PlaybackOrder {
        didSet { defaults.set(playbackOrder.rawValue, forKey: Key.playbackOrder) }
    }
    var fitMode: FitMode {
        didSet { defaults.set(fitMode.rawValue, forKey: Key.fitMode) }
    }
    var displayMode: DisplayMode {
        didSet { defaults.set(displayMode.rawValue, forKey: Key.displayMode) }
    }
    var pauseOnBattery: Bool {
        didSet { defaults.set(pauseOnBattery, forKey: Key.pauseOnBattery) }
    }
    var pauseInLowPowerMode: Bool {
        didSet { defaults.set(pauseInLowPowerMode, forKey: Key.pauseInLowPowerMode) }
    }
    /// Pause while a full-screen app or windows cover the whole desktop.
    var pauseWhenCovered: Bool {
        didSet { defaults.set(pauseWhenCovered, forKey: Key.pauseWhenCovered) }
    }

    /// Paths of favorite videos.
    var favorites: Set<String> {
        didSet { defaults.set(favorites.sorted(), forKey: Key.favorites) }
    }
    /// Shuffle only among favorites (when at least one is in the library).
    var favoritesOnly: Bool {
        didSet { defaults.set(favoritesOnly, forKey: Key.favoritesOnly) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        shuffleInterval = Self.value(defaults, Key.shuffleInterval, default: .oneHour)
        playbackOrder = Self.value(defaults, Key.playbackOrder, default: .shuffle)
        fitMode = Self.value(defaults, Key.fitMode, default: .fill)
        displayMode = Self.value(defaults, Key.displayMode, default: .sameOnAll)
        pauseOnBattery = defaults.object(forKey: Key.pauseOnBattery) as? Bool ?? true
        pauseInLowPowerMode = defaults.object(forKey: Key.pauseInLowPowerMode) as? Bool ?? true
        pauseWhenCovered = defaults.object(forKey: Key.pauseWhenCovered) as? Bool ?? true
        favorites = Set(defaults.stringArray(forKey: Key.favorites) ?? [])
        favoritesOnly = defaults.bool(forKey: Key.favoritesOnly)
    }

    private nonisolated static func value<T: RawRepresentable>(
        _ defaults: UserDefaults, _ key: String, default fallback: T
    ) -> T where T.RawValue == String {
        guard let raw = defaults.string(forKey: key) else { return fallback }
        return T(rawValue: raw) ?? fallback
    }
}
