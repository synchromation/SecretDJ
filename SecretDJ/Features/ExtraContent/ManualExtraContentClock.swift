import Foundation

/// An ``ExtraContentClock`` fake for tests and previews: `schedule(after:action:)`
/// never fires on its own — call ``advance()`` to fire every currently
/// pending action, as if its duration had elapsed. Mirrors DesignSystem's
/// `ManualToastClock`.
@MainActor
final class ManualExtraContentClock: ExtraContentClock {
	private struct PendingFiring {
		let id = UUID()
		let action: () -> Void
	}

	/// How many firings are currently pending — a test's way to confirm a
	/// rotation tick was scheduled (or cancelled while hidden).
	var pendingCount: Int {
		pending.count
	}

	/// Every `duration` this clock was asked to schedule, in call order — a
	/// test's way to confirm the 10-second cadence.
	private(set) var scheduledDurations: [Duration] = []

	private var pending: [PendingFiring] = []

	init() {}

	func schedule(after duration: Duration, action: @escaping () -> Void) -> ExtraContentClockToken {
		scheduledDurations.append(duration)

		let firing = PendingFiring(action: action)
		pending.append(firing)

		return ExtraContentClockToken { [weak self] in
			self?.pending.removeAll { $0.id == firing.id }
		}
	}

	/// Fires every currently pending action, in scheduling order. A firing
	/// that reschedules itself (``ExtraContentModel``'s rotation loop always
	/// does, while visible) is *not* re-fired by this same call — call
	/// ``advance()`` again to step forward another tick.
	func advance() {
		let firing = pending
		pending.removeAll()

		for item in firing {
			item.action()
		}
	}
}
