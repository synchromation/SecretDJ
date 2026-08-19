import FeedUI
import Foundation
import SecretDJAPI
import SecretDJDomain
import Testing

@testable import SecretDJ

/// Verifies the existing S3.1–S3.3 feed pipeline
/// (``SecretDJAPI/SectionListDecoder`` → ``FeedUI/FeedDisplayModel`` →
/// ``FeedUI/FeedCellProps`` → ``FeedUI/FeedActionRouter``) against an
/// `eventhistory`-shaped response mixing every content kind LEGACY.md's
/// "Tab 2 — Activity feed" names: people (`feedItem`/300 — the only
/// template SecretDJAPI's captured `Live/EventHistory.json` and the legacy
/// repo's `SecretDJTests/JSON/EventHistory.json` actually contain), plus
/// `checkIn` (103) and `award` (102) — LEGACY.md's "rendered through the
/// generic template system (`CheckInCollectionViewCell`,
/// `AwardCollectionViewCell`, `FeedItemCollectionViewCell`, …)", a
/// combination no captured fixture happens to exercise together. This
/// fixture is derived from those two person-shaped captures plus
/// SecretDJAPI's `PersonDetails.json` "Hangouts" section (the venue/award
/// shape) — copied in-line rather than reaching into another target's test
/// bundle (PLAN.md S6.5).
enum ActivityEventHistoryFixtureTests {
	struct `Decoding an eventhistory response` {
		@Test func `resolves each section to its documented template`() throws {
			let sectionList = try SectionListDecoder().decode(eventHistoryFixture)

			#expect(sectionList.sections.map(\.template) == [.feedItem, .checkIn, .award])
		}

		@Test func `decodes the feedItem-template section's items as Person`() throws {
			let sectionList = try SectionListDecoder().decode(eventHistoryFixture)

			let section = try #require(sectionList.sections.first)
			#expect(section.items.count == 2)
			#expect(section.items.allSatisfy { if case .person = $0 { true } else { false } })
		}

		@Test func `decodes the checkIn- and award-template items as Venue`() throws {
			let sectionList = try SectionListDecoder().decode(eventHistoryFixture)

			#expect(sectionList.sections[1].items.allSatisfy { if case .venue = $0 { true } else { false } })
			#expect(sectionList.sections[2].items.allSatisfy { if case .venue = $0 { true } else { false } })
		}
	}

	struct `Building the render-ready display model` {
		/// ``FeedUI/FeedCellProps``'s own case payloads (`PersonProps`,
		/// `EventProps`) are internal to FeedUI — deliberately: they're
		/// consumed only by ``FeedUI/FeedListSection``'s own body, never by a
		/// calling app (lazy-sections' cell-props-are-compute-once rule).
		/// This suite therefore checks the case selection (which cell FeedUI
		/// picks) plus every field FeedUI does expose publicly —
		/// ``FeedUI/FeedDisplayItem/text``/``FeedUI/FeedDisplayItem/template``
		/// and the underlying Domain ``SecretDJDomain/Item`` — rather than
		/// reaching past that boundary.
		@Test func `every section renders as a plain list, nothing dropped or hidden`() throws {
			let sectionList = try SectionListDecoder().decode(eventHistoryFixture)
			let displayModel = FeedDisplayModel(sectionList: sectionList)

			#expect(displayModel.visibleSections.map(\.kind) == [.list, .list, .list])
			#expect(displayModel.hiddenSections.isEmpty)
			#expect(displayModel.droppedSections.isEmpty)
		}

		@Test func `a person feedItem selects the PersonRowCell props and keeps its tagged text`() throws {
			let sectionList = try SectionListDecoder().decode(eventHistoryFixture)
			let displayModel = FeedDisplayModel(sectionList: sectionList)

			let item = try #require(displayModel.visibleSections[0].items.first)
			guard case .person = item.props else {
				Issue.record("expected .person props, got \(item.props)")
				return
			}
			#expect(item.template == .feedItem)
			#expect(item.text == "simonib became DJ of...\nThe Royal Oak\n74-76 York Street, London W1H 1QN\n6:14pm")
			guard case .person(let person) = item.item else {
				Issue.record("expected a .person item")
				return
			}
			#expect(person.personId == "01256919_a220d696")
			#expect(person.screenName == "simonib")
		}

		@Test func `a checkIn item selects the EventRowCell props, not a browsable venue row`() throws {
			let sectionList = try SectionListDecoder().decode(eventHistoryFixture)
			let displayModel = FeedDisplayModel(sectionList: sectionList)

			let item = try #require(displayModel.visibleSections[1].items.first)
			guard case .event = item.props else {
				Issue.record("expected .event props, got \(item.props)")
				return
			}
			#expect(item.template == .checkIn)
			#expect(item
				.text == "tikky checked in at...\nDraft House\n238 Shepherds Bush Market, London W6 7NL\n5:14pm")
			guard case .venue(let venue) = item.item else {
				Issue.record("expected a .venue item")
				return
			}
			#expect(venue.venueId == "00004872_2b1b9700")
			#expect(venue.name == "Draft House")
		}

		@Test func `an award item selects the EventRowCell props, not a browsable venue row`() throws {
			let sectionList = try SectionListDecoder().decode(eventHistoryFixture)
			let displayModel = FeedDisplayModel(sectionList: sectionList)

			let item = try #require(displayModel.visibleSections[2].items.first)
			guard case .event = item.props else {
				Issue.record("expected .event props, got \(item.props)")
				return
			}
			#expect(item.template == .award)
			#expect(item.text == "ali.rapper won...\n10 Jukebox Credits\nBy adding a profile picture\nYesterday")
			guard case .venue(let venue) = item.item else {
				Issue.record("expected a .venue item")
				return
			}
			#expect(venue.venueId == "00293203_46cd72ed")
			#expect(venue.name == "Volunteer")
		}
	}

	/// The task's tap-routing contract: person items route to `.person`,
	/// venue-shaped (award/check-in) items route to `.venue` — both through
	/// the same generic ``FeedUI/FeedActionRouter``/``AppDestination``
	/// machinery every other S6 feed screen already uses, exercised here
	/// against the real eventhistory shapes rather than a synthetic one.
	struct `Routing a tap through the tab's router` {
		@Test func `a person item routes to the person destination`() throws {
			let sectionList = try SectionListDecoder().decode(eventHistoryFixture)
			let displayModel = FeedDisplayModel(sectionList: sectionList)
			let router = FeedActionRouter(installedApps: FakeInstalledApps())

			let item = try #require(displayModel.visibleSections[0].items.first)
			let outcome = try #require(router.outcome(forTap: item))

			#expect(outcome == .showPerson(personId: "01256919_a220d696"))
			#expect(AppDestination(outcome: outcome) == .person(personId: "01256919_a220d696"))
		}

		@Test func `a check-in item routes to the venue destination`() throws {
			let sectionList = try SectionListDecoder().decode(eventHistoryFixture)
			let displayModel = FeedDisplayModel(sectionList: sectionList)
			let router = FeedActionRouter(installedApps: FakeInstalledApps())

			let item = try #require(displayModel.visibleSections[1].items.first)
			let outcome = try #require(router.outcome(forTap: item))

			#expect(outcome == .showVenue(venueId: "00004872_2b1b9700"))
			#expect(AppDestination(outcome: outcome) == .venue(venueId: "00004872_2b1b9700"))
		}
	}
}

private struct FakeInstalledApps: InstalledApps {
	func isInstalled(_: SocialPlatform) -> Bool {
		false
	}
}

/// An `eventhistory`-shaped response: one `feedItem` (300) "Rabbit Feed"
/// section (person rows, derived from SecretDJAPI's `Live/EventHistory.json`
/// capture), one `checkIn` (103) section, and one `award` (102) section
/// (both venue-shaped, derived from SecretDJAPI's `PersonDetails.json`
/// "Hangouts" section) — see this file's own doc comment for provenance.
private let eventHistoryFixture = Data(
	"""
	{
	  "Sections": [
	    {
	      "Title": "Rabbit Feed",
	      "ItemTypeId": 1073741824,
	      "Templates": [300],
	      "Index": 1,
	      "Items": [
	        {
	          "Data": {
	            "User": "01256919_a220d696",
	            "ScreenName": "simonib",
	            "GenderId": 2,
	            "LikeInfo": { "Info": "Like this person...", "LikedByYou": false }
	          },
	          "Image": {
	            "Uri": "u-01256919-a220d696.jpg",
	            "Size": 3681,
	            "ItemTypeId": 1073741824,
	            "Resolutions": 5503
	          },
	          "Text": "simonib became DJ of...\\nThe Royal Oak\\n74-76 York Street, London W1H 1QN\\n6:14pm",
	          "Index": 1
	        },
	        {
	          "Data": {
	            "User": "01243026_008f4c0f",
	            "ScreenName": "emmaib",
	            "GenderId": 0,
	            "LikeInfo": { "Info": "Like this person...", "LikedByYou": false }
	          },
	          "Image": {
	            "Uri": "u-01243026-008f4c0f.jpg",
	            "Size": 3703,
	            "ItemTypeId": 1073741824,
	            "Resolutions": 5503
	          },
	          "Text": "emmaib liked...\\nBillie Eilish And Astronomyy\\nOcean eyes\\n5:22pm",
	          "Index": 2
	        }
	      ]
	    },
	    {
	      "Title": "Check-ins",
	      "ItemTypeId": 536870912,
	      "Templates": [103],
	      "Index": 2,
	      "Items": [
	        {
	          "Data": {
	            "Venue": "00004872_2b1b9700",
	            "VenueName": "Draft House",
	            "VenueAddress": "238 Shepherds Bush Market, London W6 7NL",
	            "ZoneName": "",
	            "Properties": 3,
	            "CheckedIn": true,
	            "LikeInfo": { "Info": "Liked by GoldStar and 42 others", "LikedByYou": false }
	          },
	          "Image": {
	            "Uri": "v-00004872-2b1b9700.jpg",
	            "Size": 6426,
	            "ItemTypeId": 536870912,
	            "Resolutions": 5503
	          },
	          "Text": "tikky checked in at...\\nDraft House\\n238 Shepherds Bush Market, London W6 7NL\\n5:14pm",
	          "Index": 1
	        }
	      ]
	    },
	    {
	      "Title": "Awards",
	      "ItemTypeId": 536870912,
	      "Templates": [102],
	      "Index": 3,
	      "Items": [
	        {
	          "Data": {
	            "Venue": "00293203_46cd72ed",
	            "VenueName": "Volunteer",
	            "VenueAddress": "247 Baker Street, London NW1 6XE",
	            "ZoneName": "",
	            "Properties": 3,
	            "CheckedIn": false,
	            "LikeInfo": { "Info": "Like this person...", "LikedByYou": false }
	          },
	          "Image": {
	            "Uri": "u-01256908-267ec3a5.jpg",
	            "Size": 6324,
	            "ItemTypeId": 536870912,
	            "Resolutions": 5503
	          },
	          "Text": "ali.rapper won...\\n10 Jukebox Credits\\nBy adding a profile picture\\nYesterday",
	          "Index": 1
	        }
	      ]
	    }
	  ],
	  "Actions": [],
	  "Success": true,
	  "Token": "REDACTED-TOKEN-0000"
	}
	""".utf8,
)
