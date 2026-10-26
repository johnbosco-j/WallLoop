import SwiftUI

/// The video library: what's playing now, a grid of every playable video, the
/// folders they come from, and anything that can't play. Drop videos or folders
/// anywhere on it to add them.
struct LibraryPane: View {
    let model: any PlaybackModel

    @State private var filter = LibraryFilter()
    @State private var isDropTargeted = false
    @State private var trashError: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var library: Library { model.library }

    /// Nothing added yet: show the first-run onboarding instead of an empty grid.
    private var isFirstRun: Bool {
        library.videos.isEmpty && library.folders.count == 1 && library.unsupported.isEmpty
            && library.hiddenVideos.isEmpty && !library.isScanning
    }

    var body: some View {
        Group {
            if isFirstRun {
                LibraryOnboarding(
                    chooseFolder: { library.chooseFolders() },
                    showDefaultFolder: { NSWorkspace.shared.open(library.defaultFolder) })
            } else {
                page
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            add(urls)
            return !urls.isEmpty
        } isTargeted: { targeted in
            withAnimation(reduceMotion ? nil : Theme.easeOut(Theme.fast)) { isDropTargeted = targeted }
        }
        .overlay {
            if isDropTargeted {
                DropOverlay().transition(.opacity)
            }
        }
        .alert("Couldn’t Move to Trash", isPresented: Binding(
            get: { trashError != nil }, set: { if !$0 { trashError = nil } }
        )) {
            Button("OK") { trashError = nil }
        } message: {
            Text(trashError ?? "")
        }
    }

    private var page: some View {
        let videos = filter.apply(to: library.videos, isFavorite: model.isFavorite)
        return PaneScroll {
            VStack(alignment: .leading, spacing: Theme.Space.xl) {
                HStack(alignment: .bottom) {
                    SectionHeader(label: "Library", before: "Your ", accent: "library",
                                  detail: LibraryCopy.summary(videos: library.videos.count,
                                                              folders: library.folders.count))
                    Spacer(minLength: Theme.Space.l)
                    HStack(spacing: Theme.Space.xs) {
                        FreeWallpapersMenu()
                        Button {
                            library.chooseFolders()
                        } label: {
                            Label("Add Folder…", systemImage: "plus")
                        }
                        .buttonStyle(.rivenSecondary)
                        .help("Give WallLoop access to a folder of videos")
                    }
                }

                if let video = model.nowPlaying.first {
                    NowPlayingHeroLoader(model: model, video: video)
                }

                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    HStack(spacing: Theme.Space.s) {
                        Text(filter.scope == .favorites ? "Favorites" : "Videos").microLabel(Theme.muted)
                        Text("\(videos.count)")
                            .font(Theme.mono(11, .medium))
                            .foregroundStyle(Theme.faint)
                        if library.isScanning {
                            ProgressView()
                                .controlSize(.small)
                                .accessibilityLabel("Scanning folders")
                        }
                        Spacer(minLength: Theme.Space.m)
                        RivenSearchField(prompt: "Search videos", text: $filter.query)
                            .frame(maxWidth: 220)
                        PillPicker(options: LibraryScope.allCases.map { ($0, $0 == .all ? "All" : "Favorites") },
                                   selection: $filter.scope, accessibilityLabel: "Show")
                    }

                    if videos.isEmpty {
                        emptyGrid
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 196, maximum: 280), spacing: Theme.Space.m)],
                                  alignment: .leading, spacing: Theme.Space.m) {
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

                FolderList(library: library)
                UnplayableSections(library: library)
            }
            .padding(.horizontal, Theme.Space.xl)
            .padding(.top, 44)
            .padding(.bottom, Theme.Space.xl)
            .animation(reduceMotion ? nil : Theme.easeInOut(Theme.medium), value: videos)
        }
        .background(RivenBackground(glow: UnitPoint(x: 0.22, y: 0.18), glowRadius: 460))
    }

    @ViewBuilder
    private var emptyGrid: some View {
        if !filter.query.isEmpty {
            EmptyNote(symbol: "magnifyingglass", title: "No videos match “\(filter.query)”",
                      detail: "Try another name, or clear the search.")
        } else if filter.scope == .favorites {
            EmptyNote(symbol: "heart", title: "No favorites yet",
                      detail: "Right-click a video and choose Add to Favorites, or use the heart in the menu bar.")
        } else {
            EmptyNote(symbol: "film", title: "No videos",
                      detail: "Add MP4, MOV or M4V files to one of your folders, or drop them here.")
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

/// Copy shared by the Library pane and its tests.
enum LibraryCopy {
    static func summary(videos: Int, folders: Int) -> String {
        let v = videos == 1 ? "1 video" : "\(videos) videos"
        let f = folders == 1 ? "1 folder" : "\(folders) folders"
        return "\(v) from \(f). Click one to play it on your desktop."
    }

    /// The hero's meta line, e.g. "Video 3 of 48 · Every hour · Shuffle".
    static func meta(position: Int?, count: Int, interval: ShuffleInterval, order: PlaybackOrder) -> String {
        var parts: [String] = []
        if let position, count > 0 { parts.append("Video \(position) of \(count)") }
        parts.append(interval == .never ? "Changes manually" : interval.phrase)
        parts.append(order.title)
        return parts.joined(separator: " · ")
    }
}

// MARK: - Now Playing hero

/// Loads the hero's thumbnail and wires it to the model.
private struct NowPlayingHeroLoader: View {
    let model: any PlaybackModel
    let video: URL

    @State private var thumbnail: NSImage?

    var body: some View {
        let library = model.library
        NowPlayingHero(
            name: video.deletingPathExtension().lastPathComponent,
            thumbnail: thumbnail,
            isPaused: model.isEffectivelyPaused,
            pauseReason: model.pauseReason?.title,
            isFavorite: model.isFavorite(video),
            meta: LibraryCopy.meta(position: library.videos.firstIndex(of: video).map { $0 + 1 },
                                   count: library.videos.count,
                                   interval: model.settings.shuffleInterval,
                                   order: model.settings.playbackOrder),
            otherDisplays: max(0, model.nowPlaying.count - 1),
            previous: model.previous,
            togglePause: model.togglePause,
            next: model.next,
            toggleFavorite: { model.toggleFavorite(video) },
            reveal: { NSWorkspace.shared.activateFileViewerSelecting([video]) })
        .task(id: video) { thumbnail = await library.thumbnail(for: video) }
    }
}

/// The large "Now playing" panel at the top of the library.
struct NowPlayingHero: View {
    let name: String
    let thumbnail: NSImage?
    let isPaused: Bool
    let pauseReason: String?
    let isFavorite: Bool
    let meta: String
    let otherDisplays: Int
    let previous: () -> Void
    let togglePause: () -> Void
    let next: () -> Void
    let toggleFavorite: () -> Void
    let reveal: () -> Void

    var body: some View {
        Panel(padding: Theme.Space.m) {
            HStack(alignment: .center, spacing: Theme.Space.l) {
                poster
                    .frame(width: 336)

                VStack(alignment: .leading, spacing: Theme.Space.s) {
                    if isPaused {
                        Chip(text: "Paused", tone: .muted, dot: true)
                    } else {
                        Chip(text: "Now playing", tone: .accent, dot: true)
                    }
                    Text(name)
                        .font(Theme.sans(26, .semibold))
                        .tracking(-0.5)
                        .foregroundStyle(Theme.ink)
                        .lineLimit(2)
                        .truncationMode(.middle)
                    if let pauseReason {
                        Text("Paused automatically: \(pauseReason.lowercased()).")
                            .font(Theme.sans(13))
                            .foregroundStyle(Theme.muted)
                    }
                    Text(meta)
                        .font(Theme.mono(11))
                        .foregroundStyle(Theme.faint)
                    if otherDisplays > 0 {
                        Text("+\(otherDisplays) more on other displays")
                            .font(Theme.mono(11))
                            .foregroundStyle(Theme.faint)
                    }

                    HStack(spacing: Theme.Space.xs) {
                        Button(action: toggleFavorite) {
                            Label(isFavorite ? "Favorited" : "Favorite",
                                  systemImage: isFavorite ? "heart.fill" : "heart")
                        }
                        .buttonStyle(.rivenSecondary)
                        .accessibilityLabel(isFavorite ? "Remove from Favorites" : "Add to Favorites")
                        Button("Show in Finder", action: reveal)
                            .buttonStyle(.rivenGhost)
                    }
                    .padding(.top, Theme.Space.xs)
                }
                .frame(minWidth: 220, maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var poster: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
        return Color.clear
            .aspectRatio(16 / 9, contentMode: .fit)
            .overlay {
                if let thumbnail {
                    Image(nsImage: thumbnail).resizable().scaledToFill()
                } else {
                    PosterPlaceholder()
                }
            }
            .clipShape(shape)
            .overlay(shape.strokeBorder(Theme.line, lineWidth: 1))
            .overlay(alignment: .bottom) {
                HStack(spacing: 2) {
                    Button(action: previous) { Image(systemName: "backward.fill") }
                        .buttonStyle(RivenIconButtonStyle(diameter: 30))
                        .accessibilityLabel("Previous")
                    Button(action: togglePause) { Image(systemName: isPaused ? "play.fill" : "pause.fill") }
                        .buttonStyle(RivenIconButtonStyle(diameter: 38, prominent: true))
                        .accessibilityLabel(isPaused ? "Play" : "Pause")
                    Button(action: next) { Image(systemName: "forward.fill") }
                        .buttonStyle(RivenIconButtonStyle(diameter: 30))
                        .accessibilityLabel("Next")
                }
                .padding(4)
                .glassCapsule()
                .padding(.bottom, Theme.Space.s)
            }
    }
}

// MARK: - Video tile

/// Loads a tile's thumbnail and shows it as a `VideoCard`.
private struct VideoTile: View {
    let video: URL
    let library: Library
    let isPlaying: Bool
    let isFavorite: Bool
    let play: () -> Void
    let toggleFavorite: () -> Void

    @State private var thumbnail: NSImage?

    var body: some View {
        VideoCard(name: video.deletingPathExtension().lastPathComponent, thumbnail: thumbnail,
                  isPlaying: isPlaying, isFavorite: isFavorite, play: play, toggleFavorite: toggleFavorite)
            .task(id: video) { thumbnail = await library.thumbnail(for: video) }
    }
}

/// One video in the grid: a Riven card that lifts on hover. The playing video gets an
/// accent ring and badge; favorites get a rose heart.
struct VideoCard: View {
    let name: String
    let thumbnail: NSImage?
    let isPlaying: Bool
    let isFavorite: Bool
    let play: () -> Void
    let toggleFavorite: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    var body: some View {
        Button(action: play) {
            VStack(alignment: .leading, spacing: 10) {
                artwork
                HStack(spacing: 6) {
                    Text(name)
                        .font(Theme.sans(13, .medium))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 0)
                    if isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                            .accessibilityHidden(true)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 4)
            }
            .padding(8)
            .rivenSurface(radius: Theme.Radius.card, hovered: isHovered, selected: isPlaying)
            .offset(y: isHovered && !reduceMotion ? -4 : 0)
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(reduceMotion ? nil : Theme.easeOut(Theme.medium), value: isHovered)
        .accessibilityLabel(name)
        .accessibilityValue([isPlaying ? "Now playing" : nil, isFavorite ? "Favorite" : nil]
            .compactMap { $0 }.joined(separator: ", "))
        .accessibilityHint("Plays this video as your wallpaper")
        .accessibilityAction(named: isFavorite ? "Remove from Favorites" : "Add to Favorites", toggleFavorite)
    }

    private var artwork: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.input, style: .continuous)
        return Color.clear
            .aspectRatio(16 / 9, contentMode: .fit)
            .overlay {
                if let thumbnail {
                    Image(nsImage: thumbnail).resizable().scaledToFill()
                } else {
                    PosterPlaceholder()
                }
            }
            .clipShape(shape)
            .overlay(alignment: .topLeading) {
                if isPlaying {
                    OverlayBadge(text: "Now playing", dot: Theme.accent).padding(8)
                }
            }
            .overlay {
                if isHovered && !isPlaying {
                    Image(systemName: "play.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 40, height: 40)
                        .glassCapsule()
                        .transition(.opacity)
                }
            }
    }
}

/// A small badge over imagery: mono text on dark glass, with an optional status dot.
struct OverlayBadge: View {
    let text: String
    var dot: Color?

    var body: some View {
        HStack(spacing: 6) {
            if let dot { Circle().fill(dot).frame(width: 6, height: 6) }
            Text(text)
                .font(Theme.mono(10, .medium))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(Theme.ink)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .glassCapsule()
    }
}

/// Shown while a thumbnail loads: the surface with a faint film glyph.
struct PosterPlaceholder: View {
    var body: some View {
        ZStack {
            Theme.surface2
            Image(systemName: "film")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(Theme.faint)
        }
    }
}

// MARK: - Empty notes

private struct EmptyNote: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        Card(padding: Theme.Space.xl) {
            VStack(spacing: Theme.Space.xs) {
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(Theme.faint)
                    .padding(.bottom, 4)
                Text(title)
                    .font(Theme.sans(15, .semibold))
                    .foregroundStyle(Theme.ink)
                Text(detail)
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Onboarding

/// First run: Loopy, three steps and the buttons to add videos.
struct LibraryOnboarding: View {
    let chooseFolder: () -> Void
    let showDefaultFolder: () -> Void

    var body: some View {
        PaneScroll {
            VStack(spacing: Theme.Space.l) {
                BrandMark()
                    .frame(width: 210, height: 210)
                    .accessibilityHidden(true)
                    .entrance(0)

                VStack(spacing: Theme.Space.xs) {
                    Text("Welcome to WallLoop").microLabel()
                    AccentHeading(before: "Add your ", accent: "videos", after: ".", size: 40)
                    Text("WallLoop turns your own videos into a live wallpaper. Nothing leaves your Mac.")
                        .font(Theme.sans(15))
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)
                }
                .entrance(1)

                Card(padding: 0) {
                    VStack(spacing: 0) {
                        step("01", "Put MP4, MOV or M4V videos in a folder.")
                        Hairline().padding(.leading, 64)
                        step("02", "Choose that folder so WallLoop can read it.")
                        Hairline().padding(.leading, 64)
                        step("03", "Your desktop comes alive.")
                    }
                }
                .frame(maxWidth: 460)
                .entrance(2)

                HStack(spacing: Theme.Space.s) {
                    Button("Choose Folder…", action: chooseFolder)
                        .buttonStyle(.riven(.primary, size: .large))
                        .keyboardShortcut(.defaultAction)
                    Button("Show Movies › WallLoop", action: showDefaultFolder)
                        .buttonStyle(.riven(.secondary, size: .large))
                }
                .entrance(3)

                FreeWallpapersMenu(style: .ghost)
                    .entrance(3)

                Text("Or drop videos or folders anywhere here")
                    .microLabel()
                    .entrance(4)
            }
            .padding(48)
            .frame(maxWidth: .infinity)
        }
        .background(RivenBackground())
    }

    private func step(_ number: String, _ text: String) -> some View {
        HStack(spacing: Theme.Space.m) {
            Text(number)
                .font(Theme.mono(13, .medium))
                .foregroundStyle(Theme.accent)
                .frame(width: 32, alignment: .leading)
            Text(text)
                .font(Theme.sans(14))
                .foregroundStyle(Theme.ink)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Space.l)
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Folders

private struct FolderList: View {
    let library: Library

    var body: some View {
        Card(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Folders")
                    .microLabel(Theme.muted)
                    .padding(.horizontal, Theme.Space.l)
                    .padding(.top, Theme.Space.m)
                    .padding(.bottom, Theme.Space.xs)
                ForEach(Array(library.folders.enumerated()), id: \.element.id) { index, folder in
                    if index > 0 { Hairline().padding(.leading, 70) }
                    FolderRow(folder: folder, library: library)
                }
            }
            .padding(.bottom, Theme.Space.xs)
        }
    }
}

private struct FolderRow: View {
    let folder: Library.Folder
    let library: Library

    var body: some View {
        HStack(spacing: Theme.Space.s) {
            Image(systemName: folder.isAccessible ? (folder.isDefault ? "film.stack" : "folder") : "exclamationmark.triangle")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(folder.isAccessible ? Theme.ink : Theme.amber)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.surface2))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(folder.isDefault ? "Movies › WallLoop" : folder.url.lastPathComponent)
                    .font(Theme.sans(13.5, .medium))
                    .foregroundStyle(Theme.ink)
                Text(folder.isAccessible ? folder.displayPath : "WallLoop can’t open this folder. Choose it again.")
                    .font(Theme.mono(11))
                    .foregroundStyle(folder.isAccessible ? Theme.faint : Theme.amber)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .accessibilityElement(children: .combine)

            Spacer()

            if !folder.isAccessible {
                Button("Choose Again…") { library.chooseFolders() }
                    .buttonStyle(.riven(.secondary, size: .small))
            }
            Button {
                NSWorkspace.shared.open(folder.url)
            } label: {
                Image(systemName: "arrow.up.forward")
            }
            .buttonStyle(RivenIconButtonStyle(diameter: 28))
            .help("Show in Finder")
            .accessibilityLabel("Show \(folder.url.lastPathComponent) in Finder")
            .disabled(!folder.isAccessible)

            if !folder.isDefault {
                Button {
                    library.removeFolder(folder)
                } label: {
                    Image(systemName: "minus")
                }
                .buttonStyle(RivenIconButtonStyle(diameter: 28))
                .help("Remove from Library. The folder and its videos stay on your Mac.")
                .accessibilityLabel("Remove \(folder.url.lastPathComponent) from Library")
            }
        }
        .padding(.horizontal, Theme.Space.l)
        .padding(.vertical, Theme.Space.s)
    }
}

// MARK: - Can't play / hidden

private struct UnplayableSections: View {
    let library: Library

    var body: some View {
        if !library.unsupported.isEmpty {
            DisclosureCard(title: "Can’t play", count: library.unsupported.count, tone: .warning) {
                ForEach(library.unsupported.keys.sorted(by: Library.byName), id: \.self) { url in
                    HStack(alignment: .firstTextBaseline) {
                        Text(url.lastPathComponent)
                            .font(Theme.sans(13))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Text(library.unsupported[url] ?? "")
                            .font(Theme.mono(11))
                            .foregroundStyle(Theme.faint)
                            .multilineTextAlignment(.trailing)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        if !library.hiddenVideos.isEmpty {
            DisclosureCard(title: "Hidden", count: library.hiddenVideos.count, tone: .muted) {
                ForEach(library.hiddenVideos, id: \.self) { url in
                    HStack {
                        Text(url.deletingPathExtension().lastPathComponent)
                            .font(Theme.sans(13))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                        Spacer()
                        Button("Show Again") { library.unhide(url) }
                            .buttonStyle(.riven(.ghost, size: .small))
                    }
                }
            }
        }
    }
}

/// A card whose body folds away behind a mono header.
private struct DisclosureCard<Content: View>: View {
    let title: String
    let count: Int
    let tone: Chip.Tone
    @ViewBuilder var content: Content

    @State private var isExpanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Card(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    withAnimation(reduceMotion ? nil : Theme.easeInOut(Theme.medium)) { isExpanded.toggle() }
                } label: {
                    HStack(spacing: Theme.Space.s) {
                        Text(title).microLabel(Theme.muted)
                        Chip(text: "\(count)", tone: tone)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.faint)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    }
                    .padding(.horizontal, Theme.Space.l)
                    .padding(.vertical, Theme.Space.m)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(title), \(count)")
                .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")

                if isExpanded {
                    Hairline()
                    VStack(alignment: .leading, spacing: 10) { content }
                        .padding(.horizontal, Theme.Space.l)
                        .padding(.vertical, Theme.Space.m)
                }
            }
        }
    }
}

// MARK: - Drop overlay

private struct DropOverlay: View {
    var body: some View {
        ZStack {
            Theme.bg.opacity(0.8)
            RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous)
                .strokeBorder(Theme.accent, style: StrokeStyle(lineWidth: 1.5, dash: [8, 6]))
                .padding(Theme.Space.m)
            VStack(spacing: Theme.Space.s) {
                BrandMark(parts: [.orbit, .buddy, .face])
                    .frame(width: 84, height: 84)
                AccentHeading(before: "Drop to add to ", accent: "WallLoop", size: 24)
                Text("Videos are copied into Movies › WallLoop. Folders are added as they are.")
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.muted)
            }
            .padding(Theme.Space.xl)
            .glassSurface(cornerRadius: Theme.Radius.panel)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
