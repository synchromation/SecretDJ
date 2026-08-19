import Testing

@testable import SecretDJKiosk

/// Covers ``StaffResetGestureModel``'s five-taps-in-three-seconds counting
/// — the staff reset's hidden trigger gesture (PLAN.md S7.1: "a staff
/// reset affordance replacing the legacy `?RESTART?` search incantation").
/// ``ManualStaffResetGestureClock`` stands in for real elapsed time so the
/// three-second window can be exercised without sleeping (swift-testing
/// skill: async code never uses sleeps).
@MainActor
enum StaffResetGestureModelTests {
	struct `Counting taps within the window` {
		@Test func `does not trigger before the fifth tap`() {
			let model = StaffResetGestureModel(clock: ManualStaffResetGestureClock())

			#expect(model.recordTap() == false)
			#expect(model.recordTap() == false)
			#expect(model.recordTap() == false)
			#expect(model.recordTap() == false)

			#expect(model.tapCount == 4)
		}

		@Test func `triggers on the fifth tap`() {
			let model = StaffResetGestureModel(clock: ManualStaffResetGestureClock())

			for _ in 0 ..< 4 {
				_ = model.recordTap()
			}

			#expect(model.recordTap() == true)
		}

		@Test func `resets the count after triggering, so the next tap starts a fresh run`() {
			let model = StaffResetGestureModel(clock: ManualStaffResetGestureClock())
			for _ in 0 ..< 5 {
				_ = model.recordTap()
			}

			let triggeredAgain = model.recordTap()

			#expect(triggeredAgain == false)
			#expect(model.tapCount == 1)
		}
	}

	struct `Taps spread across time` {
		@Test func `a tap outside the three-second window starts a new run`() {
			let clock = ManualStaffResetGestureClock()
			let model = StaffResetGestureModel(clock: clock)
			_ = model.recordTap()

			clock.advance(by: .seconds(4))
			_ = model.recordTap()

			#expect(model.tapCount == 1)
		}

		@Test func `taps that stay inside the window keep accumulating`() {
			let clock = ManualStaffResetGestureClock()
			let model = StaffResetGestureModel(clock: clock)
			_ = model.recordTap()

			clock.advance(by: .seconds(2))
			_ = model.recordTap()

			#expect(model.tapCount == 2)
		}

		@Test func `a lapsed run followed by four fresh taps does not trigger`() {
			let clock = ManualStaffResetGestureClock()
			let model = StaffResetGestureModel(clock: clock)
			_ = model.recordTap()

			clock.advance(by: .seconds(4))
			var triggered = false
			for _ in 0 ..< 4 {
				triggered = model.recordTap()
			}

			#expect(triggered == false)
		}
	}
}
