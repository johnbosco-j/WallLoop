import Foundation
import Testing
@testable import WallLoop

struct SchedulerTests {
    private let videos = (1...5).map { URL(fileURLWithPath: "/videos/clip\($0).mp4") }

    @Test func shufflePlaysEveryVideoBeforeRepeating() {
        var scheduler = Scheduler(fileExists: { _ in true })
        let firstRound = (0..<videos.count).compactMap { _ in scheduler.next(from: videos, count: 1)?.first }
        #expect(Set(firstRound) == Set(videos))
    }

    @Test func shuffleNeverRepeatsBackToBack() {
        var scheduler = Scheduler(fileExists: { _ in true })
        var last: URL?
        for _ in 0..<50 {
            let pick = scheduler.next(from: videos, count: 1)?.first
            #expect(pick != last)
            last = pick
        }
    }

    @Test func inOrderWrapsAround() {
        var scheduler = Scheduler(fileExists: { _ in true })
        scheduler.order = .inOrder
        let picks = (0..<7).compactMap { _ in scheduler.next(from: videos, count: 1)?.first }
        #expect(picks == [videos[0], videos[1], videos[2], videos[3], videos[4], videos[0], videos[1]])
    }

    @Test func perDisplaySelectionsAreDistinct() {
        var scheduler = Scheduler(fileExists: { _ in true })
        let selection = scheduler.next(from: videos, count: 3) ?? []
        #expect(selection.count == 3)
        #expect(Set(selection).count == 3)
    }

    @Test func moreDisplaysThanVideosStillFillsEveryDisplay() {
        var scheduler = Scheduler(fileExists: { _ in true })
        #expect(scheduler.next(from: Array(videos.prefix(2)), count: 3)?.count == 3)
    }

    @Test func previousThenNextReplaysHistory() {
        var scheduler = Scheduler(fileExists: { _ in true })
        let a = scheduler.next(from: videos, count: 1)
        let b = scheduler.next(from: videos, count: 1)
        #expect(scheduler.previous() == a)
        #expect(scheduler.previous() == nil)
        #expect(scheduler.next(from: videos, count: 1) == b)
    }

    @Test func historySkipsDeletedFiles() {
        var deleted: Set<URL> = []
        var scheduler = Scheduler(fileExists: { !deleted.contains($0) })
        scheduler.order = .inOrder
        _ = scheduler.next(from: videos, count: 1)  // clip1
        _ = scheduler.next(from: videos, count: 1)  // clip2
        _ = scheduler.next(from: videos, count: 1)  // clip3
        deleted.insert(videos[1])
        #expect(scheduler.previous() == [videos[0]])
    }

    @Test func inOrderContinuesAfterCurrentVideoIsRemoved() {
        var scheduler = Scheduler(fileExists: { _ in true })
        scheduler.order = .inOrder
        _ = scheduler.next(from: videos, count: 1)  // clip1
        _ = scheduler.next(from: videos, count: 1)  // clip2
        let remaining = videos.filter { $0 != videos[1] }
        #expect(scheduler.next(from: remaining, count: 1) == [videos[2]])
    }

    @Test func extendCurrentAddsVideosForNewDisplays() {
        var scheduler = Scheduler(fileExists: { _ in true })
        let first = scheduler.next(from: videos, count: 1) ?? []
        let extended = scheduler.extendCurrent(to: 2, from: videos) ?? []
        #expect(extended.count == 2)
        #expect(extended.first == first.first)
        #expect(Set(extended).count == 2)
        #expect(scheduler.current == extended)
    }

    @Test func emptyLibraryPicksNothing() {
        var scheduler = Scheduler(fileExists: { _ in true })
        #expect(scheduler.next(from: [], count: 1) == nil)
        #expect(scheduler.current == nil)
    }

    @Test func chosenVideoBecomesCurrentAndPreviousReturnsToEarlier() {
        var scheduler = Scheduler(fileExists: { _ in true })
        let first = scheduler.next(from: videos, count: 1)
        scheduler.choose([videos[3]])
        #expect(scheduler.current == [videos[3]])
        #expect(scheduler.previous() == first)
    }
}
