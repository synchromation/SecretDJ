import SecretDJAPI
import Testing

@testable import SecretDJKiosk

/// Covers ``SessionStore/signIn(from:passwordHash:)`` (the
/// `KioskAuthenticatedSession` overload) — the forced-venue handling
/// PLAN.md S7.1 calls out explicitly: "the `KioskSignIn` fixture shows
/// `Venues.Force` — store the forced venue in the session."
@MainActor
struct SessionStoreKioskAuthenticatedSessionTests {
	private func makeSessionStore() -> SessionStore {
		SessionStore(snapshotStore: InMemorySessionSnapshotStore(), credentialStore: InMemoryCredentialStore())
	}

	@Test func `signs in with the forced venue id standing in for the not-yet-known venue name`() {
		let store = makeSessionStore()
		let session = KioskAuthenticatedSession(
			personId: "41",
			screenName: "TheDuke",
			forcedVenueId: "00002162_f22f602a",
			rotatedToken: "tok",
		)

		let result = store.signIn(from: session, passwordHash: "hash")

		#expect(result == true)
		#expect(store.user == SessionUser(personId: "41", screenName: "TheDuke"))
		#expect(store.venue == SessionVenue(venueId: "00002162_f22f602a", name: "00002162_f22f602a"))
		#expect(store.credential == APICredential(token: "tok", passwordHash: "hash"))
	}

	@Test func `leaves the session untouched when the response carried no rotated token`() {
		let store = makeSessionStore()
		let session = KioskAuthenticatedSession(
			personId: "41",
			screenName: "TheDuke",
			forcedVenueId: "v1",
			rotatedToken: nil,
		)

		let result = store.signIn(from: session, passwordHash: "hash")

		#expect(result == false)
		#expect(store.isSignedIn == false)
	}
}
