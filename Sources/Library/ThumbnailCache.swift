import AppKit
import AVFoundation
import CryptoKit
import ImageIO
import UniformTypeIdentifiers

/// Poster frames for the library, kept in memory and as JPEGs in Caches.
/// A cached file is keyed by the video's path, modification date and size, so
/// an edited or replaced video gets a fresh thumbnail.
@MainActor
final class ThumbnailCache {
    nonisolated static let maxPixelSize: CGFloat = 480

    let directory: URL
    private let memory = NSCache<NSString, NSImage>()
    private var inFlight: [String: Task<Data?, Never>] = [:]

    init(directory: URL? = nil) {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.directory = directory ?? caches.appendingPathComponent("Thumbnails", isDirectory: true)
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
        memory.countLimit = 300
    }

    func image(for video: URL) async -> NSImage? {
        guard let key = Self.cacheKey(for: video) else { return nil }
        if let image = memory.object(forKey: key as NSString) { return image }

        let file = directory.appendingPathComponent("\(key).jpg")
        let task = inFlight[key] ?? Task.detached { await Self.loadOrGenerate(video, cachedAt: file) }
        inFlight[key] = task
        let data = await task.value
        inFlight[key] = nil

        guard let data, let image = NSImage(data: data) else { return nil }
        memory.setObject(image, forKey: key as NSString)
        return image
    }

    /// Deletes cached thumbnails for videos that are no longer in the library.
    func prune(keeping videos: [URL]) {
        let directory = directory
        Task.detached(priority: .utility) {
            let keep = Set(videos.compactMap { Self.cacheKey(for: $0).map { "\($0).jpg" } })
            let fm = FileManager.default
            for file in (try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
            where !keep.contains(file.lastPathComponent) {
                try? fm.removeItem(at: file)
            }
        }
    }

    nonisolated static func cacheKey(for video: URL) -> String? {
        // A fresh URL, because URL caches resource values and the file may have changed.
        let file = URL(fileURLWithPath: video.path)
        guard let values = try? file.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        else { return nil }
        let modified = values.contentModificationDate?.timeIntervalSince1970 ?? 0
        // "poster2": bump when the way the frame is chosen changes, so old thumbnails regenerate.
        let identity = "poster2|\(file.standardizedFileURL.path)|\(modified)|\(values.fileSize ?? 0)"
        return SHA256.hash(data: Data(identity.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private nonisolated static func loadOrGenerate(_ video: URL, cachedAt file: URL) async -> Data? {
        if let data = try? Data(contentsOf: file) { return data }

        guard let image = await VideoPoster.image(of: video, maxSize: CGSize(width: maxPixelSize, height: maxPixelSize)),
              let data = jpegData(image) else { return nil }
        try? data.write(to: file, options: .atomic)
        return data
    }

    private nonisolated static func jpegData(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }
}
