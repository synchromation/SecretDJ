import Foundation

/// A ``StaffResetGestureClock`` fake for tests: starts at an arbitrary
/// instant and only moves when ``advance(by:)`` is called — mirrors
/// `DesignSystem`'s `ManualToastClock` shape for the same reason (a
/// deterministic stand-in for real elapsed time).
final class ManualStaffResetGestureClock: StaffResetGestureClock {
	private var current = ContinuousClock.now

	func now() -> ContinuousClock.Instant {
		current
	}

	func advance(by duration: Duration) {
		current += duration
	}
}
