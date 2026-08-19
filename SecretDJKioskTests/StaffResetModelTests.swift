import Observability
import SecretDJAPI
import Testing

@testable import SecretDJKiosk

/// Covers ``StaffResetModel``'s side effects: signing the session out and
/// running every registered ``KioskCacheClearing`` — no `exit(0)` (PLAN.md
/// S7.1's staff reset "clears session, skin, and caches, returns to
/// sign-in").
@MainActor
struct StaffResetModelTests {
	private final class RecordingCacheClearing: KioskCacheClearing {
		private(set) var clearCallCount = 0

		func clear() {
			clearCallCount += 1
		}
	}

	private static func makeSignedInSessionStore() -> SessionStore {
		let store = SessionStore(
			snapshotStore: InMemorySessionSnapshotStore(),
			credentialStore: InMemoryCredentialStore(),
		)
		store.signIn(
			user: SessionUser(personId: "41", screenName: "TheDuke"),
			venue: SessionVenue(venueId: "v1", name: "v1"),
			credential: APICredential(token: "tok", passwordHash: "hash"),
		)
		return store
	}

	@Test func `signs the session out`() {
		let sessionStore = StaffResetModelTests.makeSignedInSessionStore()
		let model = StaffResetModel(sessionStore: sessionStore, cacheClearing: [])

		model.performReset()

		#expect(sessionStore.isSignedIn == false)
	}

	@Test func `clears every registered cache`() {
		let firstClearer = RecordingCacheClearing()
		let secondClearer = RecordingCacheClearing()
		let model = StaffResetModel(
			sessionStore: StaffResetModelTests.makeSignedInSessionStore(),
			cacheClearing: [firstClearer, secondClearer],
		)

		model.performReset()

		#expect(firstClearer.clearCallCount == 1)
		#expect(secondClearer.clearCallCount == 1)
	}

	@Test func `leaves an interaction breadcrumb`() {
		let recorder = RecordingDestination()
		let model = StaffResetModel(
			sessionStore: StaffResetModelTests.makeSignedInSessionStore(),
			cacheClearing: [],
			observability: ObservabilityPipeline(destinations: [recorder]),
		)

		model.performReset()

		#expect(recorder.breadcrumbs.contains(.interaction(description: "staffReset")))
	}
}
