import Foundation
import SecretDJDomain

/// A tap or server-driven action's routed effect — the vocabulary
/// ``FeedActionRouter`` produces from a ``FeedDisplayItem`` or Domain
/// ``Action``. Purely descriptive: FeedUI performs no navigation or network
/// calls itself (PLAN.md S3.3); a consuming app's handler executes the
/// outcome.
public enum FeedActionOutcome: Sendable, Hashable {
	/// Show the TuneIn screen — either a specific song, or (an artist row
	/// with exactly one song) that artist's only song, keyed by name because
	/// no song id is known at that point
	/// (`secretdjv3/FeedActionProvider.swift`'s `handle(songItem:)` and
	/// `handleArtist(artist:...)`, the `numSongs == 1` branch).
	case showSong(TuneInTarget)
	/// An artist row with more than one song — show the song-selection list
	/// (`secretdjv3/FeedActionProvider.swift`'s `handleArtist`, the `else`
	/// branch).
	case showSongsForArtist(artist: String)
	case showVenue(venueId: String)
	case showPerson(personId: String)
	/// A browsable jukebox/genre row (`ActionKind/jukeboxGotoItem` on a
	/// ``SecretDJDomain/Jukebox`` item) — navigate into that collection
	/// (`secretdjv3/FeedActionProvider.swift`'s `actionGotoJukebox(jukebox:)`).
	case showJukebox(jukeboxId: Int)
	case showTopUps(context: TopUpContext)
	case launchSearch
	/// `ActionKind/jukeboxChangeAtmosphere` — set the venue's mood/genre for
	/// `itemId`'s duration. Also how the kiosk digest's change-mood tiles
	/// dispatch (S7).
	case changeAtmosphere(itemId: Int)
	/// `ActionKind/jukeboxRequestSong` — request `itemId` on the jukebox.
	case requestSong(itemId: Int)
	/// `ActionKind/jukeboxSkipSong`/`jukeboxBlacklistSong` — a server-granted
	/// moderation action against `itemId` (LEGACY.md "Which buttons show is
	/// server-decided": these only ever appear when the server includes them
	/// on a song, i.e. staff/permission-gated, not client logic).
	case machineControl(action: MachineControlAction, itemId: Int)
	case openURL(URLDestination)
	/// A promotion's social profile URL, converted to a native deep link
	/// (`secretdjv3/FeedActionProvider.swift`'s `handle(promotion:venue:)`).
	/// `webFallbackURL` is the original web profile URL, for the caller to
	/// fall back to if the deep link fails to open at dispatch time.
	case openSocialApp(platform: SocialPlatform, identifier: String, webFallbackURL: URL)
	/// A URL-less internal promotion — ping the server's engagement endpoint
	/// rather than navigating anywhere (LEGACY.md "Actions"; PLAN.md S3.3).
	case engagePromotion(promotionId: Int)
	/// `ActionKind/launchUberApp`/`launchUberSignup` — open the
	/// server-supplied URL directly. The server only ever sends this action
	/// once the client's `appmask` has reported Uber installed (LEGACY.md
	/// "Gaps and cross-checks" — the client→server signal, then the
	/// server→client feature), so no local installed-check happens here.
	case hailRide(url: URL)

	/// Which screen a song-related outcome resolves to.
	public enum TuneInTarget: Sendable, Hashable {
		/// The full ``SecretDJDomain/Song`` payload from the tap itself — S6.3b's
		/// TuneIn screen needs artwork/title/artist/actions/likeInfo, and no
		/// `songdetails`-by-id endpoint exists to re-fetch them (LEGACY.md's
		/// endpoint catalog), so the tapped row's own Domain payload rides
		/// along rather than being thinned to just its id.
		case song(Song)
		case artist(name: String)
	}

	/// `topupdetails`'s `context` parameter
	/// (`secretdjv3/TopUpAPIAccess.swift`'s `TopUpContext`), mirrored here
	/// rather than reused from SecretDJAPI's own `TopUpContext` — FeedUI
	/// takes no dependency on SecretDJAPI.
	public enum TopUpContext: Sendable, Hashable {
		case insertCoin
		case noCredits
	}

	/// Which `machinecontrol` moderation action to submit. Named for the
	/// effect rather than the wire term LEGACY.md's "never-play buttons"
	/// section uses interchangeably with "blacklist".
	public enum MachineControlAction: Sendable, Hashable {
		case skip
		case neverPlay
	}

	public enum URLDestination: Sendable, Hashable {
		case external(URL)
		case inApp(URL)
	}
}
