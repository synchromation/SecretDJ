import DesignSystem
import FeedUI
import Observability
import SecretDJAPI
import SecretDJDomain
import SharedFeatures
import SwiftUI

/// The kiosk's signed-in home screen (PLAN.md S7.4/S7.5) — a permanent
/// now-playing header (``KioskNowPlayingHeaderView``) above the venue's
/// jukebox digest (``SharedFeatures/MusicSelectionScreen``, reused wholesale
/// with the kiosk's own ``FeedUI/FeedChangeDetector/Policy/reloadInPlace``
/// injected — LEGACY.md's kiosk digest branch, PLAN.md S7.4), replacing the
/// S7.1 placeholder that only confirmed sign-in by naming the venue.
///
/// Tapping a jukebox tile drills into that jukebox's own song grid (the same
/// ``SharedFeatures/MusicSelectionScreen``, scoped to one jukebox); tapping a
/// song opens ``KioskTuneInScreen`` to request it — LEGACY.md "Requesting a
/// song (the kiosk's whole write path)": tapping any song anywhere on the
/// legacy kiosk opened `KioskTuneInViewController` to preview and request it
/// unmetered, so this wires the same behavior through the shared S6.3
/// TuneIn screen rather than the consumer's browse-only assumption. A
/// change-mood tile (the `matrixControlLarge` template, when the venue's
/// digest carries one) is self-handled by `MusicSelectionScreen` itself —
/// this view never sees that tap (S7.5, D13: no other kiosk-side control
/// exists).
struct KioskHomeView: View {
	let sessionStore: SessionStore
	let apiClient: APIClient
	let venueId: String
	let previewPlayer: PreviewPlayerModel
	let observability: ObservabilityPipeline

	@State private var nowPlayingModel: KioskNowPlayingModel
	@State private var path: [KioskHomeDestination] = []
	@State private var toastQueue = ToastQueue()

	@Environment(\.kioskSkin) private var kioskSkin

	/// The legacy 50-song page size for `musicdigest`/`musicselection`
	/// (LEGACY.md "Choosing music": "hash-checked pagination in 50-song
	/// batches" — mirrors the consumer's own `TabsView.musicSelectionBatchSize`).
	private static let batchSize = 50

	init(
		sessionStore: SessionStore,
		apiClient: APIClient,
		venueId: String,
		previewPlayer: PreviewPlayerModel,
		observability: ObservabilityPipeline = .disabled,
	) {
		self.sessionStore = sessionStore
		self.apiClient = apiClient
		self.venueId = venueId
		self.previewPlayer = previewPlayer
		self.observability = observability
		_nowPlayingModel = State(initialValue: KioskNowPlayingModel(
			loader: KioskAPIClientFeedLoading.sessionFeed(
				sessionStore: sessionStore,
				endpoint: { userId, credential, _ in try await apiClient.nowPlaying(
					userId: userId,
					venueId: venueId,
					credential: credential,
				) },
			),
			onVenueNameResolved: { sessionStore.updateVenueName($0) },
			observability: observability,
		))
	}

	var body: some View {
		VStack(spacing: 0) {
			KioskNowPlayingHeaderView(display: nowPlayingModel.display)

			NavigationStack(path: $path) {
				digestScreen
					.navigationDestination(for: KioskHomeDestination.self) { destination in
						self.destination(for: destination)
					}
			}
		}
		.background(Theme.ColorRole.background.color)
		.toastPresenter(queue: toastQueue, appearance: kioskSkin.toast.toastAppearance)
		.task { await nowPlayingModel.start() }
		.tracksScreen("KioskHome")
	}

	private var digestScreen: some View {
		MusicSelectionScreen(
			venueId: venueId,
			loader: digestLoader,
			atmosphereChanging: KioskAtmosphereChanging(client: apiClient, sessionStore: sessionStore),
			toastQueue: toastQueue,
			copy: Self.digestCopy,
			changePolicy: .reloadInPlace,
			onOutcome: handle(outcome:),
		)
	}

	private var digestLoader: KioskAPIClientFeedLoading {
		KioskAPIClientFeedLoading.sessionFeed(
			sessionStore: sessionStore,
			endpoint: { userId, credential, page in try await apiClient.musicDigest(
				userId: userId,
				venueId: venueId,
				offset: (page ?? 0) * Self.batchSize,
				batchSize: Self.batchSize,
				item: 0,
				type: 0,
				hash: nil,
				credential: credential,
			) },
		)
	}

	@ViewBuilder
	private func destination(for destination: KioskHomeDestination) -> some View {
		switch destination {
		case .jukebox(let jukeboxId):
			jukeboxScreen(jukeboxId: jukeboxId)

		case .song(.song(let song)):
			KioskTuneInScreen(
				song: song,
				venueId: venueId,
				apiClient: apiClient,
				sessionStore: sessionStore,
				toastQueue: toastQueue,
				previewPlayer: previewPlayer,
				observability: observability,
			)

		case .song(.artist):
			// The kiosk digest/jukebox grids only ever tap through a song's
			// own `.showSong(.song(_:))` outcome (``KioskHomeDestination``'s
			// doc comment) — an artist row exists only in search results,
			// which S7.6 hasn't built on the kiosk yet.
			EmptyView()
		}
	}

	private func jukeboxScreen(jukeboxId: Int) -> some View {
		MusicSelectionScreen(
			venueId: venueId,
			loader: KioskAPIClientFeedLoading.sessionFeed(
				sessionStore: sessionStore,
				endpoint: { userId, credential, page in try await apiClient.musicSelection(
					userId: userId,
					venueId: venueId,
					offset: (page ?? 0) * Self.batchSize,
					batchSize: Self.batchSize,
					item: jukeboxId,
					type: Int64(ItemType.song.rawValue),
					hash: nil,
					credential: credential,
				) },
			),
			atmosphereChanging: KioskAtmosphereChanging(client: apiClient, sessionStore: sessionStore),
			toastQueue: toastQueue,
			copy: Self.digestCopy,
			changePolicy: .reloadInPlace,
			onOutcome: handle(outcome:),
		)
	}

	private func handle(outcome: FeedActionOutcome) {
		guard let destination = KioskHomeDestination(outcome: outcome) else { return }
		path.append(destination)
	}

	private static var digestCopy: FeedScreenCopy {
		FeedScreenCopy(
			emptySystemImage: Theme.Icon.jukebox.systemName,
			emptyTitle: Text(
				"Nothing Here Yet",
				comment: "Title shown on the kiosk's jukebox wall (or a jukebox's own song list) when it has no content yet.",
			),
			emptyMessage: Text(
				"This venue hasn't got anything to show yet — check back soon.",
				comment: "Body shown on the kiosk's jukebox wall (or a jukebox's own song list) when it has no content yet.",
			),
			errorTitle: Text(
				"Something Went Wrong",
				comment: "Title shown on the kiosk's jukebox wall (or a jukebox's own song list) when it fails to load.",
			),
			errorMessage: Text(
				"Sorry, we couldn't load the music.\n\nPlease check the venue's connection and try again.",
				comment: "Body shown on the kiosk's jukebox wall (or a jukebox's own song list) when it fails to load.",
			),
			offlineTitle: Text(
				"You're Offline",
				comment: "Title shown on the kiosk's jukebox wall (or a jukebox's own song list) when the device has no internet connection.",
			),
			offlineMessage: Text(
				"Check the venue's connection and try again.",
				comment: "Body shown on the kiosk's jukebox wall (or a jukebox's own song list) when the device has no internet connection.",
			),
			retryTitle: Text(
				"Try Again",
				comment: "Button that retries loading the kiosk's jukebox wall (or a jukebox's own song list) after a failure.",
			),
		)
	}
}

#Preview("Signed in") {
	KioskHomeView(
		sessionStore: PreviewKioskSessionStore.signedIn(),
		apiClient: PreviewAPIClient.broken(),
		venueId: "v1",
		previewPlayer: PreviewPlayerModel(
			downloading: InMemoryPreviewDownloading(),
			playerFactory: InMemoryAudioPlayerFactory(),
		),
	)
}

#Preview("Accessibility text size") {
	KioskHomeView(
		sessionStore: PreviewKioskSessionStore.signedIn(),
		apiClient: PreviewAPIClient.broken(),
		venueId: "v1",
		previewPlayer: PreviewPlayerModel(
			downloading: InMemoryPreviewDownloading(),
			playerFactory: InMemoryAudioPlayerFactory(),
		),
	)
	.environment(\.dynamicTypeSize, .accessibility5)
}
