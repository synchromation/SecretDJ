import Foundation
import Testing

@testable import SecretDJDomain

enum VenueTests {
	struct `Decoding a well-formed venue` {
		@Test func `reads every documented field`() throws {
			let json = Data(
				"""
				{
				  "Text": "The Crown",
				  "Index": 1,
				  "Data": {
				    "Venue": "42",
				    "VenueName": "The Crown",
				    "VenueAddress": "1 High Street",
				    "Telephone": "01234 567890",
				    "Lat": 51.5,
				    "Lng": -0.1,
				    "ZoneName": "Bar",
				    "VenuePromotionUrl": "https://example.com/promo",
				    "LikeInfo": {"LikedByYou": true, "Info": "3 people like this"},
				    "Properties": 3,
				    "CheckedIn": true,
				    "MachineControl": 1,
				    "Action": {"Id": 300},
				    "Actions": []
				  }
				}
				""".utf8,
			)

			let venue = try JSONDecoder().decode(Venue.self, from: json)

			#expect(venue.venueId == "42")
			#expect(venue.name == "The Crown")
			#expect(venue.address == "1 High Street")
			#expect(venue.telephone == "01234 567890")
			#expect(venue.lat == 51.5)
			#expect(venue.lng == -0.1)
			#expect(venue.zoneName == "Bar")
			#expect(venue.promotionURL == "https://example.com/promo")
			#expect(venue.likeInfo.likedByYou)
			#expect(venue.properties == [.reportsPlayHistory, .hasJukebox])
			#expect(venue.checkedIn)
			#expect(venue.hasMachineControl)
			#expect(venue.text == "The Crown")
			#expect(venue.sortIndex == 1)
			#expect(venue.action?.kind == .jukeboxGotoItem)
		}

		@Test func `an empty promotion URL decodes to no URL`() throws {
			let json = Data(#"{"Data": {"Venue": "1", "VenuePromotionUrl": ""}}"#.utf8)

			let venue = try JSONDecoder().decode(Venue.self, from: json)

			#expect(venue.promotionURL == nil)
		}

		@Test func `MachineControl of zero means no machine control`() throws {
			let json = Data(#"{"Data": {"Venue": "1", "MachineControl": 0}}"#.utf8)

			let venue = try JSONDecoder().decode(Venue.self, from: json)

			#expect(!venue.hasMachineControl)
		}

		@Test func `a missing MachineControl defaults to no machine control`() throws {
			let json = Data(#"{"Data": {"Venue": "1"}}"#.utf8)

			let venue = try JSONDecoder().decode(Venue.self, from: json)

			#expect(!venue.hasMachineControl)
		}
	}

	struct `MachineControl decodes leniently across wire representations` {
		/// `secretdjv3` sends `MachineControl` as a JSON string on some
		/// payloads — `VenueFeed.json`: `"63"`.
		@Test func `a numeric string MachineControl of "1" means hasMachineControl is true`() throws {
			let json = Data(#"{"Data": {"Venue": "1", "MachineControl": "1"}}"#.utf8)

			let venue = try JSONDecoder().decode(Venue.self, from: json)

			#expect(venue.hasMachineControl)
		}

		@Test func `a numeric string MachineControl of "0" means hasMachineControl is false`() throws {
			let json = Data(#"{"Data": {"Venue": "1", "MachineControl": "0"}}"#.utf8)

			let venue = try JSONDecoder().decode(Venue.self, from: json)

			#expect(!venue.hasMachineControl)
		}

		/// The real wire value from `VenueFeed.json`.
		@Test func `a numeric string MachineControl of "63" means hasMachineControl is true`() throws {
			let json = Data(#"{"Data": {"Venue": "1", "MachineControl": "63"}}"#.utf8)

			let venue = try JSONDecoder().decode(Venue.self, from: json)

			#expect(venue.hasMachineControl)
		}

		/// `secretdjv3` sends `MachineControl` as a JSON bool on some
		/// payloads — `PlacesNearby.json`'s "Also recommended..." section:
		/// `false`.
		@Test func `a bool MachineControl of true means hasMachineControl is true`() throws {
			let json = Data(#"{"Data": {"Venue": "1", "MachineControl": true}}"#.utf8)

			let venue = try JSONDecoder().decode(Venue.self, from: json)

			#expect(venue.hasMachineControl)
		}

		@Test func `a bool MachineControl of false means hasMachineControl is false`() throws {
			let json = Data(#"{"Data": {"Venue": "1", "MachineControl": false}}"#.utf8)

			let venue = try JSONDecoder().decode(Venue.self, from: json)

			#expect(!venue.hasMachineControl)
		}

		/// `secretdjv3` sends `MachineControl` as a plain JSON int on most
		/// payloads — every fixture but the two above.
		@Test func `an int MachineControl of 1 means hasMachineControl is true`() throws {
			let json = Data(#"{"Data": {"Venue": "1", "MachineControl": 1}}"#.utf8)

			let venue = try JSONDecoder().decode(Venue.self, from: json)

			#expect(venue.hasMachineControl)
		}
	}

	struct `Identity validation` {
		@Test func `a missing venue id fails to decode`() {
			let json = Data(#"{"Data": {"VenueName": "The Crown"}}"#.utf8)

			#expect(throws: (any Error).self) {
				try JSONDecoder().decode(Venue.self, from: json)
			}
		}

		@Test func `an empty venue id fails to decode`() {
			let json = Data(#"{"Data": {"Venue": ""}}"#.utf8)

			#expect(throws: (any Error).self) {
				try JSONDecoder().decode(Venue.self, from: json)
			}
		}
	}

	struct `VenueProperties bitmask` {
		@Test func `composes independently settable flags`() {
			let properties: VenueProperties = [.reportsPlayHistory, .hasJukebox]

			#expect(properties.contains(.reportsPlayHistory))
			#expect(properties.contains(.hasJukebox))
		}

		@Test func `a bare reportsPlayHistory flag does not imply hasJukebox`() {
			let properties: VenueProperties = [.reportsPlayHistory]

			#expect(!properties.contains(.hasJukebox))
		}
	}
}
