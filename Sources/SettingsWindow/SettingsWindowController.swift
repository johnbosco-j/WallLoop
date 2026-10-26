import AppKit
import SwiftUI

enum SettingsPane: String, CaseIterable, Identifiable {
    case library, general, shortcuts, about

    var id: Self { self }

    var title: String {
        switch self {
        case .library: "Library"
        case .general: "General"
        case .shortcuts: "Shortcuts"
        case .about: "About"
        }
    }

    var symbol: String {
        switch self {
        case .library: "square.grid.2x2"
        case .general: "slider.horizontal.3"
        case .shortcuts: "command"
        case .about: "info.circle"
        }
    }
}

/// The selected pane, remembered across launches.
@MainActor
@Observable
final class SettingsNavigation {
    private static let key = "settingsPane"

    var selection: SettingsPane? {
        didSet { UserDefaults.standard.set(selection?.rawValue, forKey: Self.key) }
    }

    init() {
        selection = UserDefaults.standard.string(forKey: Self.key).flatMap(SettingsPane.init(rawValue:)) ?? .library
    }
}

/// Hosts the SwiftUI settings in a plain NSWindow: always dark, with a transparent,
/// integrated title bar over Riven's studio background. A SwiftUI `Settings` scene is
/// hard to open reliably from an NSMenu in an accessory app.
@MainActor
final class SettingsWindowController {
    private let model: AppModel
    private let navigation = SettingsNavigation()
    private var window: NSWindow?

    init(model: AppModel) {
        self.model = model
    }

    func show(_ pane: SettingsPane? = nil) {
        if let pane { navigation.selection = pane }
        let window = window ?? makeWindow()
        self.window = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let host = NSHostingController(rootView: SettingsView(model: model, navigation: navigation))
        host.sceneBridgingOptions = []
        host.sizingOptions = [.minSize]

        let window = NSWindow(contentViewController: host)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.title = "WallLoop"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = NSColor(Theme.bg)
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 1080, height: 720))
        window.center()
        window.setFrameAutosaveName("RivenSettingsWindow")
        return window
    }
}
