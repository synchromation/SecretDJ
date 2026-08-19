import Foundation

/// Schedules ``IdleTimerModel``'s attract/idle countdowns so they can be
/// exercised deterministically in tests (``ManualIdleTimerClock``) instead
/// of waiting out real seconds. Mirrors `SharedFeatures/PreviewCapClock` —
/// this one stays kiosk-local (ios-architecture: a dependency used by a
/// single app lives in that app's `Features/<Name>/`, not a shared package).
protocol IdleTimerClock {
	/// Schedules `action` to run once, after `duration` has elapsed, and
	/// returns a token that cancels the pending firing if invoked first.
	@discardableResult
	func schedule(after duration: Duration, action: @escaping () -> Void) -> IdleTimerClockToken
}

/// Cancels a pending ``IdleTimerClock`` firing. Cancelling after the action
/// has already fired (or after a prior cancel) is harmless.
struct IdleTimerClockToken {
	private let onCancel: () -> Void

	init(onCancel: @escaping () -> Void) {
		self.onCancel = onCancel
	}

	func cancel() {
		onCancel()
	}
}

/// The production ``IdleTimerClock``: schedules against real elapsed time.
struct SystemIdleTimerClock: IdleTimerClock {
	func schedule(after duration: Duration, action: @escaping () -> Void) -> IdleTimerClockToken {
		let task = Task {
			try? await Task.sleep(for: duration)

			guard !Task.isCancelled else { return }

			action()
		}

		return IdleTimerClockToken { task.cancel() }
	}
}
