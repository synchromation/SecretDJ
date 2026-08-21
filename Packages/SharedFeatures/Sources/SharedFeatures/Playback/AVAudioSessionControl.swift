import AVFoundation
import Foundation

/// The production ``AudioSessionControlling``: wraps the shared
/// `AVAudioSession` directly. `AVAudioSession` doesn't exist on macOS, which
/// this package's native test suite also targets (mirrors
/// ``SystemAudioPlayerFactory``'s own `#if canImport(UIKit)` guard) — both
/// methods are no-ops there.
@MainActor
public struct AVAudioSessionControl: AudioSessionControlling {
	public init() {}

	public func activate() throws {
		#if canImport(UIKit)
			try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
			try AVAudioSession.sharedInstance().setActive(true)
		#endif
	}

	public func deactivateNotifyingOthers() throws {
		#if canImport(UIKit)
			try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
		#endif
	}
}
