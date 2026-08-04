import Observability
import Observation

/// Drives the counter feature: holds the current count and persists every change.
@Observable
final class CounterModel {
	private(set) var count: Int

	private let store: CounterStoring
	private let observability: ObservabilityPipeline

	init(store: CounterStoring, observability: ObservabilityPipeline = .disabled) {
		self.store = store
		self.observability = observability
		count = store.savedCount()
	}

	func increment() {
		observability.interaction("increment")

		update(to: count + 1)
	}

	func decrement() {
		observability.interaction("decrement")

		update(to: count - 1)
	}

	func reset() {
		observability.interaction("reset")
		observability.track(CounterEvent.counterReset)

		update(to: 0)
	}

	private func update(to newCount: Int) {
		count = newCount
		store.save(newCount)
	}
}
