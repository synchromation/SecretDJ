import Testing

@testable import FeedUI

import Foundation
import SecretDJDomain

/// ``FeedScreenModel/actionButtons`` and ``FeedScreenModel/outcome(forBarButton:)``
/// — the nav-bar action buttons a loaded feed carries (S6.12), sourced and
/// republished the same way ``FeedScreenModel``'s existing `venueDetails`/
/// `personDetails` already are (``FeedScreenModelVenueDetailsTests``'s own
/// doc comment), plus the bar-button counterpart of ``outcome(forTap:)`` —
/// PLAN.md S6.12 notes the router mapping (``FeedActionRouter/outcome(forBarButton:)``)
/// already exists and is tested; this only exposes it through the model.
enum FeedScreenModelActionButtonsTests {
	@MainActor
	struct `Action buttons` {
		@Test func `starts empty before any load`() {
			let model = makeScreenModel(loader: InMemoryFeedLoading())

			#expect(model.actionButtons.isEmpty)
		}

		@Test func `exposes the section list's actions, in order, after a load`() async {
			let insertCoin = makeAction(kind: .showTopup, button: .insertCoin)
			let hailTaxi = makeAction(kind: .launchUberApp, url: "https://m.uber.com", button: .hailTaxi)
			let sectionList = SectionList(hash: FeedHash(rawValue: "h1"), sections: [], actions: [insertCoin, hailTaxi])
			let loader = InMemoryFeedLoading()
			await loader.setOutcome(.success(sectionList), forPage: nil)
			let model = makeScreenModel(loader: loader)

			await model.start()

			#expect(model.actionButtons == [insertCoin, hailTaxi])
		}

		@Test func `updates to the freshest actions on refresh`() async {
			let loader = InMemoryFeedLoading()
			await loader.setOutcome(
				.success(SectionList(
					hash: FeedHash(rawValue: "h1"),
					sections: [],
					actions: [makeAction(kind: .showTopup, button: .insertCoin)],
				)),
				forPage: nil,
			)
			let model = makeScreenModel(loader: loader)
			await model.start()

			await loader.setOutcome(
				.success(SectionList(hash: FeedHash(rawValue: "h2"), sections: [], actions: [])),
				forPage: nil,
			)
			await model.refresh()

			#expect(model.actionButtons.isEmpty)
		}

		@Test func `stays empty for a feed with no actions`() async {
			let loader = InMemoryFeedLoading()
			await loader.setOutcome(
				.success(makeLoadedSectionList(hash: "h1", items: [makeFeedSong(songId: "1")])),
				forPage: nil,
			)
			let model = makeScreenModel(loader: loader)

			await model.start()

			#expect(model.actionButtons.isEmpty)
		}
	}

	@MainActor
	struct `Bar-button outcome routing` {
		@Test func `routes a bar-button action through the same router as a cell tap`() {
			let model = makeScreenModel(loader: InMemoryFeedLoading())
			let action = makeAction(kind: .showTopup, button: .insertCoin)

			#expect(model.outcome(forBarButton: action) == .showTopUps(context: .insertCoin))
		}

		@Test func `returns nil for an action the router can't resolve`() {
			let model = makeScreenModel(loader: InMemoryFeedLoading())
			let action = makeAction(kind: .unsupported(999), button: .insertCoin)

			#expect(model.outcome(forBarButton: action) == nil)
		}
	}
}
