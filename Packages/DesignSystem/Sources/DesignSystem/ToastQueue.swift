import Observation

/// Presents the legacy server-driven toast contract: enqueued toasts show
/// one at a time, first in first out, each auto-dismissing after its own
/// duration unless dismissed early.
@MainActor
@Observable
public final class ToastQueue {
	public private(set) var current: ToastItem?

	private var waiting: [ToastItem] = []
	private let clock: any ToastClock
	private var dismissToken: ToastClockToken?

	public init(clock: any ToastClock = SystemToastClock()) {
		self.clock = clock
	}

	/// Adds `item` to the queue. If nothing is currently shown, it becomes
	/// current immediately; otherwise it waits its turn behind whatever is
	/// already queued.
	public func enqueue(_ item: ToastItem) {
		if current == nil {
			show(item)
		} else {
			waiting.append(item)
		}
	}

	/// Dismisses the current toast immediately — e.g. the user tapped it —
	/// cancelling its pending auto-dismiss, then advances to the next
	/// queued toast, if any.
	public func dismissCurrent() {
		dismissToken?.cancel()
		dismissToken = nil

		if waiting.isEmpty {
			current = nil
		} else {
			show(waiting.removeFirst())
		}
	}

	private func show(_ item: ToastItem) {
		current = item
		dismissToken = clock.schedule(after: item.duration) { [weak self] in
			self?.dismissCurrent()
		}
	}
}
