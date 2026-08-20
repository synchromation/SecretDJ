import DesignSystem
import FeedUI
import Observability
import SecretDJAPI
import SharedFeatures
import SwiftUI

/// The kiosk's own wiring over ``SharedFeatures/SongsForArtistScreen``
/// (PLAN.md S7.6) — the multi-song-artist drill-in a kiosk search result
/// row routes to (``KioskHomeDestination/songsForArtist(artist:)``). Opts
/// into S7.7's unattended error recovery, same as the digest/jukebox wall
/// (``KioskHomeView/digestScreen``'s own doc comment) — this screen is
/// exactly the kind PLAN.md S7.7 worries about: reachable while browsing,
/// left mid-error if a customer walks away, and still under the attract
/// overlay if it's still showing when attract next dismisses.
struct KioskSongsForArtistScreen: View {
	let artistName: String
	let venueId: String
	let apiClient: APIClient
	let sessionStore: SessionStore
	let observability: ObservabilityPipeline
	let onOutcome: (FeedActionOutcome) -> Void

	var body: some View {
		SongsForArtistScreen(
			artistName: artistName,
			searching: KioskMusicSearching(client: apiClient, sessionStore: sessionStore, venueId: venueId),
			copy: Self.copy,
			errorRecovery: FeedConfiguration.ErrorRecovery(),
			onOutcome: onOutcome,
			observability: observability,
		)
	}

	private static var copy: FeedScreenCopy {
		FeedScreenCopy(
			emptySystemImage: Theme.Icon.song.systemName,
			emptyTitle: Text(
				"No Songs",
				comment: "Title shown on the kiosk when an artist has no songs here yet.",
			),
			emptyMessage: Text(
				"This artist hasn't got anything to show yet — check back soon.",
				comment: "Body shown on the kiosk when an artist has no songs here yet.",
			),
			errorTitle: Text(
				"Something Went Wrong",
				comment: "Title shown on the kiosk when an artist's song list fails to load.",
			),
			errorMessage: Text(
				"Sorry, we couldn't load these songs.\n\nPlease check the venue's connection and try again.",
				comment: "Body shown on the kiosk when an artist's song list fails to load.",
			),
			offlineTitle: Text(
				"You're Offline",
				comment: "Title shown on the kiosk when the device has no internet connection.",
			),
			offlineMessage: Text(
				"Check the venue's connection and try again.",
				comment: "Body shown on the kiosk when the device has no internet connection.",
			),
			retryTitle: Text(
				"Try Again",
				comment: "Button that retries loading an artist's song list on the kiosk after a failure.",
			),
		)
	}
}

// MARK: - Previews

#Preview("Loaded") {
	NavigationStack {
		KioskSongsForArtistScreen(
			artistName: "Coldplay",
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
		KioskSongsForArtistScreen(
			artistName: "Coldplay",
			venueId: "v1",
			apiClient: PreviewAPIClient.broken(),
			sessionStore: PreviewKioskSessionStore.signedIn(),
			observability: .disabled,
			onOutcome: { _ in },
		)
	}
	.environment(\.dynamicTypeSize, .accessibility5)
}
