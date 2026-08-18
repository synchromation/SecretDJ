import Foundation
import Testing

@testable import SecretDJDomain

struct JukeboxTests {
	@Test func `reads every documented field`() throws {
		let json = Data(
			"""
			{"Text": "Rock", "Index": 4, "Data": {
			  "ItemTypeId": 1, "Id": 7, "TextColour": "#FF0000", "Description": "Rock classics",
			  "Action": {"Id": 300}, "Actions": []
			}}
			""".utf8,
		)

		let jukebox = try JSONDecoder().decode(Jukebox.self, from: json)

		#expect(jukebox.itemType == .album)
		#expect(jukebox.jukeboxId == 7)
		#expect(jukebox.textColour == "#FF0000")
		#expect(jukebox.subtitle == "Rock classics")
		#expect(jukebox.text == "Rock")
		#expect(jukebox.sortIndex == 4)
		#expect(jukebox.action?.kind == .jukeboxGotoItem)
	}

	@Test func `an absent TextColour falls back to the server's default grey`() throws {
		let json = Data(#"{"Data": {"Id": 1}}"#.utf8)

		let jukebox = try JSONDecoder().decode(Jukebox.self, from: json)

		#expect(jukebox.textColour == "#D3D3D3")
	}

	@Test func `an absent ItemTypeId decodes to an empty type mask`() throws {
		let json = Data(#"{"Data": {"Id": 1}}"#.utf8)

		let jukebox = try JSONDecoder().decode(Jukebox.self, from: json)

		#expect(jukebox.itemType.isEmpty)
	}

	/// `Image` is a sibling of `Text`/`Index`/`Data`, not nested inside
	/// `Data` — the real shape from `MusicSelection.json`'s "Recently Added".
	@Test func `decodes the sibling Image object into artwork`() throws {
		let json = Data(
			"""
			{"Data": {"Id": 1},
			 "Image": {"ItemTypeId": 134217728, "Resolutions": 5503, "Size": 2, "Uri": "j-1879048193.jpg"}}
			""".utf8,
		)

		let jukebox = try JSONDecoder().decode(Jukebox.self, from: json)

		#expect(jukebox.image?.url(for: .size3x3) ==
			URL(string: "https://secretdj.s3.amazonaws.com/jukeboxes/195x195/j-1879048193.jpg?2"))
	}

	@Test func `a missing Image decodes to no artwork`() throws {
		let json = Data(#"{"Data": {"Id": 1}}"#.utf8)

		let jukebox = try JSONDecoder().decode(Jukebox.self, from: json)

		#expect(jukebox.image == nil)
	}

	@Test func `a malformed Image never fails the whole item`() throws {
		let json = Data(#"{"Data": {"Id": 1}, "Image": "not an object"}"#.utf8)

		let jukebox = try JSONDecoder().decode(Jukebox.self, from: json)

		#expect(jukebox.image == nil)
		#expect(jukebox.jukeboxId == 1)
	}
}
