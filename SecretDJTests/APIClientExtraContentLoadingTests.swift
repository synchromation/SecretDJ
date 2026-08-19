import SecretDJAPI
import Testing

@testable import SecretDJ

/// ``APIClientExtraContentLoading`` — reads the signed-in session fresh on
/// every call (never captured once at construction time) and rotates the
/// session's token when the response carries one. Mirrors
/// ``APIClientCheckingInTests``'s exact shape; the wire format itself
/// (`user`/`screenid`/`venue` parameters) is already covered by
/// `SecretDJAPI`'s own `FeedAPITests`.
@MainActor
enum APIClientExtraContentLoadingTests {
	struct `Calling the endpoint` {
		@Test func `throws instead of calling the endpoint when no session is signed in`() async {
			let sessionStore = SessionStore(
				snapshotStore: InMemorySessionSnapshotStore(),
				credentialStore: InMemoryCredentialStore(),
			)
			let loading = APIClientExtraContentLoading(client: PreviewAPIClient.broken(), sessionStore: sessionStore)

			await #expect(throws: NotSignedInExtraContentLoadingError()) {
				try await loading.loadExtraContent(venueId: nil, screen: .placesNearby)
			}
		}
	}
}
