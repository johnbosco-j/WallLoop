import AppKit
import Observation

/// Connects the library, scheduler and engine, and owns the shuffle timer.
/// The menu bar and Settings window read and drive the app through it.
@MainActor
@Observable
final class AppModel {
    let settings: SettingsStore
    let library: Library

    private(set) var nowPlaying: [URL] = []
    private(set) var isPaused = false

    @ObservationIgnored private var scheduler = Scheduler()
    @ObservationIgnored private let engine: WallpaperEngine
    @ObservationIgnored private let stills = LockScreenStill()
    @ObservationIgnored private var timer: Timer?

    init(settings: SettingsStore, library: Library = Library()) {
        self.settings = settings
        self.library = library
        engine = WallpaperEngine(fitMode: settings.fitMode)
        scheduler.order = settings.playbackOrder

        engine.onScreensChanged = { [weak self] in self?.redisplay() }

        observe({ settings.fitMode }) { [weak self] fitMode in
            guard let self else { return }
            engine.fitMode = fitMode
            stills.update(assignment: engine.assignment, fitMode: fitMode)
        }
        observe({ settings.displayMode }) { [weak self] _ in self?.redisplay() }
        observe({ settings.playbackOrder }) { [weak self] order in self?.scheduler.order = order }
        observe({ settings.shuffleInterval }) { [weak self] _ in self?.restartTimer() }
    }

    /// How many different videos are on screen at once.
    private var slotCount: Int {
        settings.displayMode == .sameOnAll ? 1 : max(NSScreen.screens.count, 1)
    }

    func start() {
        library.refresh()
        next()
    }

    func next() {
        if let selection = scheduler.next(from: library.videos, count: slotCount) {
            present(selection)
        }
        restartTimer()
    }

    func previous() {
        if let selection = scheduler.previous() {
            present(selection)
        }
        restartTimer()
    }

    func togglePause() {
        isPaused.toggle()
        engine.setPaused(isPaused)
    }

    /// Rescans the library and starts playing if nothing is on screen yet.
    func refreshLibrary() {
        library.refresh()
        if nowPlaying.isEmpty, !library.videos.isEmpty { next() }
    }

    /// Shows the current selection again, after a display or display-mode change.
    private func redisplay() {
        if let current = scheduler.current { present(current) }
    }

    private func present(_ selection: Scheduler.Selection) {
        var selection = selection
        if selection.count < slotCount,
           let extended = scheduler.extendCurrent(to: slotCount, from: library.videos) {
            selection = extended
        }
        let shown = Array(selection.prefix(slotCount))
        engine.show(shown)
        nowPlaying = shown
        stills.update(assignment: engine.assignment, fitMode: settings.fitMode)
    }

    private func restartTimer() {
        timer?.invalidate()
        timer = nil
        guard let seconds = settings.shuffleInterval.seconds else { return }
        timer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, !self.isPaused else { return }
                self.next()
            }
        }
        timer?.tolerance = min(seconds * 0.05, 30)
    }
}
