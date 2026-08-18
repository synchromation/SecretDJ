import Testing

@testable import DesignSystem

struct ToastItemTests {
	@Test func `defaults to a three second display duration`() {
		let item = ToastItem(message: "Saved")

		#expect(item.duration == .seconds(3))
	}

	@Test func `each item gets a distinct identity even with identical messages`() {
		let first = ToastItem(message: "Saved")
		let second = ToastItem(message: "Saved")

		#expect(first.id != second.id)
		#expect(first != second)
	}
}
