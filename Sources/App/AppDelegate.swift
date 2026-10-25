import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = SettingsStore()
    private var menuBar: MenuBarController?
    private lazy var settingsWindow = SettingsWindowController(settings: settings)

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBar = MenuBarController(settings: settings) { [weak self] pane in
            self?.settingsWindow.show(pane)
        }
    }

    // Opening the app again from Finder or Spotlight while it runs shows Settings,
    // since a menu bar app has no other window to bring forward.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        settingsWindow.show()
        return true
    }
}
