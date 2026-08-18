/// Schedules ``ToastQueue``'s auto-dismiss timing.
///
/// Abstracting time behind this protocol lets ``ToastQueue`` be tested with
/// ``ManualToastClock`` instead of waiting out real delays.
@MainActor
public protocol ToastClock {
	/// Schedules `action` to run once, after `duration` has elapsed, and
	/// returns a token that cancels the pending firing if invoked first.
	@discardableResult
	func schedule(after duration: Duration, action: @escaping () -> Void) -> ToastClockToken
}

/// Cancels a pending ``ToastClock`` firing. Cancelling after the action has
/// already fired (or after a prior cancel) is harmless.
@MainActor
public struct ToastClockToken {
	private let onCancel: () -> Void

	init(onCancel: @escaping () -> Void) {
		self.onCancel = onCancel
	}

	public func cancel() {
		onCancel()
	}
}

/// The production ``ToastClock``: schedules against real elapsed time.
@MainActor
public struct SystemToastClock: ToastClock {
	public init() {}

	public func schedule(after duration: Duration, action: @escaping () -> Void) -> ToastClockToken {
		let task = Task {
			try? await Task.sleep(for: duration)

			guard !Task.isCancelled else { return }

			action()
		}

		return ToastClockToken { task.cancel() }
	}
}
