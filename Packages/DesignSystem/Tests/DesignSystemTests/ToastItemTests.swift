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

	@Test func `has no rich content by default`() {
		let item = ToastItem(message: "Saved")

		#expect(item.richContent == nil)
	}

	@Test func `carries the rich content it's constructed with`() {
		let content = RichToastContent(title: "Reward!", headline: "", bodyText: "", vip: nil)

		let item = ToastItem(message: "Saved", richContent: content)

		#expect(item.richContent == content)
	}
}
