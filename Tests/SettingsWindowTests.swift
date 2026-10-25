import Foundation
import KeyboardShortcuts
import Testing
@testable import WallLoop

struct LibraryFilterTests {
    private let videos = ["Ocean Waves", "City Lights", "ocean sunset", "Forest"].map {
        URL(fileURLWithPath: "/videos/\($0).mp4")
    }

    @Test func emptyQueryShowsEverything() {
        #expect(LibraryFilter().apply(to: videos, isFavorite: { _ in false }) == videos)
    }

    @Test func searchMatchesNameIgnoringCaseAndExtension() {
        let filter = LibraryFilter(query: "  OCEAN ")
        #expect(filter.apply(to: videos, isFavorite: { _ in false }) == [videos[0], videos[2]])
        #expect(LibraryFilter(query: "mp4").apply(to: videos, isFavorite: { _ in false }).isEmpty)
    }

    @Test func favoritesScopeCombinesWithSearch() {
        let favorites: Set<URL> = [videos[1], videos[2]]
        var filter = LibraryFilter(scope: .favorites)
        #expect(filter.apply(to: videos, isFavorite: favorites.contains) == [videos[1], videos[2]])
        filter.query = "ocean"
        #expect(filter.apply(to: videos, isFavorite: favorites.contains) == [videos[2]])
    }
}

@MainActor
struct ShortcutDefaultsTests {
    @Test func defaultsAreDistinctAndUseThreeModifiers() {
        let shortcuts = Shortcuts.all.compactMap(\.name.initialShortcut)
        #expect(shortcuts.count == 3)
        #expect(Set(shortcuts.map(\.description)).count == 3)
        for shortcut in shortcuts {
            #expect(shortcut.modifiers.contains([.control, .option, .command]))
        }
    }
}
