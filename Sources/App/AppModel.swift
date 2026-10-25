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
    /// Paused by the user from the menu.
    private(set) var isPaused = false
    /// Paused automatically (battery, lock screen, covered desktop…), if at all.
    private(set) var pauseReason: PauseReason?

    @ObservationIgnored private var scheduler = Scheduler()
    @ObservationIgnored private let engine: WallpaperEngine
    @ObservationIgnored private let stills = LockScreenStill()
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private let pausePolicy: PausePolicy

    init(settings: SettingsStore, library: Library = Library()) {
        self.settings = settings
        self.library = library
        // History skips videos that were deleted, hidden or whose folder was removed.
        scheduler = Scheduler(fileExists: { [library] url in MainActor.assumeIsolated { library.isPlayable(url) } })
        engine = WallpaperEngine(fitMode: settings.fitMode)
        pausePolicy = PausePolicy(settings: settings)
        pauseReason = pausePolicy.reason
        scheduler.order = settings.playbackOrder

        engine.onScreensChanged = { [weak self] in self?.redisplay() }
        engine.hasAlpha = { [library] url in library.hasAlpha(url) }
        engine.onVisibilityChange = { [weak self] visible in self?.pausePolicy.setCovered(!visible) }
        pausePolicy.onChange = { [weak self] reason in
            self?.pauseReason = reason
            self?.applyPause()
        }
        applyPause()

        observe({ settings.fitMode }) { [weak self] fitMode in
            guard let self else { return }
            engine.fitMode = fitMode
            updateStills()
        }
        observe({ settings.displayMode }) { [weak self] _ in self?.redisplay() }
        observe({ settings.playbackOrder }) { [weak self] order in self?.scheduler.order = order }
        observe({ settings.shuffleInterval }) { [weak self] _ in self?.restartTimer() }
        observe({ library.videos }) { [weak self] videos in self?.libraryChanged(videos) }
    }

    /// How many different videos are on screen at once.
    private var slotCount: Int {
        settings.displayMode == .sameOnAll ? 1 : max(NSScreen.screens.count, 1)
    }

    func start() {
        if !library.videos.isEmpty { next() }
    }

    func next() {
        if let selection = scheduler.next(from: candidates, count: slotCount) {
            present(selection)
        } else if library.videos.isEmpty {
            engine.clear()
            nowPlaying = []
        }
        restartTimer()
    }

    func previous() {
        if let selection = scheduler.previous() {
            present(selection)
        }
        restartTimer()
    }

    /// Plays `video` now, on every display or on the first one in per-display mode.
    func play(_ video: URL) {
        guard library.isPlayable(video) else { return }
        scheduler.choose([video])
        present([video])
        restartTimer()
    }

    // MARK: Favorites

    func isFavorite(_ video: URL) -> Bool {
        settings.favorites.contains(video.path)
    }

    func toggleFavorite(_ video: URL) {
        if isFavorite(video) {
            settings.favorites.remove(video.path)
        } else {
            settings.favorites.insert(video.path)
        }
    }

    /// The videos shuffle draws from: favorites only when that's on and any are available.
    private var candidates: [URL] {
        guard settings.favoritesOnly else { return library.videos }
        let favorites = library.videos.filter(isFavorite)
        return favorites.isEmpty ? library.videos : favorites
    }

    func togglePause() {
        isPaused.toggle()
        applyPause()
    }

    /// Paused by the user or automatically. Resuming continues the same video.
    private var isEffectivelyPaused: Bool { isPaused || pauseReason != nil }

    private func applyPause() {
        engine.setPaused(isEffectivelyPaused)
    }

    /// Starts playing when the first videos arrive, and moves on when a video
    /// on screen leaves the library (deleted, hidden, or its folder removed).
    private func libraryChanged(_ videos: [URL]) {
        let available = Set(videos)
        if nowPlaying.isEmpty {
            if !videos.isEmpty { next() }
        } else if !nowPlaying.allSatisfy(available.contains) {
            next()
        }
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
        updateStills()
    }

    private func updateStills() {
        // Videos with alpha play over the existing desktop picture, so leave it alone.
        stills.update(assignment: engine.assignment.filter { !library.hasAlpha($0.value) },
                      fitMode: settings.fitMode)
    }

    private func restartTimer() {
        timer?.invalidate()
        timer = nil
        guard let seconds = settings.shuffleInterval.seconds else { return }
        timer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, !self.isEffectivelyPaused else { return }
                self.next()
            }
        }
        timer?.tolerance = min(seconds * 0.05, 30)
    }
}
