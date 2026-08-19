import Testing

@testable import FeedUI

import Foundation
import SecretDJDomain

/// ``FeedScreenModel/personDetails`` — the profile header payload S6.6's
/// profile screen reads (screen name, avatar, likeInfo), sourced the same
/// way ``FeedScreenModel/venueDetails`` already is
/// (``FeedScreenModelVenueDetailsTests``'s doc comment): extracted from the
/// loaded feed's `hiddenProfile` section and republished after every full
/// load. `persondetails` returns this same section shape whether the
/// screen is showing the signed-in user's own profile or someone else's
/// (LEGACY.md "Tab 3 — Profile" — one endpoint, one hidden-section
/// template, for both) — own-vs-other is derived elsewhere
/// (``ProfileScreenModel/isOwnProfile``), not by this property.
enum FeedScreenModelPersonDetailsTests {
	@MainActor
	struct `Person details` {
		@Test func `starts nil before any load`() {
			let model = makeScreenModel(loader: InMemoryFeedLoading())

			#expect(model.personDetails == nil)
		}

		@Test func `exposes the hiddenProfile payload after a load`() async {
			let person = makePersonDetails(personId: "p1", screenName: "Nick")
			let sectionList = SectionList(
				hash: FeedHash(rawValue: "h1"),
				sections: [makeFeedSection(template: .hiddenProfile, index: 0, items: [.person(person)])],
				actions: [],
			)
			let loader = InMemoryFeedLoading()
			await loader.setOutcome(.success(sectionList), forPage: nil)
			let model = makeScreenModel(loader: loader)

			await model.start()

			#expect(model.personDetails == person)
		}

		@Test func `updates to the freshest payload on refresh`() async {
			let loader = InMemoryFeedLoading()
			await loader.setOutcome(
				.success(SectionList(
					hash: FeedHash(rawValue: "h1"),
					sections: [
						makeFeedSection(
							template: .hiddenProfile,
							index: 0,
							items: [.person(makePersonDetails(personId: "p1", screenName: "Nick"))],
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
							template: .hiddenProfile,
							index: 0,
							items: [.person(makePersonDetails(personId: "p1", screenName: "Nicholas"))],
						),
					],
					actions: [],
				)),
				forPage: nil,
			)
			await model.refresh()

			#expect(model.personDetails?.screenName == "Nicholas")
		}

		@Test func `stays nil for a feed with no hiddenProfile section`() async {
			let loader = InMemoryFeedLoading()
			await loader.setOutcome(
				.success(makeLoadedSectionList(hash: "v1", items: [makeFeedSong(songId: "1")])),
				forPage: nil,
			)
			let model = makeScreenModel(loader: loader)

			await model.start()

			#expect(model.personDetails == nil)
		}
	}
}

// MARK: - Fixtures

private func makePersonDetails(personId: String, screenName: String) -> Person {
	Person(
		personId: personId,
		screenName: screenName,
		gender: .unisex,
		likeInfo: LikeInfo(likedByYou: false, info: ""),
		email: nil,
		firstName: nil,
		lastName: nil,
		text: "",
		sortIndex: 0,
		action: nil,
		actions: [],
	)
}
