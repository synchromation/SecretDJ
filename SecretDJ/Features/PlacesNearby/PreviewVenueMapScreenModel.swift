import FeedUI
import SecretDJDomain

/// A ``VenueMapScreenModel`` over a couple of sample venues — previews only,
/// never production (previews always inject fakes, per swiftui-views).
/// Goes through ``FeedDisplayModel/init(sectionList:)`` since
/// ``FeedDisplayModel/VisibleSection``'s own initializer is `internal` to
/// FeedUI.
enum PreviewVenueMapScreenModel {
	static func sample() -> VenueMapScreenModel {
		let sectionList = SectionList(
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
						.venue(makeVenue(
							venueId: "v1",
							name: "The Lamb",
							lat: 51.4919,
							lng: -0.2624,
							hasJukebox: true,
						)),
						.venue(makeVenue(
							venueId: "v2",
							name: "No. 197",
							lat: 51.4923,
							lng: -0.2575,
							hasJukebox: false,
						)),
					],
				),
			],
			actions: [],
		)
		return VenueMapScreenModel(sections: FeedDisplayModel(sectionList: sectionList).visibleSections)
	}

	private static func makeVenue(venueId: String, name: String, lat: Double, lng: Double, hasJukebox: Bool) -> Venue {
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
			properties: hasJukebox ? .hasJukebox : [],
			checkedIn: false,
			hasMachineControl: false,
			text: name,
			sortIndex: 0,
			action: nil,
			actions: [],
		)
	}
}
