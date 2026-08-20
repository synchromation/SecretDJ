import Testing

@testable import SecretDJKiosk

import FeedUI
import Foundation
import SecretDJDomain

/// ``KioskNowPlayingModel`` — the kiosk header's own polling model (PLAN.md
/// S7.4): fetches `playhistory` at the legacy 20-second cadence
/// (LEGACY.md "Home screen: Now Playing + jukebox wall" — "polls... every 20
/// seconds"), turning the response into a ``KioskNowPlayingDisplay`` and, when
/// the feed happens to carry a `hiddenVenueDetails` section, resolving the
/// venue's real name (PLAN.md S7.4's venue-name-resolution scope item).
/// Mirrors ``FeedUI/FeedScreenModel``'s own auto-refresh shape
/// (``FeedRefreshClock``/``ManualFeedRefreshClock``), reused directly rather
/// than reinvented.
enum KioskNowPlayingModelTests {
	@MainActor
	struct `Starting up` {
		@Test func `starts idle before any load`() {
			let model = KioskNowPlayingModel(loader: InMemoryFeedLoading(), clock: ManualFeedRefreshClock())

			#expect(model.display == .idle)
		}

		@Test func `start loads the feed and shows its current song`() async {
			let loader = InMemoryFeedLoading()
			await loader.setOutcome(
				.success(makeSectionList(songs: [makeSong(songId: "1", title: "Yellow", artist: "Coldplay")])),
				forPage: nil,
			)
			let model = KioskNowPlayingModel(loader: loader, clock: ManualFeedRefreshClock())

			await model.start()

			#expect(model.display == .nowPlaying(title: "Yellow", artist: "Coldplay", artworkURL: nil))
		}

		@Test func `start shows idle for a feed with no song yet`() async {
			let loader = InMemoryFeedLoading()
			await loader.setOutcome(.success(makeSectionList(songs: [])), forPage: nil)
			let model = KioskNowPlayingModel(loader: loader, clock: ManualFeedRefreshClock())

			await model.start()

			#expect(model.display == .idle)
		}

		@Test func `start shows intermission for the sentinel song`() async {
			let loader = InMemoryFeedLoading()
			await loader.setOutcome(
				.success(makeSectionList(songs: [makeSong(songId: "0", title: "Back soon\n\nGrab a drink!")])),
				forPage: nil,
			)
			let model = KioskNowPlayingModel(loader: loader, clock: ManualFeedRefreshClock())

			await model.start()

			#expect(model.display == .intermission(title: "Back soon", subtitle: "Grab a drink!"))
		}

		@Test func `a failed load keeps the previous display rather than clearing it`() async {
			let loader = InMemoryFeedLoading()
			await loader.setOutcome(
				.success(makeSectionList(songs: [makeSong(songId: "1", title: "Yellow", artist: "Coldplay")])),
				forPage: nil,
			)
			let model = KioskNowPlayingModel(loader: loader, clock: ManualFeedRefreshClock())
			await model.start()

			await loader.setOutcome(.failure(URLError(.notConnectedToInternet)), forPage: nil)
			await model.refresh()

			#expect(model.display == .nowPlaying(title: "Yellow", artist: "Coldplay", artworkURL: nil))
		}
	}

	@MainActor
	struct `Polling cadence` {
		@Test func `start schedules the next tick at the legacy 20-second cadence`() async {
			let loader = InMemoryFeedLoading()
			await loader.setOutcome(.success(makeSectionList(songs: [])), forPage: nil)
			let clock = ManualFeedRefreshClock()
			let model = KioskNowPlayingModel(loader: loader, clock: clock)

			await model.start()

			#expect(clock.scheduledDurations == [.seconds(20)])
		}

		@Test func `advancing the clock performs another load and reschedules`() async {
			let loader = InMemoryFeedLoading()
			await loader.setOutcome(
				.success(makeSectionList(songs: [makeSong(songId: "1", title: "Yellow", artist: "Coldplay")])),
				forPage: nil,
			)
			let clock = ManualFeedRefreshClock()
			let model = KioskNowPlayingModel(loader: loader, clock: clock)
			await model.start()

			await loader.setOutcome(
				.success(makeSectionList(songs: [makeSong(songId: "2", title: "Clocks", artist: "Coldplay")])),
				forPage: nil,
			)
			await clock.advance()

			#expect(await loader.requestedPages.count == 2)
			#expect(model.display == .nowPlaying(title: "Clocks", artist: "Coldplay", artworkURL: nil))
			#expect(clock.pendingCount == 1)
		}

		@Test func `stop cancels the pending tick`() async {
			let loader = InMemoryFeedLoading()
			await loader.setOutcome(.success(makeSectionList(songs: [])), forPage: nil)
			let clock = ManualFeedRefreshClock()
			let model = KioskNowPlayingModel(loader: loader, clock: clock)
			await model.start()

			model.stop()

			#expect(clock.pendingCount == 0)
		}

		@Test func `starting twice does not double-schedule`() async {
			let loader = InMemoryFeedLoading()
			await loader.setOutcome(.success(makeSectionList(songs: [])), forPage: nil)
			let clock = ManualFeedRefreshClock()
			let model = KioskNowPlayingModel(loader: loader, clock: clock)

			await model.start()
			await model.start()

			#expect(clock.pendingCount == 1)
		}
	}

	@MainActor
	struct `Venue name resolution` {
		@Test func `calls back with the venue's name when the feed carries a hiddenVenueDetails section`() async {
			let loader = InMemoryFeedLoading()
			await loader.setOutcome(
				.success(makeSectionList(songs: [], venueName: "The Fox")),
				forPage: nil,
			)
			var resolvedNames: [String] = []
			let model = KioskNowPlayingModel(
				loader: loader,
				clock: ManualFeedRefreshClock(),
				onVenueNameResolved: { resolvedNames.append($0) },
			)

			await model.start()

			#expect(resolvedNames == ["The Fox"])
		}

		@Test func `never calls back when the feed carries no hiddenVenueDetails section`() async {
			let loader = InMemoryFeedLoading()
			await loader.setOutcome(.success(makeSectionList(songs: [])), forPage: nil)
			var resolvedNames: [String] = []
			let model = KioskNowPlayingModel(
				loader: loader,
				clock: ManualFeedRefreshClock(),
				onVenueNameResolved: { resolvedNames.append($0) },
			)

			await model.start()

			#expect(resolvedNames.isEmpty)
		}
	}
}

// MARK: - Fixtures

private func makeSectionList(songs: [Song], venueName: String? = nil) -> SectionList {
	var sections = [Section(
		itemType: [],
		template: .song,
		title: "",
		index: 0,
		store: nil,
		hash: nil,
		items: songs.map(Item.song),
	)]

	if let venueName {
		sections.append(Section(
			itemType: [],
			template: .hiddenVenueDetails,
			title: "",
			index: 1,
			store: nil,
			hash: nil,
			items: [.venue(makeVenue(name: venueName))],
		))
	}

	return SectionList(hash: FeedHash(rawValue: "h1"), sections: sections, actions: [])
}

private func makeSong(songId: String, title: String, artist: String = "") -> Song {
	Song(
		songId: songId,
		title: title,
		artist: artist,
		previewURL: nil,
		likeInfo: LikeInfo(likedByYou: false, info: ""),
		text: "",
		sortIndex: 0,
		action: nil,
		actions: [],
	)
}

private func makeVenue(name: String) -> Venue {
	Venue(
		venueId: "v1",
		name: name,
		address: "",
		telephone: "",
		lat: 0,
		lng: 0,
		zoneName: "",
		promotionURL: nil,
		likeInfo: LikeInfo(likedByYou: false, info: ""),
		properties: [],
		checkedIn: false,
		hasMachineControl: false,
		text: "",
		sortIndex: 0,
		action: nil,
		actions: [],
	)
}
