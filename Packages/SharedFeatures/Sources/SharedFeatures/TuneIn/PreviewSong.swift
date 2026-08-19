import SecretDJDomain

/// Preview-only ``SecretDJDomain/Song`` fixtures for ``TuneInScreen``'s own
/// `#Preview`s.
enum PreviewSong {
	static var requestable: Song {
		Song(
			songId: "1",
			title: "Yellow",
			artist: "Coldplay",
			previewURL: nil,
			likeInfo: LikeInfo(likedByYou: false, info: ""),
			text: "",
			sortIndex: 0,
			action: nil,
			actions: [Action(
				kind: .jukeboxRequestSong,
				itemId: 1,
				itemTypeId: nil,
				value: nil,
				url: nil,
				button: .unsupported(0),
			)],
		)
	}

	/// A requestable song that also carries a preview URL, to exercise
	/// ``TuneInScreen``'s play/stop preview button in previews.
	static var withPreview: Song {
		Song(
			songId: "4",
			title: "Viva la Vida",
			artist: "Coldplay",
			previewURL: "https://example.com/viva-la-vida.pbz",
			likeInfo: LikeInfo(likedByYou: false, info: ""),
			text: "",
			sortIndex: 0,
			action: nil,
			actions: [Action(
				kind: .jukeboxRequestSong,
				itemId: 4,
				itemTypeId: nil,
				value: nil,
				url: nil,
				button: .unsupported(0),
			)],
		)
	}

	static var moderatable: Song {
		Song(
			songId: "2",
			title: "Clocks",
			artist: "Coldplay",
			previewURL: nil,
			likeInfo: LikeInfo(likedByYou: false, info: ""),
			text: "",
			sortIndex: 0,
			action: nil,
			actions: [
				Action(
					kind: .jukeboxSkipSong,
					itemId: 2,
					itemTypeId: nil,
					value: nil,
					url: nil,
					button: .unsupported(0),
				),
				Action(
					kind: .jukeboxBlacklistSong,
					itemId: 2,
					itemTypeId: nil,
					value: nil,
					url: nil,
					button: .unsupported(0),
				),
			],
		)
	}

	static var liked: Song {
		Song(
			songId: "3",
			title: "Fix You",
			artist: "Coldplay",
			previewURL: nil,
			likeInfo: LikeInfo(likedByYou: true, info: "24 people buzzed this"),
			text: "",
			sortIndex: 0,
			action: nil,
			actions: [Action(
				kind: .jukeboxRequestSong,
				itemId: 3,
				itemTypeId: nil,
				value: nil,
				url: nil,
				button: .unsupported(0),
			)],
		)
	}
}
