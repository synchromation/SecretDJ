import Foundation

/// The seam ``PreviewPlayerModel`` uses to activate and deactivate the
/// shared system audio session around preview playback (ios-architecture: a
/// protocol seam per real dependency), thinned so its tests never touch
/// `AVFoundation`. The real adapter is ``AVAudioSessionControl``.
///
/// **Deliberate divergence from legacy** (LEGACY.md "Audio and playback" →
/// "Audio session configuration"): legacy activated the session once at
/// launch, in both app delegates, and never deactivated it — meaning the
/// non-mixable `.playback` category silenced/interrupted whatever the user
/// was already listening to (their own Music/Spotify/podcast) from the
/// moment the app opened, whether or not they ever played a preview, and
/// never handed that audio back. This app instead activates only when a
/// preview is about to actually start sounding, and deactivates — via
/// `setActive(false, options: .notifyOthersOnDeactivation)` — every time it
/// returns to idle, so other audio is interrupted only while a preview is
/// actually audible and reliably resumes afterward.
@MainActor
public protocol AudioSessionControlling {
	/// Configures the session for preview playback (category `.playback`)
	/// and activates it. Safe to call repeatedly without an intervening
	/// deactivate — e.g. when one preview supersedes another still playing.
	func activate() throws

	/// Deactivates the session and notifies other apps they may resume
	/// their own audio.
	func deactivateNotifyingOthers() throws
}
