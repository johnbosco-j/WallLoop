import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: AppModel?
    private var menuBar: MenuBarController?
    private var settingsWindow: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Unit tests run inside the app; don't take over the desktop while they do.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }

        let model = AppModel(settings: SettingsStore())
        let settingsWindow = SettingsWindowController(model: model)
        menuBar = MenuBarController(model: model) { pane in settingsWindow.show(pane) }
        self.model = model
        self.settingsWindow = settingsWindow
        model.start()
    }

    // Opening the app again from Finder or Spotlight while it runs shows Settings,
    // since a menu bar app has no other window to bring forward.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        settingsWindow?.show()
        return true
    }
}
