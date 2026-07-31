import Observation

/// Drives the counter feature: holds the current count and persists every change.
@Observable
final class CounterModel {
	private(set) var count: Int

	private let store: CounterStoring

	init(store: CounterStoring) {
		self.store = store
		count = store.savedCount()
	}

	func increment() {
		update(to: count + 1)
	}

	func decrement() {
		update(to: count - 1)
	}

	func reset() {
		update(to: 0)
	}

	private func update(to newCount: Int) {
		count = newCount
		store.save(newCount)
	}
}
