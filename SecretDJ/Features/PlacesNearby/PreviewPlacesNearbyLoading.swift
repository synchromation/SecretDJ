import FeedUI
import SecretDJDomain

/// A ``FeedUI/FeedLoading`` that returns a fixed result immediately —
/// previews only, never production (previews always inject fakes, per
/// swiftui-views). Simpler than ``FeedUI/InMemoryFeedLoading`` for this
/// purpose: that fake's outcomes are configured through `async` actor calls,
/// awkward from a `#Preview` builder that needs a value synchronously.
struct PreviewPlacesNearbyLoading: FeedLoading {
	private let sectionList: SectionList

	func load(page _: Int?) async throws -> SectionList {
		sectionList
	}

	static func loaded() -> PreviewPlacesNearbyLoading {
		PreviewPlacesNearbyLoading(sectionList: SectionList(
			hash: FeedHash(rawValue: "preview"),
			sections: [
				Section(
					itemType: [],
					template: .venue,
					title: "Venues",
					index: 0,
					store: nil,
					hash: nil,
					items: [
						.venue(makeVenue(venueId: "v1", name: "The Lamb")),
						.venue(makeVenue(venueId: "v2", name: "No. 197 Chiswick Fire Station")),
					],
				),
			],
			actions: [],
		))
	}

	static func empty() -> PreviewPlacesNearbyLoading {
		PreviewPlacesNearbyLoading(sectionList: SectionList(
			hash: FeedHash(rawValue: "preview"),
			sections: [],
			actions: [],
		))
	}

	private static func makeVenue(venueId: String, name: String) -> Venue {
		Venue(
			venueId: venueId,
			name: name,
			address: "9 Barley Mow Passage, London W4 4PH",
			telephone: "",
			lat: 51.4919,
			lng: -0.2624,
			zoneName: "",
			promotionURL: nil,
			likeInfo: LikeInfo(likedByYou: false, info: ""),
			properties: .hasJukebox,
			checkedIn: false,
			hasMachineControl: false,
			text: "\(name)\n9 Barley Mow Passage, London W4 4PH\n0.2 miles",
			sortIndex: 0,
			action: nil,
			actions: [],
		)
	}
}
