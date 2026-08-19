import Testing

@testable import FeedUI

import Foundation
import SecretDJDomain

/// ``FeedScreenModel/venueDetails`` — the venue header payload S6.2's venue
/// screen reads (name, address, likeInfo), sourced the same way
/// ``FeedScreenModel``'s existing `jukeboxList` already is: extracted from
/// the loaded feed's hidden sections and republished after every full load.
enum FeedScreenModelVenueDetailsTests {
	@MainActor
	struct `Venue details` {
		@Test func `starts nil before any load`() {
			let model = makeScreenModel(loader: InMemoryFeedLoading())

			#expect(model.venueDetails == nil)
		}

		@Test func `exposes the hiddenVenueDetails payload after a load`() async {
			let venue = makeVenueDetails(venueId: "v1", name: "The Fox")
			let sectionList = SectionList(
				hash: FeedHash(rawValue: "h1"),
				sections: [makeFeedSection(template: .hiddenVenueDetails, index: 0, items: [.venue(venue)])],
				actions: [],
			)
			let loader = InMemoryFeedLoading()
			await loader.setOutcome(.success(sectionList), forPage: nil)
			let model = makeScreenModel(loader: loader)

			await model.start()

			#expect(model.venueDetails == venue)
		}

		@Test func `updates to the freshest payload on refresh`() async {
			let loader = InMemoryFeedLoading()
			await loader.setOutcome(
				.success(SectionList(
					hash: FeedHash(rawValue: "h1"),
					sections: [
						makeFeedSection(
							template: .hiddenVenueDetails,
							index: 0,
							items: [.venue(makeVenueDetails(venueId: "v1", name: "The Fox"))],
						),
					],
					actions: [],
				)),
				forPage: nil,
			)
			let model = makeScreenModel(loader: loader)
			await model.start()

			await loader.setOutcome(
				.success(SectionList(
					hash: FeedHash(rawValue: "h2"),
					sections: [
						makeFeedSection(
							template: .hiddenVenueDetails,
							index: 0,
							items: [.venue(makeVenueDetails(venueId: "v1", name: "The Fox & Hounds"))],
						),
					],
					actions: [],
				)),
				forPage: nil,
			)
			await model.refresh()

			#expect(model.venueDetails?.name == "The Fox & Hounds")
		}

		@Test func `stays nil for a feed with no hiddenVenueDetails section`() async {
			let loader = InMemoryFeedLoading()
			await loader.setOutcome(
				.success(makeLoadedSectionList(hash: "v1", items: [makeFeedSong(songId: "1")])),
				forPage: nil,
			)
			let model = makeScreenModel(loader: loader)

			await model.start()

			#expect(model.venueDetails == nil)
		}
	}
}

// MARK: - Fixtures

private func makeVenueDetails(venueId: String, name: String) -> Venue {
	Venue(
		venueId: venueId,
		name: name,
		address: "9 Barley Mow Passage, London W4 4PH",
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
