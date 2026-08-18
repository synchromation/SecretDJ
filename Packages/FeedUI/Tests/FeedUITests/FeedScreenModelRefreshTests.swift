import Testing

@testable import FeedUI

import Foundation
import SecretDJDomain

/// Auto-refresh cadence and infinite-scroll pagination — split out of
/// `FeedScreenModelTests` to keep that file under the project's
/// file-length limit; fixtures (`makeScreenModel`, `makeFeedSong`, ...) are
/// shared from there.
enum FeedScreenModelRefreshTests {
	@MainActor
	struct `Auto-refresh cadence` {
		@Test func `auto-refresh disabled schedules no ticks`() async {
			let loader = InMemoryFeedLoading()
			await loader.setOutcome(.success(makeLoadedSectionList(hash: "v1", items: [makeFeedSong()])), forPage: nil)
			let clock = ManualFeedRefreshClock()
			let model = makeScreenModel(loader: loader, autoRefresh: nil, clock: clock)

			await model.start()

			#expect(clock.pendingCount == 0)
		}

		@Test func `auto-refresh with no GPS provider schedules the base cadence`() async {
			let loader = InMemoryFeedLoading()
			await loader.setOutcome(.success(makeLoadedSectionList(hash: "v1", items: [makeFeedSong()])), forPage: nil)
			let clock = ManualFeedRefreshClock()
			let model = makeScreenModel(loader: loader, autoRefresh: FeedConfiguration.AutoRefresh(), clock: clock)

			await model.start()

			#expect(clock.scheduledDurations == [.seconds(20)])
		}

		@Test func `auto-refresh with no GPS fix yet schedules the tightened cadence`() async {
			let loader = InMemoryFeedLoading()
			await loader.setOutcome(.success(makeLoadedSectionList(hash: "v1", items: [makeFeedSong()])), forPage: nil)
			let clock = ManualFeedRefreshClock()
			let model = makeScreenModel(
				loader: loader,
				autoRefresh: FeedConfiguration.AutoRefresh(),
				gpsFixAge: FakeGPSFixAgeProviding(age: nil),
				clock: clock,
			)

			await model.start()

			#expect(clock.scheduledDurations == [.seconds(3)])
		}

		@Test func `a GPS fix younger than the tightened window keeps the tightened cadence`() async {
			let loader = InMemoryFeedLoading()
			await loader.setOutcome(.success(makeLoadedSectionList(hash: "v1", items: [makeFeedSong()])), forPage: nil)
			let clock = ManualFeedRefreshClock()
			let model = makeScreenModel(
				loader: loader,
				autoRefresh: FeedConfiguration.AutoRefresh(),
				gpsFixAge: FakeGPSFixAgeProviding(age: .seconds(5)),
				clock: clock,
			)

			await model.start()

			#expect(clock.scheduledDurations == [.seconds(3)])
		}

		@Test func `a GPS fix at or past the tightened window relaxes to the base cadence`() async {
			let loader = InMemoryFeedLoading()
			await loader.setOutcome(.success(makeLoadedSectionList(hash: "v1", items: [makeFeedSong()])), forPage: nil)
			let clock = ManualFeedRefreshClock()
			let model = makeScreenModel(
				loader: loader,
				autoRefresh: FeedConfiguration.AutoRefresh(),
				gpsFixAge: FakeGPSFixAgeProviding(age: .seconds(12)),
				clock: clock,
			)

			await model.start()

			#expect(clock.scheduledDurations == [.seconds(20)])
		}

		@Test func `advancing the clock performs another load and reschedules the next tick`() async {
			let loader = InMemoryFeedLoading()
			await loader.setOutcome(
				.success(makeLoadedSectionList(hash: "v1", items: [makeFeedSong(songId: "1")])),
				forPage: nil,
			)
			let clock = ManualFeedRefreshClock()
			let model = makeScreenModel(loader: loader, autoRefresh: FeedConfiguration.AutoRefresh(), clock: clock)
			await model.start()

			await loader.setOutcome(
				.success(makeLoadedSectionList(hash: "v2", items: [makeFeedSong(songId: "2")])),
				forPage: nil,
			)
			await clock.advance()

			#expect(await loader.requestedPages.count == 2)
			#expect(model.visibleSections[0].items.map(\.id) == ["song-2"])
			#expect(clock.pendingCount == 1)
		}

		@Test func `stop cancels the pending tick`() async {
			let loader = InMemoryFeedLoading()
			await loader.setOutcome(.success(makeLoadedSectionList(hash: "v1", items: [makeFeedSong()])), forPage: nil)
			let clock = ManualFeedRefreshClock()
			let model = makeScreenModel(loader: loader, autoRefresh: FeedConfiguration.AutoRefresh(), clock: clock)
			await model.start()

			model.stop()

			#expect(clock.pendingCount == 0)
		}

		@Test func `starting twice does not double-schedule auto-refresh`() async {
			let loader = InMemoryFeedLoading()
			await loader.setOutcome(.success(makeLoadedSectionList(hash: "v1", items: [makeFeedSong()])), forPage: nil)
			let clock = ManualFeedRefreshClock()
			let model = makeScreenModel(loader: loader, autoRefresh: FeedConfiguration.AutoRefresh(), clock: clock)

			await model.start()
			await model.start()

			#expect(clock.pendingCount == 1)
		}
	}

	@MainActor
	struct Pagination {
		@Test func `pagination disabled makes loadNextPage a no-op`() async {
			let loader = InMemoryFeedLoading()
			await loader.setOutcome(
				.success(makeLoadedSectionList(hash: "v1", items: [makeFeedSong(songId: "1")])),
				forPage: nil,
			)
			let model = makeScreenModel(loader: loader, paginationEnabled: false)
			await model.start()

			await model.loadNextPage()

			#expect(await loader.requestedPages == [nil])
		}

		@Test func `loadNextPage appends the new page's items to the matching section`() async {
			let loader = InMemoryFeedLoading()
			await loader.setOutcome(
				.success(makeLoadedSectionList(hash: "v1", items: [makeFeedSong(songId: "1")])),
				forPage: nil,
			)
			await loader.setOutcome(
				.success(makeLoadedSectionList(hash: "v1", items: [makeFeedSong(songId: "2")])),
				forPage: 1,
			)
			let model = makeScreenModel(loader: loader, paginationEnabled: true)
			await model.start()

			await model.loadNextPage()

			#expect(model.visibleSections[0].items.map(\.id) == ["song-1", "song-2"])
		}

		@Test func `loadNextPage skips items already present in the section, for overlapping page windows`() async {
			let loader = InMemoryFeedLoading()
			await loader.setOutcome(
				.success(makeLoadedSectionList(hash: "v1", items: [
					makeFeedSong(songId: "1"),
					makeFeedSong(songId: "2"),
				])),
				forPage: nil,
			)
			await loader.setOutcome(
				.success(makeLoadedSectionList(hash: "v1", items: [
					// "2" is the overlapping tail of the previous window.
					makeFeedSong(songId: "2"),
					makeFeedSong(songId: "3"),
				])),
				forPage: 1,
			)
			let model = makeScreenModel(loader: loader, paginationEnabled: true)
			await model.start()

			await model.loadNextPage()

			#expect(model.visibleSections[0].items.map(\.id) == ["song-1", "song-2", "song-3"])
		}

		@Test func `appendPage merges into the correct section when the initial page had id-colliding sections`() async {
			let loader = InMemoryFeedLoading()
			await loader.setOutcome(
				.success(SectionList(
					hash: FeedHash(rawValue: "v1"),
					sections: [
						makeFeedSection(template: .song, index: 0, items: [.song(makeFeedSong(songId: "1"))]),
						makeFeedSection(template: .song, index: 0, items: [.song(makeFeedSong(songId: "a"))]),
					],
					actions: [],
				)),
				forPage: nil,
			)
			await loader.setOutcome(
				.success(SectionList(
					hash: FeedHash(rawValue: "v1"),
					sections: [
						makeFeedSection(template: .song, index: 0, items: [.song(makeFeedSong(songId: "2"))]),
					],
					actions: [],
				)),
				forPage: 1,
			)
			let model = makeScreenModel(loader: loader, paginationEnabled: true)
			await model.start()

			await model.loadNextPage()

			#expect(model.visibleSections.map(\.id) == ["200-0", "200-0#2"])
			#expect(model.visibleSections[0].items.map(\.id) == ["song-1", "song-2"])
			#expect(model.visibleSections[1].items.map(\.id) == ["song-a"])
		}

		@Test func `an empty page marks the feed as having no more pages`() async {
			let loader = InMemoryFeedLoading()
			await loader.setOutcome(
				.success(makeLoadedSectionList(hash: "v1", items: [makeFeedSong(songId: "1")])),
				forPage: nil,
			)
			await loader.setOutcome(.success(makeEmptySectionList(hash: "v1")), forPage: 1)
			let model = makeScreenModel(loader: loader, paginationEnabled: true)
			await model.start()

			await model.loadNextPage()
			#expect(model.hasMorePages == false)

			await model.loadNextPage()
			#expect(await loader.requestedPages == [nil, 1])
		}

		@Test func `concurrent loadNextPage calls only issue one request`() async {
			let loader = InMemoryFeedLoading()
			await loader.setOutcome(
				.success(makeLoadedSectionList(hash: "v1", items: [makeFeedSong(songId: "1")])),
				forPage: nil,
			)
			await loader.setOutcome(
				.success(makeLoadedSectionList(hash: "v1", items: [makeFeedSong(songId: "2")])),
				forPage: 1,
			)
			let model = makeScreenModel(loader: loader, paginationEnabled: true)
			await model.start()

			async let first: Void = model.loadNextPage()
			async let second: Void = model.loadNextPage()
			_ = await (first, second)

			#expect(await loader.requestedPages == [nil, 1])
		}

		@Test func `a hash change mid-pagination surfaces jukeboxChanged and drops the mismatched page`() async {
			let loader = InMemoryFeedLoading()
			await loader.setOutcome(
				.success(makeLoadedSectionList(hash: "v1", items: [makeFeedSong(songId: "1")])),
				forPage: nil,
			)
			await loader.setOutcome(
				.success(makeLoadedSectionList(hash: "v2", items: [makeFeedSong(songId: "2")])),
				forPage: 1,
			)
			let model = makeScreenModel(loader: loader, paginationEnabled: true, changePolicy: .surfaceChange)
			await model.start()

			await model.loadNextPage()

			#expect(model.jukeboxChangedEvent != nil)
			#expect(model.visibleSections[0].items.map(\.id) == ["song-1"])
		}

		@Test func `the kiosk's reloadInPlace policy absorbs a hash change instead of surfacing it`() async {
			let loader = InMemoryFeedLoading()
			await loader.setOutcome(
				.success(makeLoadedSectionList(hash: "v1", items: [makeFeedSong(songId: "1")])),
				forPage: nil,
			)
			await loader.setOutcome(
				.success(makeLoadedSectionList(hash: "v2", items: [makeFeedSong(songId: "2")])),
				forPage: 1,
			)
			let model = makeScreenModel(loader: loader, paginationEnabled: true, changePolicy: .reloadInPlace)
			await model.start()

			await model.loadNextPage()

			#expect(model.jukeboxChangedEvent == nil)
			#expect(model.visibleSections[0].items.map(\.id) == ["song-1", "song-2"])
		}
	}
}
