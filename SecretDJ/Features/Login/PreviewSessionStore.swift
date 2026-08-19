import SecretDJAPI

/// Signed-in and signed-out ``SessionStore``s backed by in-memory stores —
/// previews only, never production (previews always inject fakes, per
/// swiftui-views).
enum PreviewSessionStore {
	@MainActor
	static func signedOut() -> SessionStore {
		SessionStore(snapshotStore: InMemorySessionSnapshotStore(), credentialStore: InMemoryCredentialStore())
	}

	@MainActor
	static func signedIn(personId: String = "41", screenName: String = "TurboTim") -> SessionStore {
		let store = SessionStore(
			snapshotStore: InMemorySessionSnapshotStore(),
			credentialStore: InMemoryCredentialStore(),
		)
		store.signIn(
			user: SessionUser(personId: personId, screenName: screenName),
			venue: nil,
			credential: APICredential(token: "tok", passwordHash: "hash"),
		)
		return store
	}
}
