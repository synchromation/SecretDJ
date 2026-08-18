import Testing

@testable import FeedUI

import Foundation
import SecretDJDomain

/// Initial load, pull-to-refresh, and the S3.3 song→jukebox correlation.
/// Auto-refresh cadence and pagination live in
/// `FeedScreenModelRefreshTests`, split out to keep this file under the
/// project's file-length limit; both files share the fixtures below, plus
/// `makeAction`/`FakeInstalledApps` from `FeedActionRouterTests.swift`.
enum FeedScreenModelTests {
	@MainActor
	struct `Initial load` {
		@Test func `starts in the loading phase before any load`() {
			let model = makeScreenModel(loader: InMemoryFeedLoading())

			#expect(model.phase == .loading)
		}

		@Test func `a feed with content loads`() async {
			let loader = InMemoryFeedLoading()
			await loader.setOutcome(
				.success(makeLoadedSectionList(hash: "v1", items: [makeFeedSong(songId: "1")])),
				forPage: nil,
			)
			let model = makeScreenModel(loader: loader)

			await model.start()

			#expect(model.phase == .loaded)
			#expect(model.visibleSections.count == 1)
			#expect(model.visibleSections[0].items.map(\.id) == ["song-1"])
		}

		@Test func `a feed with no sections loads empty`() async {
			let loader = InMemoryFeedLoading()
			await loader.setOutcome(.success(makeEmptySectionList(hash: "v1")), forPage: nil)
			let model = makeScreenModel(loader: loader)

			await model.start()

			#expect(model.phase == .empty)
		}

		@Test func `an offline URLError surfaces as an offline error`() async {
			let loader = InMemoryFeedLoading()
			await loader.setOutcome(.failure(URLError(.notConnectedToInternet)), forPage: nil)
			let model = makeScreenModel(loader: loader)

			await model.start()

			#expect(model.phase == .error(offline: true))
		}

		@Test func `a non-network error surfaces as a non-offline error`() async {
			// Page nil is deliberately left unconfigured — the fake throws
			// UnconfiguredPageError, which isn't a URLError.
			let model = makeScreenModel(loader: InMemoryFeedLoading())

			await model.start()

			#expect(model.phase == .error(offline: false))
		}

		@Test func `an initial load bumps the generation so the feed view scrolls to top`() async {
			let loader = InMemoryFeedLoading()
			await loader.setOutcome(
				.success(makeLoadedSectionList(hash: "v1", items: [makeFeedSong(songId: "1")])),
				forPage: nil,
			)
			let model = makeScreenModel(loader: loader)

			await model.start()

			#expect(model.generation == 1)
		}
	}

	@MainActor
	struct `Pull-to-refresh` {
		@Test func `refresh replaces the feed's content`() async {
			let loader = InMemoryFeedLoading()
			await loader.setOutcome(
				.success(makeLoadedSectionList(hash: "v1", items: [makeFeedSong(songId: "1")])),
				forPage: nil,
			)
			let model = makeScreenModel(loader: loader)
			await model.start()

			await loader.setOutcome(
				.success(makeLoadedSectionList(
					hash: "v2",
					items: [makeFeedSong(songId: "2"), makeFeedSong(songId: "3")],
				)),
				forPage: nil,
			)
			await model.refresh()

			#expect(model.visibleSections[0].items.map(\.id) == ["song-2", "song-3"])
		}

		@Test func `refresh bumps the generation again`() async {
			let loader = InMemoryFeedLoading()
			await loader.setOutcome(
				.success(makeLoadedSectionList(hash: "v1", items: [makeFeedSong(songId: "1")])),
				forPage: nil,
			)
			let model = makeScreenModel(loader: loader)
			await model.start()

			await model.refresh()

			#expect(model.generation == 2)
		}

		@Test func `a refresh failure keeps existing content instead of showing the error surface`() async {
			let loader = InMemoryFeedLoading()
			await loader.setOutcome(
				.success(makeLoadedSectionList(hash: "v1", items: [makeFeedSong(songId: "1")])),
				forPage: nil,
			)
			let model = makeScreenModel(loader: loader)
			await model.start()

			await loader.setOutcome(.failure(URLError(.notConnectedToInternet)), forPage: nil)
			await model.refresh()

			#expect(model.phase == .loaded)
			#expect(model.visibleSections[0].items.map(\.id) == ["song-1"])
		}
	}

	@MainActor
	struct `Jukebox tap correlation` {
		@Test func `outcome(forTap:) resolves a song's jukeboxGotoItem via the loaded hidden jukebox list`() async {
			let jukebox = makeFeedJukebox(jukeboxId: 9, action: makeAction(kind: .jukeboxGotoItem, itemId: 100))
			let song = makeFeedSong(songId: "1", action: makeAction(kind: .jukeboxGotoItem, itemId: 100))
			let sectionList = SectionList(
				hash: FeedHash(rawValue: "v1"),
				sections: [
					makeFeedSection(template: .hiddenJukeboxList, index: 0, items: [.jukebox(jukebox)]),
					makeFeedSection(template: .song, index: 1, items: [.song(song)]),
				],
				actions: [],
			)
			let loader = InMemoryFeedLoading()
			await loader.setOutcome(.success(sectionList), forPage: nil)
			let model = makeScreenModel(loader: loader)
			await model.start()

			let tappedItem = FeedDisplayItem(id: Item.song(song).stableID, item: .song(song), text: "", template: .song)

			#expect(model.outcome(forTap: tappedItem) == .showJukebox(jukeboxId: 9))
		}
	}
}

// MARK: - Fixtures

/// Shared with `FeedScreenModelRefreshTests` — not `private`, and
/// distinctively named, so both files in this test target can use them
/// without colliding with the similarly-named fixtures other test files
/// keep `private` to themselves.
@MainActor
func makeScreenModel(
	loader: any FeedLoading,
	autoRefresh: FeedConfiguration.AutoRefresh? = nil,
	paginationEnabled: Bool = false,
	changePolicy: FeedChangeDetector.Policy = .surfaceChange,
	gpsFixAge: (any GPSFixAgeProviding)? = nil,
	clock: any FeedRefreshClock = ManualFeedRefreshClock(),
) -> FeedScreenModel {
	FeedScreenModel(
		loader: loader,
		router: FeedActionRouter(installedApps: FakeInstalledApps()),
		configuration: FeedConfiguration(
			autoRefresh: autoRefresh,
			paginationEnabled: paginationEnabled,
			changePolicy: changePolicy,
		),
		gpsFixAge: gpsFixAge,
		clock: clock,
	)
}

@MainActor
final class FakeGPSFixAgeProviding: GPSFixAgeProviding {
	var age: Duration?

	init(age: Duration?) {
		self.age = age
	}

	func firstFixAge() -> Duration? {
		age
	}
}

func makeLoadedSectionList(hash: String, items: [Song], template: Template = .song) -> SectionList {
	SectionList(
		hash: FeedHash(rawValue: hash),
		sections: [makeFeedSection(template: template, index: 0, items: items.map(Item.song))],
		actions: [],
	)
}

func makeEmptySectionList(hash: String) -> SectionList {
	SectionList(hash: FeedHash(rawValue: hash), sections: [], actions: [])
}

func makeFeedSection(template: Template, index: Int, items: [Item]) -> Section {
	Section(itemType: [], template: template, title: "Songs", index: index, store: nil, hash: nil, items: items)
}

func makeFeedSong(songId: String = "1", action: Action? = nil) -> Song {
	Song(
		songId: songId,
		title: "",
		artist: "",
		previewURL: nil,
		likeInfo: LikeInfo(likedByYou: false, info: ""),
		text: "",
		sortIndex: 0,
		action: action,
		actions: [],
	)
}

func makeFeedJukebox(jukeboxId: Int, action: Action? = nil) -> Jukebox {
	Jukebox(
		itemType: [],
		jukeboxId: jukeboxId,
		textColour: "#000000",
		subtitle: "",
		text: "",
		sortIndex: 0,
		action: action,
		actions: [],
	)
}
