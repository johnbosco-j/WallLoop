import AppKit
import AVFoundation

/// A borderless window at desktop level that covers one display: below the
/// desktop icons, above the system wallpaper, on every Space, never clickable.
@MainActor
final class WallpaperWindow: NSWindow {
    private let playerLayer = AVPlayerLayer()

    var player: AVPlayer? {
        get { playerLayer.player }
        set { if playerLayer.player !== newValue { playerLayer.player = newValue } }
    }

    var fitMode: FitMode = .fill {
        didSet { playerLayer.videoGravity = fitMode.videoGravity }
    }

    /// For videos with alpha: let the desktop picture show through transparent areas.
    var showsTransparency = false {
        didSet {
            guard showsTransparency != oldValue else { return }
            isOpaque = !showsTransparency
            backgroundColor = showsTransparency ? .clear : .black
            playerLayer.backgroundColor = showsTransparency ? nil : NSColor.black.cgColor
        }
    }

    init(screen: NSScreen) {
        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        hasShadow = false
        animationBehavior = .none
        backgroundColor = .black

        let view = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
        view.wantsLayer = true
        playerLayer.frame = view.bounds
        playerLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        playerLayer.videoGravity = fitMode.videoGravity
        playerLayer.backgroundColor = NSColor.black.cgColor
        view.layer?.addSublayer(playerLayer)
        contentView = view
    }

    /// Covers `screen` again after a resolution or arrangement change.
    func place(on screen: NSScreen) {
        guard frame != screen.frame else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        setFrame(screen.frame, display: true)
        CATransaction.commit()
    }
}

private extension FitMode {
    var videoGravity: AVLayerVideoGravity {
        switch self {
        case .fill: .resizeAspectFill
        case .fit: .resizeAspect
        case .stretch: .resize
        }
    }
}
