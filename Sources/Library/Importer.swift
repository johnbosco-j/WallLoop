import Foundation

/// Copies dropped videos into the default library folder.
enum Importer {
    /// Copies every supported video in `urls` (including videos inside dropped
    /// folders) into `folder`, renaming rather than overwriting. Files already in
    /// `folder` are skipped. Returns the new files.
    static func importVideos(_ urls: [URL], into folder: URL) async -> [URL] {
        await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            var imported: [URL] = []
            for source in supportedFiles(in: urls) where !isInside(source, folder) {
                let destination = uniqueDestination(for: source.lastPathComponent, in: folder)
                do {
                    try fm.copyItem(at: source, to: destination)
                    imported.append(destination)
                } catch {
                    continue
                }
            }
            return imported
        }.value
    }

    /// The supported videos among `urls`, looking inside folders.
    static func supportedFiles(in urls: [URL]) -> [URL] {
        urls.flatMap { url -> [URL] in
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return [] }
            if isDirectory.boolValue {
                return Library.scan([url]).map(\.url)
            }
            return Library.videoExtensions.contains(url.pathExtension.lowercased()) ? [url] : []
        }
    }

    /// `folder/name`, or `folder/name 2.ext`, `name 3.ext`… if that's taken.
    static func uniqueDestination(for name: String, in folder: URL) -> URL {
        let fm = FileManager.default
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var candidate = folder.appendingPathComponent(name)
        var n = 2
        while fm.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent(ext.isEmpty ? "\(base) \(n)" : "\(base) \(n).\(ext)")
            n += 1
        }
        return candidate
    }

    private static func isInside(_ file: URL, _ folder: URL) -> Bool {
        file.standardizedFileURL.path.hasPrefix(folder.standardizedFileURL.path + "/")
    }
}
