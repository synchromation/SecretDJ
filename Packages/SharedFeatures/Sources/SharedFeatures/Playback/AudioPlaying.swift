import Foundation

/// A single playing-or-stopped audio clip, decoded once from already-
/// downloaded bytes — the seam ``PreviewPlayerModel`` drives, thinned so its
/// tests never touch `AVFoundation` (ios-architecture: a protocol seam per
/// real dependency). The real adapter (`AVAudioPlayerAdapter`, behind
/// ``SystemAudioPlayerFactory``) wraps `AVAudioPlayer(data:)` directly —
/// LEGACY.md's `.pbz`/generic-Content-Type quirk means the bytes must
/// already be fully downloaded before this type ever sees them; it never
/// touches the network itself.
@MainActor
public protocol AudioPlaying: AnyObject {
	/// Fires once, the moment the clip finishes playing on its own — never
	/// called for an explicit ``stop()``. Mirrors
	/// `AVAudioPlayerDelegate.audioPlayerDidFinishPlaying(_:successfully:)`.
	var onFinished: (() -> Void)? { get set }
	func play()
	func stop()
}

/// Decodes already-downloaded preview bytes into a playable
/// ``AudioPlaying`` — split from ``AudioPlaying`` itself because decoding
/// can fail (a malformed or truncated download), which a factory method can
/// throw but a live player instance can't represent once it exists.
@MainActor
public protocol AudioPlayerFactory {
	func makePlayer(data: Data) throws -> any AudioPlaying
}
