import Foundation

/// Schedules ``ExtraContentModel``'s rotation ticks.
///
/// Abstracting time behind this protocol lets rotation be driven
/// deterministically in tests (``ManualExtraContentClock``) instead of
/// waiting out real 10-second delays — mirrors DesignSystem's `ToastClock`
/// and FeedUI's `FeedRefreshClock`; a new type rather than reusing either
/// directly, following this project's established convention of one small
/// clock protocol per feature (`FeedRefreshClock`'s own doc comment: "mirrors
/// DesignSystem's ToastClock") so this feature's dependency list stays
/// self-contained and doesn't couple to an unrelated package's naming.
@MainActor
protocol ExtraContentClock {
	/// Schedules `action` to run once, after `duration` has elapsed, and
	/// returns a token that cancels the pending firing if invoked first.
	@discardableResult
	func schedule(after duration: Duration, action: @escaping () -> Void) -> ExtraContentClockToken
}

/// Cancels a pending ``ExtraContentClock`` firing. Cancelling after the
/// action has already fired (or after a prior cancel) is harmless.
@MainActor
struct ExtraContentClockToken {
	private let onCancel: () -> Void

	init(onCancel: @escaping () -> Void) {
		self.onCancel = onCancel
	}

	func cancel() {
		onCancel()
	}
}

/// The production ``ExtraContentClock``: schedules against real elapsed
/// time.
@MainActor
struct SystemExtraContentClock: ExtraContentClock {
	init() {}

	func schedule(after duration: Duration, action: @escaping () -> Void) -> ExtraContentClockToken {
		let task = Task {
			try? await Task.sleep(for: duration)

			guard !Task.isCancelled else { return }

			action()
		}

		return ExtraContentClockToken { task.cancel() }
	}
}
