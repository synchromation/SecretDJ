import Foundation
import SecretDJDomain
import Testing

@testable import SecretDJAPI

enum SectionListDecoderTests {
	/// Wraps one raw `Items` entry in a single-section feed body and
	/// decodes it, for tests that only care about one template's dispatch
	/// in isolation. `itemJSON` is the full item object (`Text`/`Index`/`Data`
	/// for every payload but `Artist`, which is flat).
	static func decodeSingleItem(templateCode: Int, itemJSON: String) throws -> Item? {
		let json = Data(
			"""
			{"Sections": [{"Title": "t", "ItemTypeId": 0, "Templates": [\(templateCode)], "Items": [\(
				itemJSON
			)], "Index": 1}], "Success": true}
			""".utf8,
		)
		let sectionList = try SectionListDecoder().decode(json)
		return sectionList.sections.first?.items.first
	}

	/// Every template's dispatch, proven with a minimal, self-consistent
	/// payload for each — clean of the wire's real-world type
	/// variance (see `SectionListDecoderWireVarianceTests`), so these
	/// isolate ``SectionListDecoder``'s own dispatch table from bugs in the
	/// ``SecretDJDomain`` leaf types it calls into.
	struct `Per-template dispatch` {
		@Test func `venue template (100) dispatches to Item venue`() throws {
			let item = try SectionListDecoderTests.decodeSingleItem(
				templateCode: 100,
				itemJSON: """
				{"Text": "t", "Index": 1, "Data": {
				  "Venue": "V1", "VenueName": "Test Venue", "VenueAddress": "1 Road", "Telephone": "123",
				  "Lat": 1.0, "Lng": 2.0, "ZoneName": "Zone", "MachineControl": 5,
				  "LikeInfo": {"Info": "i", "LikedByYou": false}
				}}
				""",
			)

			guard case .venue(let venue) = try #require(item) else {
				Issue.record("expected .venue")
				return
			}
			#expect(venue.venueId == "V1")
			#expect(venue.name == "Test Venue")
			#expect(venue.hasMachineControl == true)
		}

		@Test func `song template (200) dispatches to Item song`() throws {
			let item = try SectionListDecoderTests.decodeSingleItem(
				templateCode: 200,
				itemJSON: """
				{"Text": "t", "Index": 1, "Data": {
				  "SongId": "S1", "Title": "Song Title", "Artist": "Artist Name",
				  "LikeInfo": {"Info": "i", "LikedByYou": true}
				}}
				""",
			)

			guard case .song(let song) = try #require(item) else {
				Issue.record("expected .song")
				return
			}
			#expect(song.songId == "S1")
			#expect(song.title == "Song Title")
		}

		@Test func `person template (304) dispatches to Item person`() throws {
			let item = try SectionListDecoderTests.decodeSingleItem(
				templateCode: 304,
				itemJSON: """
				{"Text": "t", "Index": 1, "Data": {
				  "User": "U1", "ScreenName": "Name", "GenderId": 1,
				  "LikeInfo": {"Info": "i", "LikedByYou": false}
				}}
				""",
			)

			guard case .person(let person) = try #require(item) else {
				Issue.record("expected .person")
				return
			}
			#expect(person.personId == "U1")
			#expect(person.screenName == "Name")
		}

		@Test func `artist template (800) dispatches to Item artist`() throws {
			let item = try SectionListDecoderTests.decodeSingleItem(
				templateCode: 800,
				itemJSON: #"{"Name": "A", "Artist": "Artist Name", "NumSongs": 3, "Index": 1}"#,
			)

			guard case .artist(let artist) = try #require(item) else {
				Issue.record("expected .artist")
				return
			}
			#expect(artist.artist == "Artist Name")
			#expect(artist.numSongs == 3)
		}

		@Test func `jukeboxList template (600) dispatches to Item jukebox`() throws {
			let item = try SectionListDecoderTests.decodeSingleItem(
				templateCode: 600,
				itemJSON: """
				{"Text": "t", "Index": 1, "Data": {
				  "ItemTypeId": 1, "Id": 42, "TextColour": "#FFF", "Description": "desc"
				}}
				""",
			)

			guard case .jukebox(let jukebox) = try #require(item) else {
				Issue.record("expected .jukebox")
				return
			}
			#expect(jukebox.jukeboxId == 42)
			#expect(jukebox.subtitle == "desc")
		}

		@Test func `topUp template (700) dispatches to Item topUp`() throws {
			let item = try SectionListDecoderTests.decodeSingleItem(
				templateCode: 700,
				itemJSON: """
				{"Text": "t", "Index": 1, "Data": {
				  "SKU": "SKU1", "VendorId": 2, "Name": "10 credits", "Description": "d",
				  "Price": "0.99", "DisplayPrice": "£0.99", "CurrencyCode": "GBP", "NumCredits": 10
				}}
				""",
			)

			guard case .topUp(let topUp) = try #require(item) else {
				Issue.record("expected .topUp")
				return
			}
			#expect(topUp.sku == "SKU1")
			#expect(topUp.numCredits == 10)
		}

		@Test func `promotion template (400) dispatches to Item promotion`() throws {
			let item = try SectionListDecoderTests.decodeSingleItem(
				templateCode: 400,
				itemJSON: """
				{"Text": "t", "Index": 1, "Data": {"Id": 5, "Url": "https://example.com", "ExternalBrowser": true, "Height": 100}}
				""",
			)

			guard case .promotion(let promotion) = try #require(item) else {
				Issue.record("expected .promotion")
				return
			}
			#expect(promotion.promotionId == 5)
			#expect(promotion.externalBrowser == true)
		}

		@Test func `matrixControlLarge template (1000) dispatches to Item control`() throws {
			let item = try SectionListDecoderTests.decodeSingleItem(
				templateCode: 1000,
				itemJSON: """
				{"Text": "Daytime", "Index": 1, "Data": {"FgCol": "#000000", "BgCol": "#fffa9c"}}
				""",
			)

			guard case .control(let control) = try #require(item) else {
				Issue.record("expected .control")
				return
			}
			#expect(control.text == "Daytime")
			#expect(control.bgColour == "#fffa9c")
		}

		/// `container` (9999) is a real server template code with no
		/// dispatchable Domain payload — `SecretDJDomain.Item` has no
		/// `.container` case (legacy only ever synthesizes it client-side
		/// to nest a horizontal collection, never receives it from the
		/// server as an item's own template).
		@Test func `container template (9999) dispatches to unsupported`() throws {
			let item = try SectionListDecoderTests.decodeSingleItem(templateCode: 9999, itemJSON: #"{"Text": "t"}"#)

			guard case .unsupported(.container) = try #require(item) else {
				Issue.record("expected .unsupported(.container)")
				return
			}
		}
	}

	struct `Malformed and missing data tolerance` {
		/// Mirrors `secretdjv3/Section.swift`'s `parseItem` returning `nil`
		/// for one bad entry without failing its siblings — LEGACY.md's
		/// per-item tolerance this decoder preserves even though it stopped
		/// mirroring legacy's whole-section dropping (see
		/// ``SectionListDecoder``'s doc comment).
		@Test func `drops a malformed item but keeps its well-formed siblings`() throws {
			let json = Data(
				"""
				{
				  "Sections": [{
				    "Title": "Songs",
				    "ItemTypeId": 2,
				    "Templates": [200],
				    "Items": [
				      {"Text": "ok", "Index": 1, "Data": {"SongId": "1", "Title": "A", "Artist": "B"}},
				      {"Text": "no Data key at all"},
				      {"Text": "ok2", "Index": 2, "Data": {"SongId": "2", "Title": "C", "Artist": "D"}}
				    ],
				    "Index": 1
				  }],
				  "Success": true
				}
				""".utf8,
			)

			let sectionList = try SectionListDecoder().decode(json)

			let section = try #require(sectionList.sections.first)
			#expect(section.items.count == 2)
		}

		@Test func `decodes a section with no Items key as having zero items, not one empty item`() throws {
			let json = Data(
				#"""
				{"Sections": [{"Title": "Empty", "ItemTypeId": 2, "Templates": [200], "Index": 1}], "Success": true}
				"""#.utf8,
			)

			let sectionList = try SectionListDecoder().decode(json)

			#expect(sectionList.sections.first?.items.isEmpty == true)
		}

		@Test func `decodes an entirely unrecognized template code as unsupported, not dropped`() throws {
			let json = Data(
				#"""
				{
				  "Sections": [{
				    "Title": "Future feature",
				    "ItemTypeId": 0,
				    "Templates": [42424242],
				    "Items": [{"Text": "?", "Index": 1, "Data": {}}],
				    "Index": 1
				  }],
				  "Success": true
				}
				"""#.utf8,
			)

			let sectionList = try SectionListDecoder().decode(json)

			let section = try #require(sectionList.sections.first)
			#expect(section.template == .unsupported(42_424_242))
			#expect(section.items.count == 1)
			#expect(section.items.allSatisfy {
				if case .unsupported(.unsupported(42_424_242)) = $0 { true } else { false }
			})
		}

		@Test func `defaults a section with no Templates key to the unsupported zero code`() throws {
			let json = Data(
				#"""
				{"Sections": [{"Title": "?", "ItemTypeId": 0, "Items": [], "Index": 1}], "Success": true}
				"""#.utf8,
			)

			let sectionList = try SectionListDecoder().decode(json)

			#expect(sectionList.sections.first?.template == .unsupported(0))
		}

		@Test func `decodes an entirely empty Sections array without throwing`() throws {
			let json = Data(#"{"Success": true, "Sections": []}"#.utf8)

			let sectionList = try SectionListDecoder().decode(json)

			#expect(sectionList.sections.isEmpty)
		}

		@Test func `decodes a missing Sections key as an empty section list`() throws {
			let json = Data(#"{"Success": true}"#.utf8)

			let sectionList = try SectionListDecoder().decode(json)

			#expect(sectionList.sections.isEmpty)
		}
	}
}
