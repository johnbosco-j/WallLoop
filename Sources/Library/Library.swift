import AppKit
import Observation
import os

/// The videos WallLoop can play, gathered from the folders the user chose.
///
/// `~/Movies/WallLoop` is always part of the library: the `assets.movies`
/// entitlement lets the sandboxed app read and write it without asking. Other
/// folders come from an open panel and are remembered with read-only,
/// security-scoped bookmarks. Folders are watched with FSEvents, and every file
/// is checked for hardware decoding before it is offered for playback.
@MainActor
@Observable
final class Library {
    struct Folder: Identifiable, Hashable, Sendable {
        var id: URL { url }
        let url: URL
        let isDefault: Bool
        var isAccessible: Bool

        /// The path with the home folder shown as `~`.
        var displayPath: String {
            let home = Library.homeFolder.path
            return url.path.hasPrefix(home + "/") ? "~" + url.path.dropFirst(home.count) : url.path
        }
    }

    enum LibraryError: LocalizedError {
        case readOnly(URL)

        var errorDescription: String? {
            switch self {
            case .readOnly(let url):
                "“\(url.lastPathComponent)” is in a folder WallLoop can only read. Remove it in Finder, or hide it instead."
            }
        }
    }

    nonisolated static let videoExtensions: Set<String> = ["mp4", "mov", "m4v"]

    let defaultFolder: URL
    /// The default folder first, then the folders the user added, in order.
    private(set) var folders: [Folder] = []
    /// Playable, visible videos, sorted by name.
    private(set) var videos: [URL] = []
    /// Files that were found but can't play, with the reason.
    private(set) var unsupported: [URL: String] = [:]
    /// Videos the user removed from the library without deleting them.
    private(set) var hiddenVideos: [URL] = []
    private(set) var isScanning = false

    @ObservationIgnored let thumbnails: ThumbnailCache
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var stored: [StoredFolder] = []
    @ObservationIgnored private var accessing: [String: URL] = [:]
    @ObservationIgnored private var hidden: Set<String>
    @ObservationIgnored private var results: [URL: VideoProbe.Result] = [:]
    @ObservationIgnored private var playable: Set<URL> = []
    @ObservationIgnored private let prober = VideoProber()
    @ObservationIgnored private var watcher: FolderWatcher?
    @ObservationIgnored private var scanTask: Task<Void, Never>?
    @ObservationIgnored private var rescanPending = false
    @ObservationIgnored private let log = Logger(subsystem: "com.johnbosco.wallloop", category: "library")

    private enum Key {
        static let folders = "libraryFolders"
        static let hidden = "hiddenVideos"
    }

    private struct StoredFolder: Codable {
        var path: String
        var bookmark: Data
    }

    init(defaultFolder: URL = Library.moviesFolder.appendingPathComponent("WallLoop", isDirectory: true),
         defaults: UserDefaults = .standard,
         thumbnails: ThumbnailCache = ThumbnailCache(),
         watchesFolders: Bool = true) {
        self.defaultFolder = defaultFolder.standardizedFileURL
        self.defaults = defaults
        self.thumbnails = thumbnails
        hidden = Set(defaults.stringArray(forKey: Key.hidden) ?? [])
        try? FileManager.default.createDirectory(at: defaultFolder, withIntermediateDirectories: true)

        loadFolders()
        if watchesFolders {
            watcher = FolderWatcher { [weak self] in self?.rescan() }
        }
        foldersChanged()
    }

    // MARK: Folders

    /// Asks the user for folders of videos and adds them.
    func chooseFolders() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.prompt = "Add"
        panel.message = "Choose folders with videos for WallLoop to play."
        NSApp.activate()
        guard panel.runModal() == .OK else { return }
        addFolders(panel.urls)
    }

    /// Adds folders the user picked (open panel or drag and drop). Folders
    /// already in the library are ignored; an inaccessible one is replaced.
    func addFolders(_ urls: [URL]) {
        var changed = false
        for url in urls.map(\.standardizedFileURL) {
            if let existing = folders.first(where: { $0.url.path == url.path }), existing.isAccessible { continue }
            do {
                let bookmark = try Self.bookmark(for: url)
                stored.removeAll { $0.path == url.path }
                folders.removeAll { $0.url.path == url.path }
                var entry = StoredFolder(path: url.path, bookmark: bookmark)
                folders.append(resolve(&entry))
                stored.append(entry)
                changed = true
            } catch {
                log.error("Couldn't remember \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
        guard changed else { return }
        saveFolders()
        foldersChanged()
    }

    func removeFolder(_ folder: Folder) {
        guard !folder.isDefault else { return }
        if let url = accessing.removeValue(forKey: folder.url.path) {
            url.stopAccessingSecurityScopedResource()
        }
        stored.removeAll { $0.path == folder.url.path }
        folders.removeAll { $0.url.path == folder.url.path }
        saveFolders()
        foldersChanged()
    }

    private func loadFolders() {
        let data = defaults.data(forKey: Key.folders)
        stored = data.flatMap { try? PropertyListDecoder().decode([StoredFolder].self, from: $0) } ?? []
        folders = [Folder(url: defaultFolder, isDefault: true, isAccessible: true)]
        for i in stored.indices {
            folders.append(resolve(&stored[i]))
        }
        saveFolders()
    }

    /// Resolves a bookmark and opens its security scope, refreshing stale bookmarks.
    private func resolve(_ entry: inout StoredFolder) -> Folder {
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: entry.bookmark, options: .withSecurityScope,
                                 relativeTo: nil, bookmarkDataIsStale: &isStale) else {
            return Folder(url: URL(fileURLWithPath: entry.path, isDirectory: true), isDefault: false, isAccessible: false)
        }
        let started = url.startAccessingSecurityScopedResource()
        if started { accessing[url.standardizedFileURL.path] = url }
        if isStale, started, let fresh = try? Self.bookmark(for: url) {
            entry.bookmark = fresh
        }
        entry.path = url.standardizedFileURL.path
        let exists = FileManager.default.fileExists(atPath: url.path)
        return Folder(url: url.standardizedFileURL, isDefault: false, isAccessible: started && exists)
    }

    private func saveFolders() {
        if let data = try? PropertyListEncoder().encode(stored) {
            defaults.set(data, forKey: Key.folders)
        }
    }

    private func foldersChanged() {
        watcher?.watch(folders.filter(\.isAccessible).map(\.url))
        rescan()
    }

    private static func bookmark(for url: URL) throws -> Data {
        try url.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                             includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    // MARK: Videos

    /// Whether `video` is in the library, visible and still on disk.
    func isPlayable(_ video: URL) -> Bool {
        playable.contains(video) && FileManager.default.fileExists(atPath: video.path)
    }

    func hasAlpha(_ video: URL) -> Bool {
        results[video] == .playable(hasAlpha: true)
    }

    func thumbnail(for video: URL) async -> NSImage? {
        await thumbnails.image(for: video)
    }

    /// Copies videos (or folders of videos) into the default folder. Returns the new files.
    @discardableResult
    func importVideos(_ urls: [URL]) async -> [URL] {
        try? FileManager.default.createDirectory(at: defaultFolder, withIntermediateDirectories: true)
        let imported = await Importer.importVideos(urls, into: defaultFolder)
        if !imported.isEmpty { rescan() }
        return imported
    }

    func hide(_ video: URL) {
        hidden.insert(video.path)
        saveHidden()
    }

    func unhide(_ video: URL) {
        hidden.remove(video.path)
        saveHidden()
    }

    /// Only videos in the default folder can be trashed; other folders are read-only.
    func canMoveToTrash(_ video: URL) -> Bool {
        video.standardizedFileURL.path.hasPrefix(defaultFolder.path + "/")
    }

    func moveToTrash(_ video: URL) async throws {
        guard canMoveToTrash(video) else { throw LibraryError.readOnly(video) }
        _ = try await NSWorkspace.shared.recycle([video])
        rescan()
    }

    private func saveHidden() {
        defaults.set(hidden.sorted(), forKey: Key.hidden)
        publish()
    }

    // MARK: Scanning

    /// Rescans every folder in the background. Calls while a scan runs are
    /// coalesced into one more scan when it finishes.
    func rescan() {
        guard scanTask == nil else {
            rescanPending = true
            return
        }
        isScanning = true
        let roots = folders.filter(\.isAccessible).map(\.url)
        let prober = prober
        scanTask = Task {
            let files = await Task.detached(priority: .utility) { Self.scan(roots) }.value
            var found: [URL: VideoProbe.Result] = [:]
            for file in files {
                found[file.url] = await prober.probe(file)
            }
            results = found
            publish()
            thumbnails.prune(keeping: Array(found.keys))

            scanTask = nil
            if rescanPending {
                rescanPending = false
                rescan()
            } else {
                isScanning = false
            }
        }
    }

    /// Waits until scanning has finished, including any queued rescan.
    func waitForScan() async {
        while let task = scanTask {
            await task.value
        }
    }

    /// Recomputes the published lists from the last scan and the hidden set.
    private func publish() {
        var visible: [URL] = []
        var bad: [URL: String] = [:]
        var hiddenList: [URL] = []
        for (url, result) in results {
            if hidden.contains(url.path) {
                hiddenList.append(url)
                continue
            }
            switch result {
            case .playable: visible.append(url)
            case .unsupported(let reason): bad[url] = reason
            }
        }
        visible.sort(by: Self.byName)
        hiddenList.sort(by: Self.byName)

        if visible != videos { videos = visible }
        if bad != unsupported { unsupported = bad }
        if hiddenList != hiddenVideos { hiddenVideos = hiddenList }
        playable = Set(visible)
    }

    nonisolated static func byName(_ a: URL, _ b: URL) -> Bool {
        switch a.lastPathComponent.localizedStandardCompare(b.lastPathComponent) {
        case .orderedAscending: true
        case .orderedDescending: false
        case .orderedSame: a.path < b.path
        }
    }

    /// Every file with a supported extension in `folders` and their subfolders.
    nonisolated static func scan(_ folders: [URL]) -> [ScannedFile] {
        var seen: Set<URL> = []
        var files: [ScannedFile] = []
        let keys: [URLResourceKey] = [.isRegularFileKey, .contentModificationDateKey, .fileSizeKey]
        for folder in folders {
            guard let enumerator = FileManager.default.enumerator(
                at: folder, includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            for case let url as URL in enumerator
            where videoExtensions.contains(url.pathExtension.lowercased()) {
                let url = url.standardizedFileURL
                guard seen.insert(url).inserted,
                      let values = try? url.resourceValues(forKeys: Set(keys)),
                      values.isRegularFile == true else { continue }
                files.append(ScannedFile(url: url, modified: values.contentModificationDate, size: values.fileSize))
            }
        }
        return files
    }

    // MARK: Locations

    /// The real home folder. Inside the sandbox `homeDirectoryForCurrentUser`
    /// points into the app's container, so ask the user database instead.
    nonisolated static var homeFolder: URL {
        let home = getpwuid(getuid()).flatMap { $0.pointee.pw_dir.map { String(cString: $0) } }
            ?? NSHomeDirectory()
        return URL(fileURLWithPath: home, isDirectory: true)
    }

    /// The real `~/Movies`.
    nonisolated static var moviesFolder: URL {
        homeFolder.appendingPathComponent("Movies", isDirectory: true)
    }
}
