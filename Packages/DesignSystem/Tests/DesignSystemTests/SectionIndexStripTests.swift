import Testing

@testable import DesignSystem

/// Coverage for ``SectionIndexStrip``'s pure geometry/step math — the view
/// body itself isn't TDD'd (tdd skill), but the drag-to-index mapping and
/// the VoiceOver adjustable step are logic, extracted so they're testable
/// without a hosted view.
enum SectionIndexStripTests {
	struct `Mapping a drag position to a letter index` {
		@Test func `the top of the strip selects the first letter`() {
			let index = SectionIndexStrip.index(forDragY: 0, height: 260, letterCount: 26)

			#expect(index == 0)
		}

		@Test func `the bottom of the strip selects the last letter`() {
			let index = SectionIndexStrip.index(forDragY: 259, height: 260, letterCount: 26)

			#expect(index == 25)
		}

		@Test func `the midpoint selects a middle letter`() {
			let index = SectionIndexStrip.index(forDragY: 130, height: 260, letterCount: 26)

			#expect(index == 13)
		}

		@Test func `a y above the strip clamps to the first letter`() {
			let index = SectionIndexStrip.index(forDragY: -40, height: 260, letterCount: 26)

			#expect(index == 0)
		}

		@Test func `a y past the bottom clamps to the last letter`() {
			let index = SectionIndexStrip.index(forDragY: 900, height: 260, letterCount: 26)

			#expect(index == 25)
		}

		@Test func `no letters produces no index`() {
			let index = SectionIndexStrip.index(forDragY: 100, height: 260, letterCount: 0)

			#expect(index == nil)
		}

		@Test func `zero height produces no index`() {
			let index = SectionIndexStrip.index(forDragY: 100, height: 0, letterCount: 26)

			#expect(index == nil)
		}
	}

	struct `Stepping through letters for VoiceOver's adjustable action` {
		@Test func `incrementing moves to the next letter`() {
			let next = SectionIndexStrip.adjustedIndex(from: 3, direction: .increment, letterCount: 10)

			#expect(next == 4)
		}

		@Test func `decrementing moves to the previous letter`() {
			let next = SectionIndexStrip.adjustedIndex(from: 3, direction: .decrement, letterCount: 10)

			#expect(next == 2)
		}

		@Test func `incrementing at the last letter stays put`() {
			let next = SectionIndexStrip.adjustedIndex(from: 9, direction: .increment, letterCount: 10)

			#expect(next == 9)
		}

		@Test func `decrementing at the first letter stays put`() {
			let next = SectionIndexStrip.adjustedIndex(from: 0, direction: .decrement, letterCount: 10)

			#expect(next == 0)
		}

		@Test func `with no letters the step stays at zero`() {
			let next = SectionIndexStrip.adjustedIndex(from: 0, direction: .increment, letterCount: 0)

			#expect(next == 0)
		}
	}
}
