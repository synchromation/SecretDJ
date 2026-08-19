import Foundation

/// Schedules ``PreviewPlayerModel``'s 30-second hard cap — so it can be
/// exercised deterministically in tests (``ManualPreviewCapClock``) instead
/// of waiting out real delays. Mirrors ``SearchDebounceClock``/
/// `FeedUI/FeedRefreshClock`.
@MainActor
public protocol PreviewCapClock {
	/// Schedules `action` to run once, after `duration` has elapsed, and
	/// returns a token that cancels the pending firing if invoked first.
	@discardableResult
	func schedule(after duration: Duration, action: @escaping () -> Void) -> PreviewCapClockToken
}

/// Cancels a pending ``PreviewCapClock`` firing. Cancelling after the action
/// has already fired (or after a prior cancel) is harmless.
@MainActor
public struct PreviewCapClockToken {
	private let onCancel: () -> Void

	init(onCancel: @escaping () -> Void) {
		self.onCancel = onCancel
	}

	public func cancel() {
		onCancel()
	}
}

/// The production ``PreviewCapClock``: schedules against real elapsed time.
@MainActor
public struct SystemPreviewCapClock: PreviewCapClock {
	public init() {}

	public func schedule(after duration: Duration, action: @escaping () -> Void) -> PreviewCapClockToken {
		let task = Task {
			try? await Task.sleep(for: duration)

			guard !Task.isCancelled else { return }

			action()
		}

		return PreviewCapClockToken { task.cancel() }
	}
}
