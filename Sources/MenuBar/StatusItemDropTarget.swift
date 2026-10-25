import AppKit

/// What a drag onto the menu bar icon contains that WallLoop can use.
struct DroppedItems: Equatable {
    /// Video files to copy into Movies › WallLoop.
    var videos: [URL] = []
    /// Folders to add to the library as they are.
    var folders: [URL] = []

    var isEmpty: Bool { videos.isEmpty && folders.isEmpty }

    /// Sorts dropped URLs into supported videos and folders; everything else is ignored.
    /// `isFolder` returns `nil` for files that don't exist.
    static func classify(_ urls: [URL], isFolder: (URL) -> Bool? = DroppedItems.isFolder) -> DroppedItems {
        var items = DroppedItems()
        for url in urls {
            switch isFolder(url) {
            case true?:
                items.folders.append(url)
            case false?:
                if Library.videoExtensions.contains(url.pathExtension.lowercased()) {
                    items.videos.append(url)
                }
            case nil:
                continue
            }
        }
        return items
    }

    /// Whether `url` is a folder. Packages such as apps count as files.
    static func isFolder(_ url: URL) -> Bool? {
        guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey]),
              let isDirectory = values.isDirectory else { return nil }
        return isDirectory && values.isPackage != true
    }
}

/// A transparent view laid over the status item button that accepts videos and
/// folders dragged onto the menu bar icon. Clicks pass through to the button.
@MainActor
final class StatusItemDropTarget: NSView {
    /// Called with the usable contents of a drop.
    var onDrop: ((DroppedItems) -> Void)?

    private weak var button: NSStatusBarButton?

    init(button: NSStatusBarButton) {
        self.button = button
        super.init(frame: button.bounds)
        autoresizingMask = [.width, .height]
        registerForDraggedTypes([.fileURL])
        button.addSubview(self)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    // The button opens the menu; this view only exists for drags.
    override func mouseDown(with event: NSEvent) { button?.mouseDown(with: event) }
    override func rightMouseDown(with event: NSEvent) { button?.rightMouseDown(with: event) }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard !items(in: sender).isEmpty else { return [] }
        button?.highlight(true)
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        items(in: sender).isEmpty ? [] : .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        button?.highlight(false)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        button?.highlight(false)
        let items = items(in: sender)
        guard !items.isEmpty else { return false }
        onDrop?(items)
        return true
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        button?.highlight(false)
    }

    private func items(in drag: NSDraggingInfo) -> DroppedItems {
        let urls = drag.draggingPasteboard.readObjects(
            forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        return DroppedItems.classify(urls)
    }
}
