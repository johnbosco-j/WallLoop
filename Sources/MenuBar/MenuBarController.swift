import AppKit

/// The status item and its menu. The menu is rebuilt each time it opens so it
/// always reflects the current settings and playback state.
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let settings: SettingsStore
    private let openSettings: (SettingsPane?) -> Void

    init(settings: SettingsStore, openSettings: @escaping (SettingsPane?) -> Void) {
        self.settings = settings
        self.openSettings = openSettings
        super.init()

        statusItem.button?.image = NSImage(systemSymbolName: "play.rectangle.on.rectangle",
                                           accessibilityDescription: "WallLoop")
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let now = NSMenuItem(title: "No Videos Yet", action: nil, keyEquivalent: "")
        now.isEnabled = false
        menu.addItem(now)
        menu.addItem(.separator())

        // Playback controls arrive with the wallpaper engine (Milestone 2).
        menu.addItem(NSMenuItem(title: "Previous", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Next", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Pause", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())

        let shuffleMenu = NSMenu()
        for interval in ShuffleInterval.allCases {
            let item = makeItem(interval.title, #selector(chooseInterval(_:)))
            item.representedObject = interval.rawValue
            item.state = interval == settings.shuffleInterval ? .on : .off
            shuffleMenu.addItem(item)
        }
        let shuffleItem = NSMenuItem(title: "Shuffle Every", action: nil, keyEquivalent: "")
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

        menu.addItem(makeItem("Open Library…", #selector(showLibrary)))
        menu.addItem(makeItem("Settings…", #selector(showSettings), key: ","))
        menu.addItem(.separator())
        menu.addItem(makeItem("Quit WallLoop", #selector(quit), key: "q"))
    }

    private func makeItem(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
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

    @objc private func showLibrary() { openSettings(.library) }
    @objc private func showSettings() { openSettings(nil) }
    @objc private func quit() { NSApp.terminate(nil) }
}
