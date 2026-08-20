import FeedUI
import SecretDJDomain
import Testing

@testable import SecretDJKiosk

/// ``KioskHomeDestination/init(outcome:)`` — which of the kiosk digest's
/// tap outcomes actually push a screen. PLAN.md S7.4–S7.6: a song tap goes
/// through TuneIn to request it (LEGACY.md "the kiosk's whole write path");
/// a jukebox tile drills into that jukebox's own song grid; the header's
/// search button and a multi-song artist row from search both push their
/// own screens (S7.6); moderation has no kiosk screen and is dropped (D13).
enum KioskHomeDestinationTests {
	struct `Mapping an outcome` {
		@Test func `maps showSong to the song destination`() {
			let song = Song(
				songId: "1",
				title: "Yellow",
				artist: "Coldplay",
				previewURL: nil,
				likeInfo: LikeInfo(likedByYou: false, info: ""),
				text: "",
				sortIndex: 0,
				action: nil,
				actions: [],
			)

			#expect(KioskHomeDestination(outcome: .showSong(.song(song))) == .song(.song(song)))
		}

		@Test func `maps showJukebox to the jukebox destination`() {
			#expect(KioskHomeDestination(outcome: .showJukebox(jukeboxId: 42)) == .jukebox(jukeboxId: 42))
		}

		@Test func `drops changeAtmosphere, already self-handled by MusicSelectionScreen`() {
			#expect(KioskHomeDestination(outcome: .changeAtmosphere(itemId: 1)) == nil)
		}

		@Test func `maps launchSearch to the search destination`() {
			#expect(KioskHomeDestination(outcome: .launchSearch) == .search)
		}

		@Test func `maps showSongsForArtist to the songsForArtist destination`() {
			#expect(
				KioskHomeDestination(outcome: .showSongsForArtist(artist: "Coldplay")) ==
					.songsForArtist(artist: "Coldplay"),
			)
		}

		@Test func `drops machineControl, no kiosk-side moderation per D13`() {
			#expect(KioskHomeDestination(outcome: .machineControl(action: .skip, itemId: 1)) == nil)
		}
	}
}
