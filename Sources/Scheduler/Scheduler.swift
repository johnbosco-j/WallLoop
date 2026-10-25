import Foundation

/// Decides what plays next and remembers what played before.
///
/// A *selection* is the set of videos on screen at once: one video in "same on
/// all displays" mode, or one per display. The scheduler is a plain value type
/// so it is easy to test; `AppModel` owns the timer that drives it.
struct Scheduler {
    typealias Selection = [URL]

    static let historyLimit = 200

    var order: PlaybackOrder = .shuffle
    private(set) var history: [Selection] = []
    private(set) var index = -1
    /// Shuffled videos still to play, so every video plays once before any repeats.
    private var deck: [URL] = []
    private let fileExists: (URL) -> Bool

    init(fileExists: @escaping (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }) {
        self.fileExists = fileExists
    }

    var current: Selection? { history.indices.contains(index) ? history[index] : nil }

    /// Moves forward. After going back, this replays history; otherwise it picks new videos.
    /// Entries whose files were deleted are skipped.
    mutating func next(from videos: [URL], count: Int) -> Selection? {
        while index < history.count - 1 {
            index += 1
            if history[index].allSatisfy(fileExists) { return history[index] }
        }
        guard !videos.isEmpty else { return nil }

        let selection = pick(count, from: videos, after: current?.last, avoiding: Set(current ?? []))
        history.append(selection)
        if history.count > Self.historyLimit {
            history.removeFirst(history.count - Self.historyLimit)
        }
        index = history.count - 1
        return selection
    }

    /// Moves back to the most recent earlier selection whose files all still exist.
    mutating func previous() -> Selection? {
        for i in stride(from: index - 1, through: 0, by: -1) where history[i].allSatisfy(fileExists) {
            index = i
            return history[i]
        }
        return nil
    }

    /// Adds videos to the current selection, for when a display is connected.
    mutating func extendCurrent(to count: Int, from videos: [URL]) -> Selection? {
        guard var selection = current, selection.count < count, !videos.isEmpty else { return nil }
        selection += pick(count - selection.count, from: videos, after: selection.last, avoiding: Set(selection))
        history[index] = selection
        return selection
    }

    private mutating func pick(_ count: Int, from videos: [URL], after last: URL?, avoiding: Set<URL>) -> Selection {
        switch order {
        case .shuffle:
            return draw(count, from: videos, avoiding: avoiding)
        case .inOrder:
            let start = last.map { last in
                videos.firstIndex(of: last).map { $0 + 1 }
                    // The last video was removed: continue from where its name would sort.
                    ?? videos.firstIndex { $0.lastPathComponent.localizedStandardCompare(last.lastPathComponent) == .orderedDescending }
                    ?? 0
            } ?? 0
            return (0..<count).map { videos[(start + $0) % videos.count] }
        }
    }

    private mutating func draw(_ count: Int, from videos: [URL], avoiding: Set<URL>) -> Selection {
        let available = Set(videos)
        deck.removeAll { !available.contains($0) }

        var picked: Selection = []
        while picked.count < count {
            let isFresh = { (url: URL) in !avoiding.contains(url) && !picked.contains(url) }
            var i = deck.firstIndex(where: isFresh)
            if i == nil {
                deck += videos.shuffled()
                i = deck.firstIndex(where: isFresh)
            }
            // With fewer videos than displays, repeats are unavoidable.
            picked.append(deck.remove(at: i ?? 0))
        }
        return picked
    }
}
