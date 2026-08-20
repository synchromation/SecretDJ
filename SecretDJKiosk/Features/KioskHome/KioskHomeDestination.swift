import FeedUI

/// A screen ``KioskHomeView``'s own `NavigationStack` can push — the kiosk's
/// deliberately small counterpart to the consumer's own `AppDestination`
/// (`SecretDJ/Features/Tabs/AppDestination.swift`). Only two cases, because
/// only two kinds of tap exist anywhere in the kiosk's browsing stack
/// (PLAN.md S7.4/S7.5's own scope): a jukebox tile (browse its songs) and a
/// song row (request it). No `venueId` on either case, unlike the
/// consumer's — the kiosk's venue is fixed for the whole signed-in session,
/// so ``KioskHomeView`` already has it in scope rather than threading it
/// through every destination.
enum KioskHomeDestination: Hashable {
	case jukebox(jukeboxId: Int)
	case song(FeedActionOutcome.TuneInTarget)
}

extension KioskHomeDestination {
	/// Maps a routed feed outcome to the screen it opens, mirroring
	/// `AppDestination.init(outcome:)`'s shape. Every outcome outside
	/// ``FeedUI/FeedActionOutcome/showSong(_:)``/``FeedUI/FeedActionOutcome/showJukebox(jukeboxId:)``
	/// returns `nil` and is dropped: ``FeedUI/FeedActionOutcome/changeAtmosphere(itemId:)``
	/// is already intercepted by ``SharedFeatures/MusicSelectionScreen``
	/// itself before it ever reaches this router (that screen's own doc
	/// comment), and every other case (search, artist, moderation, ...) has
	/// no kiosk screen yet — S7.6+ scope, or D13's "no kiosk-side
	/// moderation" resolution for the two `machineControl` cases.
	init?(outcome: FeedActionOutcome) {
		switch outcome {
		case .showSong(let target):
			self = .song(target)

		case .showJukebox(let jukeboxId):
			self = .jukebox(jukeboxId: jukeboxId)

		default:
			return nil
		}
	}
}
