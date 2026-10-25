import Foundation
import Observation

/// The videos WallLoop can play.
///
/// For now this scans only the default folder, `~/Movies/WallLoop`, which the
/// `assets.movies` entitlement lets the sandboxed app read without a folder
/// picker. User-chosen folders, live watching and thumbnails come next.
@MainActor
@Observable
final class Library {
    nonisolated static let videoExtensions: Set<String> = ["mp4", "mov", "m4v"]

    let defaultFolder: URL
    private(set) var videos: [URL] = []

    init(defaultFolder: URL = Library.moviesFolder.appendingPathComponent("WallLoop", isDirectory: true)) {
        self.defaultFolder = defaultFolder
        try? FileManager.default.createDirectory(at: defaultFolder, withIntermediateDirectories: true)
    }

    func refresh() {
        let found = Self.scan(defaultFolder)
        if found != videos { videos = found }
    }

    /// Every playable video in `folder` and its subfolders, sorted by name.
    nonisolated static func scan(_ folder: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: folder, includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        return enumerator
            .compactMap { $0 as? URL }
            .filter { videoExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    /// The real `~/Movies`. Inside the sandbox `homeDirectoryForCurrentUser`
    /// points into the app's container, so ask the user database instead.
    nonisolated static var moviesFolder: URL {
        let home = getpwuid(getuid()).flatMap { $0.pointee.pw_dir.map { String(cString: $0) } }
            ?? NSHomeDirectory()
        return URL(fileURLWithPath: home, isDirectory: true).appendingPathComponent("Movies", isDirectory: true)
    }
}
