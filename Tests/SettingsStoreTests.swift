import Foundation
import Testing
@testable import WallLoop

@MainActor
struct SettingsStoreTests {
    private let suiteName = "WallLoopTests.\(UUID().uuidString)"
    private var defaults: UserDefaults { UserDefaults(suiteName: suiteName)! }

    @Test func defaultsOnFirstLaunch() {
        let store = SettingsStore(defaults: defaults)
        #expect(store.shuffleInterval == .oneHour)
        #expect(store.playbackOrder == .shuffle)
        #expect(store.fitMode == .fill)
        #expect(store.displayMode == .sameOnAll)
        #expect(store.pauseOnBattery)
        #expect(store.pauseInLowPowerMode)
        #expect(store.pauseWhenCovered)
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test func changesPersistAcrossLaunches() {
        let store = SettingsStore(defaults: defaults)
        store.shuffleInterval = .daily
        store.playbackOrder = .inOrder
        store.fitMode = .stretch
        store.displayMode = .perDisplay
        store.pauseOnBattery = false

        let reloaded = SettingsStore(defaults: defaults)
        #expect(reloaded.shuffleInterval == .daily)
        #expect(reloaded.playbackOrder == .inOrder)
        #expect(reloaded.fitMode == .stretch)
        #expect(reloaded.displayMode == .perDisplay)
        #expect(!reloaded.pauseOnBattery)
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test func unknownStoredValueFallsBackToDefault() {
        defaults.set("every-tuesday", forKey: SettingsStore.Key.shuffleInterval)
        #expect(SettingsStore(defaults: defaults).shuffleInterval == .oneHour)
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test func intervalDurations() {
        #expect(ShuffleInterval.fiveMinutes.seconds == 300)
        #expect(ShuffleInterval.daily.seconds == 86_400)
        #expect(ShuffleInterval.never.seconds == nil)
        #expect(ShuffleInterval.daily.phrase == "Every day")
        #expect(ShuffleInterval.fifteenMinutes.phrase == "Every 15 minutes")
    }
}
