import Foundation
import Testing
@testable import WallLoop

struct DroppedItemsTests {
    private func url(_ path: String) -> URL { URL(fileURLWithPath: path) }

    @Test func sortsVideosAndFoldersAndIgnoresTheRest() {
        let folders: Set<String> = ["/drop/Clips"]
        let missing: Set<String> = ["/drop/gone.mp4"]
        let items = DroppedItems.classify(
            [url("/drop/a.mp4"), url("/drop/B.MOV"), url("/drop/c.m4v"), url("/drop/Clips"),
             url("/drop/notes.txt"), url("/drop/movie.mkv"), url("/drop/gone.mp4")],
            isFolder: { missing.contains($0.path) ? nil : folders.contains($0.path) })

        #expect(items.videos == [url("/drop/a.mp4"), url("/drop/B.MOV"), url("/drop/c.m4v")])
        #expect(items.folders == [url("/drop/Clips")])
    }

    @Test func nothingUsableIsEmpty() {
        let items = DroppedItems.classify([url("/drop/photo.jpg")], isFolder: { _ in false })
        #expect(items.isEmpty)
    }

    @Test func realFilesystem() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let folder = dir.appendingPathComponent("Clips", isDirectory: true)
        let package = dir.appendingPathComponent("Thing.app", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
        let video = dir.appendingPathComponent("clip.mp4")
        try Data().write(to: video)
        defer { try? FileManager.default.removeItem(at: dir) }

        let items = DroppedItems.classify([video, folder, package, dir.appendingPathComponent("missing.mov")])
        #expect(items.videos.map(\.lastPathComponent) == ["clip.mp4"])
        #expect(items.folders.map(\.lastPathComponent) == ["Clips"])
    }
}
