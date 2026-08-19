import FeedUI
import SecretDJDomain

/// A ``FeedUI/FeedLoading`` that returns a fixed music-selection feed
/// immediately — previews only, never production (previews always inject
/// fakes, per swiftui-views). A song row plus a mood tile row, so
/// ``MusicSelectionScreen``'s controlTile-dispatches-changeAtmosphere path
/// (S6.3 scope item 1) is visible in previews too.
struct PreviewMusicSelectionLoading: FeedLoading {
	private let sectionList: SectionList

	func load(page _: Int?) async throws -> SectionList {
		sectionList
	}

	static func loaded() -> PreviewMusicSelectionLoading {
		PreviewMusicSelectionLoading(sectionList: SectionList(
			hash: FeedHash(rawValue: "preview"),
			sections: [songSection(), moodSection()],
			actions: [],
		))
	}

	static func empty() -> PreviewMusicSelectionLoading {
		PreviewMusicSelectionLoading(sectionList: SectionList(
			hash: FeedHash(rawValue: "preview"),
			sections: [],
			actions: [],
		))
	}

	private static func songSection() -> Section {
		Section(
			itemType: .song,
			template: .song,
			title: "Songs",
			index: 0,
			store: nil,
			hash: nil,
			items: [
				.song(Song(
					songId: "1",
					title: "Ocean Eyes",
					artist: "Billie Eilish",
					previewURL: nil,
					likeInfo: LikeInfo(likedByYou: false, info: ""),
					text: "Ocean Eyes\nBillie Eilish",
					sortIndex: 0,
					action: nil,
					actions: [],
				)),
			],
		)
	}

	private static func moodSection() -> Section {
		Section(
			itemType: .control,
			template: .matrixControlLarge,
			title: "Change The Mood",
			index: 1,
			store: nil,
			hash: nil,
			items: [
				.control(Control(
					fgColour: "#FFFFFF",
					bgColour: "#6C2BD9",
					text: "Chilled",
					sortIndex: 0,
					action: Action(
						kind: .jukeboxChangeAtmosphere,
						itemId: 42,
						itemTypeId: Int(ItemType.control.rawValue),
						value: "30",
						url: nil,
						button: .init(rawValue: 0),
					),
					actions: [],
				)),
			],
		)
	}
}
