import AppKit

/// The status item and its menu. The menu is rebuilt each time it opens so it
/// always reflects the current settings and playback state.
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let model: AppModel
    private let openSettings: (SettingsPane?) -> Void

    private var settings: SettingsStore { model.settings }

    init(model: AppModel, openSettings: @escaping (SettingsPane?) -> Void) {
        self.model = model
        self.openSettings = openSettings
        super.init()

        statusItem.button?.image = NSImage(systemSymbolName: "play.rectangle.on.rectangle",
                                           accessibilityDescription: "WallLoop")
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        model.refreshLibrary()
        menu.removeAllItems()

        if model.nowPlaying.isEmpty {
            menu.addItem(.sectionHeader(title: "No Videos Yet"))
            menu.addItem(makeItem("Add Videos to Movies › WallLoop…", #selector(showVideoFolder),
                                  symbol: "folder"))
        } else {
            menu.addItem(.sectionHeader(title: model.isPaused ? "Paused" : "Now Playing"))
            for url in model.nowPlaying {
                let item = NSMenuItem(title: url.deletingPathExtension().lastPathComponent,
                                      action: nil, keyEquivalent: "")
                item.isEnabled = false
                menu.addItem(item)
            }
        }
        menu.addItem(.separator())

        let hasVideos = !model.library.videos.isEmpty
        let previous = makeItem("Previous", #selector(previous), symbol: "backward.fill")
        let next = makeItem("Next", #selector(next), symbol: "forward.fill")
        let pause = model.isPaused
            ? makeItem("Play", #selector(togglePause), symbol: "play.fill")
            : makeItem("Pause", #selector(togglePause), symbol: "pause.fill")
        for item in [previous, next, pause] {
            if !hasVideos { item.action = nil }
            menu.addItem(item)
        }
        menu.addItem(.separator())

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
        menu.addItem(.separator())

        menu.addItem(makeItem("Open Library…", #selector(showLibrary), symbol: "film.stack"))
        let updates = makeItem("Check for Updates…", #selector(checkForUpdates), symbol: "arrow.down.circle")
        if !Updater.shared.canCheckForUpdates { updates.action = nil }
        menu.addItem(updates)
        menu.addItem(makeItem("Settings…", #selector(showSettings), key: ",", symbol: "gearshape"))
        menu.addItem(.separator())
        menu.addItem(makeItem("Quit WallLoop", #selector(quit), key: "q"))
    }

    private func makeItem(_ title: String, _ action: Selector, key: String = "", symbol: String? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        if let symbol {
            item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        }
        return item
    }

    @objc private func previous() { model.previous() }
    @objc private func next() { model.next() }
    @objc private func togglePause() { model.togglePause() }

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

    @objc private func showVideoFolder() { NSWorkspace.shared.open(model.library.defaultFolder) }
    @objc private func showLibrary() { openSettings(.library) }
    @objc private func showSettings() { openSettings(nil) }
    @objc private func checkForUpdates() { Updater.shared.checkForUpdates() }
    @objc private func quit() { NSApp.terminate(nil) }
}
