import Foundation

/// A scriptable ``AudioPlayerFactory``/``AudioPlaying`` fake pair for tests
/// and previews — never touches `AVFoundation`. ``InMemoryAudioPlayerFactory``
/// records every ``Foundation/Data`` it's asked to decode and hands back a
/// fresh ``InMemoryAudioPlaying`` each time (or throws ``failure``, when
/// set, to exercise the decode-failure path), so a test can drive
/// ``lastPlayer`` directly to simulate the clip finishing naturally.
@MainActor
public final class InMemoryAudioPlayerFactory: AudioPlayerFactory {
	public private(set) var decodedData: [Data] = []
	/// When set, ``makePlayer(data:)`` throws this instead of succeeding —
	/// exercises ``PreviewPlayerModel``'s decode-failure path.
	public var failure: (any Error)?
	/// The most recently created player, for a test to drive directly.
	public private(set) var lastPlayer: InMemoryAudioPlaying?

	public init() {}

	public func makePlayer(data: Data) throws -> any AudioPlaying {
		decodedData.append(data)
		if let failure {
			throw failure
		}
		let player = InMemoryAudioPlaying()
		lastPlayer = player
		return player
	}
}

/// See ``InMemoryAudioPlayerFactory``.
@MainActor
public final class InMemoryAudioPlaying: AudioPlaying {
	public var onFinished: (() -> Void)?
	public private(set) var playCount = 0
	public private(set) var stopCount = 0

	public init() {}

	public func play() {
		playCount += 1
	}

	public func stop() {
		stopCount += 1
	}

	/// Simulates the clip reaching its natural end — mirrors
	/// `AVAudioPlayerDelegate`'s `audioPlayerDidFinishPlaying(_:successfully:)`
	/// firing.
	public func finish() {
		onFinished?()
	}
}
