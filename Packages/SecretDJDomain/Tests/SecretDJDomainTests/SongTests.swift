import Foundation
import Testing

@testable import SecretDJDomain

enum SongTests {
	struct `Decoding a well-formed song` {
		@Test func `reads every documented field`() throws {
			let json = Data(
				"""
				{
				  "Text": "Song Title\\nArtist Name",
				  "Index": 3,
				  "Data": {
				    "SongId": "123",
				    "Title": "Song Title",
				    "Artist": "Artist Name",
				    "Preview": "https://example.com/preview.pbz",
				    "LikeInfo": {"LikedByYou": true, "Info": "12 people buzzed this"},
				    "Action": {"Id": 403},
				    "Actions": [{"Id": 401}, {"Id": 402}]
				  }
				}
				""".utf8,
			)

			let song = try JSONDecoder().decode(Song.self, from: json)

			#expect(song.songId == "123")
			#expect(song.title == "Song Title")
			#expect(song.artist == "Artist Name")
			#expect(song.previewURL == "https://example.com/preview.pbz")
			#expect(song.likeInfo.likedByYou)
			#expect(song.likeInfo.info == "12 people buzzed this")
			#expect(song.text == "Song Title\nArtist Name")
			#expect(song.sortIndex == 3)
			#expect(song.action?.kind == .jukeboxRequestSong)
			#expect(song.actions.map(\.kind) == [.jukeboxSkipSong, .jukeboxBlacklistSong])
		}

		@Test func `an empty preview string decodes to no preview`() throws {
			let json = Data(#"{"Data": {"SongId": "1", "Preview": ""}}"#.utf8)

			let song = try JSONDecoder().decode(Song.self, from: json)

			#expect(song.previewURL == nil)
		}

		/// `Image` is a sibling of `Text`/`Index`/`Data`, not nested inside
		/// `Data` — the real shape from `PlayHistory.json`'s first item.
		@Test func `decodes the sibling Image object into artwork`() throws {
			let json = Data(
				"""
				{"Data": {"SongId": "1"},
				 "Image": {"ItemTypeId": 2, "Resolutions": 5503, "Size": 4483, "Uri": "s102000/s102698.jpg"}}
				""".utf8,
			)

			let song = try JSONDecoder().decode(Song.self, from: json)

			#expect(song.image?.url(for: .size1x1) ==
				URL(string: "https://secretdj.s3.amazonaws.com/songcovers/640x640/s102000/s102698.jpg?4483"))
		}

		@Test func `a missing Image decodes to no artwork`() throws {
			let json = Data(#"{"Data": {"SongId": "1"}}"#.utf8)

			let song = try JSONDecoder().decode(Song.self, from: json)

			#expect(song.image == nil)
		}

		@Test func `a malformed Image never fails the whole item`() throws {
			let json = Data(#"{"Data": {"SongId": "1"}, "Image": "not an object"}"#.utf8)

			let song = try JSONDecoder().decode(Song.self, from: json)

			#expect(song.image == nil)
			#expect(song.songId == "1")
		}
	}

	struct `Intermission contract` {
		@Test func `a missing SongId defaults to the intermission id`() throws {
			let json = Data(#"{"Data": {}}"#.utf8)

			let song = try JSONDecoder().decode(Song.self, from: json)

			#expect(song.songId == "0")
			#expect(song.isIntermission)
		}

		@Test func `songId "0" is an intermission`() {
			let song = Song(
				songId: "0",
				title: "",
				artist: "",
				previewURL: nil,
				likeInfo: LikeInfo(likedByYou: false, info: ""),
				text: "",
				sortIndex: 0,
				action: nil,
				actions: [],
			)

			#expect(song.isIntermission)
		}

		@Test func `any other songId is not an intermission`() {
			let song = Song(
				songId: "42",
				title: "",
				artist: "",
				previewURL: nil,
				likeInfo: LikeInfo(likedByYou: false, info: ""),
				text: "",
				sortIndex: 0,
				action: nil,
				actions: [],
			)

			#expect(!song.isIntermission)
		}

		@Test func `a two-line intermission title splits into title and subtitle`() {
			let song = Song(
				songId: "0",
				title: "Back in 10 minutes\n\nGrab another drink!",
				artist: "",
				previewURL: nil,
				likeInfo: LikeInfo(likedByYou: false, info: ""),
				text: "",
				sortIndex: 0,
				action: nil,
				actions: [],
			)

			let lines = song.intermissionMessageLines

			#expect(lines.title == "Back in 10 minutes")
			#expect(lines.subtitle == "Grab another drink!")
		}

		@Test func `an intermission title with no separator has an empty subtitle`() {
			let song = Song(
				songId: "0",
				title: "Back soon",
				artist: "",
				previewURL: nil,
				likeInfo: LikeInfo(likedByYou: false, info: ""),
				text: "",
				sortIndex: 0,
				action: nil,
				actions: [],
			)

			let lines = song.intermissionMessageLines

			#expect(lines.title == "Back soon")
			#expect(lines.subtitle.isEmpty)
		}
	}
}
