import SwiftUI

/// The video library. This is a simple list for now; folder picking and the
/// thumbnail grid arrive with the Library milestone.
struct LibraryPane: View {
    let model: AppModel

    private var library: Library { model.library }

    var body: some View {
        Group {
            if library.videos.isEmpty {
                emptyState
            } else {
                List(library.videos, id: \.self) { url in
                    HStack {
                        Label(url.deletingPathExtension().lastPathComponent, systemImage: "film")
                        Spacer()
                        if model.nowPlaying.contains(url) {
                            Image(systemName: "waveform")
                                .foregroundStyle(.tint)
                                .help("Now playing")
                        }
                    }
                }
                .safeAreaInset(edge: .bottom) { footer }
            }
        }
        .onAppear { model.refreshLibrary() }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Add Your Videos", systemImage: "film.stack")
        } description: {
            Text("Put your MP4, MOV or M4V videos in Movies › WallLoop, or give WallLoop access to another folder. WallLoop only reads the folders you choose, and nothing leaves your Mac.")
        } actions: {
            HStack(spacing: 12) {
                Button("Show Folder in Finder") { NSWorkspace.shared.open(library.defaultFolder) }
                    .glassButtonStyle(prominent: true)
                Button("Choose Folder…") {}
                    .glassButtonStyle()
                    .disabled(true)
                    .help("Coming in the next build")
                FreeWallpapersMenu()
            }
            .controlSize(.large)
        }
    }

    private var footer: some View {
        HStack {
            Text("\(library.videos.count) videos in Movies › WallLoop")
                .foregroundStyle(.secondary)
            Spacer()
            Button("Show in Finder") { NSWorkspace.shared.open(library.defaultFolder) }
                .glassButtonStyle()
        }
        .padding(12)
    }
}

/// Opens openly licensed video sites in the browser. WallLoop never downloads anything itself.
struct FreeWallpapersMenu: View {
    @Environment(\.openURL) private var openURL

    private static let sources: [(name: String, url: URL)] = [
        ("Pexels", URL(string: "https://www.pexels.com/videos/")!),
        ("Pixabay", URL(string: "https://pixabay.com/videos/")!),
        ("Mixkit", URL(string: "https://mixkit.co/free-stock-video/")!),
    ]

    var body: some View {
        Menu("Get Free Wallpapers") {
            ForEach(Self.sources, id: \.name) { source in
                Button(source.name) { openURL(source.url) }
            }
        }
        .fixedSize()
    }
}
