import Testing

@testable import DesignSystem

enum ToastQueueTests {
	@MainActor
	struct `Starting up` {
		@Test func `starts with no current toast`() {
			let queue = ToastQueue(clock: ManualToastClock())

			#expect(queue.current == nil)
		}
	}

	@MainActor
	struct Enqueuing {
		@Test func `enqueuing a toast when idle shows it immediately`() {
			let queue = ToastQueue(clock: ManualToastClock())
			let item = ToastItem(message: "Saved")

			queue.enqueue(item)

			#expect(queue.current == item)
		}

		@Test func `enqueuing while a toast is showing queues the new one behind it`() {
			let queue = ToastQueue(clock: ManualToastClock())
			let first = ToastItem(message: "First")
			let second = ToastItem(message: "Second")

			queue.enqueue(first)
			queue.enqueue(second)

			#expect(queue.current == first)
		}

		@Test func `queued toasts are shown in first-in-first-out order`() {
			let queue = ToastQueue(clock: ManualToastClock())
			let first = ToastItem(message: "First")
			let second = ToastItem(message: "Second")
			let third = ToastItem(message: "Third")

			queue.enqueue(first)
			queue.enqueue(second)
			queue.enqueue(third)
			queue.dismissCurrent()

			#expect(queue.current == second)

			queue.dismissCurrent()

			#expect(queue.current == third)
		}
	}

	@MainActor
	struct `Auto-dismiss timing` {
		@Test func `showing a toast schedules exactly one pending auto-dismiss`() {
			let clock = ManualToastClock()
			let queue = ToastQueue(clock: clock)

			queue.enqueue(ToastItem(message: "Saved"))

			#expect(clock.pendingCount == 1)
		}

		@Test func `a toast stays current until the clock fires`() {
			let clock = ManualToastClock()
			let queue = ToastQueue(clock: clock)
			queue.enqueue(ToastItem(message: "Saved"))

			#expect(queue.current != nil)
		}

		@Test func `the clock firing dismisses the current toast`() {
			let clock = ManualToastClock()
			let queue = ToastQueue(clock: clock)
			queue.enqueue(ToastItem(message: "Saved"))

			clock.advance()

			#expect(queue.current == nil)
		}

		@Test func `the clock firing advances to the next queued toast`() {
			let clock = ManualToastClock()
			let queue = ToastQueue(clock: clock)
			let first = ToastItem(message: "First")
			let second = ToastItem(message: "Second")
			queue.enqueue(first)
			queue.enqueue(second)

			clock.advance()

			#expect(queue.current == second)
		}

		@Test func `each newly shown toast schedules its own fresh auto-dismiss`() {
			let clock = ManualToastClock()
			let queue = ToastQueue(clock: clock)
			queue.enqueue(ToastItem(message: "First"))
			queue.enqueue(ToastItem(message: "Second"))

			clock.advance()

			#expect(clock.pendingCount == 1)
		}
	}

	@MainActor
	struct `Manual dismissal` {
		@Test func `dismissCurrent advances immediately to the next queued toast`() {
			let queue = ToastQueue(clock: ManualToastClock())
			let first = ToastItem(message: "First")
			let second = ToastItem(message: "Second")
			queue.enqueue(first)
			queue.enqueue(second)

			queue.dismissCurrent()

			#expect(queue.current == second)
		}

		@Test func `dismissCurrent on the only toast leaves the queue empty`() {
			let queue = ToastQueue(clock: ManualToastClock())
			queue.enqueue(ToastItem(message: "Saved"))

			queue.dismissCurrent()

			#expect(queue.current == nil)
		}

		@Test func `dismissCurrent on an idle queue is a harmless no-op`() {
			let queue = ToastQueue(clock: ManualToastClock())

			queue.dismissCurrent()

			#expect(queue.current == nil)
		}

		@Test func `dismissCurrent cancels the dismissed toast's pending auto-dismiss`() {
			let clock = ManualToastClock()
			let queue = ToastQueue(clock: clock)
			queue.enqueue(ToastItem(message: "Saved"))

			queue.dismissCurrent()

			#expect(clock.pendingCount == 0)
		}
	}
}
