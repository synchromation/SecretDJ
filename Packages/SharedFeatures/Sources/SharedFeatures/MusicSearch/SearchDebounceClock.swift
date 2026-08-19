import Foundation

/// Schedules ``SearchModel``'s debounced track search — so track search
/// (LEGACY.md "Song search": "server round-trip per keystroke") can be
/// exercised deterministically in tests (``ManualSearchDebounceClock``)
/// instead of waiting out real delays. Mirrors `FeedUI/FeedRefreshClock`.
@MainActor
public protocol SearchDebounceClock {
	/// Schedules `action` to run once, after `duration` has elapsed, and
	/// returns a token that cancels the pending firing if invoked first.
	@discardableResult
	func schedule(after duration: Duration, action: @escaping () async -> Void) -> SearchDebounceClockToken
}

/// Cancels a pending ``SearchDebounceClock`` firing. Cancelling after the
/// action has already fired (or after a prior cancel) is harmless.
@MainActor
public struct SearchDebounceClockToken {
	private let onCancel: () -> Void

	init(onCancel: @escaping () -> Void) {
		self.onCancel = onCancel
	}

	public func cancel() {
		onCancel()
	}
}

/// The production ``SearchDebounceClock``: schedules against real elapsed
/// time.
@MainActor
public struct SystemSearchDebounceClock: SearchDebounceClock {
	public init() {}

	public func schedule(after duration: Duration, action: @escaping () async -> Void) -> SearchDebounceClockToken {
		let task = Task {
			try? await Task.sleep(for: duration)

			guard !Task.isCancelled else { return }

			await action()
		}

		return SearchDebounceClockToken { task.cancel() }
	}
}
