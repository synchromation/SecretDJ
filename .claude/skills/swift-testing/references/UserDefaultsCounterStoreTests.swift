import Foundation
import Testing

@testable import MyApp

struct UserDefaultsCounterStoreTests {
	@Test func `returns zero when nothing is saved`() throws {
		let store = try UserDefaultsCounterStore(defaults: scratchDefaults())

		#expect(store.savedCount() == 0)
	}

	@Test func `round-trips a saved count`() throws {
		let store = try UserDefaultsCounterStore(defaults: scratchDefaults())

		store.save(41)

		#expect(store.savedCount() == 41)
	}

	/// A throwaway `UserDefaults` suite so tests never touch the app's real defaults.
	private func scratchDefaults() throws -> UserDefaults {
		let suiteName = "test.\(UUID().uuidString)"
		let defaults = try #require(UserDefaults(suiteName: suiteName))

		defaults.removePersistentDomain(forName: suiteName)

		return defaults
	}
}
