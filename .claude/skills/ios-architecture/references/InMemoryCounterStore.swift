/// Holds the counter's value in memory only.
///
/// Used by tests and previews so they never touch real persistence.
final class InMemoryCounterStore: CounterStoring {
	private(set) var count: Int

	init(count: Int = 0) {
		self.count = count
	}

	func savedCount() -> Int {
		count
	}

	func save(_ count: Int) {
		self.count = count
	}
}
