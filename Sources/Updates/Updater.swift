import AppKit
import Observation
import Sparkle

/// Sparkle auto-updates. One shared instance, started by the app delegate.
///
/// The updater only starts once a real appcast URL and public key are set in
/// `Config/Shared.xcconfig`, so development builds never touch the network.
@MainActor
@Observable
final class Updater {
    static let shared = Updater()

    /// False while `APPCAST_URL` / `SPARKLE_PUBLIC_KEY` are still placeholders.
    let isConfigured: Bool
    private(set) var canCheckForUpdates = false

    var automaticallyChecksForUpdates: Bool {
        get {
            access(keyPath: \.automaticallyChecksForUpdates)
            return controller?.updater.automaticallyChecksForUpdates ?? false
        }
        set {
            withMutation(keyPath: \.automaticallyChecksForUpdates) {
                controller?.updater.automaticallyChecksForUpdates = newValue
            }
        }
    }

    @ObservationIgnored private var controller: SPUStandardUpdaterController?
    @ObservationIgnored private var canCheckObservation: NSKeyValueObservation?

    private init() {
        let info = Bundle.main.infoDictionary
        let feed = info?["SUFeedURL"] as? String ?? ""
        let key = info?["SUPublicEDKey"] as? String ?? ""
        isConfigured = URL(string: feed)?.host.map { $0 != "example.com" } == true
            && !key.isEmpty && !key.hasPrefix("REPLACE")
    }

    func start() {
        guard isConfigured, controller == nil else { return }
        let controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil,
                                                      userDriverDelegate: nil)
        canCheckObservation = controller.updater.observe(\.canCheckForUpdates, options: [.initial, .new]) {
            [weak self] updater, _ in
            // Sparkle changes this property on the main thread.
            MainActor.assumeIsolated { self?.canCheckForUpdates = updater.canCheckForUpdates }
        }
        self.controller = controller
    }

    func checkForUpdates() {
        // A menu bar app isn't active by default; bring Sparkle's window to the front.
        NSApp.activate()
        controller?.checkForUpdates(nil)
    }
}
