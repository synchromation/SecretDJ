import Foundation

/// Schedules ``FeedScreenModel``'s auto-refresh ticks.
///
/// Abstracting time behind this protocol lets auto-refresh be driven
/// deterministically in tests (``ManualFeedRefreshClock``) instead of
/// waiting out real delays — mirrors DesignSystem's `ToastClock`, but the
/// scheduled action is `async`: a refresh tick awaits a network fetch,
/// where a toast's auto-dismiss never does.
@MainActor
public protocol FeedRefreshClock {
	/// Schedules `action` to run once, after `duration` has elapsed, and
	/// returns a token that cancels the pending firing if invoked first.
	@discardableResult
	func schedule(after duration: Duration, action: @escaping () async -> Void) -> FeedRefreshClockToken
}

/// Cancels a pending ``FeedRefreshClock`` firing. Cancelling after the
/// action has already fired (or after a prior cancel) is harmless.
@MainActor
public struct FeedRefreshClockToken {
	private let onCancel: () -> Void

	init(onCancel: @escaping () -> Void) {
		self.onCancel = onCancel
	}

	public func cancel() {
		onCancel()
	}
}

/// The production ``FeedRefreshClock``: schedules against real elapsed time.
@MainActor
public struct SystemFeedRefreshClock: FeedRefreshClock {
	public init() {}

	public func schedule(after duration: Duration, action: @escaping () async -> Void) -> FeedRefreshClockToken {
		let task = Task {
			try? await Task.sleep(for: duration)

			guard !Task.isCancelled else { return }

			await action()
		}

		return FeedRefreshClockToken { task.cancel() }
	}
}
