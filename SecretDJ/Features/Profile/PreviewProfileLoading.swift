import FeedUI
import SecretDJDomain

/// A ``FeedUI/FeedLoading`` that returns a fixed profile feed immediately —
/// previews only, never production (previews always inject fakes, per
/// swiftui-views). Mirrors ``PreviewVenueLoading``: a `hiddenProfile`
/// section (drives ``ProfileHeaderView``) plus a visible check-in/award
/// section so the feed itself isn't empty — `.checkIn`/`.award` both
/// collapse onto the ``SecretDJDomain/Venue`` payload
/// (``FeedUI/FeedCellProps``'s doc comment).
struct PreviewProfileLoading: FeedLoading {
	private let sectionList: SectionList

	func load(page _: Int?) async throws -> SectionList {
		sectionList
	}

	static func ownProfile() -> PreviewProfileLoading {
		PreviewProfileLoading(sectionList: SectionList(
			hash: FeedHash(rawValue: "preview"),
			sections: [profileDetailsSection(personId: "9", screenName: "TurboTim"), hangoutsSection()],
			actions: [],
		))
	}

	static func otherProfile() -> PreviewProfileLoading {
		PreviewProfileLoading(sectionList: SectionList(
			hash: FeedHash(rawValue: "preview"),
			sections: [profileDetailsSection(personId: "41", screenName: "Someone Else"), hangoutsSection()],
			actions: [],
		))
	}

	static func empty(personId: String = "9", screenName: String = "TurboTim") -> PreviewProfileLoading {
		PreviewProfileLoading(sectionList: SectionList(
			hash: FeedHash(rawValue: "preview"),
			sections: [profileDetailsSection(personId: personId, screenName: screenName)],
			actions: [],
		))
	}

	private static func profileDetailsSection(personId: String, screenName: String) -> Section {
		Section(
			itemType: .person,
			template: .hiddenProfile,
			title: "",
			index: 0,
			store: nil,
			hash: nil,
			items: [.person(Person(
				personId: personId,
				screenName: screenName,
				gender: .unisex,
				likeInfo: LikeInfo(likedByYou: false, info: "3 people buzzed them"),
				email: nil,
				firstName: nil,
				lastName: nil,
				text: "",
				sortIndex: 0,
				action: nil,
				actions: [],
			))],
		)
	}

	private static func hangoutsSection() -> Section {
		Section(
			itemType: .venue,
			template: .checkIn,
			title: "Hangouts",
			index: 1,
			store: nil,
			hash: nil,
			items: [.venue(Venue(
				venueId: "v1",
				name: "The Fox and Hounds",
				address: "123 High Street, Chiswick, London",
				telephone: "",
				lat: 51.4919,
				lng: -0.2624,
				zoneName: "",
				promotionURL: nil,
				likeInfo: LikeInfo(likedByYou: false, info: ""),
				properties: [],
				checkedIn: false,
				hasMachineControl: false,
				text: "Checked in at\nThe Fox and Hounds",
				sortIndex: 0,
				action: nil,
				actions: [],
			))],
		)
	}
}
