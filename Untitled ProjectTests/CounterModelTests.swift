import Testing

@testable import Untitled_Project

enum CounterModelTests {
	struct `Starting up` {
		@Test func `starts at zero with an empty store`() {
			let model = CounterModel(store: InMemoryCounterStore())

			#expect(model.count == 0)
		}

		@Test func `restores the saved count on launch`() {
			let store = InMemoryCounterStore(count: 41)

			let model = CounterModel(store: store)

			#expect(model.count == 41)
		}
	}

	struct `Changing the count` {
		@Test func `increment raises the count by one`() {
			let model = CounterModel(store: InMemoryCounterStore())

			model.increment()

			#expect(model.count == 1)
		}

		@Test func `decrement lowers the count by one`() {
			let model = CounterModel(store: InMemoryCounterStore())

			model.decrement()

			#expect(model.count == -1)
		}

		@Test func `reset returns the count to zero`() {
			let model = CounterModel(store: InMemoryCounterStore(count: 41))

			model.reset()

			#expect(model.count == 0)
		}
	}

	struct Persistence {
		@Test func `every change is persisted to the store`() {
			let store = InMemoryCounterStore()
			let model = CounterModel(store: store)

			model.increment()
			model.increment()

			#expect(store.count == 2)
		}
	}
}
