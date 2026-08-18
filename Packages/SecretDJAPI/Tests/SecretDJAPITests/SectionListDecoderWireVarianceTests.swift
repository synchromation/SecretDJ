import Foundation
import SecretDJDomain
import Testing

@testable import SecretDJAPI

/// Pins ``SectionListDecoder`` against real legacy feed fixtures whose
/// `Action.ItemId` and `Venue.MachineControl` fields arrive in a wire
/// representation other than a plain JSON number — string ids, and
/// string/bool/int machine-control flags. `SecretDJDomain`'s decoders
/// (`Action.swift`, `Venue.swift`) now tolerate this variance via
/// `Support/KeyedDecodingContainer+DecodingHelpers.swift`'s lenient
/// helpers; these were previously pinned as known gaps (every song/venue
/// item on the affected fixtures failed to decode) until that fix landed.
/// See `SectionListDecoderFixtureTests` for the rest of each fixture's
/// shape.
enum SectionListDecoderWireVarianceTests {
	struct `String-typed Action ItemId` {
		/// `secretdjv3`'s wire format sends `Data.Actions[].ItemId` as a
		/// **string** for `jukeboxRequestSong` actions (the song id, e.g.
		/// `"152380"`) — every real song-list fixture's `Actions` entries
		/// look like this.
		@Test func `decodes every song in MusicSelection json, whose Actions carry a string ItemId`() throws {
			let sectionList = try SectionListDecoder().decode(Fixture.data("MusicSelection"))

			let section = try #require(sectionList.sections.first)
			#expect(section.template == .song)
			#expect(section.items.count == 78)
		}

		/// The first song's request-song action, whose `ItemId` ("121607")
		/// matches its own `SongId`.
		@Test func `decodes a song's request-song action ItemId as an Int matching its SongId`() throws {
			let sectionList = try SectionListDecoder().decode(Fixture.data("MusicSelection"))

			let section = try #require(sectionList.sections.first)
			guard case .song(let song) = try #require(section.items.first) else {
				Issue.record("expected a .song item")
				return
			}
			#expect(song.songId == "121607")
			let action = try #require(song.actions.first)
			#expect(action.kind == .jukeboxRequestSong)
			#expect(action.itemId == 121_607)
		}

		/// Same root cause as above, pinned against `StyleInfo.json`'s
		/// `song` section (legacy: 50 songs).
		@Test func `decodes every song in StyleInfo json, whose Actions carry a string ItemId`() throws {
			let sectionList = try SectionListDecoder().decode(Fixture.data("StyleInfo"))

			let songSection = try #require(sectionList.sections.dropFirst().first)
			#expect(songSection.items.count == 50)
		}
	}

	struct `Wire-inconsistent MachineControl` {
		/// `secretdjv3`'s wire format sends venue `Data.MachineControl` as a
		/// JSON **string** (`VenueFeed.json`: `"63"`), a **bool**
		/// (`PlacesNearby.json`'s "Also recommended..." section: `false`),
		/// or an **int** (every other fixture: `0`) — the field is
		/// genuinely wire-inconsistent.
		@Test func `decodes VenueFeed json's one venue item, whose MachineControl is a wire string`() throws {
			let sectionList = try SectionListDecoder().decode(Fixture.data("VenueFeed"))

			let venueSection = try #require(sectionList.sections.first)
			#expect(venueSection.template == .hiddenVenueDetails)
			guard case .venue(let venue) = try #require(venueSection.items.first) else {
				Issue.record("expected a .venue item")
				return
			}
			// MachineControl "63" is a non-zero numeric string, so this
			// venue does grant machine-control affordances.
			#expect(venue.hasMachineControl)
		}

		/// Same root cause, pinned against `PlacesNearby.json`'s third
		/// venue section (legacy: 31 venues — `MachineControl` is the JSON
		/// bool `false` there).
		@Test func `decodes every venue in PlacesNearby json's third section, whose MachineControl is a wire bool`(
		) throws {
			let sectionList = try SectionListDecoder().decode(Fixture.data("PlacesNearby"))

			let thirdVenueSection = try #require(sectionList.sections.last)
			#expect(thirdVenueSection.template == .venue)
			#expect(thirdVenueSection.items.count == 31)
			let venues = thirdVenueSection.items.compactMap { item -> Venue? in
				guard case .venue(let venue) = item else { return nil }
				return venue
			}
			#expect(venues.count == 31)
			// MachineControl false everywhere in this section, so none of
			// its venues grant machine-control affordances.
			#expect(venues.allSatisfy { !$0.hasMachineControl })
		}
	}
}
