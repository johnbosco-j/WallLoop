import SwiftUI

/// The video library: folders and the videos found in them. This is a simple
/// list for now; the Settings milestone replaces it with a thumbnail grid.
struct LibraryPane: View {
    let model: AppModel

    @State private var trashError: String?

    private var library: Library { model.library }

    var body: some View {
        Group {
            if library.videos.isEmpty, library.folders.count == 1, library.unsupported.isEmpty, !library.isScanning {
                emptyState
            } else {
                list
            }
        }
        .alert("Couldn't Move to Trash", isPresented: Binding(get: { trashError != nil }, set: { if !$0 { trashError = nil } })) {
            Button("OK") { trashError = nil }
        } message: {
            Text(trashError ?? "")
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Add Your Videos", systemImage: "film.stack")
        } description: {
            Text("Put your MP4, MOV or M4V videos in Movies › WallLoop, or give WallLoop access to another folder. WallLoop only reads the folders you choose, and nothing leaves your Mac.")
        } actions: {
            HStack(spacing: 12) {
                Button("Choose Folder…") { library.chooseFolders() }
                    .glassButtonStyle(prominent: true)
                Button("Show Movies › WallLoop") { NSWorkspace.shared.open(library.defaultFolder) }
                    .glassButtonStyle()
                FreeWallpapersMenu()
            }
            .controlSize(.large)
        }
    }

    private var list: some View {
        List {
            Section("Folders") {
                ForEach(library.folders) { folder in
                    FolderRow(folder: folder, library: library)
                }
            }

            Section {
                ForEach(library.videos, id: \.self) { url in
                    VideoRow(url: url, isPlaying: model.nowPlaying.contains(url))
                        .contextMenu { videoMenu(url) }
                }
            } header: {
                HStack {
                    Text("Videos")
                    if library.isScanning { ProgressView().controlSize(.small) }
                }
            }

            if !library.unsupported.isEmpty {
                Section {
                    DisclosureGroup("Can't Play (\(library.unsupported.count))") {
                        ForEach(library.unsupported.keys.sorted(by: Library.byName), id: \.self) { url in
                            LabeledContent(url.lastPathComponent, value: library.unsupported[url] ?? "")
                        }
                    }
                }
            }

            if !library.hiddenVideos.isEmpty {
                Section {
                    DisclosureGroup("Hidden (\(library.hiddenVideos.count))") {
                        ForEach(library.hiddenVideos, id: \.self) { url in
                            HStack {
                                Text(url.deletingPathExtension().lastPathComponent)
                                Spacer()
                                Button("Show Again") { library.unhide(url) }
                                    .buttonStyle(.link)
                            }
                        }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) { footer }
    }

    @ViewBuilder
    private func videoMenu(_ url: URL) -> some View {
        Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
        Divider()
        Button("Hide from Library") { library.hide(url) }
        if library.canMoveToTrash(url) {
            Button("Move to Trash") {
                Task {
                    do { try await library.moveToTrash(url) } catch { trashError = error.localizedDescription }
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Text("\(library.videos.count) videos")
                .foregroundStyle(.secondary)
            Spacer()
            FreeWallpapersMenu()
            Button("Add Folder…") { library.chooseFolders() }
                .glassButtonStyle()
        }
        .padding(12)
    }
}

private struct FolderRow: View {
    let folder: Library.Folder
    let library: Library

    var body: some View {
        HStack {
            Label {
                VStack(alignment: .leading) {
                    Text(folder.url.lastPathComponent)
                    Text(folder.displayPath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: folder.isAccessible ? "folder" : "exclamationmark.triangle")
                    .foregroundStyle(folder.isAccessible ? Color.accentColor : .orange)
            }
            Spacer()
            if !folder.isAccessible {
                Button("Re-add…") { library.chooseFolders() }
                    .help("WallLoop lost access to this folder. Choose it again to restore access.")
            }
            if folder.isDefault {
                Button("Show") { NSWorkspace.shared.open(folder.url) }
                    .buttonStyle(.link)
            } else {
                Button {
                    library.removeFolder(folder)
                } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.borderless)
                .help("Remove from Library. The folder and its videos stay on your Mac.")
            }
        }
    }
}

private struct VideoRow: View {
    let url: URL
    let isPlaying: Bool

    var body: some View {
        HStack {
            Label(url.deletingPathExtension().lastPathComponent, systemImage: "film")
            Spacer()
            if isPlaying {
                Image(systemName: "waveform")
                    .foregroundStyle(.tint)
                    .help("Now playing")
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
