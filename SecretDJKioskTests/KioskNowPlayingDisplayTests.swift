import Testing

@testable import SecretDJKiosk

import SecretDJDomain

/// ``KioskNowPlayingDisplay`` — the kiosk header's own render model
/// (PLAN.md S7.4): a real song shows artwork/title/artist; the server's
/// intermission placeholder (``SecretDJDomain/Song/isIntermission``, song id
/// `"0"`) shows as a two-line message instead, split on the server's blank
/// line separator, with artwork suppressed (LEGACY.md "Home screen: Now
/// Playing + jukebox wall").
enum KioskNowPlayingDisplayTests {
	struct `Building from a song` {
		@Test func `is idle for no song`() {
			#expect(KioskNowPlayingDisplay(song: nil) == .idle)
		}

		@Test func `is nowPlaying for an ordinary song, carrying its title, artist, and artwork URL`() {
			let song = makeSong(songId: "1", title: "Yellow", artist: "Coldplay")

			let display = KioskNowPlayingDisplay(song: song)

			#expect(display == .nowPlaying(title: "Yellow", artist: "Coldplay", artworkURL: nil))
		}

		@Test func `is intermission for the sentinel song id, splitting the title on the server's blank line`() {
			let song = makeSong(songId: "0", title: "Back in ten minutes\n\nGrab another drink at the bar!")

			let display = KioskNowPlayingDisplay(song: song)

			#expect(display == .intermission(
				title: "Back in ten minutes",
				subtitle: "Grab another drink at the bar!",
			))
		}

		@Test func `is intermission with an empty subtitle when the server sends no second line`() {
			let song = makeSong(songId: "0", title: "Back soon")

			let display = KioskNowPlayingDisplay(song: song)

			#expect(display == .intermission(title: "Back soon", subtitle: ""))
		}
	}
}

// MARK: - Fixtures

private func makeSong(songId: String, title: String, artist: String = "") -> Song {
	Song(
		songId: songId,
		title: title,
		artist: artist,
		previewURL: nil,
		likeInfo: LikeInfo(likedByYou: false, info: ""),
		text: "",
		sortIndex: 0,
		action: nil,
		actions: [],
	)
}
