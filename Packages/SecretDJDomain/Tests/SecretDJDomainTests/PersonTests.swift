import Foundation
import Testing

@testable import SecretDJDomain

enum PersonTests {
	struct `Decoding a well-formed person` {
		@Test func `reads every documented field`() throws {
			let json = Data(
				"""
				{
				  "Text": "Jamie",
				  "Index": 2,
				  "Data": {
				    "User": "99",
				    "ScreenName": "Jamie",
				    "GenderId": 2,
				    "LikeInfo": {"LikedByYou": false, "Info": ""},
				    "Action": {"Id": 300},
				    "Actions": []
				  }
				}
				""".utf8,
			)

			let person = try JSONDecoder().decode(Person.self, from: json)

			#expect(person.personId == "99")
			#expect(person.screenName == "Jamie")
			#expect(person.gender == .male)
			#expect(!person.likeInfo.likedByYou)
			#expect(person.text == "Jamie")
			#expect(person.sortIndex == 2)
			#expect(person.action?.kind == .jukeboxGotoItem)
		}

		@Test func `an unrecognised GenderId falls back to unisex`() throws {
			let json = Data(#"{"Data": {"User": "1", "ScreenName": "A", "GenderId": 9}}"#.utf8)

			let person = try JSONDecoder().decode(Person.self, from: json)

			#expect(person.gender == .unisex)
		}

		@Test func `email, first name, and last name are not decoded from an item's own payload`() throws {
			// S1.3: these arrive on the parent hidden section's `Custom` payload,
			// not the person item's own `Data` — wiring that through needs a
			// captured `hiddenUserDetails` fixture.
			let json = Data(#"{"Data": {"User": "1", "ScreenName": "A"}}"#.utf8)

			let person = try JSONDecoder().decode(Person.self, from: json)

			#expect(person.email == nil)
			#expect(person.firstName == nil)
			#expect(person.lastName == nil)
		}

		/// `Image` is a sibling of `Text`/`Index`/`Data`, not nested inside
		/// `Data` — the real shape from `PlacesNearby.json`'s "nickbot".
		@Test func `decodes the sibling Image object into an avatar`() throws {
			let json = Data(
				"""
				{"Data": {"User": "1", "ScreenName": "A"},
				 "Image": {"ItemTypeId": 1073741824, "Resolutions": 5503, "Size": 3345, "Uri": "u-01256912-5442fc6c.jpg"}}
				""".utf8,
			)

			let person = try JSONDecoder().decode(Person.self, from: json)

			#expect(person.image?.url(for: .size4x4) ==
				URL(string: "https://secretdj.s3.amazonaws.com/useravatars/large/u-01256912-5442fc6c.jpg?3345"))
		}

		@Test func `a missing Image decodes to no avatar`() throws {
			let json = Data(#"{"Data": {"User": "1", "ScreenName": "A"}}"#.utf8)

			let person = try JSONDecoder().decode(Person.self, from: json)

			#expect(person.image == nil)
		}

		@Test func `a malformed Image never fails the whole item`() throws {
			let json = Data(#"{"Data": {"User": "1", "ScreenName": "A"}, "Image": "not an object"}"#.utf8)

			let person = try JSONDecoder().decode(Person.self, from: json)

			#expect(person.image == nil)
			#expect(person.personId == "1")
		}
	}

	struct `Identity validation` {
		@Test func `a missing personId fails to decode`() {
			let json = Data(#"{"Data": {"ScreenName": "A"}}"#.utf8)

			#expect(throws: (any Error).self) {
				try JSONDecoder().decode(Person.self, from: json)
			}
		}

		@Test func `a missing screenName fails to decode`() {
			let json = Data(#"{"Data": {"User": "1"}}"#.utf8)

			#expect(throws: (any Error).self) {
				try JSONDecoder().decode(Person.self, from: json)
			}
		}

		@Test func `an empty screenName fails to decode`() {
			let json = Data(#"{"Data": {"User": "1", "ScreenName": ""}}"#.utf8)

			#expect(throws: (any Error).self) {
				try JSONDecoder().decode(Person.self, from: json)
			}
		}
	}

	struct GenderTests {
		static let rawValues = [0, 1, 2]
		static let genders: [Gender] = [.unisex, .female, .male]

		@Test(arguments: zip(rawValues, genders))
		func `raw value initializes the matching case`(rawValue: Int, gender: Gender) {
			#expect(Gender(rawValue: rawValue) == gender)
		}

		@Test func `round-trips through JSON`() throws {
			let encoded = try JSONEncoder().encode(Gender.female)

			#expect(try JSONDecoder().decode(Gender.self, from: encoded) == .female)
		}
	}

	struct PersonInteractionsTests {
		@Test func `decodes the profile header stats`() throws {
			let json = Data(
				"""
				{
				  "PlacesVisited": 12,
				  "SongRequests": 34,
				  "NumPeopleWhoLikeUser": 5,
				  "LastCheckin": {"VenueName": "The Crown", "ZoneName": "Bar"}
				}
				""".utf8,
			)

			let interactions = try JSONDecoder().decode(PersonInteractions.self, from: json)

			#expect(interactions.placesVisited == 12)
			#expect(interactions.songRequests == 34)
			#expect(interactions.peopleWhoLikeUser == 5)
			#expect(interactions.lastVenueName == "The Crown")
			#expect(interactions.lastZoneName == "Bar")
		}

		@Test func `missing fields default to zero counts and no last check-in`() throws {
			let json = Data("{}".utf8)

			let interactions = try JSONDecoder().decode(PersonInteractions.self, from: json)

			#expect(interactions.placesVisited == 0)
			#expect(interactions.songRequests == 0)
			#expect(interactions.peopleWhoLikeUser == 0)
			#expect(interactions.lastVenueName == nil)
			#expect(interactions.lastZoneName == nil)
		}
	}
}
