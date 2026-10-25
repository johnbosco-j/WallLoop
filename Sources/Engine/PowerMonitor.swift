import Foundation
import IOKit.ps
import os

/// Tracks whether the Mac runs on battery and whether Low Power Mode is on.
///
/// Create one for the lifetime of the app: the IOKit callback holds an
/// unretained pointer to it.
@MainActor
final class PowerMonitor: NSObject {
    var onChange: (() -> Void)?

    private(set) var isOnBattery = PowerMonitor.readIsOnBattery()
    private(set) var isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled

    private var runLoopSource: CFRunLoopSource?
    private let log = Logger(subsystem: "com.johnbosco.wallloop", category: "power")

    override init() {
        super.init()

        // IOKit calls back on the run loop the source is added to: the main one.
        let context = Unmanaged.passUnretained(self).toOpaque()
        let callback: IOPowerSourceCallbackType = { context in
            guard let context else { return }
            let monitor = Unmanaged<PowerMonitor>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { monitor.update() }
        }
        if let source = IOPSNotificationCreateRunLoopSource(callback, context)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = source
        } else {
            log.error("Couldn't watch power source changes")
        }

        NotificationCenter.default.addObserver(
            self, selector: #selector(powerStateChanged),
            name: .NSProcessInfoPowerStateDidChange, object: nil)
    }

    // Posted on an arbitrary thread.
    @objc nonisolated private func powerStateChanged() {
        Task { @MainActor in self.update() }
    }

    private func update() {
        let onBattery = Self.readIsOnBattery()
        let lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        guard onBattery != isOnBattery || lowPower != isLowPowerModeEnabled else { return }
        isOnBattery = onBattery
        isLowPowerModeEnabled = lowPower
        log.info("Power changed: battery \(onBattery), Low Power Mode \(lowPower)")
        onChange?()
    }

    private nonisolated static func readIsOnBattery() -> Bool {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let type = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue()
        else { return false }
        return (type as String) == kIOPSBatteryPowerValue
    }
}
