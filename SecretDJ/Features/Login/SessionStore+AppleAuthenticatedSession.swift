import SecretDJAPI

extension SessionStore {
	/// Signs the session in from a successful `applesignin` call, using the
	/// server-issued credential as the signing password hash (unlike native
	/// sign-in/sign-up, whose credential is the caller's own SHA-1 hash —
	/// ``AppleAuthenticatedSession``'s doc comment). No venue is
	/// force-joined (`applesignin` never returns one).
	///
	/// - Returns: `false`, leaving the session untouched, when the response
	///   carried no rotated token or no issued credential to sign future
	///   requests with.
	@discardableResult
	func signIn(from session: AppleAuthenticatedSession) -> Bool {
		guard let token = session.rotatedToken, let issuedCredential = session.issuedCredential else {
			return false
		}

		signIn(
			user: SessionUser(personId: session.personId, screenName: session.screenName),
			venue: nil,
			credential: APICredential(token: token, passwordHash: issuedCredential),
		)
		return true
	}
}
