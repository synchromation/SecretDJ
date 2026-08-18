import Foundation
import Testing

@testable import SecretDJAPI

enum UserDefaultsSessionSnapshotStoreTests {
	@MainActor
	struct Persistence {
		@Test func `savedSnapshot returns nil when nothing has been saved`() throws {
			let suiteName = "test.\(UUID().uuidString)"
			let defaults = try #require(UserDefaults(suiteName: suiteName))
			let store = UserDefaultsSessionSnapshotStore(defaults: defaults)

			#expect(store.savedSnapshot() == nil)
		}

		@Test func `a scratch defaults store round-trips a snapshot with a venue`() throws {
			let suiteName = "test.\(UUID().uuidString)"
			let defaults = try #require(UserDefaults(suiteName: suiteName))
			let store = UserDefaultsSessionSnapshotStore(defaults: defaults)
			let snapshot = SessionSnapshot(
				user: SessionUser(personId: "41", screenName: "nick"),
				venue: SessionVenue(venueId: "7", name: "The Fox"),
			)

			store.save(snapshot)

			#expect(store.savedSnapshot() == snapshot)
		}

		@Test func `a scratch defaults store round-trips a snapshot with no venue`() throws {
			let suiteName = "test.\(UUID().uuidString)"
			let defaults = try #require(UserDefaults(suiteName: suiteName))
			let store = UserDefaultsSessionSnapshotStore(defaults: defaults)
			let snapshot = SessionSnapshot(user: SessionUser(personId: "41", screenName: "nick"), venue: nil)

			store.save(snapshot)

			#expect(store.savedSnapshot() == snapshot)
		}

		@Test func `save(nil) removes a previously saved snapshot`() throws {
			let suiteName = "test.\(UUID().uuidString)"
			let defaults = try #require(UserDefaults(suiteName: suiteName))
			let store = UserDefaultsSessionSnapshotStore(defaults: defaults)
			store.save(SessionSnapshot(user: SessionUser(personId: "41", screenName: "nick"), venue: nil))

			store.save(nil)

			#expect(store.savedSnapshot() == nil)
		}
	}
}
