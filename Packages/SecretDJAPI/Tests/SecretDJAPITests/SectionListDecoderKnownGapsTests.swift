import Foundation
import SecretDJDomain
import Testing

@testable import SecretDJAPI

/// Two pre-existing `SecretDJDomain` decode gaps (S1.1, already merged —
/// out of scope for this package to fix) discovered while pinning S1.3c
/// against real legacy fixtures. Both make ``SectionListDecoder``'s
/// per-item tolerance kick in far more than legacy's own parsing ever did
/// on the same payloads, because legacy's Objective-C-era dictionary
/// access never type-checked these fields at all. Flagged for follow-up
/// rather than fixed here (`Do NOT touch files outside Packages/SecretDJAPI/`).
enum SectionListDecoderKnownGapsTests {
	struct `String-typed Action ItemId drops every requestable song` {
		/// `secretdjv3`'s wire format sends `Data.Actions[].ItemId` as a
		/// **string** for `jukeboxRequestSong` actions (the song id, e.g.
		/// `"152380"` — every real song-list fixture's `Actions` entries
		/// look like this) but as a JSON **number** for
		/// `jukeboxChangeAtmosphere` actions (a numeric control/mood id —
		/// `StyleInfo-Short.json`'s `Action.ItemId: 679`).
		/// `SecretDJDomain.Action.itemId` is declared `Int?` and decodes
		/// with a plain `decodeIfPresent(Int.self, ...)`
		/// (`Packages/SecretDJDomain/Sources/SecretDJDomain/Action.swift`),
		/// which throws — not returns `nil` — when the key is present with
		/// the wrong JSON type. Because `Song.actions` decodes its whole
		/// `[Action]` array in one shot, one bad `Action` fails the entire
		/// `Song`, and this decoder's per-item tolerance drops it. In
		/// practice this means **every song carrying a request-song action
		/// currently fails to decode** — close to all of them in a real
		/// jukebox feed (`MusicSelection.json`: 78/78 dropped;
		/// `StyleInfo.json`: 50/50 dropped). `PersonDetails.json`'s "Your
		/// Favourite Tunes" section is the one fixture that survives, only
		/// because its songs' `Actions` arrays happen to be empty.
		@Test func `drops every song in MusicSelection json, whose Actions carry a string ItemId`() throws {
			let sectionList = try SectionListDecoder().decode(Fixture.data("MusicSelection"))

			let section = try #require(sectionList.sections.first)
			#expect(section.template == .song)
			#expect(section.items.isEmpty)
		}

		/// Same root cause as above, pinned against `StyleInfo.json`'s
		/// `song` section (legacy: 50 songs; this build: 0 survive decode).
		@Test func `drops every song in StyleInfo json, whose Actions carry a string ItemId`() throws {
			let sectionList = try SectionListDecoder().decode(Fixture.data("StyleInfo"))

			let songSection = try #require(sectionList.sections.dropFirst().first)
			#expect(songSection.items.isEmpty)
		}
	}

	struct `Wire-inconsistent MachineControl drops most real venues` {
		/// `secretdjv3`'s wire format sends venue `Data.MachineControl` as a
		/// JSON **string** (`VenueFeed.json`: `"63"`), a **bool**
		/// (`PlacesNearby.json`'s "Also recommended..." section: `false`),
		/// or an **int** (every other fixture: `0`) — the field is
		/// genuinely wire-inconsistent.
		/// `SecretDJDomain.Venue.hasMachineControl` decodes with
		/// `data.decodeIfPresent(Int.self, forKey: .machineControl)`
		/// (`Packages/SecretDJDomain/Sources/SecretDJDomain/Venue.swift`),
		/// which throws for the string/bool cases instead of tolerating
		/// them, so every such `Venue` item is dropped.
		@Test func `drops VenueFeed json's one venue item, whose MachineControl is a wire string`() throws {
			let sectionList = try SectionListDecoder().decode(Fixture.data("VenueFeed"))

			let venueSection = try #require(sectionList.sections.first)
			#expect(venueSection.template == .hiddenVenueDetails)
			#expect(venueSection.items.isEmpty)
		}

		/// Same root cause, pinned against `PlacesNearby.json`'s third
		/// venue section (legacy: 31 venues; this build: 0 survive decode
		/// — `MachineControl` is the JSON bool `false` there).
		@Test func `drops every venue in PlacesNearby json's third section, whose MachineControl is a wire bool`(
		) throws {
			let sectionList = try SectionListDecoder().decode(Fixture.data("PlacesNearby"))

			let thirdVenueSection = try #require(sectionList.sections.last)
			#expect(thirdVenueSection.template == .venue)
			#expect(thirdVenueSection.items.isEmpty)
		}
	}
}
