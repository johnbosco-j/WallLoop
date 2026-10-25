import AVFoundation
import os

/// One looping, muted video. Displays showing the same video share a channel,
/// so the video is decoded once however many screens it is on.
@MainActor
final class PlaybackChannel {
    let url: URL
    let player = AVQueuePlayer()
    private var looper: AVPlayerLooper?
    private var statusObservation: NSKeyValueObservation?

    init(url: URL) {
        self.url = url
        player.isMuted = true
        // AVPlayer keeps the display awake by default; a wallpaper must not.
        player.preventsDisplaySleepDuringVideoPlayback = false
        let looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
        statusObservation = looper.observe(\.status) { looper, _ in
            guard looper.status == .failed else { return }
            Logger(subsystem: "com.johnbosco.wallloop", category: "engine").error(
                "Can't play \(url.lastPathComponent, privacy: .public): \(looper.error?.localizedDescription ?? "unknown error", privacy: .public)")
        }
        self.looper = looper
    }

    func play() { player.play() }
    func pause() { player.pause() }

    func stop() {
        looper?.disableLooping()
        looper = nil
        player.pause()
        player.removeAllItems()
    }
}
