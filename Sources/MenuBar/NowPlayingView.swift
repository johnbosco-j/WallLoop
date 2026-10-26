import AppKit
import SwiftUI

/// The header of the menu: a Riven card with a poster frame of the current video,
/// its name, a status chip and the playback settings.
struct NowPlayingView: View {
    static let width: CGFloat = 280
    private static let cardInset: CGFloat = 8
    private static let posterWidth = width - cardInset * 2 - 20

    let videos: [URL]
    let isPaused: Bool
    /// Why WallLoop paused itself, if it did.
    let pauseReason: String?
    /// A mono line under the name, e.g. "Every hour · Shuffle".
    let meta: String
    /// Loads the thumbnail when `initialThumbnail` is missing. `nil` in render tests.
    let library: Library?
    /// A thumbnail that's already loaded, so the menu opens without a placeholder.
    let initialThumbnail: NSImage?

    @State private var thumbnail: NSImage?

    private var video: URL? { videos.first }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            poster
            VStack(alignment: .leading, spacing: 4) {
                Text(video.map(Self.name) ?? "")
                    .font(Theme.sans(14, .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let pauseReason {
                    Text("Paused: \(pauseReason)")
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.muted)
                }
                Text(meta)
                    .font(Theme.mono(10.5))
                    .foregroundStyle(Theme.faint)
                    .lineLimit(1)
            }
            .padding(.horizontal, 4)
            .accessibilityElement(children: .combine)
        }
        .padding(10)
        .rivenSurface(radius: Theme.Radius.card)
        .padding(.horizontal, Self.cardInset)
        .padding(.top, 4)
        .padding(.bottom, 2)
        .frame(width: Self.width, alignment: .leading)
        .environment(\.colorScheme, .dark)
        .task(id: video) {
            guard let video else { return }
            if thumbnail == nil, let initialThumbnail { thumbnail = initialThumbnail }
            if thumbnail == nil, let library { thumbnail = await library.thumbnail(for: video) }
        }
    }

    private var poster: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.input, style: .continuous)
        return ZStack {
            if let image = thumbnail ?? initialThumbnail {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                PosterPlaceholder()
            }
        }
        .frame(width: Self.posterWidth, height: Self.posterWidth * 9 / 16)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Theme.line, lineWidth: 1))
        .overlay(alignment: .topLeading) {
            OverlayBadge(text: isPaused ? "Paused" : "Now playing", dot: isPaused ? Theme.muted : Theme.accent)
                .padding(8)
        }
        .accessibilityHidden(true)
    }

    static func name(_ video: URL) -> String {
        video.deletingPathExtension().lastPathComponent
    }

    /// The meta line: interval and order, plus how many other displays show something.
    nonisolated static func meta(interval: ShuffleInterval, order: PlaybackOrder, otherDisplays: Int) -> String {
        var parts = [interval == .never ? "Changes manually" : interval.phrase, order.title]
        if otherDisplays > 0 { parts.append("+\(otherDisplays) display\(otherDisplays == 1 ? "" : "s")") }
        return parts.joined(separator: " · ")
    }
}

extension NSMenuItem {
    /// A non-interactive menu item that hosts the Now Playing header.
    @MainActor
    static func nowPlaying(_ view: NowPlayingView) -> NSMenuItem {
        let host = NSHostingView(rootView: view)
        host.frame.size = host.fittingSize
        let item = NSMenuItem()
        item.view = host
        item.isEnabled = false
        return item
    }
}

/// WallLoop's menu bar icon, drawn in code as a template image: a small orbit ring
/// with its travelling dot (Riven's orbit motif) around a play triangle, or pause
/// bars while paused.
enum StatusIcon {
    static let size = NSSize(width: 18, height: 18)

    static func image(paused: Bool) -> NSImage {
        let image = NSImage(size: size, flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let radius: CGFloat = 7.4

            // The ring.
            context.setStrokeColor(NSColor.black.cgColor)
            context.setLineWidth(1.5)
            context.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius,
                                          width: radius * 2, height: radius * 2))
            context.strokePath()

            // Punch a gap and draw the travelling dot at about two o'clock.
            let angle = CGFloat.pi / 5.5
            let dot = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
            context.setBlendMode(.clear)
            context.fillEllipse(in: CGRect(x: dot.x - 3.3, y: dot.y - 3.3, width: 6.6, height: 6.6))
            context.setBlendMode(.normal)
            context.setFillColor(NSColor.black.cgColor)
            context.fillEllipse(in: CGRect(x: dot.x - 2.1, y: dot.y - 2.1, width: 4.2, height: 4.2))

            if paused {
                for x in [center.x - 2.4, center.x + 0.9] {
                    let bar = CGPath(roundedRect: CGRect(x: x, y: center.y - 3.3, width: 1.6, height: 6.6),
                                     cornerWidth: 0.8, cornerHeight: 0.8, transform: nil)
                    context.addPath(bar)
                }
                context.fillPath()
            } else {
                // A softly rounded play triangle, nudged right to look centred.
                let triangle = CGMutablePath()
                triangle.move(to: CGPoint(x: center.x - 2.2, y: center.y + 3.5))
                triangle.addLine(to: CGPoint(x: center.x + 3.6, y: center.y))
                triangle.addLine(to: CGPoint(x: center.x - 2.2, y: center.y - 3.5))
                triangle.closeSubpath()
                context.addPath(triangle)
                context.setLineJoin(.round)
                context.setLineWidth(1.1)
                context.drawPath(using: .fillStroke)
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = paused ? "WallLoop, paused" : "WallLoop"
        return image
    }
}
