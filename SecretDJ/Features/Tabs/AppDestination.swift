import FeedUI

/// A typed screen a tab's `NavigationStack` can push, derived from FeedUI's
/// ``FeedActionOutcome`` by ``TabRouter`` (PLAN.md S5.2). Every case names a
/// screen S6 builds; until then ``ComingSoonScreen`` renders in its place,
/// so the navigation model is exercisable end to end before any real feed
/// exists.
enum AppDestination: Hashable {
	/// The song/TuneIn screen (S6.3).
	case song(FeedActionOutcome.TuneInTarget)
	/// An artist's song list — an artist row with more than one song (S6.3).
	case songsForArtist(artist: String)
	/// A venue's feed (S6.2).
	case venue(venueId: String)
	/// A person's profile (S6.6).
	case person(personId: String)
	/// A jukebox/mood's song list — the music digest/selection stack (S6.3).
	case jukebox(jukeboxId: Int)
	/// The credits top-up screen (S6.7).
	case topUps(context: FeedActionOutcome.TopUpContext)
	/// The artist/song search screen (S6.3).
	case search
}

extension AppDestination {
	/// Maps a routed feed outcome to the screen it opens, when the outcome
	/// is navigational. Non-navigational outcomes — server actions like
	/// ``FeedActionOutcome/requestSong(itemId:)``/``FeedActionOutcome/machineControl(action:itemId:)``,
	/// or external hand-offs like ``FeedActionOutcome/hailRide(url:)``/
	/// ``FeedActionOutcome/openSocialApp(platform:identifier:webFallbackURL:)``
	/// — return `nil`: S6 wires those up as their own side effects off
	/// `FeedScreen`'s outcome closure directly, not as a pushed screen.
	init?(outcome: FeedActionOutcome) {
		switch outcome {
		case .showSong(let target):
			self = .song(target)

		case .showSongsForArtist(let artist):
			self = .songsForArtist(artist: artist)

		case .showVenue(let venueId):
			self = .venue(venueId: venueId)

		case .showPerson(let personId):
			self = .person(personId: personId)

		case .showJukebox(let jukeboxId):
			self = .jukebox(jukeboxId: jukeboxId)

		case .showTopUps(let context):
			self = .topUps(context: context)

		case .launchSearch:
			self = .search

		case .changeAtmosphere,
		     .requestSong,
		     .machineControl,
		     .openURL,
		     .openSocialApp,
		     .engagePromotion,
		     .hailRide:
			return nil
		}
	}
}

extension AppDestination {
	/// A stable, non-sensitive screen name for analytics (observability
	/// skill) — the destination's own identifier never appears here.
	var screenTrackingName: String {
		switch self {
		case .song: "ComingSoon-Song"
		case .songsForArtist: "ComingSoon-SongsForArtist"
		case .venue: "ComingSoon-Venue"
		case .person: "ComingSoon-Person"
		case .jukebox: "ComingSoon-Jukebox"
		case .topUps: "ComingSoon-TopUps"
		case .search: "ComingSoon-Search"
		}
	}
}
