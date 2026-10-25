import AppKit
import SwiftUI

enum SettingsPane: String, CaseIterable, Identifiable {
    case library, general, about

    var id: Self { self }

    var title: String {
        switch self {
        case .library: "Library"
        case .general: "General"
        case .about: "About"
        }
    }

    var symbol: String {
        switch self {
        case .library: "film.stack"
        case .general: "gearshape"
        case .about: "info.circle"
        }
    }
}

@MainActor
@Observable
final class SettingsNavigation {
    var selection: SettingsPane? = .library
}

/// Hosts the SwiftUI settings in a plain NSWindow. A SwiftUI `Settings` scene is
/// hard to open reliably from an NSMenu in an accessory app, and owning the
/// window lets it look like a regular Mac app window.
@MainActor
final class SettingsWindowController {
    private let settings: SettingsStore
    private let navigation = SettingsNavigation()
    private var window: NSWindow?

    init(settings: SettingsStore) {
        self.settings = settings
    }

    func show(_ pane: SettingsPane? = nil) {
        if let pane { navigation.selection = pane }
        let window = window ?? makeWindow()
        self.window = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let host = NSHostingController(rootView: SettingsView(settings: settings, navigation: navigation))
        host.sceneBridgingOptions = [.toolbars, .title]
        host.sizingOptions = [.minSize]

        let window = NSWindow(contentViewController: host)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.toolbarStyle = .unified
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 820, height: 560))
        window.center()
        window.setFrameAutosaveName("SettingsWindow")
        return window
    }
}
