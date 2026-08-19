import Foundation

/// An ``IdleTimerClock`` fake for tests: `schedule(after:action:)` never
/// fires on its own. ``IdleTimerModel`` always has *two* schedules pending
/// at once (attract + idle, per its own doc comment) with different
/// durations, so — unlike `SharedFeatures/ManualPreviewCapClock`'s single
/// blanket ``fire()`` — firing here is keyed by duration, letting a test
/// trigger the attract timeout without also triggering the idle one (or
/// vice versa), matching how legacy's two independent one-shot `Timer`s
/// actually behave (`KioskTimer.swift`).
final class ManualIdleTimerClock: IdleTimerClock {
	private struct PendingFiring {
		let id = UUID()
		let duration: Duration
		let action: () -> Void
	}

	/// The durations currently pending — a test's way to confirm exactly
	/// which timers are armed (e.g. only idle, when the skin has no attract
	/// URL; neither, while a preview is suppressing both).
	var pendingDurations: [Duration] {
		pending.map(\.duration)
	}

	private var pending: [PendingFiring] = []

	func schedule(after duration: Duration, action: @escaping () -> Void) -> IdleTimerClockToken {
		let firing = PendingFiring(duration: duration, action: action)
		pending.append(firing)

		return IdleTimerClockToken { [weak self] in
			self?.pending.removeAll { $0.id == firing.id }
		}
	}

	/// Fires every pending action scheduled with exactly `duration`, as if
	/// that timeout had elapsed. A no-op when nothing matches.
	func fire(after duration: Duration) {
		let matching = pending.filter { $0.duration == duration }
		pending.removeAll { $0.duration == duration }

		for firing in matching {
			firing.action()
		}
	}
}
