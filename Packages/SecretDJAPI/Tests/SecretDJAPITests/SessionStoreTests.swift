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

	@MainActor
	struct `Rotating the token` {
		@Test func `rotateToken updates the credential's token while keeping the password hash`() {
			let store = SessionStore(
				snapshotStore: InMemorySessionSnapshotStore(),
				credentialStore: InMemoryCredentialStore(),
			)
			store.signIn(
				user: SessionUser(personId: "41", screenName: "nick"),
				venue: nil,
				credential: APICredential(token: "old-token", passwordHash: "hash"),
			)

			store.rotateToken("new-token")

			#expect(store.credential == APICredential(token: "new-token", passwordHash: "hash"))
		}

		@Test func `rotateToken persists the updated credential to the credential store`() {
			let credentialStore = InMemoryCredentialStore()
			let store = SessionStore(snapshotStore: InMemorySessionSnapshotStore(), credentialStore: credentialStore)
			store.signIn(
				user: SessionUser(personId: "41", screenName: "nick"),
				venue: nil,
				credential: APICredential(token: "old-token", passwordHash: "hash"),
			)

			store.rotateToken("new-token")

			#expect(credentialStore.savedCredential() == APICredential(token: "new-token", passwordHash: "hash"))
		}

		@Test func `rotateToken while signed out does nothing`() {
			let credentialStore = InMemoryCredentialStore()
			let store = SessionStore(snapshotStore: InMemorySessionSnapshotStore(), credentialStore: credentialStore)

			store.rotateToken("new-token")

			#expect(store.credential == nil)
			#expect(credentialStore.saveInvocations.isEmpty)
		}
	}

	@MainActor
	struct `Updating the password hash` {
		@Test func `updatePasswordHash updates the credential's hash while keeping the token`() {
			let store = SessionStore(
				snapshotStore: InMemorySessionSnapshotStore(),
				credentialStore: InMemoryCredentialStore(),
			)
			store.signIn(
				user: SessionUser(personId: "41", screenName: "nick"),
				venue: nil,
				credential: APICredential(token: "tok", passwordHash: "old-hash"),
			)

			store.updatePasswordHash("new-hash")

			#expect(store.credential == APICredential(token: "tok", passwordHash: "new-hash"))
		}

		@Test func `updatePasswordHash persists the updated credential to the credential store`() {
			let credentialStore = InMemoryCredentialStore()
			let store = SessionStore(snapshotStore: InMemorySessionSnapshotStore(), credentialStore: credentialStore)
			store.signIn(
				user: SessionUser(personId: "41", screenName: "nick"),
				venue: nil,
				credential: APICredential(token: "tok", passwordHash: "old-hash"),
			)

			store.updatePasswordHash("new-hash")

			#expect(credentialStore.savedCredential() == APICredential(token: "tok", passwordHash: "new-hash"))
		}

		@Test func `updatePasswordHash while signed out does nothing`() {
			let credentialStore = InMemoryCredentialStore()
			let store = SessionStore(snapshotStore: InMemorySessionSnapshotStore(), credentialStore: credentialStore)

			store.updatePasswordHash("new-hash")

			#expect(store.credential == nil)
			#expect(credentialStore.saveInvocations.isEmpty)
		}
	}

	@MainActor
	struct `Updating the screen name` {
		@Test func `updateScreenName updates the user's screen name while keeping the personId`() {
			let store = SessionStore(
				snapshotStore: InMemorySessionSnapshotStore(),
				credentialStore: InMemoryCredentialStore(),
			)
			store.signIn(
				user: SessionUser(personId: "41", screenName: "OldName"),
				venue: nil,
				credential: APICredential(token: "tok", passwordHash: "hash"),
			)

			store.updateScreenName("NewName")

			#expect(store.user == SessionUser(personId: "41", screenName: "NewName"))
		}

		@Test func `updateScreenName persists the updated snapshot, keeping the venue`() {
			let snapshotStore = InMemorySessionSnapshotStore()
			let store = SessionStore(snapshotStore: snapshotStore, credentialStore: InMemoryCredentialStore())
			let venue = SessionVenue(venueId: "7", name: "The Fox")
			store.signIn(
				user: SessionUser(personId: "41", screenName: "OldName"),
				venue: venue,
				credential: APICredential(token: "tok", passwordHash: "hash"),
			)

			store.updateScreenName("NewName")

			#expect(snapshotStore.savedSnapshot() == SessionSnapshot(
				user: SessionUser(personId: "41", screenName: "NewName"),
				venue: venue,
			))
		}

		@Test func `updateScreenName while signed out does nothing`() {
			let snapshotStore = InMemorySessionSnapshotStore()
			let store = SessionStore(snapshotStore: snapshotStore, credentialStore: InMemoryCredentialStore())

			store.updateScreenName("NewName")

			#expect(store.user == nil)
			#expect(snapshotStore.saveInvocations.isEmpty)
		}
	}
}
