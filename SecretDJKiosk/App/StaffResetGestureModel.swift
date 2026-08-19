import Observation

/// The staff reset's hidden trigger gesture: five taps in a corner within
/// three seconds — this rewrite's replacement for legacy's `?RESTART?`
/// search incantation (LEGACY.md "Venue login and the skin system": "Staff
/// reset easter egg"; PLAN.md S7.1: "the trigger mechanism is a small
/// product decision... easily changeable" — both constants below are the
/// whole knob).
///
/// Owns only the counting, not the confirmation or the reset itself
/// (``StaffResetModel``) — kept in its own model so the gesture can be
/// tuned and tested in isolation from the UI and from what triggering it
/// actually does.
@Observable
final class StaffResetGestureModel {
	/// How many taps within ``window`` trigger the reset confirmation.
	static let requiredTapCount = 5
	/// The rolling window a run of taps must land inside, measured from the
	/// run's first tap.
	static let window = Duration.seconds(3)

	private(set) var tapCount = 0

	private let clock: any StaffResetGestureClock
	private var firstTapAt: ContinuousClock.Instant?

	init(clock: any StaffResetGestureClock = SystemStaffResetGestureClock()) {
		self.clock = clock
	}

	/// Records one tap. Returns `true` exactly once the run reaches
	/// ``requiredTapCount`` within ``window`` — the caller's cue to show the
	/// reset confirmation — and resets the count immediately after, so a
	/// dismissed confirmation starts a fresh run rather than firing again on
	/// the very next tap.
	@discardableResult
	func recordTap() -> Bool {
		let now = clock.now()

		if let firstTapAt, now - firstTapAt > Self.window {
			tapCount = 0
		}

		if tapCount == 0 {
			firstTapAt = now
		}
		tapCount += 1

		guard tapCount >= Self.requiredTapCount else {
			return false
		}

		tapCount = 0
		firstTapAt = nil
		return true
	}
}
