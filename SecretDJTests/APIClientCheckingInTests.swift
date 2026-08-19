import SecretDJAPI
import Testing

@testable import SecretDJ

/// ``APIClientCheckingIn`` — reads the signed-in session fresh on every call
/// (never captured once at construction time, matching
/// ``APIClientFeedLoadingSessionFeedTests``'s doc comment) and rotates the
/// session's token when the response carries one. Mirrors
/// ``APIClientLikeTogglingTests``'s exact shape; the wire format itself
/// (`user`/`venue`/`scope` parameters, the `Sections[0].Custom.Response`
/// decode) is already covered by `SecretDJAPI`'s own `CheckInAPITests`.
@MainActor
enum APIClientCheckingInTests {
	struct `Calling the endpoint` {
		@Test func `throws notSignedIn instead of calling the endpoint when no session is signed in`() async {
			let sessionStore = SessionStore(
				snapshotStore: InMemorySessionSnapshotStore(),
				credentialStore: InMemoryCredentialStore(),
			)
			let checkingIn = APIClientCheckingIn(client: PreviewAPIClient.broken(), sessionStore: sessionStore)

			await #expect(throws: CheckInError.notSignedIn) {
				try await checkingIn.checkIn(venueId: "v1")
			}
		}

		@Test func `maps a transport failure to a connection error`() async {
			let sessionStore = makeSignedInSessionStore()
			let checkingIn = APIClientCheckingIn(client: PreviewAPIClient.broken(), sessionStore: sessionStore)

			await #expect(throws: CheckInError.connection) {
				try await checkingIn.checkIn(venueId: "v1")
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
