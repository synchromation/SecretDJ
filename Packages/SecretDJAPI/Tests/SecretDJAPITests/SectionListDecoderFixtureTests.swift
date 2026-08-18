import Foundation
import SecretDJDomain
import Testing

@testable import SecretDJAPI

/// Pins ``SectionListDecoder`` against real legacy feed fixtures — one
/// suite per endpoint shape, each citing which legacy file/test it's
/// checked against. See `SectionListDecoderTests` for isolated
/// per-template dispatch and malformed-data tolerance, and
/// `SectionListDecoderWireVarianceTests` for the fixtures whose
/// `Action.ItemId`/`Venue.MachineControl` arrive in a non-Int wire
/// representation.
enum SectionListDecoderFixtureTests {
	struct `Venue feed shape` {
		/// `VenueFeed.json`: four sections (venue, VIP list, one promotion,
		/// social links) plus one bar-button action — the fixture
		/// `secret-dj-ios-old/SecretDJTests/SectionListTests.swift` pins
		/// against directly.
		@Test func `decodes every section in server order, sorting nothing`() throws {
			let sectionList = try SectionListDecoder().decode(Fixture.data("VenueFeed"))

			#expect(sectionList.sections.count == 4)
			#expect(sectionList.sections.map(\.title) == ["Venue", "VIP List", " ", "Social"])
			#expect(sectionList.sections.map(\.index) == [1, 2, 3, 4])
		}

		@Test func `decodes a VIP template section into a Person item`() throws {
			let sectionList = try SectionListDecoder().decode(Fixture.data("VenueFeed"))

			let vipSection = try #require(sectionList.sections.dropFirst().first)
			#expect(vipSection.template == .vip)
			guard case .person(let person) = try #require(vipSection.items.first) else {
				Issue.record("expected a .person item")
				return
			}
			#expect(person.screenName == "lewiswork")
		}

		@Test func `decodes a section whose Custom is JSON null as having no store or hash`() throws {
			let sectionList = try SectionListDecoder().decode(Fixture.data("VenueFeed"))

			let venueSection = try #require(sectionList.sections.first)
			#expect(venueSection.store == nil)
			#expect(venueSection.hash == nil)
		}

		@Test func `decodes the section-list-wide bar-button action`() throws {
			let sectionList = try SectionListDecoder().decode(Fixture.data("VenueFeed"))

			#expect(sectionList.actions.count == 1)
			let action = try #require(sectionList.actions.first)
			#expect(action.kind == .launchUberSignup)
			#expect(action.button == .hailTaxi)
			#expect(action.value == nil)
		}

		/// `VenueFeed.json` carries no top-level `Hash` field.
		@Test func `defaults the feed-wide hash to empty when Hash is absent`() throws {
			let sectionList = try SectionListDecoder().decode(Fixture.data("VenueFeed"))

			#expect(sectionList.hash == FeedHash(rawValue: ""))
		}
	}

	struct `Places nearby shape` {
		/// `PlacesNearby.json` (`placesnearby`'s legacy fixture): a hidden
		/// profile section (301) plus three venue-template (100) sections.
		@Test func `decodes the hidden profile section as a Person`() throws {
			let sectionList = try SectionListDecoder().decode(Fixture.data("PlacesNearby"))

			let profileSection = try #require(sectionList.sections.first)
			#expect(profileSection.template == .hiddenUserDetails)
			guard case .person(let person) = try #require(profileSection.items.first) else {
				Issue.record("expected a .person item")
				return
			}
			#expect(person.screenName == "TurboTim")
		}

		@Test func `decodes every venue-template section`() throws {
			let sectionList = try SectionListDecoder().decode(Fixture.data("PlacesNearby"))

			let venueSections = sectionList.sections.dropFirst()
			#expect(venueSections.map(\.template) == [.venue, .venue, .venue])
		}
	}

	struct `Activity (eventhistory) shape` {
		/// `EventHistory.json`: one `feedItem` (300) section, 50 items.
		@Test func `decodes the feed-item template section as Person entries`() throws {
			let sectionList = try SectionListDecoder().decode(Fixture.data("EventHistory"))

			let section = try #require(sectionList.sections.first)
			#expect(section.template == .feedItem)
			#expect(section.items.count == 50)
			#expect(section.items.allSatisfy { if case .person = $0 { true } else { false } })
		}
	}

	struct `Profile (persondetails) shape` {
		/// `PersonDetails.json`: hidden profile (302), a "Your Favourite
		/// Tunes" section whose `Templates` is `[203, 200]`, and an
		/// `award` (102) "Hangouts" section — a real multi-template array,
		/// unlike the single-element ones every other fixture carries.
		@Test func `resolves a multi-element Templates array to its first recognized code`() throws {
			let sectionList = try SectionListDecoder().decode(Fixture.data("PersonDetails"))

			let tunesSection = try #require(sectionList.sections.dropFirst().first)
			#expect(tunesSection.title == "Your Favourite Tunes")
			// 203 (horizontalSong) precedes 200 (song) in the raw array and
			// both are recognized, so horizontalSong wins — legacy's
			// `firstValidTemplate` never reorders by "most specific".
			#expect(tunesSection.template == .horizontalSong)
			#expect(tunesSection.items.count == 20)
			#expect(tunesSection.items.allSatisfy { if case .song = $0 { true } else { false } })
		}

		@Test func `decodes the hidden profile section as a Person`() throws {
			let sectionList = try SectionListDecoder().decode(Fixture.data("PersonDetails"))

			let profileSection = try #require(sectionList.sections.first)
			#expect(profileSection.template == .hiddenProfile)
			guard case .person(let person) = try #require(profileSection.items.first) else {
				Issue.record("expected a .person item")
				return
			}
			#expect(person.screenName == "TurboTim")
		}

		@Test func `decodes an award-template section as a Venue`() throws {
			let sectionList = try SectionListDecoder().decode(Fixture.data("PersonDetails"))

			let hangoutsSection = try #require(sectionList.sections.last)
			#expect(hangoutsSection.title == "Hangouts")
			#expect(hangoutsSection.template == .award)
			#expect(hangoutsSection.items.count == 1)
			#expect(hangoutsSection.items.allSatisfy { if case .venue = $0 { true } else { false } })
		}
	}

	struct `Music selection shape` {
		/// `MusicSelection.json`: one `song` (200) section, no top-level
		/// `Index`, and `Custom.Hash` — the pagination/change-detection
		/// token S1.3e surfaces directly on ``SecretDJDomain/Section``.
		/// Section-level metadata (`hash`/`store`/`index`) decodes from
		/// `Custom` independently of item decode — see
		/// `SectionListDecoderWireVarianceTests` for this fixture's 78
		/// songs, whose `Actions` carry a string `ItemId`.
		@Test func `decodes the section's Custom Hash as its pagination token`() throws {
			let sectionList = try SectionListDecoder().decode(Fixture.data("MusicSelection"))

			let section = try #require(sectionList.sections.first)
			#expect(section.hash == FeedHash(rawValue: "adjfa92"))
		}

		@Test func `decodes the section's affiliate store override`() throws {
			let sectionList = try SectionListDecoder().decode(Fixture.data("MusicSelection"))

			let section = try #require(sectionList.sections.first)
			let store = try #require(section.store)
			#expect(
				store.searchURL ==
					"http://itunes.apple.com/search?entity=musicTrack&limit=1&country=gb&partnerId=2003&term=",
			)
		}

		/// No top-level `Index` key on this fixture's one section.
		@Test func `defaults a missing section Index to zero`() throws {
			let sectionList = try SectionListDecoder().decode(Fixture.data("MusicSelection"))

			#expect(sectionList.sections.first?.index == 0)
		}
	}

	struct `Style info shape` {
		/// `StyleInfo.json`: an unrecognized `matrixControlLarge`-shaped
		/// section (`Templates: [1001]`, this build only knows `1000`) plus
		/// a `song` (200) section carrying `Custom.Hash`
		/// (`secret-dj-ios-old/SecretDJTests/MachineControlAPIAccessTests.swift`'s
		/// `testCanParseStyleInfo`: hash `2a31478b`, 50 songs — see
		/// `SectionListDecoderWireVarianceTests` for that item count, whose
		/// `Actions` carry a string `ItemId`).
		@Test func `keeps the section for an unrecognized template code, tagged unsupported`() throws {
			let sectionList = try SectionListDecoder().decode(Fixture.data("StyleInfo"))

			let moodSection = try #require(sectionList.sections.first)
			#expect(moodSection.template == .unsupported(1001))
			#expect(moodSection.items.count == 1)
			#expect(moodSection.items.allSatisfy {
				if case .unsupported(.unsupported(1001)) = $0 { true } else { false }
			})
		}

		@Test func `decodes the song section's template and pagination hash`() throws {
			let sectionList = try SectionListDecoder().decode(Fixture.data("StyleInfo"))

			let songSection = try #require(sectionList.sections.dropFirst().first)
			#expect(songSection.template == .song)
			#expect(songSection.hash == FeedHash(rawValue: "2a31478b"))
		}
	}
}
