import AppKit
import Testing
@testable import WallLoop

struct LibraryCopyTests {
    @Test func summaryPluralizes() {
        #expect(LibraryCopy.summary(videos: 1, folders: 1) == "1 video from 1 folder. Click one to play it on your desktop.")
        #expect(LibraryCopy.summary(videos: 48, folders: 2) == "48 videos from 2 folders. Click one to play it on your desktop.")
    }

    @Test func heroMetaLine() {
        #expect(LibraryCopy.meta(position: 3, count: 48, interval: .daily, order: .shuffle)
            == "Video 3 of 48 · Every day · Shuffle")
        #expect(LibraryCopy.meta(position: nil, count: 48, interval: .never, order: .inOrder)
            == "Changes manually · In Order")
    }
}

struct NowPlayingMetaTests {
    @Test func metaMentionsOtherDisplays() {
        #expect(NowPlayingView.meta(interval: .daily, order: .inOrder, otherDisplays: 0) == "Every day · In Order")
        #expect(NowPlayingView.meta(interval: .never, order: .shuffle, otherDisplays: 1)
            == "Changes manually · Shuffle · +1 display")
        #expect(NowPlayingView.meta(interval: .daily, order: .shuffle, otherDisplays: 2).hasSuffix("+2 displays"))
    }
}

struct AboutCopyTests {
    @Test func versionReadsBundleInfo() {
        #expect(AboutCopy.version(["CFBundleShortVersionString": "0.1.0", "CFBundleVersion": "7"]) == "v0.1.0 · build 7")
        #expect(AboutCopy.version(nil) == "v? · build ?")
    }

    @Test func creditNamesTheFounderWithoutPronouns() {
        #expect(AboutCopy.credit == "Carved by Johnbosco J Elanjikal, founder of Riven")
        #expect(AboutCopy.studio == "Built by RivenDevs")
    }
}

@MainActor
struct StatusIconTests {
    @Test func iconsAreTemplatesAtMenuBarSize() {
        for paused in [false, true] {
            let image = StatusIcon.image(paused: paused)
            #expect(image.isTemplate)
            #expect(image.size == NSSize(width: 18, height: 18))
            #expect(image.accessibilityDescription == (paused ? "WallLoop, paused" : "WallLoop"))
        }
    }
}
