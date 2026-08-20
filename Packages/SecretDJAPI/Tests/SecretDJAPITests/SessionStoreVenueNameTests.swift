import Testing

@testable import SecretDJAPI

/// ``SessionStore/updateVenueName(_:)`` — mirrors ``SessionStoreTests``'s own
/// "Updating the screen name" struct, but for ``SessionStore/venue`` instead
/// of ``SessionStore/user``. Added for the kiosk's own venue-name resolution
/// (PLAN.md S7.4): sign-in's response carries only the venue id
/// (`SessionStore+KioskAuthenticatedSession`'s doc comment), so the real name
/// arrives later from whichever feed's `hiddenVenueDetails` section supplies
/// it, and gets folded in here.
enum SessionStoreVenueNameTests {
	@MainActor
	struct `Updating the venue name` {
		@Test func `updateVenueName updates the venue's name while keeping the venueId`() {
			let store = SessionStore(
				snapshotStore: InMemorySessionSnapshotStore(),
				credentialStore: InMemoryCredentialStore(),
			)
			store.signIn(
				user: SessionUser(personId: "41", screenName: "nick"),
				venue: SessionVenue(venueId: "7", name: "7"),
				credential: APICredential(token: "tok", passwordHash: "hash"),
			)

			store.updateVenueName("The Fox")

			#expect(store.venue == SessionVenue(venueId: "7", name: "The Fox"))
		}

		@Test func `updateVenueName persists the updated snapshot, keeping the user`() {
			let snapshotStore = InMemorySessionSnapshotStore()
			let store = SessionStore(snapshotStore: snapshotStore, credentialStore: InMemoryCredentialStore())
			let user = SessionUser(personId: "41", screenName: "nick")
			store.signIn(
				user: user,
				venue: SessionVenue(venueId: "7", name: "7"),
				credential: APICredential(token: "tok", passwordHash: "hash"),
			)

			store.updateVenueName("The Fox")

			#expect(snapshotStore.savedSnapshot() == SessionSnapshot(
				user: user,
				venue: SessionVenue(venueId: "7", name: "The Fox"),
			))
		}

		@Test func `updateVenueName while signed out does nothing`() {
			let snapshotStore = InMemorySessionSnapshotStore()
			let store = SessionStore(snapshotStore: snapshotStore, credentialStore: InMemoryCredentialStore())

			store.updateVenueName("The Fox")

			#expect(store.venue == nil)
			#expect(snapshotStore.saveInvocations.isEmpty)
		}

		@Test func `updateVenueName while signed in with no venue checked in does nothing`() {
			let snapshotStore = InMemorySessionSnapshotStore()
			let store = SessionStore(snapshotStore: snapshotStore, credentialStore: InMemoryCredentialStore())
			store.signIn(
				user: SessionUser(personId: "41", screenName: "nick"),
				venue: nil,
				credential: APICredential(token: "tok", passwordHash: "hash"),
			)

			store.updateVenueName("The Fox")

			#expect(store.venue == nil)
		}
	}
}
