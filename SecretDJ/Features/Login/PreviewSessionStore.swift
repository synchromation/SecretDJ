import SecretDJAPI

/// A signed-out ``SessionStore`` backed by in-memory stores — previews only,
/// never production (previews always inject fakes, per swiftui-views).
enum PreviewSessionStore {
	@MainActor
	static func signedOut() -> SessionStore {
		SessionStore(snapshotStore: InMemorySessionSnapshotStore(), credentialStore: InMemoryCredentialStore())
	}
}
