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

	struct `Image decoding` {
		/// `Image` is a sibling of `Name`/`Index`/`Data`, matching every other
		/// payload type — no live fixture carries an artist `Image` (none of
		/// this package's fixtures include an artist row), so this shape
		/// follows `secretdjv3/ItemImage.swift`'s documented wire contract
		/// rather than a captured payload.
		@Test func `decodes a present Image object`() throws {
			let json = Data(
				"""
				{"Artist": "The Beatles",
				 "Image": {"ItemTypeId": 8, "Resolutions": 5503, "Size": 1, "Uri": "artist.jpg"}}
				""".utf8,
			)

			let artist = try JSONDecoder().decode(Artist.self, from: json)

			#expect(artist.image != nil)
			// Legacy's `imageBaseURL()` has no `.artist` case — artist rows
			// never resolved to a real bucket even when `Image` was present.
			#expect(artist.image?.url(for: .size1x1) == nil)
		}

		@Test func `a missing Image decodes to no artwork`() throws {
			let json = Data(#"{"Artist": "Solo Act"}"#.utf8)

			let artist = try JSONDecoder().decode(Artist.self, from: json)

			#expect(artist.image == nil)
		}

		@Test func `a malformed Image never fails the whole item`() throws {
			let json = Data(#"{"Artist": "Solo Act", "Image": "not an object"}"#.utf8)

			let artist = try JSONDecoder().decode(Artist.self, from: json)

			#expect(artist.image == nil)
			#expect(artist.artist == "Solo Act")
		}
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
