import AppKit
import SwiftUI
import Testing
@testable import WallLoop

/// Renders the restyled UI to PNGs for visual review. Opt-in: runs only when
/// `WALLLOOP_RENDER_DIR` is set (pass `TEST_RUNNER_WALLLOOP_RENDER_DIR=<name>` to
/// `xcodebuild test`). The sandboxed test host writes to `<its tmp>/<name>`, i.e.
/// `~/Library/Containers/com.johnbosco.wallloop/Data/tmp/<name>`. Uses a stand-in
/// model, so no wallpaper windows open.
@MainActor
@Suite(.enabled(if: ProcessInfo.processInfo.environment["WALLLOOP_RENDER_DIR"] != nil))
struct UIRenderTests {
    private let directory = FileManager.default.temporaryDirectory
        .appending(path: ProcessInfo.processInfo.environment["WALLLOOP_RENDER_DIR"] ?? "render")

    @Test func renderSettingsPanes() async throws {
        Theme.registerFonts()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let model = try await PreviewModel(thumbnails: directory.appending(path: "thumbs"))

        for pane in SettingsPane.allCases {
            let view = SettingsContent(model: model, selection: .constant(pane))
            try await render(view, size: CGSize(width: 1080, height: 760), name: "settings-\(pane.rawValue)")
        }
        try await render(SettingsContent(model: model, selection: .constant(.library)),
                         size: CGSize(width: 980, height: 620), name: "settings-library-min")

        let onboarding = LibraryOnboarding(chooseFolder: {}, showDefaultFolder: {})
        try await render(onboarding, size: CGSize(width: 848, height: 760), name: "onboarding")

        let video = model.library.videos.first
        let thumbnail = if let video { await model.library.thumbnail(for: video) } else { NSImage?.none }
        let menuCard = NowPlayingView(videos: model.nowPlaying, isPaused: false, pauseReason: nil,
                                      meta: NowPlayingView.meta(interval: .oneHour, order: .shuffle, otherDisplays: 0),
                                      library: nil, initialThumbnail: thumbnail)
        try await render(menuCard.background(Color(white: 0.16)), size: CGSize(width: 280, height: 270), name: "menu-card")
        let pausedCard = NowPlayingView(videos: model.nowPlaying, isPaused: true, pauseReason: "On Battery Power",
                                        meta: NowPlayingView.meta(interval: .oneHour, order: .shuffle, otherDisplays: 1),
                                        library: nil, initialThumbnail: thumbnail)
        try await render(pausedCard.background(Color(white: 0.92)), size: CGSize(width: 280, height: 290),
                         name: "menu-card-paused-light-menu")

        try writeStatusIcons()
    }

    private func render(_ view: some View, size: CGSize, name: String) async throws {
        let root = view
            .frame(width: size.width, height: size.height)
            .environment(\.rivenStaticRender, true)
            .environment(\.colorScheme, .dark)
        // Two captures: ImageRenderer draws SwiftUI effects (shadows, translucency) faithfully
        // but not AppKit controls; cacheDisplay draws the controls but not the effects.
        let host = NSHostingView(rootView: root)
        host.frame = CGRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        // Let thumbnails load and SwiftUI settle.
        try await Task.sleep(for: .milliseconds(900))
        host.layoutSubtreeIfNeeded()
        if let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
            host.cacheDisplay(in: host.bounds, to: rep)
            try rep.representation(using: .png, properties: [:])?.write(to: directory.appending(path: "\(name)-controls.png"))
        }

        let renderer = ImageRenderer(content: root)
        renderer.scale = 2
        if let image = renderer.cgImage,
           let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) {
            try png.write(to: directory.appending(path: "\(name).png"))
        }
    }

    private func writeStatusIcons() throws {
        // 8× so the shapes are easy to inspect, on light and dark menu bars.
        let scale: CGFloat = 8
        let size = NSSize(width: 18 * scale * 2 + 24, height: 18 * scale * 2 + 24)
        let canvas = NSImage(size: size)
        canvas.lockFocus()
        for (row, background) in [NSColor(white: 0.95, alpha: 1), NSColor(white: 0.12, alpha: 1)].enumerated() {
            for (column, paused) in [false, true].enumerated() {
                let rect = NSRect(x: CGFloat(column) * (18 * scale + 24), y: CGFloat(row) * (18 * scale + 24),
                                  width: 18 * scale, height: 18 * scale)
                background.setFill()
                rect.fill()
                let icon = StatusIcon.image(paused: paused)
                let tinted = NSImage(size: rect.size, flipped: false) { r in
                    icon.draw(in: r)
                    (row == 0 ? NSColor.black : NSColor.white).set()
                    r.fill(using: .sourceAtop)
                    return true
                }
                tinted.draw(in: rect)
            }
        }
        canvas.unlockFocus()
        guard let tiff = canvas.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return }
        try png.write(to: directory.appending(path: "status-icons.png"))
    }
}

/// A stand-in for `AppModel` with the user's real library (read only) and sample state.
@MainActor
@Observable
private final class PreviewModel: PlaybackModel {
    let settings: SettingsStore
    let library: Library
    var nowPlaying: [URL] = []
    var isPaused = false
    var pauseReason: PauseReason?
    private var favorites: Set<URL> = []

    init(thumbnails: URL) async throws {
        let suite = "WallLoopRender.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        settings = SettingsStore(defaults: defaults)
        library = Library(defaults: defaults, thumbnails: ThumbnailCache(directory: thumbnails), watchesFolders: false)
        await library.waitForScan()
        nowPlaying = Array(library.videos.prefix(1))
        favorites = Set(library.videos.dropFirst(2).prefix(3))
    }

    func play(_ video: URL) { nowPlaying = [video] }
    func next() {}
    func previous() {}
    func togglePause() { isPaused.toggle() }
    func isFavorite(_ video: URL) -> Bool { favorites.contains(video) }
    func toggleFavorite(_ video: URL) {
        if favorites.contains(video) { favorites.remove(video) } else { favorites.insert(video) }
    }
}
