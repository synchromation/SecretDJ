import Testing

@testable import SecretDJAPI

enum SessionStoreTests {
	@MainActor
	struct `Starting up` {
		@Test func `starts signed out with no persisted session`() {
			let store = SessionStore(
				snapshotStore: InMemorySessionSnapshotStore(),
				credentialStore: InMemoryCredentialStore(),
			)

			#expect(store.user == nil)
			#expect(store.venue == nil)
			#expect(store.credential == nil)
			#expect(store.isSignedIn == false)
		}

		@Test func `restores the signed-in user, venue, and credential when both stores have data`() {
			let user = SessionUser(personId: "41", screenName: "nick")
			let venue = SessionVenue(venueId: "7", name: "The Fox")
			let credential = APICredential(token: "tok", passwordHash: "hash")
			let snapshotStore = InMemorySessionSnapshotStore(snapshot: SessionSnapshot(user: user, venue: venue))
			let credentialStore = InMemoryCredentialStore(credential: credential)

			let store = SessionStore(snapshotStore: snapshotStore, credentialStore: credentialStore)

			#expect(store.user == user)
			#expect(store.venue == venue)
			#expect(store.credential == credential)
			#expect(store.isSignedIn == true)
		}

		@Test func `restores with no venue when the saved snapshot has none`() {
			let user = SessionUser(personId: "41", screenName: "nick")
			let credential = APICredential(token: "tok", passwordHash: "hash")
			let snapshotStore = InMemorySessionSnapshotStore(snapshot: SessionSnapshot(user: user, venue: nil))
			let credentialStore = InMemoryCredentialStore(credential: credential)

			let store = SessionStore(snapshotStore: snapshotStore, credentialStore: credentialStore)

			#expect(store.venue == nil)
			#expect(store.isSignedIn == true)
		}

		@Test func `treats a snapshot without a saved credential as signed out`() {
			let user = SessionUser(personId: "41", screenName: "nick")
			let snapshotStore = InMemorySessionSnapshotStore(snapshot: SessionSnapshot(user: user, venue: nil))
			let credentialStore = InMemoryCredentialStore()

			let store = SessionStore(snapshotStore: snapshotStore, credentialStore: credentialStore)

			#expect(store.user == nil)
			#expect(store.isSignedIn == false)
		}

		@Test func `treats a saved credential without a snapshot as signed out`() {
			let credential = APICredential(token: "tok", passwordHash: "hash")
			let snapshotStore = InMemorySessionSnapshotStore()
			let credentialStore = InMemoryCredentialStore(credential: credential)

			let store = SessionStore(snapshotStore: snapshotStore, credentialStore: credentialStore)

			#expect(store.credential == nil)
			#expect(store.isSignedIn == false)
		}

		@Test func `starting up with no persisted session writes nothing to either store`() {
			let snapshotStore = InMemorySessionSnapshotStore()
			let credentialStore = InMemoryCredentialStore()

			_ = SessionStore(snapshotStore: snapshotStore, credentialStore: credentialStore)

			#expect(snapshotStore.saveInvocations.isEmpty)
			#expect(credentialStore.saveInvocations.isEmpty)
		}
	}

	@MainActor
	struct `Signing in` {
		@Test func `signIn sets the user, venue, and credential`() {
			let store = SessionStore(
				snapshotStore: InMemorySessionSnapshotStore(),
				credentialStore: InMemoryCredentialStore(),
			)
			let user = SessionUser(personId: "41", screenName: "nick")
			let venue = SessionVenue(venueId: "7", name: "The Fox")
			let credential = APICredential(token: "tok", passwordHash: "hash")

			store.signIn(user: user, venue: venue, credential: credential)

			#expect(store.user == user)
			#expect(store.venue == venue)
			#expect(store.credential == credential)
		}

		@Test func `signIn marks the session as signed in`() {
			let store = SessionStore(
				snapshotStore: InMemorySessionSnapshotStore(),
				credentialStore: InMemoryCredentialStore(),
			)

			store.signIn(
				user: SessionUser(personId: "41", screenName: "nick"),
				venue: nil,
				credential: APICredential(token: "tok", passwordHash: "hash"),
			)

			#expect(store.isSignedIn == true)
		}

		@Test func `signIn persists the snapshot to the snapshot store`() {
			let snapshotStore = InMemorySessionSnapshotStore()
			let store = SessionStore(snapshotStore: snapshotStore, credentialStore: InMemoryCredentialStore())
			let user = SessionUser(personId: "41", screenName: "nick")
			let venue = SessionVenue(venueId: "7", name: "The Fox")

			store.signIn(user: user, venue: venue, credential: APICredential(token: "tok", passwordHash: "hash"))

			#expect(snapshotStore.savedSnapshot() == SessionSnapshot(user: user, venue: venue))
		}

		@Test func `signIn persists the credential to the credential store`() {
			let credentialStore = InMemoryCredentialStore()
			let store = SessionStore(snapshotStore: InMemorySessionSnapshotStore(), credentialStore: credentialStore)
			let credential = APICredential(token: "tok", passwordHash: "hash")

			store.signIn(user: SessionUser(personId: "41", screenName: "nick"), venue: nil, credential: credential)

			#expect(credentialStore.savedCredential() == credential)
		}

		@Test func `signIn with no venue persists a snapshot with no venue`() {
			let snapshotStore = InMemorySessionSnapshotStore()
			let store = SessionStore(snapshotStore: snapshotStore, credentialStore: InMemoryCredentialStore())
			let user = SessionUser(personId: "41", screenName: "nick")

			store.signIn(user: user, venue: nil, credential: APICredential(token: "tok", passwordHash: "hash"))

			#expect(snapshotStore.savedSnapshot() == SessionSnapshot(user: user, venue: nil))
		}
	}

	@MainActor
	struct `Signing out` {
		@Test func `signOut clears the user, venue, and credential`() {
			let store = SessionStore(
				snapshotStore: InMemorySessionSnapshotStore(),
				credentialStore: InMemoryCredentialStore(),
			)
			store.signIn(
				user: SessionUser(personId: "41", screenName: "nick"),
				venue: SessionVenue(venueId: "7", name: "The Fox"),
				credential: APICredential(token: "tok", passwordHash: "hash"),
			)

			store.signOut()

			#expect(store.user == nil)
			#expect(store.venue == nil)
			#expect(store.credential == nil)
		}

		@Test func `signOut marks the session as signed out`() {
			let store = SessionStore(
				snapshotStore: InMemorySessionSnapshotStore(),
				credentialStore: InMemoryCredentialStore(),
			)
			store.signIn(
				user: SessionUser(personId: "41", screenName: "nick"),
				venue: nil,
				credential: APICredential(token: "tok", passwordHash: "hash"),
			)

			store.signOut()

			#expect(store.isSignedIn == false)
		}

		@Test func `signOut wipes the snapshot store`() {
			let snapshotStore = InMemorySessionSnapshotStore()
			let store = SessionStore(snapshotStore: snapshotStore, credentialStore: InMemoryCredentialStore())
			store.signIn(
				user: SessionUser(personId: "41", screenName: "nick"),
				venue: nil,
				credential: APICredential(token: "tok", passwordHash: "hash"),
			)

			store.signOut()

			#expect(snapshotStore.savedSnapshot() == nil)
		}

		@Test func `signOut wipes the credential store`() {
			let credentialStore = InMemoryCredentialStore()
			let store = SessionStore(snapshotStore: InMemorySessionSnapshotStore(), credentialStore: credentialStore)
			store.signIn(
				user: SessionUser(personId: "41", screenName: "nick"),
				venue: nil,
				credential: APICredential(token: "tok", passwordHash: "hash"),
			)

			store.signOut()

			#expect(credentialStore.savedCredential() == nil)
		}

		@Test func `signOut when already signed out still wipes both stores`() {
			let snapshotStore = InMemorySessionSnapshotStore()
			let credentialStore = InMemoryCredentialStore()
			let store = SessionStore(snapshotStore: snapshotStore, credentialStore: credentialStore)

			store.signOut()

			#expect(snapshotStore.saveInvocations == [nil])
			#expect(credentialStore.saveInvocations == [nil])
		}
	}
}
