import Foundation

/// Where ``StaffResetGestureModel`` reads "now" from — abstracted so the
/// five-tap gesture's rolling three-second window is testable without
/// waiting out real seconds (swift-testing skill: async code is tested
/// with real `await`, never sleeps; this gesture isn't even async, so a
/// sleep-based test would be worse still).
protocol StaffResetGestureClock: Sendable {
	func now() -> ContinuousClock.Instant
}

/// The production ``StaffResetGestureClock``: real elapsed time.
struct SystemStaffResetGestureClock: StaffResetGestureClock {
	func now() -> ContinuousClock.Instant {
		ContinuousClock.now
	}
}
