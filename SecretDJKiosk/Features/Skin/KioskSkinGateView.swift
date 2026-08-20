import DesignSystem
import Observability
import SecretDJAPI
import SharedFeatures
import SwiftUI

/// Sits between venue sign-in and the kiosk home screen: a signed-in
/// session isn't enough to show ``KioskHomeView`` yet, because nearly every
/// pixel of kiosk chrome is server-skinnable and legacy's own rule is
/// absolute — "the kiosk cannot proceed unskinned" (LEGACY.md "Venue login
/// and the skin system"). Drives one ``SkinModel`` for the venue and
/// switches on its ``SkinModel/Phase``: downloading shows progress, a
/// failure blocks with a retry-only surface (no skip), and only
/// ``SkinModel/Phase/ready`` reveals the home screen, with the resolved
/// ``KioskSkin`` injected into the environment for it (and everything
/// S7.3+ pushes from there) to read.
struct KioskSkinGateView: View {
	let sessionStore: SessionStore
	/// Threaded through to ``KioskHomeView`` once the skin is ready.
	let apiClient: APIClient
	let venueId: String
	let previewPlayer: PreviewPlayerModel
	let observability: ObservabilityPipeline

	@State private var skinModel: SkinModel

	init(
		venueId: String,
		apiClient: APIClient,
		sessionStore: SessionStore,
		skinStoring: any SkinStoring,
		previewPlayer: PreviewPlayerModel,
		observability: ObservabilityPipeline,
	) {
		self.sessionStore = sessionStore
		self.apiClient = apiClient
		self.venueId = venueId
		self.previewPlayer = previewPlayer
		self.observability = observability
		_skinModel = State(initialValue: SkinModel(
			venueId: venueId,
			loading: APIClientSkinLoading(client: apiClient, sessionStore: sessionStore),
			assetDownloading: URLSessionSkinAssetDownloading(),
			storing: skinStoring,
			observability: observability,
		))
	}

	/// Test/preview-only entry point — injects the ``SkinModel`` directly
	/// rather than building production dependencies from an `APIClient`
	/// (``apiClient`` still takes a harmless ``PreviewAPIClient/broken()``
	/// default, since ``KioskHomeView`` needs a concrete one regardless of
	/// whether this preview ever taps into a real feed).
	init(
		sessionStore: SessionStore,
		skinModel: SkinModel,
		apiClient: APIClient = PreviewAPIClient.broken(),
		venueId: String = "v1",
		previewPlayer: PreviewPlayerModel = PreviewPlayerModel(
			downloading: InMemoryPreviewDownloading(),
			playerFactory: InMemoryAudioPlayerFactory(),
		),
		observability: ObservabilityPipeline = .disabled,
	) {
		self.sessionStore = sessionStore
		self.apiClient = apiClient
		self.venueId = venueId
		self.previewPlayer = previewPlayer
		self.observability = observability
		_skinModel = State(initialValue: skinModel)
	}

	var body: some View {
		content
			.task { await skinModel.start() }
	}

	@ViewBuilder
	private var content: some View {
		switch skinModel.phase {
		case .idle:
			SkinDownloadProgressView(progress: 0)

		case .loading(let progress):
			SkinDownloadProgressView(progress: progress)

		case .failed:
			failureView

		case .ready(let skin, let behavioralConfig):
			AttractIdleContainerView(
				behavioralConfig: behavioralConfig,
				previewPlayer: previewPlayer,
				observability: observability,
			) {
				KioskHomeView(
					sessionStore: sessionStore,
					apiClient: apiClient,
					venueId: venueId,
					previewPlayer: previewPlayer,
					observability: observability,
				)
			}
			.environment(\.kioskSkin, skin)
		}
	}

	private var failureView: some View {
		ErrorStateView(
			systemImage: "wifi.exclamationmark",
			title: Text(
				"Setup didn't finish",
				comment: "Title shown when the kiosk can't download its venue skin after signing in.",
			),
			message: Text(
				"Sorry, we couldn't download this venue's look. Check the connection and try again.",
				comment: "Body text under the kiosk skin-download failure title; a retry button follows.",
			),
			retryTitle: Text(
				"Try Again",
				comment: "Retry button on the kiosk skin-download failure screen.",
			),
			retryAction: retry,
		)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(Theme.ColorRole.background.color)
		.tracksScreen("KioskSkinDownloadFailed")
	}

	private func retry() {
		Task { await skinModel.retry() }
	}
}

/// The kiosk's post-login "getting ready" surface — a determinate progress
/// bar bound to ``SkinModel/Phase/loading(progress:)``'s fraction, standing
/// in for legacy's `KioskSigningInViewController` progress bar
/// (`UIProgressView.progress`).
private struct SkinDownloadProgressView: View {
	let progress: Double

	var body: some View {
		VStack(spacing: Spacing.large) {
			Text("Getting ready", comment: "Heading shown while the kiosk downloads its venue's look after signing in.")
				.font(Theme.TextStyle.screenTitle.font)
				.foregroundStyle(Theme.ColorRole.primaryText.color)
				.accessibilityAddTraits(.isHeader)

			ProgressView(value: progress)
				.tint(Theme.ColorRole.accent.color)
				.frame(maxWidth: 320)
				.accessibilityLabel(Text(
					"Downloading this venue's look",
					comment: "Accessibility label for the kiosk's skin-download progress bar.",
				))
				.accessibilityValue(Text(progress, format: .percent.precision(.fractionLength(0))))
		}
		.padding(Spacing.large)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(Theme.ColorRole.background.color)
		.tracksScreen("KioskSkinDownload")
	}
}

#Preview("Downloading") {
	KioskSkinGateView(
		sessionStore: PreviewKioskSessionStore.signedIn(),
		skinModel: SkinModel(
			venueId: "v1",
			loading: InMemorySkinLoading(result: .success(PreviewSkinManifest.withOneImage)),
			assetDownloading: InMemorySkinAssetDownloading(),
			storing: InMemorySkinStoring(),
		),
	)
}

#Preview("Download failed") {
	KioskSkinGateView(
		sessionStore: PreviewKioskSessionStore.signedIn(),
		skinModel: SkinModel(
			venueId: "v1",
			loading: InMemorySkinLoading(result: .failure(.connection)),
			assetDownloading: InMemorySkinAssetDownloading(),
			storing: InMemorySkinStoring(),
		),
	)
}

#Preview("Ready") {
	let storing = InMemorySkinStoring()
	let venueId = "v1"
	return KioskSkinGateView(
		sessionStore: PreviewKioskSessionStore.signedIn(venueId: venueId),
		skinModel: SkinModel(
			venueId: venueId,
			loading: InMemorySkinLoading(result: .success(PreviewSkinManifest.withOneImage)),
			assetDownloading: InMemorySkinAssetDownloading(),
			storing: PreviewSkinManifest.preSeed(storing, venueId: venueId),
		),
	)
}

#Preview("Accessibility text size") {
	KioskSkinGateView(
		sessionStore: PreviewKioskSessionStore.signedIn(),
		skinModel: SkinModel(
			venueId: "v1",
			loading: InMemorySkinLoading(result: .failure(.connection)),
			assetDownloading: InMemorySkinAssetDownloading(),
			storing: InMemorySkinStoring(),
		),
	)
	.environment(\.dynamicTypeSize, .accessibility5)
}
