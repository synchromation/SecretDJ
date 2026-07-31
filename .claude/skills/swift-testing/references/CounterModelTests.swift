import Testing

@testable import MyApp

struct CounterModelTests {
	@Test func startsAtZeroWithAnEmptyStore() {
		let model = CounterModel(store: InMemoryCounterStore())

		#expect(model.count == 0)
	}

	@Test func restoresTheSavedCountOnLaunch() {
		let store = InMemoryCounterStore(count: 41)

		let model = CounterModel(store: store)

		#expect(model.count == 41)
	}

	@Test func incrementRaisesTheCountByOne() {
		let model = CounterModel(store: InMemoryCounterStore())

		model.increment()

		#expect(model.count == 1)
	}

	@Test func decrementLowersTheCountByOne() {
		let model = CounterModel(store: InMemoryCounterStore())

		model.decrement()

		#expect(model.count == -1)
	}

	@Test func resetReturnsTheCountToZero() {
		let model = CounterModel(store: InMemoryCounterStore(count: 41))

		model.reset()

		#expect(model.count == 0)
	}

	@Test func everyChangeIsPersistedToTheStore() {
		let store = InMemoryCounterStore()
		let model = CounterModel(store: store)

		model.increment()
		model.increment()

		#expect(store.count == 2)
	}
}
