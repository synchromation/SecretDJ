import SecretDJAPI
import SharedFeatures
import Testing

@testable import SecretDJ

/// ``APIClientMusicSearching`` — reads the signed-in session fresh on every
/// call (never captured once at construction time, matching
/// ``APIClientFeedLoadingSessionFeedTests``'s doc comment).
@MainActor
enum APIClientMusicSearchingTests {
	struct `Calling the endpoints` {
		@Test func `search throws notSignedIn instead of calling the endpoint when no session is signed in`() async {
			let sessionStore = SessionStore(
				snapshotStore: InMemorySessionSnapshotStore(),
				credentialStore: InMemoryCredentialStore(),
			)
			let searching = APIClientMusicSearching(
				client: PreviewAPIClient.broken(),
				sessionStore: sessionStore,
				venueId: "v1",
			)

			await #expect(throws: MusicSearchError.notSignedIn) {
				try await searching.search(query: "Queen", mode: .track)
			}
		}

		@Test func `search maps a transport failure to a connection error`() async {
			let sessionStore = makeSignedInSessionStore()
			let searching = APIClientMusicSearching(
				client: PreviewAPIClient.broken(),
				sessionStore: sessionStore,
				venueId: "v1",
			)

			await #expect(throws: MusicSearchError.connection) {
				try await searching.search(query: "Queen", mode: .track)
			}
		}

		@Test func `artistsAvailable maps a transport failure to a connection error`() async {
			let sessionStore = makeSignedInSessionStore()
			let searching = APIClientMusicSearching(
				client: PreviewAPIClient.broken(),
				sessionStore: sessionStore,
				venueId: "v1",
			)

			await #expect(throws: MusicSearchError.connection) {
				try await searching.artistsAvailable()
			}
		}

		@Test func `songs(forArtist:) maps a transport failure to a connection error`() async {
			let sessionStore = makeSignedInSessionStore()
			let searching = APIClientMusicSearching(
				client: PreviewAPIClient.broken(),
				sessionStore: sessionStore,
				venueId: "v1",
			)

			await #expect(throws: MusicSearchError.connection) {
				try await searching.songs(forArtist: "Coldplay")
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
