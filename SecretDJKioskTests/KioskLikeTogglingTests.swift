import SecretDJAPI
import SecretDJDomain
import SharedFeatures
import Testing

@testable import SecretDJKiosk

/// ``KioskLikeToggling`` — the kiosk-local mirror of the consumer's own
/// `APIClientLikeTogglingTests`.
@MainActor
enum KioskLikeTogglingTests {
	struct `Calling the endpoint` {
		@Test func `throws notSignedIn instead of calling the endpoint when no session is signed in`() async {
			let sessionStore = SessionStore(
				snapshotStore: InMemorySessionSnapshotStore(),
				credentialStore: InMemoryCredentialStore(),
			)
			let likeToggling = KioskLikeToggling(client: PreviewAPIClient.broken(), sessionStore: sessionStore)

			await #expect(throws: LikeError.notSignedIn) {
				try await likeToggling.like(itemId: "1", venueId: "v1", type: .song)
			}
		}

		@Test func `maps a transport failure to a connection error`() async {
			let sessionStore = makeSignedInKioskSessionStore()
			let likeToggling = KioskLikeToggling(client: PreviewAPIClient.broken(), sessionStore: sessionStore)

			await #expect(throws: LikeError.connection) {
				try await likeToggling.unlike(itemId: "1", venueId: "v1", type: .song)
			}
		}
	}
}
