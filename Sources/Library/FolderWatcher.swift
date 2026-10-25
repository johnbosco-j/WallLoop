import CoreServices
import Foundation

/// Watches folders (and everything inside them) with FSEvents and calls
/// `onChange` on the main actor, at most about twice a second.
@MainActor
final class FolderWatcher {
    private let onChange: () -> Void
    private var stream: FSEventStreamRef?

    init(onChange: @escaping () -> Void) {
        self.onChange = onChange
    }

    /// Replaces whatever was watched before with `folders`.
    func watch(_ folders: [URL]) {
        stop()
        guard !folders.isEmpty else { return }

        var context = FSEventStreamContext(
            version: 0, info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil, release: nil, copyDescription: nil)
        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            let watcher = Unmanaged<FolderWatcher>.fromOpaque(info).takeUnretainedValue()
            // The stream delivers on the main queue (see below).
            MainActor.assumeIsolated { watcher.onChange() }
        }
        let flags = FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagWatchRoot)
        guard let stream = FSEventStreamCreate(
            nil, callback, &context, folders.map(\.path) as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 0.5, flags
        ) else { return }

        FSEventStreamSetDispatchQueue(stream, .main)
        FSEventStreamStart(stream)
        self.stream = stream
    }

    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }
}
