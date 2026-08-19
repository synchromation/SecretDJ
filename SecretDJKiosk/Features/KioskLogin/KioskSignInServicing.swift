/// The one auth call ``KioskSignInModel`` needs, thinned from
/// ``SecretDJAPI/APIClient`` to this feature's exact surface (ios-
/// architecture: a protocol seam per real dependency) — deliberately not a
/// reuse of the consumer app's own `AuthenticationServicing`: that protocol
/// is `internal` to the `SecretDJ` target (a different module), and its
/// surface is mostly kiosk-irrelevant (sign-up, Apple/Facebook, forgotten
/// password — none of which the kiosk has, per LEGACY.md: "a plain
/// username/password form, no Facebook/Apple sign-in on kiosk"). A thin
/// kiosk-local protocol is simpler than extracting a shared seam for a
/// single method neither app's screen actually needs to share.
protocol KioskSignInServicing: Sendable {
	/// `signin` — screen name plus the already-hashed password.
	func signIn(screenName: String, passwordHash: String) async throws(KioskSignInError) -> KioskAuthenticatedSession
}
