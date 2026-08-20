import SecretDJAPI
import SharedFeatures
import Testing

@testable import SecretDJKiosk

/// ``KioskAtmosphereChanging`` — the kiosk-local mirror of the consumer's
/// own `APIClientAtmosphereChangingTests`, covering the same two
/// transport-independent branches (no live network call happens in either).
@MainActor
enum KioskAtmosphereChangingTests {
	struct `Calling the endpoint` {
		@Test func `throws notSignedIn instead of calling the endpoint when no session is signed in`() async {
			let sessionStore = SessionStore(
				snapshotStore: InMemorySessionSnapshotStore(),
				credentialStore: InMemoryCredentialStore(),
			)
			let atmosphereChanging = KioskAtmosphereChanging(
				client: PreviewAPIClient.broken(),
				sessionStore: sessionStore,
			)

			await #expect(throws: AtmosphereChangeError.notSignedIn) {
				try await atmosphereChanging.changeAtmosphere(itemId: 1, venueId: "v1", minutes: 30)
			}
		}

		@Test func `maps a transport failure to a connection error`() async {
			let sessionStore = makeSignedInKioskSessionStore()
			let atmosphereChanging = KioskAtmosphereChanging(
				client: PreviewAPIClient.broken(),
				sessionStore: sessionStore,
			)

			await #expect(throws: AtmosphereChangeError.connection) {
				try await atmosphereChanging.changeAtmosphere(itemId: 1, venueId: "v1", minutes: 30)
			}
		}
	}
}
