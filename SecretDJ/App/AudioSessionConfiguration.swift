import AVFoundation
import Observability

/// Configures the shared audio session once at launch for song-preview
/// playback (PLAN.md S6.4): category `.playback`, active immediately —
/// ported from legacy's `AppDelegate.swift`/`KioskAppDelegate.swift`
/// (LEGACY.md "Audio and playback" → "Audio session configuration").
/// Legacy's `setPreferredIOBufferDuration(0.2)` tweak is deliberately
/// dropped (LEGACY.md's "Tech debt NOT to carry forward": "cargo-culted
/// ... of admitted-unknown purpose").
enum AudioSessionConfiguration {
	static func configureForPreviewPlayback(observability: ObservabilityPipeline) {
		do {
			try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
			try AVAudioSession.sharedInstance().setActive(true)
		} catch {
			observability.report(error, category: "AudioSession")
		}
	}
}
