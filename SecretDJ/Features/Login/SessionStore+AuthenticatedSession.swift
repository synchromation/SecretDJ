import SecretDJAPI

extension SessionStore {
	/// Signs the session in from a successful `signin`/`createuser` call,
	/// pairing the server's rotated token with the caller's own SHA-1
	/// password hash — `signin`/`createuser`'s credential is that hash,
	/// never anything the server returns (``LoginDetails``'s doc comment).
	/// No venue is force-joined here: the consumer app's login flow doesn't
	/// use `signin`'s optional forced-venue id (the kiosk's does).
	///
	/// - Returns: `false`, leaving the session untouched, when the response
	///   carried no token to sign future requests with.
	@discardableResult
	func signIn(from session: AuthenticatedSession, passwordHash: String) -> Bool {
		guard let token = session.rotatedToken else {
			return false
		}

		signIn(
			user: SessionUser(personId: session.personId, screenName: session.screenName),
			venue: nil,
			credential: APICredential(token: token, passwordHash: passwordHash),
		)
		return true
	}
}
