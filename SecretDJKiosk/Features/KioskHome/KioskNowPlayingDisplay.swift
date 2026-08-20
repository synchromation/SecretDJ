import Foundation
import SecretDJDomain

/// What the kiosk's now-playing header renders (PLAN.md S7.4) — derived once
/// from the venue's current ``SecretDJDomain/Song`` (``FeedUI/FeedDisplayModel/currentSong``)
/// rather than switched on inside the view body (lazy-sections' compute-once
/// rule, applied here even though this screen isn't a lazy feed).
enum KioskNowPlayingDisplay: Equatable {
	/// No song has played at this venue yet this session (a feed with no
	/// history row) — the header shows neither artwork nor a message.
	case idle
	/// An ordinary song: artwork (`nil` when the song carries none),
	/// title, and artist at kiosk scale.
	case nowPlaying(title: String, artist: String, artworkURL: URL?)
	/// The server's intermission placeholder
	/// (``SecretDJDomain/Song/isIntermission``, song id `"0"`) — an
	/// arbitrary two-line venue message, artwork always suppressed
	/// (LEGACY.md "Home screen: Now Playing + jukebox wall").
	case intermission(title: String, subtitle: String)

	/// Classifies `song` per ``SecretDJDomain/Song/isIntermission``: `nil`
	/// (nothing has played yet) is ``idle``; the intermission sentinel splits
	/// its title on the server's blank-line separator
	/// (``SecretDJDomain/Song/intermissionMessageLines``); every other song
	/// renders as ``nowPlaying(title:artist:artworkURL:)``, its artwork
	/// resolved at the header's own largest bucket.
	init(song: Song?) {
		guard let song else {
			self = .idle
			return
		}

		if song.isIntermission {
			let lines = song.intermissionMessageLines
			self = .intermission(title: lines.title, subtitle: lines.subtitle)
		} else {
			self = .nowPlaying(title: song.title, artist: song.artist, artworkURL: song.image?.url(for: .size1x1))
		}
	}
}
