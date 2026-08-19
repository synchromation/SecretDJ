import FeedUI

/// A typed screen a tab's `NavigationStack` can push, derived from FeedUI's
/// ``FeedActionOutcome`` by ``TabRouter`` (PLAN.md S5.2). Every case names a
/// screen S6 builds; until then ``ComingSoonScreen`` renders in its place,
/// so the navigation model is exercisable end to end before any real feed
/// exists.
enum AppDestination: Hashable {
	/// The song/TuneIn screen (S6.3). Carries `venueId` for the same reason
	/// ``songsForArtist(venueId:artist:)`` does — resolved by
	/// ``TabRouter/handle(outcome:venueId:)``, not this type's own
	/// `init(outcome:)`, since `requestsong`/`machinecontrol` both need a
	/// venue id FeedUI's outcome vocabulary never carries.
	case song(venueId: String, target: FeedActionOutcome.TuneInTarget)
	/// An artist's song list — an artist row with more than one song (S6.3).
	/// Carries `venueId` because ``FeedUI/FeedActionOutcome/showSongsForArtist(artist:)``
	/// doesn't (no venue identity is known at FeedUI's layer) — resolved by
	/// ``TabRouter/handle(outcome:venueId:)`` instead of this type's own
	/// `init(outcome:)`.
	case songsForArtist(venueId: String, artist: String)
	/// A venue's feed (S6.2).
	case venue(venueId: String)
	/// A venue's now-playing/play-history feed (S6.2) — reached from the
	/// venue screen directly (``TabRouter/push(_:)``), never through a
	/// routed feed outcome.
	case nowPlaying(venueId: String)
	/// A person's profile (S6.6).
	case person(personId: String)
	/// A jukebox/mood's song list — the music digest/selection stack (S6.3).
	/// Carries `venueId` for the same reason ``songsForArtist(venueId:artist:)``
	/// does.
	case jukebox(venueId: String, jukeboxId: Int)
	/// The credits top-up screen (S6.7).
	case topUps(context: FeedActionOutcome.TopUpContext)
	/// The artist/song search screen (S6.3). Carries `venueId` for the same
	/// reason ``songsForArtist(venueId:artist:)`` does — LEGACY.md "Search"
	/// is "only ever server-offered with a venue".
	case search(venueId: String)
}

extension AppDestination {
	/// Maps a routed feed outcome to the screen it opens, when the outcome
	/// is navigational *and* resolvable without extra context. Four
	/// navigational outcomes return `nil` here despite being navigational —
	/// ``FeedUI/FeedActionOutcome/showSong(_:)``,
	/// ``FeedUI/FeedActionOutcome/showJukebox(jukeboxId:)``,
	/// ``FeedUI/FeedActionOutcome/launchSearch``,
	/// ``FeedUI/FeedActionOutcome/showSongsForArtist(artist:)`` — because
	/// their destinations need a venue id FeedUI's outcome vocabulary never
	/// carries; ``TabRouter/handle(outcome:venueId:)`` resolves those
	/// instead, using whichever venue the calling screen already knows.
	/// Every other non-navigational outcome (server actions like
	/// ``FeedActionOutcome/requestSong(itemId:)``/``FeedActionOutcome/machineControl(action:itemId:)``,
	/// or external hand-offs like ``FeedActionOutcome/hailRide(url:)``/
	/// ``FeedActionOutcome/openSocialApp(platform:identifier:webFallbackURL:)``)
	/// also returns `nil`: S6 wires those up as their own side effects off
	/// `FeedScreen`'s outcome closure directly, not as a pushed screen.
	init?(outcome: FeedActionOutcome) {
		switch outcome {
		case .showVenue(let venueId):
			self = .venue(venueId: venueId)

		case .showPerson(let personId):
			self = .person(personId: personId)

		case .showTopUps(let context):
			self = .topUps(context: context)

		case .showSong,
		     .showSongsForArtist,
		     .showJukebox,
		     .launchSearch,
		     .changeAtmosphere,
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
		case .nowPlaying: "ComingSoon-NowPlaying"
		case .person: "ComingSoon-Person"
		case .jukebox: "ComingSoon-Jukebox"
		case .topUps: "ComingSoon-TopUps"
		case .search: "ComingSoon-Search"
		}
	}
}
