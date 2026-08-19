import SecretDJDomain

/// A fixed ``MusicSearching`` — previews only, never production (previews
/// always inject fakes, per swiftui-views).
struct PreviewMusicSearching: MusicSearching {
	private let artists: [Artist]
	private let trackResult: SectionList

	func search(query _: String, mode _: MusicSearchMode) async throws(MusicSearchError) -> SectionList {
		trackResult
	}

	func artistsAvailable() async throws(MusicSearchError) -> [Artist] {
		artists
	}

	func songs(forArtist _: String) async throws(MusicSearchError) -> SectionList {
		trackResult
	}

	static func artists() -> PreviewMusicSearching {
		PreviewMusicSearching(
			artists: [
				Artist(name: "Adele", artist: "Adele", numSongs: 3, sortIndex: 0, action: nil, actions: []),
				Artist(name: "Beyoncé", artist: "Beyoncé", numSongs: 1, sortIndex: 1, action: nil, actions: []),
				Artist(name: "Coldplay", artist: "Coldplay", numSongs: 5, sortIndex: 2, action: nil, actions: []),
			],
			trackResult: SectionList(hash: FeedHash(rawValue: "preview"), sections: [], actions: []),
		)
	}

	static func tracks() -> PreviewMusicSearching {
		PreviewMusicSearching(
			artists: [],
			trackResult: SectionList(
				hash: FeedHash(rawValue: "preview"),
				sections: [Section(
					itemType: .song,
					template: .song,
					title: "Songs",
					index: 0,
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
				)],
				actions: [],
			),
		)
	}
}
