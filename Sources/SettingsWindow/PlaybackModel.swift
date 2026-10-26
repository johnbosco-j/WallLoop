import Foundation

/// What the Settings window needs from the app: the library, the settings and
/// playback. `AppModel` provides it; render tests use a stand-in so they never
/// open wallpaper windows.
@MainActor
protocol PlaybackModel: AnyObject {
    var settings: SettingsStore { get }
    var library: Library { get }
    var nowPlaying: [URL] { get }
    var isPaused: Bool { get }
    var pauseReason: PauseReason? { get }

    func play(_ video: URL)
    func next()
    func previous()
    func togglePause()
    func isFavorite(_ video: URL) -> Bool
    func toggleFavorite(_ video: URL)
}

extension AppModel: PlaybackModel {}

extension PlaybackModel {
    /// Paused by the user or automatically.
    var isEffectivelyPaused: Bool { isPaused || pauseReason != nil }
}
