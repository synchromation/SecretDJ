import DesignSystem
import FeedUI
import Observability
import SecretDJAPI
import SharedFeatures
import SwiftUI

/// Resolves ``KioskHomeDestination/song(_:)`` into a real
/// ``KioskTuneInScreen``: a tapped song already carries its own
/// ``SecretDJDomain/Song`` payload (the digest/jukebox wall's own tap path,
/// LEGACY.md "Requesting a song") and shows immediately; a single-song
/// artist row from search (S7.6) carries only a name, so this screen
/// resolves it first via ``KioskTuneInArtistResolvingModel``, showing a
/// spinner meanwhile — the kiosk's own copy of the consumer's
/// `TuneInDestinationScreen`.
struct KioskTuneInDestinationScreen: View {
	let target: FeedActionOutcome.TuneInTarget
	let venueId: String
	let apiClient: APIClient
	let sessionStore: SessionStore
	let toastQueue: ToastQueue
	let previewPlayer: PreviewPlayerModel
	let observability: ObservabilityPipeline

	var body: some View {
		switch target {
		case .song(let song):
			KioskTuneInScreen(
				song: song,
				venueId: venueId,
				apiClient: apiClient,
				sessionStore: sessionStore,
				toastQueue: toastQueue,
				previewPlayer: previewPlayer,
				observability: observability,
			)

		case .artist(let name):
			KioskTuneInArtistResolvingScreen(
				artistName: name,
				venueId: venueId,
				apiClient: apiClient,
				sessionStore: sessionStore,
				toastQueue: toastQueue,
				previewPlayer: previewPlayer,
				observability: observability,
			)
		}
	}
}

/// The ``FeedUI/FeedActionOutcome/TuneInTarget/artist(name:)`` half of
/// ``KioskTuneInDestinationScreen``, split out so its `@State` model isn't
/// rebuilt on every body re-evaluation of the parent `switch` (mirrors the
/// consumer's own `TuneInArtistResolvingScreen`).
private struct KioskTuneInArtistResolvingScreen: View {
	let artistName: String
	let venueId: String
	let apiClient: APIClient
	let sessionStore: SessionStore
	let toastQueue: ToastQueue
	let previewPlayer: PreviewPlayerModel
	let observability: ObservabilityPipeline

	@State private var model: KioskTuneInArtistResolvingModel

	init(
		artistName: String,
		venueId: String,
		apiClient: APIClient,
		sessionStore: SessionStore,
		toastQueue: ToastQueue,
		previewPlayer: PreviewPlayerModel,
		observability: ObservabilityPipeline,
	) {
		self.artistName = artistName
		self.venueId = venueId
		self.apiClient = apiClient
		self.sessionStore = sessionStore
		self.toastQueue = toastQueue
		self.previewPlayer = previewPlayer
		self.observability = observability
		_model = State(initialValue: KioskTuneInArtistResolvingModel(
			artistName: artistName,
			musicSearching: KioskMusicSearching(client: apiClient, sessionStore: sessionStore, venueId: venueId),
			observability: observability,
		))
	}

	var body: some View {
		content
			.task { await model.resolve() }
	}

	@ViewBuilder
	private var content: some View {
		switch model.phase {
		case .loading:
			ProgressView()
				.frame(maxWidth: .infinity, maxHeight: .infinity)
				.background(Theme.ColorRole.background.color)

		case .resolved(let song):
			KioskTuneInScreen(
				song: song,
				venueId: venueId,
				apiClient: apiClient,
				sessionStore: sessionStore,
				toastQueue: toastQueue,
				previewPlayer: previewPlayer,
				observability: observability,
			)

		case .empty,
		     .failed:
			EmptyStateView(
				systemImage: Theme.Icon.song.systemName,
				title: Text(
					"Song Not Found",
					comment: "Title shown on the kiosk when a single-song artist's own song can't be found.",
				),
				message: Text(
					"Sorry, we couldn't find this artist's song.",
					comment: "Body shown on the kiosk when a single-song artist's own song can't be found.",
				),
			)
			.frame(maxWidth: .infinity, maxHeight: .infinity)
			.background(Theme.ColorRole.background.color)
		}
	}
}

// MARK: - Previews

#Preview("Artist not found") {
	NavigationStack {
		KioskTuneInDestinationScreen(
			target: .artist(name: "Some Unknown Artist"),
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
		KioskTuneInDestinationScreen(
			target: .artist(name: "Some Unknown Artist"),
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
