import AVFoundation
import Foundation

/// The production ``AudioPlayerFactory``: a thin wrapper over
/// `AVAudioPlayer(data:)` (LEGACY.md "Audio and playback" → "Evolution:
/// StreamingKit → AVPlayer → download + AVAudioPlayer" — the backend's
/// `.pbz`/generic-Content-Type quirk means `AVPlayer(url:)` can't be used;
/// the whole file must be downloaded first and handed to `AVAudioPlayer`
/// directly, which parses the container from bytes rather than trusting the
/// URL's extension/MIME type).
@MainActor
public final class SystemAudioPlayerFactory: AudioPlayerFactory {
	public init() {}

	public func makePlayer(data: Data) throws -> any AudioPlaying {
		#if canImport(UIKit)
			// Other audio (ringtones, route changes) can deactivate the shared
			// session between previews — reactivate defensively before every
			// one, exactly as both legacy Tune In screens did per-tap
			// (LEGACY.md "Audio session configuration": "other audio ... can
			// deactivate it"). `AVAudioSession` doesn't exist on macOS, which
			// this package's native test suite also targets.
			try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
			try? AVAudioSession.sharedInstance().setActive(true)
		#endif

		return try AVAudioPlayerAdapter(data: data)
	}
}

/// The thin `AVAudioPlayer` adapter behind ``SystemAudioPlayerFactory``.
@MainActor
final class AVAudioPlayerAdapter: NSObject, AudioPlaying, AVAudioPlayerDelegate {
	var onFinished: (() -> Void)?

	private let player: AVAudioPlayer

	init(data: Data) throws {
		player = try AVAudioPlayer(data: data)
		super.init()
		player.delegate = self
	}

	func play() {
		player.prepareToPlay()
		player.play()
	}

	func stop() {
		player.stop()
	}

	func audioPlayerDidFinishPlaying(_: AVAudioPlayer, successfully _: Bool) {
		onFinished?()
	}
}
