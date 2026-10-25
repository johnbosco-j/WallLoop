import AppKit
import AVFoundation
import os

/// Owns one wallpaper window per display and the players feeding them.
@MainActor
final class WallpaperEngine: NSObject {
    /// Called after displays are connected, disconnected or rearranged.
    var onScreensChanged: (() -> Void)?
    /// Called when the desktop becomes hidden (`false`) behind full-screen apps
    /// or windows on every display, or visible again (`true`).
    var onVisibilityChange: ((Bool) -> Void)?

    var fitMode: FitMode {
        didSet { windows.values.forEach { $0.fitMode = fitMode } }
    }

    private(set) var isPaused = false
    /// Whether any part of any wallpaper window can be seen.
    private(set) var isAnyWindowVisible = true
    /// Which video each display is showing.
    private(set) var assignment: [CGDirectDisplayID: URL] = [:]

    private var windows: [CGDirectDisplayID: WallpaperWindow] = [:]
    private var channels: [URL: PlaybackChannel] = [:]
    private var visibilityCheck: Task<Void, Never>?
    private let log = Logger(subsystem: "com.johnbosco.wallloop", category: "engine")

    init(fitMode: FitMode) {
        self.fitMode = fitMode
        super.init()
        syncWindows()

        NotificationCenter.default.addObserver(
            self, selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(activeSpaceChanged),
            name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(occlusionChanged(_:)),
            name: NSWindow.didChangeOcclusionStateNotification, object: nil)
    }

    /// Shows `selection` across the displays: video *i* on display *i*, wrapping
    /// around when there are more displays than videos. Channels whose video
    /// stays on screen keep playing without a restart.
    func show(_ selection: [URL]) {
        guard !selection.isEmpty else { return }
        var newAssignment: [CGDirectDisplayID: URL] = [:]
        for (i, screen) in NSScreen.screens.enumerated() {
            guard let id = screen.displayID else { continue }
            newAssignment[id] = selection[i % selection.count]
        }

        var newChannels: [URL: PlaybackChannel] = [:]
        for url in Set(newAssignment.values) {
            newChannels[url] = channels[url] ?? PlaybackChannel(url: url)
        }
        for (url, channel) in channels where newChannels[url] == nil {
            channel.stop()
        }
        channels = newChannels
        assignment = newAssignment

        for (id, url) in newAssignment {
            windows[id]?.player = channels[url]?.player
        }
        channels.values.forEach { isPaused ? $0.pause() : $0.play() }
        log.info("Showing \(selection.map(\.lastPathComponent), privacy: .public) on \(newAssignment.count) display(s)")
    }

    func setPaused(_ paused: Bool) {
        isPaused = paused
        channels.values.forEach { paused ? $0.pause() : $0.play() }
    }

    /// Creates, moves or removes windows so each connected display has exactly one.
    private func syncWindows() {
        let screens = NSScreen.screens.compactMap { screen in screen.displayID.map { ($0, screen) } }
        let connected = Set(screens.map(\.0))

        for (id, window) in windows where !connected.contains(id) {
            window.orderOut(nil)
            windows[id] = nil
        }
        for (id, screen) in screens {
            if let window = windows[id] {
                window.place(on: screen)
            } else {
                let window = WallpaperWindow(screen: screen)
                window.fitMode = fitMode
                window.orderFront(nil)
                windows[id] = window
            }
        }
        scheduleVisibilityCheck()
    }

    @objc private func screenParametersChanged() {
        log.info("Display configuration changed: \(NSScreen.screens.count) display(s)")
        syncWindows()
        onScreensChanged?()
    }

    @objc private func occlusionChanged(_ notification: Notification) {
        guard let window = notification.object as? WallpaperWindow,
              windows.values.contains(where: { $0 === window }) else { return }
        scheduleVisibilityCheck()
    }

    /// Occlusion flickers while switching Spaces, so wait for it to settle.
    private func scheduleVisibilityCheck() {
        visibilityCheck?.cancel()
        visibilityCheck = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            self?.updateVisibility()
        }
    }

    private func updateVisibility() {
        let visible = windows.isEmpty || windows.values.contains { $0.occlusionState.contains(.visible) }
        guard visible != isAnyWindowVisible else { return }
        isAnyWindowVisible = visible
        log.info("Desktop \(visible ? "visible" : "covered", privacy: .public)")
        onVisibilityChange?(visible)
    }

    @objc private func activeSpaceChanged() {
        // The windows join every Space, but make sure none got left behind.
        windows.values.forEach { $0.orderFront(nil) }
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}
