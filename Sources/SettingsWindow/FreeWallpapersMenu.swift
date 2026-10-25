import SwiftUI

/// Opens openly licensed video sites in the browser. WallLoop never downloads anything itself.
struct FreeWallpapersMenu: View {
    @Environment(\.openURL) private var openURL

    static let sources: [(name: String, url: URL)] = [
        ("Pexels", URL(string: "https://www.pexels.com/videos/")!),
        ("Pixabay", URL(string: "https://pixabay.com/videos/")!),
        ("Mixkit", URL(string: "https://mixkit.co/free-stock-video/")!),
    ]

    var body: some View {
        Menu {
            ForEach(Self.sources, id: \.name) { source in
                Button(source.name) { openURL(source.url) }
            }
        } label: {
            Label("Get Free Wallpapers", systemImage: "safari")
        }
        .help("Opens free, openly licensed video sites in your browser")
        .fixedSize()
    }
}
