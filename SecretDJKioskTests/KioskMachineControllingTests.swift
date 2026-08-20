import SecretDJAPI
import SharedFeatures
import Testing

@testable import SecretDJKiosk

/// ``KioskMachineControlling`` — the kiosk-local mirror of the consumer's
/// own `APIClientMachineControllingTests`. D13's own note
/// (``KioskMachineControlling``'s doc comment): this endpoint stays
/// unreachable on a real kiosk because the server never grants a venue
/// account the skip/blacklist actions that would show its buttons — these
/// tests only prove the adapter itself maps its two transport-independent
/// failures correctly, same as every other kiosk adapter here.
@MainActor
enum KioskMachineControllingTests {
	struct `Calling the endpoint` {
		@Test func `throws notSignedIn instead of calling the endpoint when no session is signed in`() async {
			let sessionStore = SessionStore(
				snapshotStore: InMemorySessionSnapshotStore(),
				credentialStore: InMemoryCredentialStore(),
			)
			let machineControlling = KioskMachineControlling(
				client: PreviewAPIClient.broken(),
				sessionStore: sessionStore,
			)

			await #expect(throws: MachineControlError.notSignedIn) {
				try await machineControlling.moderate(.skip, songId: "1", venueId: "v1")
			}
		}

		@Test func `maps a transport failure to a connection error`() async {
			let sessionStore = makeSignedInKioskSessionStore()
			let machineControlling = KioskMachineControlling(
				client: PreviewAPIClient.broken(),
				sessionStore: sessionStore,
			)

			await #expect(throws: MachineControlError.connection) {
				try await machineControlling.moderate(.neverPlay, songId: "1", venueId: "v1")
			}
		}
	}
}
