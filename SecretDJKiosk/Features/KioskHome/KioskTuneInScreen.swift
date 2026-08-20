import DesignSystem
import Observability
import SecretDJAPI
import SecretDJDomain
import SharedFeatures
import SwiftUI

/// The kiosk's own TuneIn wiring over ``SharedFeatures/TuneInScreen`` —
/// LEGACY.md "Requesting a song (the kiosk's whole write path)": tapping a
/// song anywhere in the kiosk's browsing stack opens this to preview and
/// request it, unmetered (``KioskSongRequesting``'s doc comment). Deliberately
/// simpler than the consumer's own `ResolvedTuneInScreen`: no out-of-credits
/// funnel (a venue account's requests are never metered, so
/// ``SharedFeatures/TuneInScreenModel/requestSong()``'s out-of-credits branch
/// is unreachable on this app), and no artist-name resolution (the kiosk
/// digest never routes an artist row here — only a song's own
/// ``FeedUI/FeedActionOutcome/TuneInTarget/song(_:)`` case, per
/// ``KioskHomeDestination``'s own doc comment).
struct KioskTuneInScreen: View {
	let song: Song
	let venueId: String
	let apiClient: APIClient
	let sessionStore: SessionStore
	let toastQueue: ToastQueue
	let previewPlayer: PreviewPlayerModel
	let observability: ObservabilityPipeline

	var body: some View {
		TuneInScreen(
			song: song,
			venueId: venueId,
			songRequesting: KioskSongRequesting(client: apiClient, sessionStore: sessionStore),
			machineControlling: KioskMachineControlling(client: apiClient, sessionStore: sessionStore),
			likeToggling: KioskLikeToggling(client: apiClient, sessionStore: sessionStore),
			copy: Self.copy,
			toastQueue: toastQueue,
			previewPlayer: previewPlayer,
			observability: observability,
		)
	}

	private static var copy: TuneInScreenCopy {
		TuneInScreenCopy(
			navigationTitle: Text("Tune In", comment: "Navigation title of the kiosk's song request (TuneIn) screen."),
			requestButtonTitle: Text(
				"Play on the Jukebox",
				comment: "Button that requests the current song be played on the venue's jukebox, from the kiosk.",
			),
			skipButtonTitle: Text(
				"Skip",
				comment: "Button, shown only to entitled users, that skips the current song on the jukebox. Never shown on a kiosk venue account (D13).",
			),
			neverPlayButtonTitle: Text(
				"Never Play This",
				comment: "Button, shown only to entitled users, that stops a song from ever playing on the jukebox again. Never shown on a kiosk venue account (D13).",
			),
			buzzAccessibilityLabel: Text(
				"Like this song",
				comment: "Accessible name of the kiosk TuneIn screen's like/buzz toggle button.",
			),
			previewAccessibilityLabel: Text(
				"Song Preview",
				comment: "Accessible name of the kiosk TuneIn screen's play/stop 30-second preview button.",
			),
			previewPlayingValue: Text(
				"Playing",
				comment: "Accessibility value of the kiosk TuneIn screen's preview button while the preview is playing.",
			),
			previewStoppedValue: Text(
				"Not Playing",
				comment: "Accessibility value of the kiosk TuneIn screen's preview button while no preview is playing.",
			),
			previewFailureMessage: String(
				localized: "Sorry, we couldn't play that preview. Please try again.",
				comment: "Toast shown when a song preview fails to download or decode, on the kiosk.",
			),
		)
	}
}

// MARK: - Previews

#Preview("Request granted") {
	NavigationStack {
		KioskTuneInScreen(
			song: PreviewSong.requestable,
			venueId: "v1",
			apiClient: PreviewAPIClient.broken(),
			sessionStore: PreviewKioskSessionStore.signedIn(),
			toastQueue: ToastQueue(),
			previewPlayer: PreviewPlayerModel(
				downloading: InMemoryPreviewDownloading(),
				playerFactory: InMemoryAudioPlayerFactory(),
			),
			observability: .disabled,
		)
	}
}

#Preview("Accessibility text size") {
	NavigationStack {
		KioskTuneInScreen(
			song: PreviewSong.requestable,
			venueId: "v1",
			apiClient: PreviewAPIClient.broken(),
			sessionStore: PreviewKioskSessionStore.signedIn(),
			toastQueue: ToastQueue(),
			previewPlayer: PreviewPlayerModel(
				downloading: InMemoryPreviewDownloading(),
				playerFactory: InMemoryAudioPlayerFactory(),
			),
			observability: .disabled,
		)
	}
	.environment(\.dynamicTypeSize, .accessibility5)
}

/// Preview-only ``SecretDJDomain/Song`` fixture — mirrors the consumer's own
/// `ResolvedTuneInScreen`'s private `PreviewSong` (SharedFeatures' own
/// `PreviewSong` is package-internal, so this app target needs its own
/// copy, same as the consumer's).
private enum PreviewSong {
	static var requestable: Song {
		Song(
			songId: "1",
			title: "Yellow",
			artist: "Coldplay",
			previewURL: nil,
			likeInfo: LikeInfo(likedByYou: false, info: ""),
			text: "",
			sortIndex: 0,
			action: nil,
			actions: [Action(
				kind: .jukeboxRequestSong,
				itemId: 1,
				itemTypeId: nil,
				value: nil,
				url: nil,
				button: .unsupported(0),
			)],
		)
	}
}
