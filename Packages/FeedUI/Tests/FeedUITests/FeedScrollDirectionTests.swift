import Testing

@testable import FeedUI

/// ``FeedScrollDirection/from(oldOffset:newOffset:threshold:)`` — the pure
/// direction detector ``FeedView``'s `onScrollGeometryChange` closure calls,
/// extracted so the extra-content ticker's scroll signal (PLAN.md S6.9) is
/// testable without a live `ScrollView` (tdd skill's view-body boundary).
enum FeedScrollDirectionTests {
	struct `Detecting a direction` {
		@Test func `reports towardStart when the offset decreases past the threshold`() {
			let direction = FeedScrollDirection.from(oldOffset: 100, newOffset: 40)

			#expect(direction == .towardStart)
		}

		@Test func `reports towardEnd when the offset increases past the threshold`() {
			let direction = FeedScrollDirection.from(oldOffset: 40, newOffset: 100)

			#expect(direction == .towardEnd)
		}

		@Test func `reports nil when the offset is unchanged`() {
			let direction = FeedScrollDirection.from(oldOffset: 40, newOffset: 40)

			#expect(direction == nil)
		}

		@Test func `reports nil for a sub-threshold delta in either direction`() {
			#expect(FeedScrollDirection.from(oldOffset: 40, newOffset: 40.2) == nil)
			#expect(FeedScrollDirection.from(oldOffset: 40, newOffset: 39.8) == nil)
		}

		@Test func `treats an exactly-at-threshold delta as no change`() {
			let direction = FeedScrollDirection.from(oldOffset: 40, newOffset: 40.5, threshold: 0.5)

			#expect(direction == nil)
		}

		@Test func `honors a custom threshold`() {
			let direction = FeedScrollDirection.from(oldOffset: 40, newOffset: 45, threshold: 10)

			#expect(direction == nil)
		}
	}
}
