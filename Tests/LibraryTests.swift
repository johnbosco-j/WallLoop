import AVFoundation
import Foundation
import Testing
@testable import WallLoop

/// A fresh temporary folder, removed when the test ends.
final class TempFolder {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("WallLoopTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit { try? FileManager.default.removeItem(at: url) }

    @discardableResult
    func file(_ path: String, contents: String = "x") throws -> URL {
        let file = url.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(contents.utf8).write(to: file)
        return file.standardizedFileURL
    }

    /// Writes a two-second, 128×128 H.264 video.
    func video(_ name: String) async throws -> URL {
        let file = url.appendingPathComponent(name).standardizedFileURL
        try await Self.writeVideo(to: file)
        return file
    }

    private nonisolated static func writeVideo(to file: URL) async throws {
        let size = 128
        let writer = try AVAssetWriter(outputURL: file, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: size, AVVideoHeightKey: size,
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: size, kCVPixelBufferHeightKey as String: size,
        ])
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        for frame in 0..<20 {
            while !input.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(5)) }
            var buffer: CVPixelBuffer?
            CVPixelBufferCreate(nil, size, size, kCVPixelFormatType_32BGRA, nil, &buffer)
            guard let buffer else { continue }
            CVPixelBufferLockBaseAddress(buffer, [])
            memset(CVPixelBufferGetBaseAddress(buffer), Int32(frame * 12), CVPixelBufferGetDataSize(buffer))
            CVPixelBufferUnlockBaseAddress(buffer, [])
            adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(frame), timescale: 10))
        }
        input.markAsFinished()
        await writer.finishWriting()
    }
}

@MainActor
struct LibraryTests {
    private let suiteName = "WallLoopTests.\(UUID().uuidString)"
    private var defaults: UserDefaults { UserDefaults(suiteName: suiteName)! }

    private func makeLibrary(_ folder: TempFolder, thumbnails: TempFolder) -> Library {
        Library(defaultFolder: folder.url, defaults: defaults,
                thumbnails: ThumbnailCache(directory: thumbnails.url), watchesFolders: false)
    }

    @Test func scanFindsSupportedExtensionsRecursively() throws {
        let folder = try TempFolder()
        try folder.file("a.mp4")
        try folder.file("b.MOV")
        try folder.file("c.m4v")
        try folder.file("sub/d.mp4")
        try folder.file("notes.txt")
        try folder.file("clip.webm")
        try folder.file(".hidden.mp4")

        let names = Set(Library.scan([folder.url]).map(\.url.lastPathComponent))
        #expect(names == ["a.mp4", "b.MOV", "c.m4v", "d.mp4"])
    }

    @Test func playableAndUnsupportedFilesAreSeparated() async throws {
        let folder = try TempFolder(), thumbs = try TempFolder()
        let good = try await folder.video("good.mp4")
        let bad = try folder.file("broken.mp4", contents: "not a video")

        let library = makeLibrary(folder, thumbnails: thumbs)
        await library.waitForScan()

        #expect(library.videos == [good])
        #expect(library.unsupported[bad] != nil)
        #expect(library.isPlayable(good))
        #expect(!library.isPlayable(bad))
        #expect(!library.hasAlpha(good))
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test func hiddenVideosStayHiddenAcrossLaunches() async throws {
        let folder = try TempFolder(), thumbs = try TempFolder()
        let video = try await folder.video("clip.mp4")

        let library = makeLibrary(folder, thumbnails: thumbs)
        await library.waitForScan()
        library.hide(video)
        #expect(library.videos.isEmpty)
        #expect(library.hiddenVideos == [video])
        #expect(!library.isPlayable(video))

        let relaunched = makeLibrary(folder, thumbnails: thumbs)
        await relaunched.waitForScan()
        #expect(relaunched.videos.isEmpty)
        #expect(relaunched.hiddenVideos == [video])

        relaunched.unhide(video)
        #expect(relaunched.videos == [video])
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test func importRenamesInsteadOfOverwriting() async throws {
        let library = try TempFolder(), source = try TempFolder()
        try library.file("clip.mp4", contents: "original")
        let dropped = try source.file("clip.mp4", contents: "new")
        try source.file("readme.txt")
        try source.file("album/nested.mov")

        let first = await Importer.importVideos([dropped, source.url.appendingPathComponent("readme.txt")],
                                                into: library.url)
        #expect(first.map(\.lastPathComponent) == ["clip 2.mp4"])

        let second = await Importer.importVideos([dropped, source.url.appendingPathComponent("album")],
                                                 into: library.url)
        #expect(Set(second.map(\.lastPathComponent)) == ["clip 3.mp4", "nested.mov"])

        let original = try String(contentsOf: library.url.appendingPathComponent("clip.mp4"), encoding: .utf8)
        #expect(original == "original")
    }

    @Test func importSkipsFilesAlreadyInTheLibrary() async throws {
        let library = try TempFolder()
        let existing = try library.file("clip.mp4")
        #expect(await Importer.importVideos([existing], into: library.url).isEmpty)
    }

    @Test func thumbnailKeyChangesWhenTheFileChanges() throws {
        let folder = try TempFolder()
        let file = try folder.file("clip.mp4")
        let before = ThumbnailCache.cacheKey(for: file)

        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -3600)],
                                              ofItemAtPath: file.path)
        let after = ThumbnailCache.cacheKey(for: file)

        #expect(before != nil)
        #expect(before != after)
        #expect(ThumbnailCache.cacheKey(for: file) == after)
    }

    @Test func thumbnailsAreGeneratedAndCachedOnDisk() async throws {
        let folder = try TempFolder(), thumbs = try TempFolder()
        let video = try await folder.video("clip.mp4")
        let cache = ThumbnailCache(directory: thumbs.url)

        let image = try #require(await cache.image(for: video))
        #expect(image.size.width > 0)
        let files = try FileManager.default.contentsOfDirectory(atPath: thumbs.url.path)
        #expect(files.count == 1)
    }

    @Test func videoProbeAcceptsHardwareDecodableVideo() async throws {
        let folder = try TempFolder()
        let video = try await folder.video("clip.mp4")
        #expect(await VideoProbe.probe(video) == .playable(hasAlpha: false))
    }
}
