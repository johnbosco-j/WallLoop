import Testing
@testable import WallLoop

struct PausePolicyTests {
    private let allOn = PauseRules()
    private let allOff = PauseRules(pauseInLowPowerMode: false, pauseOnBattery: false, pauseWhenCovered: false)

    @Test func playsWhenNothingApplies() {
        #expect(PauseReason.evaluate(PauseConditions(), rules: allOn) == nil)
    }

    @Test func eachConditionPausesWhenItsToggleIsOn() {
        #expect(PauseReason.evaluate(PauseConditions(isOnBattery: true), rules: allOn) == .onBattery)
        #expect(PauseReason.evaluate(PauseConditions(isLowPowerModeEnabled: true), rules: allOn) == .lowPowerMode)
        #expect(PauseReason.evaluate(PauseConditions(isCovered: true), rules: allOn) == .covered)
    }

    @Test func togglesOffIgnoreTheirConditions() {
        let conditions = PauseConditions(isLowPowerModeEnabled: true, isOnBattery: true, isCovered: true)
        #expect(PauseReason.evaluate(conditions, rules: allOff) == nil)
    }

    @Test func lockSleepAndUserSwitchAlwaysPause() {
        #expect(PauseReason.evaluate(PauseConditions(isLocked: true), rules: allOff) == .locked)
        #expect(PauseReason.evaluate(PauseConditions(isAsleep: true), rules: allOff) == .asleep)
        #expect(PauseReason.evaluate(PauseConditions(isUserSwitchedOut: true), rules: allOff) == .userSwitched)
    }

    @Test func lockedAndAsleepBeatBattery() {
        #expect(PauseReason.evaluate(PauseConditions(isLocked: true, isOnBattery: true), rules: allOn) == .locked)
        #expect(PauseReason.evaluate(PauseConditions(isAsleep: true, isLocked: true, isOnBattery: true),
                                     rules: allOn) == .asleep)
    }

    @Test func lowPowerModeBeatsBatteryAndBatteryBeatsCovered() {
        let both = PauseConditions(isLowPowerModeEnabled: true, isOnBattery: true, isCovered: true)
        #expect(PauseReason.evaluate(both, rules: allOn) == .lowPowerMode)
        #expect(PauseReason.evaluate(PauseConditions(isOnBattery: true, isCovered: true), rules: allOn) == .onBattery)
    }

    @Test func disabledHigherRuleFallsThroughToNextOne() {
        var rules = allOn
        rules.pauseOnBattery = false
        #expect(PauseReason.evaluate(PauseConditions(isOnBattery: true, isCovered: true), rules: rules) == .covered)
    }
}
