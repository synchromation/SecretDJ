import SecretDJAPI
import SharedFeatures
import Testing

@testable import SecretDJ

/// ``APIClientSongRequesting`` — reads the signed-in session fresh on every
/// call (never captured once at construction time, matching
/// ``APIClientAtmosphereChangingTests``'s doc comment) and rotates the
/// session's token when the response carries one.
@MainActor
enum APIClientSongRequestingTests {
	struct `Calling the endpoint` {
		@Test func `throws notSignedIn instead of calling the endpoint when no session is signed in`() async {
			let sessionStore = SessionStore(
				snapshotStore: InMemorySessionSnapshotStore(),
				credentialStore: InMemoryCredentialStore(),
			)
			let requesting = APIClientSongRequesting(client: PreviewAPIClient.broken(), sessionStore: sessionStore)

			await #expect(throws: SongRequestError.notSignedIn) {
				try await requesting.requestSong(songId: "1", venueId: "v1")
			}
		}

		@Test func `maps a transport failure to a connection error`() async {
			let sessionStore = makeSignedInSessionStore()
			let requesting = APIClientSongRequesting(client: PreviewAPIClient.broken(), sessionStore: sessionStore)

			await #expect(throws: SongRequestError.connection) {
				try await requesting.requestSong(songId: "1", venueId: "v1")
			}
		}
	}
}

// MARK: - Fixtures

@MainActor
private func makeSignedInSessionStore(
	personId: String = "p1",
	token: String = "t1",
	passwordHash: String = "h1",
) -> SessionStore {
	let sessionStore = SessionStore(
		snapshotStore: InMemorySessionSnapshotStore(),
		credentialStore: InMemoryCredentialStore(),
	)
	sessionStore.signIn(
		user: SessionUser(personId: personId, screenName: "dj"),
		venue: nil,
		credential: APICredential(token: token, passwordHash: passwordHash),
	)
	return sessionStore
}
