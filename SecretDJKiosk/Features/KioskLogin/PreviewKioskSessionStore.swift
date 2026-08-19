import SecretDJAPI

/// Signed-in and signed-out kiosk ``SessionStore``s backed by in-memory
/// stores — previews only, never production (mirrors the consumer's own
/// `PreviewSessionStore`; swiftui-views: previews always inject fakes).
enum PreviewKioskSessionStore {
	@MainActor
	static func signedOut() -> SessionStore {
		SessionStore(snapshotStore: InMemorySessionSnapshotStore(), credentialStore: InMemoryCredentialStore())
	}

	@MainActor
	static func signedIn(venueId: String = "00002162_f22f602a") -> SessionStore {
		let store = SessionStore(
			snapshotStore: InMemorySessionSnapshotStore(),
			credentialStore: InMemoryCredentialStore(),
		)
		store.signIn(
			user: SessionUser(personId: "41", screenName: "TheDuke"),
			venue: SessionVenue(venueId: venueId, name: venueId),
			credential: APICredential(token: "tok", passwordHash: "hash"),
		)
		return store
	}
}
