import AppKit

/// Entry point. WallLoop is a menu-bar-only app (`LSUIElement`), so it runs on
/// AppKit directly and hosts SwiftUI views where they fit.
@main
@MainActor
enum WallLoopMain {
    // NSApplication holds its delegate weakly, so keep it alive here.
    static let delegate = AppDelegate()

    static func main() {
        let app = NSApplication.shared
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
