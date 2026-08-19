import SecretDJAPI
import SharedFeatures
import Testing

@testable import SecretDJ

/// ``APIClientAtmosphereChanging`` — reads the signed-in session fresh on
/// every call (never captured once at construction time, matching
/// ``APIClientFeedLoadingSessionFeedTests``'s doc comment) and rotates the
/// session's token when the response carries one.
@MainActor
enum APIClientAtmosphereChangingTests {
	struct `Calling the endpoint` {
		@Test func `throws notSignedIn instead of calling the endpoint when no session is signed in`() async {
			let sessionStore = SessionStore(
				snapshotStore: InMemorySessionSnapshotStore(),
				credentialStore: InMemoryCredentialStore(),
			)
			let atmosphereChanging = APIClientAtmosphereChanging(
				client: PreviewAPIClient.broken(),
				sessionStore: sessionStore,
			)

			await #expect(throws: AtmosphereChangeError.notSignedIn) {
				try await atmosphereChanging.changeAtmosphere(itemId: 1, venueId: "v1", minutes: 30)
			}
		}

		@Test func `maps a transport failure to a connection error`() async {
			let sessionStore = makeSignedInSessionStore()
			let atmosphereChanging = APIClientAtmosphereChanging(
				client: PreviewAPIClient.broken(),
				sessionStore: sessionStore,
			)

			await #expect(throws: AtmosphereChangeError.connection) {
				try await atmosphereChanging.changeAtmosphere(itemId: 1, venueId: "v1", minutes: 30)
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
