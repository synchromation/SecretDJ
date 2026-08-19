import FeedUI
import SecretDJDomain

/// A ``FeedUI/FeedLoading`` that returns a fixed venue feed immediately —
/// previews only, never production (previews always inject fakes, per
/// swiftui-views). Mirrors ``PreviewActivityLoading``: a `hiddenVenueDetails`
/// section (drives ``VenueHeaderView``), an `ItemType.event` socials section
/// (exercises ``VenueSocialLinksOrdering`` end to end), and a visible song
/// section so the feed itself isn't empty.
struct PreviewVenueLoading: FeedLoading {
	private let sectionList: SectionList

	func load(page _: Int?) async throws -> SectionList {
		sectionList
	}

	static func loaded() -> PreviewVenueLoading {
		PreviewVenueLoading(sectionList: SectionList(
			hash: FeedHash(rawValue: "preview"),
			sections: [venueDetailsSection(), socialsSection(), songSection()],
			actions: [],
		))
	}

	static func empty() -> PreviewVenueLoading {
		PreviewVenueLoading(sectionList: SectionList(
			hash: FeedHash(rawValue: "preview"),
			sections: [venueDetailsSection()],
			actions: [],
		))
	}

	private static func venueDetailsSection() -> Section {
		Section(
			itemType: .venue,
			template: .hiddenVenueDetails,
			title: "",
			index: 0,
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
				likeInfo: LikeInfo(likedByYou: false, info: "12 people buzzed this"),
				properties: [.hasJukebox, .reportsPlayHistory],
				checkedIn: false,
				hasMachineControl: false,
				text: "",
				sortIndex: 0,
				action: nil,
				actions: [],
			))],
		)
	}

	private static func socialsSection() -> Section {
		Section(
			itemType: .event,
			template: .promotion,
			title: "Follow us",
			index: 1,
			store: nil,
			hash: nil,
			items: [
				.promotion(Promotion(
					promotionId: SocialPlatform.instagram.rawValue,
					url: "https://instagram.com/secretdj",
					externalBrowser: false,
					height: 60,
					text: "Instagram",
					sortIndex: 0,
					action: nil,
					actions: [],
				)),
				.promotion(Promotion(
					promotionId: SocialPlatform.facebook.rawValue,
					url: "https://facebook.com/secretdj",
					externalBrowser: true,
					height: 60,
					text: "Facebook",
					sortIndex: 1,
					action: nil,
					actions: [],
				)),
			],
		)
	}

	private static func songSection() -> Section {
		Section(
			itemType: .song,
			template: .song,
			title: "Recently Played",
			index: 2,
			store: nil,
			hash: nil,
			items: [.song(Song(
				songId: "1",
				title: "Ocean Eyes",
				artist: "Billie Eilish",
				previewURL: nil,
				likeInfo: LikeInfo(likedByYou: false, info: ""),
				text: "Ocean Eyes\nBillie Eilish",
				sortIndex: 0,
				action: nil,
				actions: [],
			))],
		)
	}
}
