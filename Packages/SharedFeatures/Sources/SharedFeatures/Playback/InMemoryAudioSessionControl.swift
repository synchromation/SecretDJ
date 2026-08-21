import Foundation

/// An in-memory ``AudioSessionControlling`` fake for tests and previews —
/// never touches `AVFoundation`, just counts calls so a test can assert on
/// the activate/deactivate contract directly.
@MainActor
public final class InMemoryAudioSessionControl: AudioSessionControlling {
	public private(set) var activateCount = 0
	public private(set) var deactivateCount = 0

	public init() {}

	public func activate() throws {
		activateCount += 1
	}

	public func deactivateNotifyingOthers() throws {
		deactivateCount += 1
	}
}
