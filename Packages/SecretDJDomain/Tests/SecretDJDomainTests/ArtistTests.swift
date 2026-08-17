import Foundation
import Testing

@testable import SecretDJDomain

struct ArtistTests {
	@Test func `reads name, artist, and song count from the outer payload`() throws {
		let json = Data(
			"""
			{"Name": "Abbey Road", "Artist": "The Beatles", "NumSongs": 3, "Index": 0,
			 "Data": {"Action": {"Id": 300}, "Actions": []}}
			""".utf8,
		)

		let artist = try JSONDecoder().decode(Artist.self, from: json)

		#expect(artist.name == "Abbey Road")
		#expect(artist.artist == "The Beatles")
		#expect(artist.numSongs == 3)
		#expect(artist.sortIndex == 0)
		#expect(artist.action?.kind == .jukeboxGotoItem)
	}

	@Test func `NumSongs defaults to one when absent`() throws {
		let json = Data(#"{"Artist": "Solo Act"}"#.utf8)

		let artist = try JSONDecoder().decode(Artist.self, from: json)

		#expect(artist.numSongs == 1)
	}

	struct `Client-synthesized display text` {
		@Test func `is just the artist name when there is one song`() throws {
			let json = Data(#"{"Artist": "Solo Act", "NumSongs": 1}"#.utf8)

			let artist = try JSONDecoder().decode(Artist.self, from: json)

			#expect(artist.displayText == "Solo Act")
		}

		@Test func `appends an ellipsis when the artist has more than one song`() throws {
			let json = Data(#"{"Artist": "The Beatles", "NumSongs": 3}"#.utf8)

			let artist = try JSONDecoder().decode(Artist.self, from: json)

			#expect(artist.displayText == "The Beatles ...")
		}
	}
}
