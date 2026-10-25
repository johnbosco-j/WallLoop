import SwiftUI

/// The video library: a thumbnail grid of every playable video, the folders
/// they come from, and anything that can't play. Drop videos or folders
/// anywhere on it to add them.
struct LibraryPane: View {
    let model: AppModel

    @State private var filter = LibraryFilter()
    @State private var isDropTargeted = false
    @State private var trashError: String?

    private var library: Library { model.library }

    /// Nothing added yet: show the first-run onboarding instead of an empty grid.
    private var isFirstRun: Bool {
        library.videos.isEmpty && library.folders.count == 1 && library.unsupported.isEmpty
            && library.hiddenVideos.isEmpty && !library.isScanning
    }

    var body: some View {
        Group {
            if isFirstRun {
                LibraryOnboarding(library: library)
            } else {
                grid
            }
        }
        .toolbar {
            ToolbarItem {
                Picker("Show", selection: $filter.scope) {
                    ForEach(LibraryScope.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .help("Show all videos or only favorites")
            }
            ToolbarItem {
                FreeWallpapersMenu()
            }
            ToolbarItem {
                Button {
                    library.chooseFolders()
                } label: {
                    Label("Add Folder…", systemImage: "folder.badge.plus")
                }
                .help("Give WallLoop access to a folder of videos")
            }
        }
        .searchable(text: $filter.query, placement: .toolbar, prompt: "Search Videos")
        .dropDestination(for: URL.self) { urls, _ in
            add(urls)
            return !urls.isEmpty
        } isTargeted: { targeted in
            withAnimation(.smooth(duration: 0.2)) { isDropTargeted = targeted }
        }
        .overlay {
            if isDropTargeted {
                DropOverlay()
                    .transition(.opacity)
            }
        }
        .alert("Couldn't Move to Trash", isPresented: Binding(
            get: { trashError != nil }, set: { if !$0 { trashError = nil } }
        )) {
            Button("OK") { trashError = nil }
        } message: {
            Text(trashError ?? "")
        }
    }

    private var grid: some View {
        let videos = filter.apply(to: library.videos, isFavorite: model.isFavorite)
        return ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                FolderList(library: library)

                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Text(filter.scope == .favorites ? "Favorites" : "Videos")
                            .font(.title3.weight(.semibold))
                        Text("\(videos.count)")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        if library.isScanning {
                            ProgressView()
                                .controlSize(.small)
                                .accessibilityLabel("Scanning folders")
                        }
                    }

                    if videos.isEmpty {
                        emptyGrid
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200, maximum: 300), spacing: 20)],
                                  alignment: .leading, spacing: 24) {
                            ForEach(videos, id: \.self) { video in
                                VideoTile(
                                    video: video,
                                    library: library,
                                    isPlaying: model.nowPlaying.contains(video),
                                    isFavorite: model.isFavorite(video),
                                    play: { model.play(video) },
                                    toggleFavorite: { model.toggleFavorite(video) }
                                )
                                .contextMenu { menu(for: video) }
                            }
                        }
                    }
                }

                UnplayableSections(library: library)
            }
            .padding(24)
            .animation(.smooth, value: videos)
        }
    }

    @ViewBuilder
    private var emptyGrid: some View {
        if !filter.query.isEmpty {
            ContentUnavailableView.search(text: filter.query)
        } else if filter.scope == .favorites {
            ContentUnavailableView {
                Label("No Favorites Yet", systemImage: "heart")
            } description: {
                Text("Right-click a video and choose Favorite, or use the heart in the menu bar.")
            }
        } else {
            ContentUnavailableView {
                Label("No Videos", systemImage: "film.stack")
            } description: {
                Text("Add MP4, MOV or M4V files to one of your folders, or drop them here.")
            }
        }
    }

    @ViewBuilder
    private func menu(for video: URL) -> some View {
        Button("Play") { model.play(video) }
        Button(model.isFavorite(video) ? "Remove from Favorites" : "Add to Favorites") {
            model.toggleFavorite(video)
        }
        Divider()
        Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([video]) }
        Divider()
        Button("Hide from Library") { library.hide(video) }
        if library.canMoveToTrash(video) {
            Button("Move to Trash") {
                Task {
                    do { try await library.moveToTrash(video) } catch { trashError = error.localizedDescription }
                }
            }
        }
    }

    /// Folders become library folders; files are copied into Movies › WallLoop.
    private func add(_ urls: [URL]) {
        var folders: [URL] = []
        var files: [URL] = []
        for url in urls where url.isFileURL {
            let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if isDirectory { folders.append(url) } else { files.append(url) }
        }
        if !folders.isEmpty { library.addFolders(folders) }
        if !files.isEmpty { Task { await library.importVideos(files) } }
    }
}

// MARK: - Onboarding

private struct LibraryOnboarding: View {
    let library: Library

    var body: some View {
        ZStack {
            Backdrop()

            VStack(spacing: 22) {
                Image(systemName: "play.rectangle.on.rectangle.fill")
                    .font(.system(size: 52, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Text("Add Your Videos")
                        .font(.largeTitle.weight(.semibold))
                    Text("WallLoop turns your own videos into a live wallpaper.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    step(1, "Put MP4, MOV or M4V videos in a folder.")
                    step(2, "Choose that folder so WallLoop can read it.")
                    step(3, "Your desktop comes alive. Nothing leaves your Mac.")
                }
                .padding(.vertical, 4)

                HStack(spacing: 12) {
                    Button("Choose Folder…") { library.chooseFolders() }
                        .glassButtonStyle(prominent: true)
                        .keyboardShortcut(.defaultAction)
                    Button("Show Movies › WallLoop") { NSWorkspace.shared.open(library.defaultFolder) }
                        .glassButtonStyle()
                }
                .controlSize(.large)

                Text("Or drop videos or folders here.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            .padding(40)
            .frame(maxWidth: 520)
            .glassSurface(cornerRadius: 32)
            .padding(32)
        }
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(number)")
                .font(.callout.weight(.semibold))
                .monospacedDigit()
                .frame(width: 24, height: 24)
                .background(.tint.opacity(0.18), in: .circle)
            Text(text)
                .font(.body)
                .multilineTextAlignment(.leading)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Video tile

private struct VideoTile: View {
    let video: URL
    let library: Library
    let isPlaying: Bool
    let isFavorite: Bool
    let play: () -> Void
    let toggleFavorite: () -> Void

    @State private var thumbnail: NSImage?
    @State private var isHovered = false

    private var name: String { video.deletingPathExtension().lastPathComponent }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: play) {
                artwork
            }
            .buttonStyle(.plain)
            .accessibilityLabel(name)
            .accessibilityValue([isPlaying ? "Now playing" : nil, isFavorite ? "Favorite" : nil]
                .compactMap { $0 }.joined(separator: ", "))
            .accessibilityHint("Plays this video as your wallpaper")
            .accessibilityAction(named: isFavorite ? "Remove from Favorites" : "Add to Favorites", toggleFavorite)

            Text(name)
                .font(.callout)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(isPlaying ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
                .accessibilityHidden(true)
        }
        .task(id: video) {
            thumbnail = await library.thumbnail(for: video)
        }
    }

    private var artwork: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        return Color.clear
            .aspectRatio(16 / 9, contentMode: .fit)
            .overlay {
                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                } else {
                    ZStack {
                        Rectangle().fill(.quaternary)
                        Image(systemName: "film")
                            .font(.title)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(isPlaying ? Color.accentColor : Color.primary.opacity(0.08),
                                   lineWidth: isPlaying ? 3 : 1)
            }
            .overlay(alignment: .topLeading) {
                if isPlaying {
                    Label("Now Playing", systemImage: "waveform")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .glassCapsule()
                        .padding(8)
                }
            }
            .overlay(alignment: .topTrailing) {
                if isFavorite {
                    Image(systemName: "heart.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.pink)
                        .padding(7)
                        .glassCapsule()
                        .padding(8)
                }
            }
            .shadow(color: .black.opacity(isHovered ? 0.25 : 0.12), radius: isHovered ? 12 : 5, y: isHovered ? 6 : 2)
            .scaleEffect(isHovered ? 1.025 : 1)
            .animation(.smooth(duration: 0.2), value: isHovered)
            .animation(.smooth, value: thumbnail != nil)
            .onHover { isHovered = $0 }
            .contentShape(shape)
    }
}

// MARK: - Folders

private struct FolderList: View {
    let library: Library

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Folders")
                .font(.title3.weight(.semibold))

            GroupBox {
                VStack(spacing: 0) {
                    ForEach(Array(library.folders.enumerated()), id: \.element.id) { index, folder in
                        if index > 0 { Divider().padding(.leading, 36) }
                        FolderRow(folder: folder, library: library)
                            .padding(.vertical, 8)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
}

private struct FolderRow: View {
    let folder: Library.Folder
    let library: Library

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: folder.isAccessible ? (folder.isDefault ? "film.stack" : "folder") : "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(folder.isAccessible ? Color.accentColor : .orange)
                .frame(width: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(folder.isDefault ? "Movies › WallLoop" : folder.url.lastPathComponent)
                Text(folder.isAccessible ? folder.displayPath : "WallLoop can't open this folder. Choose it again to restore access.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .accessibilityElement(children: .combine)

            Spacer()

            if !folder.isAccessible {
                Button("Choose Again…") { library.chooseFolders() }
            }
            Button {
                NSWorkspace.shared.open(folder.url)
            } label: {
                Image(systemName: "arrow.forward.circle")
            }
            .buttonStyle(.borderless)
            .help("Show in Finder")
            .accessibilityLabel("Show \(folder.url.lastPathComponent) in Finder")
            .disabled(!folder.isAccessible)

            if !folder.isDefault {
                Button {
                    library.removeFolder(folder)
                } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.borderless)
                .help("Remove from Library. The folder and its videos stay on your Mac.")
                .accessibilityLabel("Remove \(folder.url.lastPathComponent) from Library")
            }
        }
    }
}

// MARK: - Can't play / hidden

private struct UnplayableSections: View {
    let library: Library

    var body: some View {
        if !library.unsupported.isEmpty || !library.hiddenVideos.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                if !library.unsupported.isEmpty {
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(library.unsupported.keys.sorted(by: Library.byName), id: \.self) { url in
                                LabeledContent(url.lastPathComponent, value: library.unsupported[url] ?? "")
                            }
                        }
                        .padding(.top, 6)
                    } label: {
                        Label("Can't Play (\(library.unsupported.count))", systemImage: "exclamationmark.triangle")
                    }
                }
                if !library.hiddenVideos.isEmpty {
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(library.hiddenVideos, id: \.self) { url in
                                HStack {
                                    Text(url.deletingPathExtension().lastPathComponent)
                                    Spacer()
                                    Button("Show Again") { library.unhide(url) }
                                        .buttonStyle(.link)
                                }
                            }
                        }
                        .padding(.top, 6)
                    } label: {
                        Label("Hidden (\(library.hiddenVideos.count))", systemImage: "eye.slash")
                    }
                }
            }
        }
    }
}

// MARK: - Drop overlay

private struct DropOverlay: View {
    var body: some View {
        ZStack {
            Rectangle().fill(.tint.opacity(0.08))
            Label("Drop to Add to WallLoop", systemImage: "plus.rectangle.on.folder")
                .font(.title2.weight(.semibold))
                .padding(.horizontal, 28)
                .padding(.vertical, 18)
                .glassSurface(cornerRadius: 22)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.tint, style: StrokeStyle(lineWidth: 3, dash: [10, 6]))
                .padding(10)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
