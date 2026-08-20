import Testing

@testable import FeedUI

import SecretDJDomain

/// ``FeedDisplayModel/currentSong`` — the kiosk now-playing header's own
/// extraction (PLAN.md S7.4): `playhistory`'s response lists the venue's
/// current song first, its recent-play history after
/// (LEGACY.md "Now Playing / play history"), so the first ``Song`` item
/// across the feed's visible sections, in server order, is the one playing
/// right now.
enum FeedDisplayModelCurrentSongTests {
	struct `Current song` {
		@Test func `is nil for a feed with no song items`() {
			let displayModel = FeedDisplayModel(sectionList: makeEmptySectionList(hash: "h1"))

			#expect(displayModel.currentSong == nil)
		}

		@Test func `is the first song across a single section`() {
			let songs = [makeFeedSong(songId: "1"), makeFeedSong(songId: "2")]
			let displayModel = FeedDisplayModel(sectionList: makeLoadedSectionList(hash: "h1", items: songs))

			#expect(displayModel.currentSong?.songId == "1")
		}

		@Test func `is the first song across multiple sections, in server order`() {
			let sectionList = SectionList(
				hash: FeedHash(rawValue: "h1"),
				sections: [
					makeFeedSection(template: .song, index: 0, items: [.song(makeFeedSong(songId: "1"))]),
					makeFeedSection(template: .song, index: 1, items: [.song(makeFeedSong(songId: "2"))]),
				],
				actions: [],
			)
			let displayModel = FeedDisplayModel(sectionList: sectionList)

			#expect(displayModel.currentSong?.songId == "1")
		}

		@Test func `skips a hidden section's own song items`() {
			let sectionList = SectionList(
				hash: FeedHash(rawValue: "h1"),
				sections: [
					makeFeedSection(
						template: .hiddenExtraContentSong,
						index: 0,
						items: [.song(makeFeedSong(songId: "hidden"))],
					),
					makeFeedSection(template: .song, index: 1, items: [.song(makeFeedSong(songId: "1"))]),
				],
				actions: [],
			)
			let displayModel = FeedDisplayModel(sectionList: sectionList)

			#expect(displayModel.currentSong?.songId == "1")
		}
	}
}
