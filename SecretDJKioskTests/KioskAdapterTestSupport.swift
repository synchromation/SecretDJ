import SecretDJAPI

/// Shared fixture for the kiosk's ``APIClient``-backed adapter tests
/// (``KioskAtmosphereChangingTests``, ``KioskSongRequestingTests``,
/// ``KioskMachineControllingTests``, ``KioskLikeTogglingTests``) — mirrors
/// the consumer's own per-file `makeSignedInSessionStore()` helpers, pulled
/// into one place since four kiosk adapter test files need the identical
/// fixture.
@MainActor
func makeSignedInKioskSessionStore(
	personId: String = "p1",
	token: String = "t1",
	passwordHash: String = "h1",
) -> SessionStore {
	let sessionStore = SessionStore(
		snapshotStore: InMemorySessionSnapshotStore(),
		credentialStore: InMemoryCredentialStore(),
	)
	sessionStore.signIn(
		user: SessionUser(personId: personId, screenName: "venue"),
		venue: SessionVenue(venueId: "v1", name: "v1"),
		credential: APICredential(token: token, passwordHash: passwordHash),
	)
	return sessionStore
}
