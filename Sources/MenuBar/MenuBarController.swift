import AppKit

/// The status item and its menu. The menu is rebuilt each time it opens so it
/// always reflects the current settings and playback state. Videos and folders
/// dropped on the icon are added to the library.
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let model: AppModel
    private let openSettings: (SettingsPane?) -> Void
    private var dropTarget: StatusItemDropTarget?

    /// The current video's poster frame, loaded ahead so the menu opens with it.
    private var thumbnail: (video: URL, image: NSImage)?
    /// A symbol shown briefly after a drop, instead of the normal icon.
    private var feedbackSymbol: String?
    private var feedbackTask: Task<Void, Never>?

    private var settings: SettingsStore { model.settings }
    private var library: Library { model.library }

    init(model: AppModel, openSettings: @escaping (SettingsPane?) -> Void) {
        self.model = model
        self.openSettings = openSettings
        super.init()

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        if let button = statusItem.button {
            button.toolTip = "WallLoop — drop videos or folders here to add them"
            let target = StatusItemDropTarget(button: button)
            target.onDrop = { [weak self] items in self?.handleDrop(items) }
            dropTarget = target
        }
        updateIcon()

        WallLoop.observe({ (model.isPaused, model.pauseReason) }) { [weak self] _ in self?.updateIcon() }
        WallLoop.observe({ model.nowPlaying }) { [weak self] videos in self?.loadThumbnail(for: videos.first) }
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        addNowPlaying(to: menu)
        menu.addItem(.separator())
        addPlaybackControls(to: menu)
        menu.addItem(.separator())
        addFavorites(to: menu)
        menu.addItem(.separator())
        addShuffleOptions(to: menu)
        menu.addItem(.separator())

        menu.addItem(makeItem("Open Library…", #selector(showLibrary), symbol: "film.stack"))
        let updates = makeItem("Check for Updates…", #selector(checkForUpdates), symbol: "arrow.down.circle")
        if !Updater.shared.canCheckForUpdates { updates.action = nil }
        menu.addItem(updates)
        menu.addItem(makeItem("Settings…", #selector(showSettings), key: ",", symbol: "gearshape"))
        menu.addItem(.separator())
        menu.addItem(makeItem("Quit WallLoop", #selector(quit), key: "q"))
    }

    private func addNowPlaying(to menu: NSMenu) {
        guard let video = model.nowPlaying.first else {
            menu.addItem(.sectionHeader(title: library.isScanning ? "Looking for Videos…" : "No Videos Yet"))
            menu.addItem(makeItem("Add Videos to Movies › WallLoop…", #selector(showVideoFolder), symbol: "folder"))
            menu.addItem(makeItem("Add Folder…", #selector(addFolder), symbol: "folder.badge.plus"))
            return
        }
        let status = if let reason = model.pauseReason {
            "Paused — \(reason.title)"
        } else {
            model.isPaused ? "Paused" : "Now Playing"
        }
        menu.addItem(.nowPlaying(NowPlayingView(
            videos: model.nowPlaying,
            status: status,
            isPaused: model.isPaused || model.pauseReason != nil,
            library: library,
            initialThumbnail: thumbnail?.video == video ? thumbnail?.image : nil)))
    }

    private func addPlaybackControls(to menu: NSMenu) {
        let hasVideos = !library.videos.isEmpty
        let previous = makeItem("Previous", #selector(previous), symbol: "backward.fill")
        let next = makeItem("Next", #selector(next), symbol: "forward.fill")
        let pause = model.isPaused
            ? makeItem("Play", #selector(togglePause), symbol: "play.fill")
            : makeItem("Pause", #selector(togglePause), symbol: "pause.fill")
        for item in [previous, next, pause] {
            if !hasVideos { item.action = nil }
            menu.addItem(item)
        }
    }

    private func addFavorites(to menu: NSMenu) {
        if let video = model.nowPlaying.first {
            let isFavorite = model.isFavorite(video)
            let item = makeItem(isFavorite ? "Remove from Favorites" : "Add to Favorites",
                                #selector(toggleFavorite), symbol: isFavorite ? "heart.fill" : "heart")
            menu.addItem(item)
        }

        let favorites = library.videos.filter(model.isFavorite)
        let favoritesMenu = NSMenu()
        if favorites.isEmpty {
            let empty = NSMenuItem(title: "No Favorites Yet", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            favoritesMenu.addItem(empty)
        }
        for video in favorites {
            let item = makeItem(NowPlayingView.name(video), #selector(playVideo(_:)))
            item.representedObject = video
            item.state = model.nowPlaying.contains(video) ? .on : .off
            favoritesMenu.addItem(item)
        }
        let favoritesItem = NSMenuItem(title: "Favorites", action: nil, keyEquivalent: "")
        favoritesItem.image = NSImage(systemSymbolName: "heart.text.square", accessibilityDescription: nil)
        favoritesItem.submenu = favoritesMenu
        menu.addItem(favoritesItem)

        let only = makeItem("Shuffle Favorites Only", #selector(toggleFavoritesOnly))
        only.state = settings.favoritesOnly ? .on : .off
        if favorites.isEmpty {
            only.action = nil
            only.toolTip = "Add a video to your favorites first."
        }
        menu.addItem(only)
    }

    private func addShuffleOptions(to menu: NSMenu) {
        let shuffleMenu = NSMenu()
        for interval in ShuffleInterval.allCases {
            let item = makeItem(interval.title, #selector(chooseInterval(_:)))
            item.representedObject = interval.rawValue
            item.state = interval == settings.shuffleInterval ? .on : .off
            shuffleMenu.addItem(item)
        }
        let shuffleItem = NSMenuItem(title: "Shuffle Every", action: nil, keyEquivalent: "")
        shuffleItem.image = NSImage(systemSymbolName: "timer", accessibilityDescription: nil)
        shuffleItem.submenu = shuffleMenu
        menu.addItem(shuffleItem)

        menu.addItem(.sectionHeader(title: "Order"))
        for order in PlaybackOrder.allCases {
            let item = makeItem(order.title, #selector(chooseOrder(_:)))
            item.representedObject = order.rawValue
            item.state = order == settings.playbackOrder ? .on : .off
            menu.addItem(item)
        }
    }

    private func makeItem(_ title: String, _ action: Selector, key: String = "", symbol: String? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        if let symbol {
            item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        }
        return item
    }

    // MARK: Status icon

    private func updateIcon() {
        let isPaused = model.isPaused || model.pauseReason != nil
        let symbol = feedbackSymbol ?? (isPaused ? "pause.rectangle" : "play.rectangle.on.rectangle")
        let description = isPaused ? "WallLoop, paused" : "WallLoop"
        statusItem.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: description)
            ?? NSImage(systemSymbolName: "play.rectangle.on.rectangle", accessibilityDescription: description)
    }

    /// Swaps the icon for `symbol` for a moment, as feedback for a drop.
    private func flashIcon(_ symbol: String) {
        feedbackTask?.cancel()
        feedbackSymbol = symbol
        updateIcon()
        feedbackTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled, let self else { return }
            feedbackSymbol = nil
            updateIcon()
        }
    }

    private func loadThumbnail(for video: URL?) {
        guard let video, thumbnail?.video != video else { return }
        Task { [weak self] in
            guard let self, let image = await library.thumbnail(for: video) else { return }
            if model.nowPlaying.first == video { thumbnail = (video, image) }
        }
    }

    // MARK: Drag and drop

    /// Adds dropped folders to the library, copies dropped videos into
    /// Movies › WallLoop and plays the first one.
    private func handleDrop(_ items: DroppedItems) {
        if !items.folders.isEmpty {
            library.addFolders(items.folders)
        }
        guard !items.videos.isEmpty else {
            flashIcon("checkmark.rectangle")
            return
        }
        Task { [weak self] in
            guard let self else { return }
            let imported = await library.importVideos(items.videos)
            await library.waitForScan()
            if let first = imported.first(where: library.isPlayable) {
                model.play(first)
            }
            flashIcon(imported.isEmpty ? "exclamationmark.triangle" : "checkmark.rectangle")
        }
    }

    // MARK: Actions

    @objc private func previous() { model.previous() }
    @objc private func next() { model.next() }
    @objc private func togglePause() { model.togglePause() }

    @objc private func toggleFavorite() {
        if let video = model.nowPlaying.first { model.toggleFavorite(video) }
    }

    @objc private func toggleFavoritesOnly() { settings.favoritesOnly.toggle() }

    @objc private func playVideo(_ sender: NSMenuItem) {
        if let video = sender.representedObject as? URL { model.play(video) }
    }

    @objc private func chooseInterval(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let interval = ShuffleInterval(rawValue: raw) else { return }
        settings.shuffleInterval = interval
    }

    @objc private func chooseOrder(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let order = PlaybackOrder(rawValue: raw) else { return }
        settings.playbackOrder = order
    }

    @objc private func showVideoFolder() { NSWorkspace.shared.open(library.defaultFolder) }
    @objc private func addFolder() { library.chooseFolders() }
    @objc private func showLibrary() { openSettings(.library) }
    @objc private func showSettings() { openSettings(nil) }
    @objc private func checkForUpdates() { Updater.shared.checkForUpdates() }
    @objc private func quit() { NSApp.terminate(nil) }
}
