import FeedUI
import SecretDJDomain

/// A ``FeedUI/FeedLoading`` that returns a fixed now-playing feed
/// immediately — previews only, never production (previews always inject
/// fakes, per swiftui-views). Mirrors ``PreviewActivityLoading``.
struct PreviewNowPlayingLoading: FeedLoading {
	private let sectionList: SectionList

	func load(page _: Int?) async throws -> SectionList {
		sectionList
	}

	static func loaded() -> PreviewNowPlayingLoading {
		PreviewNowPlayingLoading(sectionList: SectionList(
			hash: FeedHash(rawValue: "preview"),
			sections: [
				Section(
					itemType: .song,
					template: .song,
					title: "Now Playing",
					index: 0,
					store: nil,
					hash: nil,
					items: [
						.song(makeSong(songId: "1", title: "Ocean Eyes", artist: "Billie Eilish")),
						.song(makeSong(songId: "2", title: "Levitating", artist: "Dua Lipa")),
					],
				),
			],
			// Exercises the S6.12 hail-taxi nav-bar action button in the Loaded
			// preview.
			actions: [
				Action(
					kind: .launchUberApp,
					itemId: nil,
					itemTypeId: nil,
					value: nil,
					url: "https://m.uber.com/ul/?action=setPickup",
					button: .hailTaxi,
				),
			],
		))
	}

	static func empty() -> PreviewNowPlayingLoading {
		PreviewNowPlayingLoading(sectionList: SectionList(
			hash: FeedHash(rawValue: "preview"),
			sections: [],
			actions: [],
		))
	}

	private static func makeSong(songId: String, title: String, artist: String) -> Song {
		Song(
			songId: songId,
			title: title,
			artist: artist,
			previewURL: nil,
			likeInfo: LikeInfo(likedByYou: false, info: ""),
			text: "\(title)\n\(artist)",
			sortIndex: 0,
			action: nil,
			actions: [],
		)
	}
}
