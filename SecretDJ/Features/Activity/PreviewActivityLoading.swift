import FeedUI
import SecretDJDomain

/// A ``FeedUI/FeedLoading`` that returns a fixed result immediately —
/// previews only, never production (previews always inject fakes, per
/// swiftui-views). Mirrors ``PreviewPlacesNearbyLoading``, mixing every
/// content kind LEGACY.md's "Tab 2 — Activity feed" names — people
/// (`feedItem`), check-ins, and awards — so the Loaded preview exercises
/// both the S3.2 ``DesignSystem/PersonRowCell`` and
/// ``DesignSystem/EventRowCell`` this screen renders through.
struct PreviewActivityLoading: FeedLoading {
	private let sectionList: SectionList

	func load(page _: Int?) async throws -> SectionList {
		sectionList
	}

	static func loaded() -> PreviewActivityLoading {
		PreviewActivityLoading(sectionList: SectionList(
			hash: FeedHash(rawValue: "preview"),
			sections: [rabbitFeedSection(), checkInSection(), awardSection()],
			// Exercises the S6.12 insert-coin nav-bar action button in the
			// Loaded preview.
			actions: [
				Action(kind: .showTopup, itemId: nil, itemTypeId: nil, value: nil, url: nil, button: .insertCoin),
			],
		))
	}

	static func empty() -> PreviewActivityLoading {
		PreviewActivityLoading(sectionList: SectionList(
			hash: FeedHash(rawValue: "preview"),
			sections: [],
			actions: [],
		))
	}

	private static func rabbitFeedSection() -> Section {
		Section(
			itemType: .person,
			template: .feedItem,
			title: "Rabbit Feed",
			index: 0,
			store: nil,
			hash: nil,
			items: [
				.person(makePerson(
					personId: "p1",
					screenName: "simonib",
					text: "simonib became DJ of...\nThe Royal Oak\n74-76 York Street, London W1H 1QN\n6:14pm",
				)),
				.person(makePerson(
					personId: "p2",
					screenName: "emmaib",
					text: "emmaib liked...\nBillie Eilish And Astronomyy\nOcean eyes\n5:22pm",
				)),
			],
		)
	}

	private static func checkInSection() -> Section {
		Section(
			itemType: .venue,
			template: .checkIn,
			title: "Check-ins",
			index: 1,
			store: nil,
			hash: nil,
			items: [
				.venue(makeVenue(
					venueId: "v1",
					name: "Draft House",
					text: "tikky checked in at...\nDraft House\n238 Shepherds Bush Market, London W6 7NL\n5:14pm",
				)),
			],
		)
	}

	private static func awardSection() -> Section {
		Section(
			itemType: .venue,
			template: .award,
			title: "Awards",
			index: 2,
			store: nil,
			hash: nil,
			items: [
				.venue(makeVenue(
					venueId: "v2",
					name: "Volunteer",
					text: "ali.rapper won...\n10 Jukebox Credits\nBy adding a profile picture\nYesterday",
				)),
			],
		)
	}

	private static func makePerson(personId: String, screenName: String, text: String) -> Person {
		Person(
			personId: personId,
			screenName: screenName,
			gender: .unisex,
			likeInfo: LikeInfo(likedByYou: false, info: "Like this person..."),
			email: nil,
			firstName: nil,
			lastName: nil,
			text: text,
			sortIndex: 0,
			action: nil,
			actions: [],
		)
	}

	private static func makeVenue(venueId: String, name: String, text: String) -> Venue {
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
			text: text,
			sortIndex: 0,
			action: nil,
			actions: [],
		)
	}
}
