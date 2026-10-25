import Cocoa
import AVFoundation

let folder = (NSHomeDirectory() as NSString).appendingPathComponent("Desktop/Wallspace")

class WallWindow {
    let window: NSWindow
    let player = AVQueuePlayer()
    var looper: AVPlayerLooper?

    init(screen: NSScreen) {
        window = NSWindow(contentRect: screen.frame, styleMask: .borderless,
                          backing: .buffered, defer: false)
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.ignoresMouseEvents = true
        window.backgroundColor = .black
        let view = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
        view.wantsLayer = true
        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        view.layer?.addSublayer(layer)
        window.contentView = view
        window.setFrame(screen.frame, display: true)
        player.isMuted = true
        window.orderFront(nil)
    }

    func play(_ url: URL) {
        looper?.disableLooping()
        player.removeAllItems()
        looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
        player.play()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var walls: [WallWindow] = []
    var history: [URL] = []
    var index = -1
    var timer: Timer?
    var paused = false
    var statusItem: NSStatusItem!
    var pauseItem: NSMenuItem!
    var nowItem: NSMenuItem!
    var intervalItems: [NSMenuItem] = []

    // minutes; 0 = never
    let intervals: [(String, Int)] = [("5 minutes", 5), ("15 minutes", 15), ("30 minutes", 30),
                                      ("1 hour", 60), ("3 hours", 180), ("Never", 0)]
    var minutes: Int {
        get { UserDefaults.standard.object(forKey: "minutes") as? Int ?? 60 }
        set { UserDefaults.standard.set(newValue, forKey: "minutes") }
    }

    func applicationDidFinishLaunching(_ n: Notification) {
        walls = NSScreen.screens.map { WallWindow(screen: $0) }
        buildMenu()
        next()
        restartTimer()
    }

    func buildMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "play.rectangle.on.rectangle",
                                           accessibilityDescription: "WallLoop")
        let menu = NSMenu()

        nowItem = NSMenuItem(title: "—", action: nil, keyEquivalent: "")
        nowItem.isEnabled = false
        menu.addItem(nowItem)
        menu.addItem(.separator())

        menu.addItem(item("◀  Previous", #selector(prevAction), "["))
        menu.addItem(item("▶  Next", #selector(nextAction), "]"))
        pauseItem = item("Pause", #selector(togglePause), "p")
        menu.addItem(pauseItem)
        menu.addItem(.separator())

        let sub = NSMenu()
        for (i, (title, _)) in intervals.enumerated() {
            let it = item(title, #selector(setInterval(_:)), "")
            it.tag = i
            sub.addItem(it)
            intervalItems.append(it)
        }
        let subItem = NSMenuItem(title: "Shuffle every", action: nil, keyEquivalent: "")
        subItem.submenu = sub
        menu.addItem(subItem)
        updateIntervalChecks()

        menu.addItem(item("Open Folder", #selector(openFolder), "o"))
        menu.addItem(.separator())
        menu.addItem(item("Quit WallLoop", #selector(quit), "q"))
        statusItem.menu = menu
    }

    func item(_ title: String, _ action: Selector, _ key: String) -> NSMenuItem {
        let it = NSMenuItem(title: title, action: action, keyEquivalent: key)
        it.target = self
        return it
    }

    func videos() -> [URL] {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: URL(fileURLWithPath: folder), includingPropertiesForKeys: nil)) ?? []
        return files.filter { ["mp4", "mov", "m4v"].contains($0.pathExtension.lowercased()) }
    }

    func show(_ url: URL) {
        walls.forEach { $0.play(url) }
        if paused { walls.forEach { $0.player.pause() } }
        nowItem.title = "Now: " + url.deletingPathExtension().lastPathComponent
        setStill(url)
    }

    func setStill(_ url: URL) {
        let gen = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        gen.appliesPreferredTrackTransform = true
        guard let cg = try? gen.copyCGImage(at: CMTime(seconds: 1, preferredTimescale: 600),
                                            actualTime: nil) else { return }
        let dir = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("WallLoop/stills")
        let fm = FileManager.default
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        for f in (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [] {
            try? fm.removeItem(at: f)
        }
        let out = dir.appendingPathComponent("still-\(Int(Date().timeIntervalSince1970)).png")
        guard let data = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])
        else { return }
        try? data.write(to: out)
        for screen in NSScreen.screens {
            try? NSWorkspace.shared.setDesktopImageURL(out, for: screen, options: [:])
        }
    }

    func next() {
        if index < history.count - 1 {
            index += 1
        } else {
            let vids = videos()
            guard !vids.isEmpty else { nowItem.title = "No videos in folder"; return }
            var pick = vids.randomElement()!
            if vids.count > 1 { while pick == history.last { pick = vids.randomElement()! } }
            history.append(pick)
            index = history.count - 1
        }
        show(history[index])
    }

    func prev() {
        guard index > 0 else { return }
        index -= 1
        show(history[index])
    }

    func restartTimer() {
        timer?.invalidate()
        timer = nil
        guard minutes > 0 else { return }
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(minutes * 60), repeats: true) { _ in
            if !self.paused { self.next() }
        }
    }

    func updateIntervalChecks() {
        for (i, it) in intervalItems.enumerated() {
            it.state = intervals[i].1 == minutes ? .on : .off
        }
    }

    @objc func nextAction() { next(); restartTimer() }
    @objc func prevAction() { prev(); restartTimer() }

    @objc func togglePause() {
        paused.toggle()
        walls.forEach { paused ? $0.player.pause() : $0.player.play() }
        pauseItem.title = paused ? "Play" : "Pause"
    }

    @objc func setInterval(_ sender: NSMenuItem) {
        minutes = intervals[sender.tag].1
        updateIntervalChecks()
        restartTimer()
    }

    @objc func openFolder() { NSWorkspace.shared.open(URL(fileURLWithPath: folder)) }
    @objc func quit() { NSApp.terminate(nil) }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
