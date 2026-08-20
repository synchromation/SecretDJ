import DesignSystem
import FeedUI
import Observability
import SecretDJAPI
import SharedFeatures
import SwiftUI

/// The kiosk's own wiring over ``SharedFeatures/MusicSearchScreen`` (PLAN.md
/// S7.6) — LEGACY.md "Search": pushed from the kiosk home's header search
/// button (``KioskNowPlayingHeaderView``), reusing the exact same
/// artist/track search screen the consumer app already ships (S6.3),
/// scaled automatically to the iPad's width by ``FeedUI/FeedView``'s own
/// adaptive grid (``FeedUI/FeedGridSection``'s `.adaptive` column rule —
/// already proven at kiosk scale by the digest wall, S7.4/S7.5, so no
/// kiosk-specific layout knob was needed here). The legacy custom on-screen
/// keyboard (`KioskSearchKeyboardViewController`) has no counterpart here —
/// D10's resolution replaces it with the system keyboard, which `TextField`
/// already gets for free.
///
/// Deliberately carries none of ``FeedUI/FeedConfiguration/ErrorRecovery``'s
/// unattended retry-with-backoff (unlike the digest/jukebox screens
/// ``KioskHomeView`` builds with `errorRecovery: FeedConfiguration.ErrorRecovery()`)
/// — `MusicSearchScreen` accepts no such parameter at all. A patron who
/// abandons a stuck or erroring search is exactly the case
/// ``IdleTimerModel/idleTimeoutFireCount`` already handles: the idle
/// countdown pops the kiosk's `NavigationStack` back to ``KioskHomeView``'s
/// digest, where `FeedScreenModel`'s own auto-recovery is already running.
/// Giving search its own recovery loop on top would just retry a screen
/// nobody's looking at.
struct KioskMusicSearchScreen: View {
	let venueId: String
	let apiClient: APIClient
	let sessionStore: SessionStore
	let observability: ObservabilityPipeline
	let onOutcome: (FeedActionOutcome) -> Void

	var body: some View {
		MusicSearchScreen(
			searching: KioskMusicSearching(client: apiClient, sessionStore: sessionStore, venueId: venueId),
			copy: Self.copy,
			onOutcome: onOutcome,
			observability: observability,
		)
	}

	private static var copy: MusicSearchScreenCopy {
		MusicSearchScreenCopy(
			navigationTitle: Text("Search", comment: "Navigation title of the kiosk's artist/song search screen."),
			artistModeLabel: Text("Artists", comment: "Kiosk search screen tab that searches by artist name."),
			trackModeLabel: Text("Songs", comment: "Kiosk search screen tab that searches by song title."),
			searchFieldPlaceholder: Text(
				"Search",
				comment: "Placeholder text in the kiosk search screen's text field, before typing anything.",
			),
			emptyTitle: Text(
				"No Results",
				comment: "Title shown on the kiosk search screen when a search finds nothing.",
			),
			emptyMessage: Text(
				"Try a different search.",
				comment: "Body shown on the kiosk search screen when a search finds nothing.",
			),
			errorTitle: Text(
				"Something Went Wrong",
				comment: "Title shown on the kiosk search screen when a search fails.",
			),
			errorMessage: Text(
				"Sorry, we couldn't search right now.\n\nPlease check the venue's connection and try again.",
				comment: "Body shown on the kiosk search screen when a search fails.",
			),
			retryTitle: Text("Try Again", comment: "Button that retries a failed search on the kiosk."),
		)
	}
}

// MARK: - Previews

#Preview("Artist mode") {
	NavigationStack {
		KioskMusicSearchScreen(
			venueId: "v1",
			apiClient: PreviewAPIClient.broken(),
			sessionStore: PreviewKioskSessionStore.signedIn(),
			observability: .disabled,
			onOutcome: { _ in },
		)
	}
}

#Preview("Accessibility text size") {
	NavigationStack {
		KioskMusicSearchScreen(
			venueId: "v1",
			apiClient: PreviewAPIClient.broken(),
			sessionStore: PreviewKioskSessionStore.signedIn(),
			observability: .disabled,
			onOutcome: { _ in },
		)
	}
	.environment(\.dynamicTypeSize, .accessibility5)
}
