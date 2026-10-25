import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    // ⌃⌥⌘ plus a key: unused by macOS and by most apps.
    static let nextWallpaper = Self("nextWallpaper", initial: .init(.rightArrow, modifiers: [.control, .option, .command]))
    static let previousWallpaper = Self("previousWallpaper", initial: .init(.leftArrow, modifiers: [.control, .option, .command]))
    static let togglePause = Self("togglePause", initial: .init(.p, modifiers: [.control, .option, .command]))
}

/// Global keyboard shortcuts. They use Carbon hot keys through the
/// KeyboardShortcuts package, so they need no Accessibility permission.
@MainActor
enum Shortcuts {
    static let all: [(name: KeyboardShortcuts.Name, title: String)] = [
        (.nextWallpaper, "Next wallpaper"),
        (.previousWallpaper, "Previous wallpaper"),
        (.togglePause, "Pause or play"),
    ]

    static func register(for model: AppModel) {
        KeyboardShortcuts.onKeyUp(for: .nextWallpaper) { [weak model] in model?.next() }
        KeyboardShortcuts.onKeyUp(for: .previousWallpaper) { [weak model] in model?.previous() }
        KeyboardShortcuts.onKeyUp(for: .togglePause) { [weak model] in model?.togglePause() }
    }

    static func restoreDefaults() {
        KeyboardShortcuts.reset(all.map(\.name))
    }
}
