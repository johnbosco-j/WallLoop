import AppKit
import SwiftUI

/// The header of the menu: a poster frame of the current video, its name and
/// whether it's playing or paused (and why).
struct NowPlayingView: View {
    static let width: CGFloat = 264
    private static let thumbnailWidth = width - 24

    let videos: [URL]
    let status: String
    let isPaused: Bool
    let library: Library
    /// A thumbnail that's already loaded, so the menu opens without a placeholder.
    let initialThumbnail: NSImage?

    @State private var thumbnail: NSImage?

    private var video: URL? { videos.first }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            poster
            VStack(alignment: .leading, spacing: 2) {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(video.map(Self.name) ?? "")
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if videos.count > 1 {
                    Text("+\(videos.count - 1) more on other displays")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .frame(width: Self.width, alignment: .leading)
        .task(id: video) {
            guard let video else { return }
            if thumbnail == nil, let initialThumbnail { thumbnail = initialThumbnail }
            if thumbnail == nil { thumbnail = await library.thumbnail(for: video) }
        }
    }

    private var poster: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        return ZStack {
            shape.fill(.quaternary)
            if let image = thumbnail ?? initialThumbnail {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "film")
                    .font(.title)
                    .foregroundStyle(.tertiary)
            }
            if isPaused {
                Image(systemName: "pause.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(.ultraThinMaterial, in: Circle())
                    .environment(\.colorScheme, .dark)
            }
        }
        .frame(width: Self.thumbnailWidth, height: Self.thumbnailWidth * 9 / 16)
        .clipShape(shape)
        .overlay(shape.strokeBorder(.separator, lineWidth: 0.5))
        .accessibilityHidden(true)
    }

    static func name(_ video: URL) -> String {
        video.deletingPathExtension().lastPathComponent
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
