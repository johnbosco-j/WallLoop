import AppKit
import AVFoundation
import os

/// Sets a still frame of each display's video as that display's desktop picture,
/// so the lock screen and login window match the live wallpaper.
///
/// Every still gets a unique file name (the system caches desktop pictures by
/// URL, so reusing a name can show a stale image), and older stills are deleted
/// once the new ones are set.
@MainActor
final class LockScreenStill {
    private let directory: URL
    private var task: Task<Void, Never>?
    private let log = Logger(subsystem: "com.johnbosco.wallloop", category: "stills")

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        directory = support.appendingPathComponent("Stills", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// Replaces any update still in progress, so rapid Next clicks only set the last one.
    func update(assignment: [CGDirectDisplayID: URL], fitMode: FitMode) {
        task?.cancel()
        task = Task { await apply(assignment: assignment, fitMode: fitMode) }
    }

    private func apply(assignment: [CGDirectDisplayID: URL], fitMode: FitMode) async {
        let screens = NSScreen.screens
        // Big enough for the largest display; one decode per video.
        let maxSize = screens.reduce(CGSize.zero) { size, screen in
            CGSize(width: max(size.width, screen.frame.width * screen.backingScaleFactor),
                   height: max(size.height, screen.frame.height * screen.backingScaleFactor))
        }

        var stills: [URL: URL] = [:]
        for screen in screens {
            guard let id = screen.displayID, let video = assignment[id] else { continue }
            if stills[video] == nil {
                guard let image = await Self.frame(of: video, maxSize: maxSize) else {
                    log.error("Couldn't read a frame from \(video.lastPathComponent, privacy: .public)")
                    continue
                }
                guard !Task.isCancelled else { return }
                let file = directory.appendingPathComponent("still-\(UUID().uuidString).jpg")
                guard Self.writeJPEG(image, to: file) else { continue }
                stills[video] = file
            }
            guard let file = stills[video] else { continue }
            do {
                try NSWorkspace.shared.setDesktopImageURL(file, for: screen, options: fitMode.desktopImageOptions)
            } catch {
                log.error("Couldn't set desktop picture: \(error.localizedDescription, privacy: .public)")
            }
        }
        removeStills(except: Set(stills.values))
    }

    private func removeStills(except keep: Set<URL>) {
        let fm = FileManager.default
        guard !keep.isEmpty, let files = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        else { return }
        let keepNames = Set(keep.map(\.lastPathComponent))
        for file in files where !keepNames.contains(file.lastPathComponent) {
            try? fm.removeItem(at: file)
        }
    }

    private nonisolated static func frame(of video: URL, maxSize: CGSize) async -> CGImage? {
        await VideoPoster.image(of: video, maxSize: maxSize)
    }

    private nonisolated static func writeJPEG(_ image: CGImage, to file: URL) -> Bool {
        guard let data = NSBitmapImageRep(cgImage: image)
            .representation(using: .jpeg, properties: [.compressionFactor: 0.9]) else { return false }
        return (try? data.write(to: file, options: .atomic)) != nil
    }
}

private extension FitMode {
    /// Matches the live video's scaling, so nothing jumps when the screen locks.
    var desktopImageOptions: [NSWorkspace.DesktopImageOptionKey: Any] {
        switch self {
        case .fill:
            [.imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue, .allowClipping: true]
        case .fit:
            [.imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue, .allowClipping: false,
             .fillColor: NSColor.black]
        case .stretch:
            [.imageScaling: NSImageScaling.scaleAxesIndependently.rawValue, .allowClipping: true]
        }
    }
}
