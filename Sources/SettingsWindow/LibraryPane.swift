import SwiftUI

/// The video library. For now it only shows the first-run state; the folder
/// picker and thumbnail grid arrive with the Library milestone.
struct LibraryPane: View {
    var body: some View {
        ContentUnavailableView {
            Label("Add Your Videos", systemImage: "film.stack")
        } description: {
            Text("Put your MP4, MOV or M4V videos in a folder, then give WallLoop access to it. WallLoop only reads the folders you choose, and nothing leaves your Mac.")
        } actions: {
            HStack(spacing: 12) {
                Button("Choose Folder…") {}
                    .glassButtonStyle(prominent: true)
                    .controlSize(.large)
                    .disabled(true)
                    .help("Coming in the next build")
                FreeWallpapersMenu()
                    .controlSize(.large)
            }
        }
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
