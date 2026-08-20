import FeedUI

/// A screen ``KioskHomeView``'s own `NavigationStack` can push — the kiosk's
/// deliberately small counterpart to the consumer's own `AppDestination`
/// (`SecretDJ/Features/Tabs/AppDestination.swift`). One case per kind of tap
/// or entry point the kiosk's browsing stack supports (PLAN.md S7.4–S7.6's
/// scope): a jukebox tile (browse its songs), a song row (request it), the
/// header's search button (``KioskNowPlayingHeaderView``'s own doc comment),
/// and a multi-song artist row from search (browse that artist's songs). No
/// `venueId` on any case, unlike the consumer's — the kiosk's venue is fixed
/// for the whole signed-in session, so ``KioskHomeView`` already has it in
/// scope rather than threading it through every destination.
enum KioskHomeDestination: Hashable {
	case jukebox(jukeboxId: Int)
	case song(FeedActionOutcome.TuneInTarget)
	case search
	case songsForArtist(artist: String)
}

extension KioskHomeDestination {
	/// Maps a routed feed outcome to the screen it opens, mirroring
	/// `AppDestination.init(outcome:)`'s shape. Every outcome outside
	/// ``FeedUI/FeedActionOutcome/showSong(_:)``/``FeedUI/FeedActionOutcome/showJukebox(jukeboxId:)``/
	/// ``FeedUI/FeedActionOutcome/launchSearch``/``FeedUI/FeedActionOutcome/showSongsForArtist(artist:)``
	/// returns `nil` and is dropped: ``FeedUI/FeedActionOutcome/changeAtmosphere(itemId:)``
	/// is already intercepted by ``SharedFeatures/MusicSelectionScreen``
	/// itself before it ever reaches this router (that screen's own doc
	/// comment), and every other case (moderation, ...) has no kiosk screen
	/// at all — D13's "no kiosk-side moderation" resolution for the two
	/// `machineControl` cases.
	init?(outcome: FeedActionOutcome) {
		switch outcome {
		case .showSong(let target):
			self = .song(target)

		case .showJukebox(let jukeboxId):
			self = .jukebox(jukeboxId: jukeboxId)

		case .launchSearch:
			self = .search

		case .showSongsForArtist(let artist):
			self = .songsForArtist(artist: artist)

		default:
			return nil
		}
	}
}
