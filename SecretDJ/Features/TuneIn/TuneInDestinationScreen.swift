import DesignSystem
import FeedUI
import Observability
import SecretDJAPI
import SharedFeatures
import SwiftUI

/// Resolves ``AppDestination/song(venueId:target:)`` into a real
/// ``ResolvedTuneInScreen``: a tapped song already carries its own
/// ``SecretDJDomain/Song`` payload (``FeedUI/FeedActionOutcome/showSong(_:)``'s
/// doc comment) and shows immediately; a single-song artist carries only a
/// name, so this screen resolves it first via
/// ``TuneInArtistResolvingModel`` (`secretdjv3/TuneInViewController.swift`'s
/// `update(artistName:...)`), showing a spinner meanwhile.
struct TuneInDestinationScreen: View {
	let target: FeedActionOutcome.TuneInTarget
	let venueId: String
	let apiClient: APIClient
	let sessionStore: SessionStore
	let toastQueue: ToastQueue
	let previewPlayerModel: PreviewPlayerModel
	let router: TabRouter
	let observability: ObservabilityPipeline

	var body: some View {
		switch target {
		case .song(let song):
			ResolvedTuneInScreen(
				song: song,
				venueId: venueId,
				apiClient: apiClient,
				sessionStore: sessionStore,
				toastQueue: toastQueue,
				previewPlayerModel: previewPlayerModel,
				router: router,
				observability: observability,
			)

		case .artist(let name):
			TuneInArtistResolvingScreen(
				artistName: name,
				venueId: venueId,
				apiClient: apiClient,
				sessionStore: sessionStore,
				toastQueue: toastQueue,
				previewPlayerModel: previewPlayerModel,
				router: router,
				observability: observability,
			)
		}
	}
}

/// The ``FeedUI/FeedActionOutcome/TuneInTarget/artist(name:)`` half of
/// ``TuneInDestinationScreen`` — a single-song artist row's own name-only
/// lookup, split out so its `@State` model isn't rebuilt on every body
/// re-evaluation of the parent `switch`.
private struct TuneInArtistResolvingScreen: View {
	let artistName: String
	let venueId: String
	let apiClient: APIClient
	let sessionStore: SessionStore
	let toastQueue: ToastQueue
	let previewPlayerModel: PreviewPlayerModel
	let router: TabRouter
	let observability: ObservabilityPipeline

	@State private var model: TuneInArtistResolvingModel

	init(
		artistName: String,
		venueId: String,
		apiClient: APIClient,
		sessionStore: SessionStore,
		toastQueue: ToastQueue,
		previewPlayerModel: PreviewPlayerModel,
		router: TabRouter,
		observability: ObservabilityPipeline,
	) {
		self.artistName = artistName
		self.venueId = venueId
		self.apiClient = apiClient
		self.sessionStore = sessionStore
		self.toastQueue = toastQueue
		self.previewPlayerModel = previewPlayerModel
		self.router = router
		self.observability = observability
		_model = State(initialValue: TuneInArtistResolvingModel(
			artistName: artistName,
			musicSearching: APIClientMusicSearching(client: apiClient, sessionStore: sessionStore, venueId: venueId),
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
			ResolvedTuneInScreen(
				song: song,
				venueId: venueId,
				apiClient: apiClient,
				sessionStore: sessionStore,
				toastQueue: toastQueue,
				previewPlayerModel: previewPlayerModel,
				router: router,
				observability: observability,
			)

		case .empty,
		     .failed:
			EmptyStateView(
				systemImage: Theme.Icon.song.systemName,
				title: Text(
					"Song Not Found",
					comment: "Title shown when a single-song artist's own song can't be found.",
				),
				message: Text(
					"Sorry, we couldn't find this artist's song.",
					comment: "Body shown when a single-song artist's own song can't be found.",
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
		TuneInDestinationScreen(
			target: .artist(name: "Some Unknown Artist"),
			venueId: "v1",
			apiClient: PreviewAPIClient.broken(),
			sessionStore: PreviewSessionStore.signedIn(),
			toastQueue: ToastQueue(),
			previewPlayerModel: PreviewPlayerModel(
				downloading: InMemoryPreviewDownloading(),
				playerFactory: InMemoryAudioPlayerFactory(),
			),
			router: TabRouter(),
			observability: .disabled,
		)
	}
}

#Preview("Accessibility text size") {
	NavigationStack {
		TuneInDestinationScreen(
			target: .artist(name: "Some Unknown Artist"),
			venueId: "v1",
			apiClient: PreviewAPIClient.broken(),
			sessionStore: PreviewSessionStore.signedIn(),
			toastQueue: ToastQueue(),
			previewPlayerModel: PreviewPlayerModel(
				downloading: InMemoryPreviewDownloading(),
				playerFactory: InMemoryAudioPlayerFactory(),
			),
			router: TabRouter(),
			observability: .disabled,
		)
	}
	.environment(\.dynamicTypeSize, .accessibility5)
}
