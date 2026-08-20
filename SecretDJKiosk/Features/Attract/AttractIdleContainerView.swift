import Observability
import SharedFeatures
import SwiftUI

/// Wires S7.3's attract/idle system around whatever the kiosk is currently
/// showing — constructed once the venue skin is ready
/// (``KioskSkinGateView``'s `.ready` case is the only place a
/// ``KioskBehavioralConfig`` exists), so it never has to guess at timeouts
/// or an attract URL a skin download hasn't resolved yet.
///
/// Owns the one place ``IdleTimerModel`` learns about preview playback:
/// `SharedFeatures/PreviewPlayerModel.isPlaying` is a plain `@Observable`
/// property with no notification of its own to subscribe to (unlike
/// legacy's `PlaybackStarted`/`PlaybackStopped` notification pair), so this
/// view watches it with `.onChange` and forwards every transition — the
/// same "observe in the view, forward to the model" shape
/// `SecretDJApp.swift` already uses for `scenePhase`/auto-lock, rather than
/// introducing a new `withObservationTracking` pattern for this one case.
///
/// Also publishes ``IdleTimerModel`` itself into the environment
/// (``EnvironmentValues/idleTimerModel``) for `content` to read — this
/// container is deliberately ignorant of what `content` does with an idle
/// timeout (S7.4+'s screens are the ones that know what "return to root"
/// means for them), so it hands the model up rather than threading a
/// navigation callback through its generic `Content` builder.
struct AttractIdleContainerView<Content: View>: View {
	let behavioralConfig: KioskBehavioralConfig
	let previewPlayer: PreviewPlayerModel
	let content: Content

	@State private var idleTimerModel: IdleTimerModel

	init(
		behavioralConfig: KioskBehavioralConfig,
		previewPlayer: PreviewPlayerModel,
		observability: ObservabilityPipeline = .disabled,
		@ViewBuilder content: () -> Content,
	) {
		self.behavioralConfig = behavioralConfig
		self.previewPlayer = previewPlayer
		self.content = content()
		_idleTimerModel = State(initialValue: IdleTimerModel(config: behavioralConfig, observability: observability))
	}

	var body: some View {
		content
			.attractIdleOverlay(model: idleTimerModel, attractURL: behavioralConfig.attractURL)
			.onChange(of: previewPlayer.isPlaying, initial: true) { _, isPlaying in
				idleTimerModel.setPreviewPlaying(isPlaying)
			}
			.environment(\.idleTimerModel, idleTimerModel)
	}
}

#Preview("With attract URL") {
	AttractIdleContainerView(
		behavioralConfig: KioskBehavioralConfig(manifest: PreviewSkinManifest.withAttract),
		previewPlayer: PreviewPlayerModel(
			downloading: InMemoryPreviewDownloading(),
			playerFactory: InMemoryAudioPlayerFactory(),
		),
	) {
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
}

#Preview("Accessibility text size") {
	AttractIdleContainerView(
		behavioralConfig: KioskBehavioralConfig(manifest: PreviewSkinManifest.withAttract),
		previewPlayer: PreviewPlayerModel(
			downloading: InMemoryPreviewDownloading(),
			playerFactory: InMemoryAudioPlayerFactory(),
		),
	) {
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
	.environment(\.dynamicTypeSize, .accessibility5)
}
