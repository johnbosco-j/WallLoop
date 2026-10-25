import Foundation

/// Which videos the library grid shows.
enum LibraryScope: String, CaseIterable, Identifiable {
    case all, favorites

    var id: Self { self }

    var title: String {
        switch self {
        case .all: "All Videos"
        case .favorites: "Favorites"
        }
    }
}

/// Filters the library grid by scope and a search query on the video name.
struct LibraryFilter: Equatable {
    var query = ""
    var scope = LibraryScope.all

    func apply(to videos: [URL], isFavorite: (URL) -> Bool) -> [URL] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return videos.filter { video in
            (scope == .all || isFavorite(video))
                && (query.isEmpty || video.deletingPathExtension().lastPathComponent.localizedStandardContains(query))
        }
    }
}
