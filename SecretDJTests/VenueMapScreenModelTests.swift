import FeedUI
import MapKit
import SecretDJDomain
import Testing

@testable import SecretDJ

/// ``VenueMapScreenModel``'s pure derivation from a feed's already-loaded
/// venue items — no network of its own (LEGACY.md "Gaps and cross-checks"'
/// `VenueMapViewController`, adapted to reuse the tab's own feed instead of
/// re-fetching `placesnearby`).
enum VenueMapScreenModelTests {
	struct `Deriving annotations` {
		@Test func `starts with no annotations from an empty feed`() {
			let model = VenueMapScreenModel(sections: [])

			#expect(model.annotations.isEmpty)
		}

		@Test func `builds one annotation per venue item`() {
			let venue = makeVenue(venueId: "v1", name: "The Lamb", lat: 51.5, lng: -0.1)
			let section = makeVenueSection(venues: [venue])

			let model = VenueMapScreenModel(sections: [section])

			#expect(model.annotations.count == 1)
			#expect(model.annotations[0].venueId == "v1")
			#expect(model.annotations[0].title == "The Lamb")
			#expect(model.annotations[0].latitude == 51.5)
			#expect(model.annotations[0].longitude == -0.1)
		}

		@Test func `flags a venue whose properties include hasJukebox`() {
			let venue = makeVenue(venueId: "v1", properties: .hasJukebox)
			let section = makeVenueSection(venues: [venue])

			let model = VenueMapScreenModel(sections: [section])

			#expect(model.annotations[0].hasJukebox)
		}

		@Test func `does not flag a venue without hasJukebox`() {
			let venue = makeVenue(venueId: "v1", properties: .reportsPlayHistory)
			let section = makeVenueSection(venues: [venue])

			let model = VenueMapScreenModel(sections: [section])

			#expect(!model.annotations[0].hasJukebox)
		}

		@Test func `ignores a section with no venue items entirely`() {
			let section = makeVenueSection(venues: [])

			let model = VenueMapScreenModel(sections: [section])

			#expect(model.annotations.isEmpty)
		}

		@Test func `collects venues across more than one section`() {
			let sectionOne = makeVenueSection(index: 0, venues: [makeVenue(venueId: "v1")])
			let sectionTwo = makeVenueSection(index: 1, venues: [makeVenue(venueId: "v2")])

			let model = VenueMapScreenModel(sections: [sectionOne, sectionTwo])

			#expect(model.annotations.map(\.venueId) == ["v1", "v2"])
		}
	}

	struct `Fitting the camera to every annotation` {
		@Test func `has no fit region for an empty feed`() {
			let model = VenueMapScreenModel(sections: [])

			#expect(model.fitRegion == nil)
		}

		@Test func `centers on the single venue when there is only one`() {
			let section = makeVenueSection(venues: [makeVenue(venueId: "v1", lat: 51.5, lng: -0.1)])

			let model = VenueMapScreenModel(sections: [section])

			let region = try? #require(model.fitRegion)
			#expect(region?.center.latitude == 51.5)
			#expect(region?.center.longitude == -0.1)
		}

		@Test func `centers between two venues and spans at least their separation`() {
			let section = makeVenueSection(venues: [
				makeVenue(venueId: "v1", lat: 51.0, lng: -0.2),
				makeVenue(venueId: "v2", lat: 52.0, lng: -0.0),
			])

			let model = VenueMapScreenModel(sections: [section])

			let region = try? #require(model.fitRegion)
			#expect(region?.center.latitude == 51.5)
			#expect(region?.center.longitude == -0.1)
			#expect((region?.span.latitudeDelta ?? 0) >= 1.0)
			#expect((region?.span.longitudeDelta ?? 0) >= 0.2)
		}
	}
}

// MARK: - Fixtures

private func makeVenue(
	venueId: String,
	name: String = "",
	lat: Double = 0,
	lng: Double = 0,
	properties: VenueProperties = [],
) -> Venue {
	Venue(
		venueId: venueId,
		name: name,
		address: "",
		telephone: "",
		lat: lat,
		lng: lng,
		zoneName: "",
		promotionURL: nil,
		likeInfo: LikeInfo(likedByYou: false, info: ""),
		properties: properties,
		checkedIn: false,
		hasMachineControl: false,
		text: name,
		sortIndex: 0,
		action: nil,
		actions: [],
	)
}

/// Goes through the real ``FeedDisplayModel/init(sectionList:)`` rather than
/// ``FeedDisplayModel/VisibleSection``'s own initializer — `internal` to
/// FeedUI, unreachable from this app-target test.
private func makeVenueSection(index: Int = 0, venues: [Venue]) -> FeedDisplayModel.VisibleSection {
	let sectionList = SectionList(
		hash: FeedHash(rawValue: "h"),
		sections: [
			Section(
				itemType: [],
				template: .venue,
				title: "Venues",
				index: index,
				store: nil,
				hash: nil,
				items: venues.map(Item.venue),
			),
		],
		actions: [],
	)
	return FeedDisplayModel(sectionList: sectionList).visibleSections[0]
}
