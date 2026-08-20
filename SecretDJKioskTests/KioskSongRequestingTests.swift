import SecretDJAPI
import SharedFeatures
import Testing

@testable import SecretDJKiosk

/// ``KioskSongRequesting`` — the kiosk-local mirror of the consumer's own
/// `APIClientSongRequestingTests`.
@MainActor
enum KioskSongRequestingTests {
	struct `Calling the endpoint` {
		@Test func `throws notSignedIn instead of calling the endpoint when no session is signed in`() async {
			let sessionStore = SessionStore(
				snapshotStore: InMemorySessionSnapshotStore(),
				credentialStore: InMemoryCredentialStore(),
			)
			let songRequesting = KioskSongRequesting(client: PreviewAPIClient.broken(), sessionStore: sessionStore)

			await #expect(throws: SongRequestError.notSignedIn) {
				try await songRequesting.requestSong(songId: "1", venueId: "v1")
			}
		}

		@Test func `maps a transport failure to a connection error`() async {
			let sessionStore = makeSignedInKioskSessionStore()
			let songRequesting = KioskSongRequesting(client: PreviewAPIClient.broken(), sessionStore: sessionStore)

			await #expect(throws: SongRequestError.connection) {
				try await songRequesting.requestSong(songId: "1", venueId: "v1")
			}
		}
	}
}
