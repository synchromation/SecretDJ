import Foundation
import SecretDJAPI
import SecretDJDomain
import Testing

@testable import SecretDJ

/// ``APIClientLikeToggling`` — reads the signed-in session fresh on every
/// call (never captured once at construction time, matching
/// ``APIClientFeedLoadingSessionFeedTests``'s doc comment) and rotates the
/// session's token when the response carries one.
@MainActor
enum APIClientLikeTogglingTests {
	struct `Calling the endpoint` {
		@Test func `throws notSignedIn instead of calling the endpoint when no session is signed in`() async {
			let sessionStore = SessionStore(
				snapshotStore: InMemorySessionSnapshotStore(),
				credentialStore: InMemoryCredentialStore(),
			)
			let toggling = APIClientLikeToggling(client: PreviewAPIClient.broken(), sessionStore: sessionStore)

			await #expect(throws: LikeError.notSignedIn) {
				try await toggling.like(itemId: "v1", venueId: "v1", type: .venue)
			}
		}

		@Test func `maps a transport failure to a connection error`() async {
			let sessionStore = makeSignedInSessionStore()
			let toggling = APIClientLikeToggling(client: PreviewAPIClient.broken(), sessionStore: sessionStore)

			await #expect(throws: LikeError.connection) {
				try await toggling.like(itemId: "v1", venueId: "v1", type: .venue)
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
