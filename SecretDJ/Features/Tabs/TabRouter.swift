import FeedUI
import Observation

/// One tab's own navigation back stack (PLAN.md S5.2 — "NavigationStack per
/// tab"): routes a tapped feed cell's ``FeedActionOutcome`` (FeedUI's
/// `FeedScreen.onOutcome`) to a typed ``AppDestination`` and pushes it,
/// mirroring a native `UITabBarController`'s per-tab nav stack
/// (LEGACY.md "Launch and root navigation").
@MainActor
@Observable
final class TabRouter {
	private(set) var path: [AppDestination] = []

	/// Routes a feed outcome and pushes its destination, when the outcome is
	/// navigational (``AppDestination/init(outcome:)``). A non-navigational
	/// outcome is silently dropped here — S6 hangs its own handling (server
	/// calls, external app hand-offs) directly off the outcome, not this
	/// router.
	func handle(outcome: FeedActionOutcome) {
		guard let destination = AppDestination(outcome: outcome) else { return }
		path.append(destination)
	}

	/// Routes an outcome that needs venue context to resolve —
	/// ``FeedUI/FeedActionOutcome/showJukebox(jukeboxId:)``,
	/// ``FeedUI/FeedActionOutcome/launchSearch``,
	/// ``FeedUI/FeedActionOutcome/showSongsForArtist(artist:)`` — the three
	/// cases ``AppDestination/init(outcome:)`` can't resolve alone, since
	/// FeedUI's outcome vocabulary carries no venue identity
	/// (``AppDestination/init(outcome:)``'s doc comment). Every other
	/// outcome routes through ``handle(outcome:)`` unmodified, ignoring
	/// `venueId` — e.g. ``FeedUI/FeedActionOutcome/showVenue(venueId:)``
	/// already names its own venue directly.
	func handle(outcome: FeedActionOutcome, venueId: String) {
		switch outcome {
		case .showJukebox(let jukeboxId):
			path.append(.jukebox(venueId: venueId, jukeboxId: jukeboxId))

		case .launchSearch:
			path.append(.search(venueId: venueId))

		case .showSongsForArtist(let artist):
			path.append(.songsForArtist(venueId: venueId, artist: artist))

		default:
			handle(outcome: outcome)
		}
	}

	/// Pushes `destination` directly — for a navigation trigger that isn't a
	/// routed feed outcome, e.g. the venue screen's own "Now Playing" button
	/// (S6.2; legacy's own path there is the extra-content ticker, S6.9,
	/// which doesn't exist yet in this rewrite).
	func push(_ destination: AppDestination) {
		path.append(destination)
	}

	/// Mirrors SwiftUI's own pops (back button, swipe-back) into this
	/// router's state — the setter half of the `Binding` a
	/// `NavigationStack(path:)` needs.
	func setPath(_ path: [AppDestination]) {
		self.path = path
	}
}
